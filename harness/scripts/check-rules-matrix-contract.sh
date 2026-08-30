#!/usr/bin/env bash
# Validates that enforcement-matrix rows, summaries, and scripted owners match
# the repository's canonical rule-enforcement catalog.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CATALOG="$PROJECT_ROOT/harness/rules-matrix/rule-enforcement.json"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

usage() {
  echo "Usage: $0 [--root <project-root>] [--catalog <catalog-path>]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      [ "$#" -ge 2 ] || usage
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --catalog)
      [ "$#" -ge 2 ] || usage
      CATALOG="$2"
      shift 2
      ;;
    *) usage ;;
  esac
done

[ -f "$CATALOG" ] || fail "missing rule-enforcement catalog: $CATALOG"
command -v jq >/dev/null 2>&1 || fail "jq is required to validate the rule-enforcement catalog"

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

owner_exists() {
  case "$1" in
    architecture-script) [ -f "$PROJECT_ROOT/harness/scripts/check-architecture-rules.sh" ] ;;
    compose-script) [ -f "$PROJECT_ROOT/harness/scripts/check-compose-rules.sh" ] ;;
    localization-script) [ -f "$PROJECT_ROOT/harness/scripts/check-localization-rules.sh" ] ;;
    detekt) [ -f "$PROJECT_ROOT/detekt.yml" ] ;;
    *) return 1 ;;
  esac
}

matrix_count=$(jq '.matrices | length' "$CATALOG")
[ "$matrix_count" -gt 0 ] || fail "rule-enforcement catalog has no matrices"

matrix_index=0
while [ "$matrix_index" -lt "$matrix_count" ]; do
  matrix_id=$(jq -r ".matrices[$matrix_index].id" "$CATALOG")
  matrix_relative_path=$(jq -r ".matrices[$matrix_index].path" "$CATALOG")
  matrix_path="$PROJECT_ROOT/$matrix_relative_path"
  [ -f "$matrix_path" ] || fail "$matrix_id matrix is missing: $matrix_relative_path"

  duplicate_ids=$(jq -r ".matrices[$matrix_index].groups[].ids[]" "$CATALOG" | sort | uniq -d)
  [ -z "$duplicate_ids" ] || fail "$matrix_id catalog has duplicate rule IDs: $(printf '%s' "$duplicate_ids" | tr '\n' ' ')"

  expected_rule_count=$(jq ".matrices[$matrix_index].groups | map(.ids | length) | add" "$CATALOG")
  actual_rule_count=$(grep -Ec '^\|[[:space:]]*[0-9]+\.[0-9]+[[:space:]]*\|' "$matrix_path" || true)
  [ "$actual_rule_count" -eq "$expected_rule_count" ] || fail "$matrix_id matrix has $actual_rule_count rule rows; catalog declares $expected_rule_count"

  group_count=$(jq ".matrices[$matrix_index].groups | length" "$CATALOG")
  group_index=0
  while [ "$group_index" -lt "$group_count" ]; do
    summary_label=$(jq -r ".matrices[$matrix_index].groups[$group_index].summary_label" "$CATALOG")
    expected_enforcement=$(jq -r ".matrices[$matrix_index].groups[$group_index].matrix_enforcement" "$CATALOG")
    group_ids=$(jq -r ".matrices[$matrix_index].groups[$group_index].ids[]" "$CATALOG")
    group_count_value=$(printf '%s\n' "$group_ids" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    group_list=$(printf '%s\n' "$group_ids" | awk 'NR == 1 { value = $0; next } { value = value ", " $0 } END { print value }')
    expected_summary="| $summary_label | $group_count_value | $group_list |"
    grep -Fxq "$expected_summary" "$matrix_path" \
      || fail "$matrix_id summary is stale or malformed for '$summary_label'; expected: $expected_summary"

    while IFS= read -r rule_id; do
      [ -n "$rule_id" ] || continue
      matching_rows=$(awk -F'|' -v id="$rule_id" '
        function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); return value }
        /^\|[[:space:]]*[0-9]+\.[0-9]+[[:space:]]*\|/ && trim($2) == id { print trim($4) }
      ' "$matrix_path")
      matching_count=$(printf '%s\n' "$matching_rows" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
      [ "$matching_count" -eq 1 ] || fail "$matrix_id rule $rule_id must have exactly one matrix row"
      actual_enforcement=$(printf '%s\n' "$matching_rows" | sed -n '1p')
      [ "$actual_enforcement" = "$expected_enforcement" ] \
        || fail "$matrix_id rule $rule_id has enforcement '$actual_enforcement'; catalog requires '$expected_enforcement'"

      if printf '%s' "$expected_enforcement" | grep -Fq 'Scripted'; then
        owner=$(jq -r --arg id "$rule_id" ".matrices[$matrix_index].groups[$group_index].owners[\$id] // empty" "$CATALOG")
        [ -n "$owner" ] || fail "$matrix_id scripted rule $rule_id has no catalog owner"
        owner_exists "$owner" || fail "$matrix_id scripted rule $rule_id names missing or unknown owner '$owner'"
      fi
    done <<EOF
$group_ids
EOF

    group_index=$((group_index + 1))
  done

  expected_total_summary="| **Total rules** | **$expected_rule_count** |"
  grep -Fq "$expected_total_summary" "$matrix_path" \
    || fail "$matrix_id total is stale; expected '$expected_total_summary'"

  matrix_index=$((matrix_index + 1))
done

echo "PASS: rule-enforcement catalog matches all matrix rows, summary counts, and scripted owners."
