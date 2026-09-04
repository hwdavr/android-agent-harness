#!/usr/bin/env bash
# Verifies that slice planning explicitly classifies production journeys and
# assigns navigation/lifecycle acceptance rows to an instrumented test.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
FEATURE_DIR_INPUT="${1:-}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

usage() {
  echo "Usage: bash harness/scripts/check-journey-planning-contract.sh <feature-directory>" >&2
  exit 2
}

[ -n "$FEATURE_DIR_INPUT" ] || usage

case "$FEATURE_DIR_INPUT" in
  /*)
    FEATURE_DIR="$FEATURE_DIR_INPUT"
    case "$FEATURE_DIR" in
      "$PROJECT_ROOT"/docs/product/*) ;;
      *) fail "feature directory must stay under docs/product/" ;;
    esac
    ;;
  *)
    FEATURE_DIR="${FEATURE_DIR_INPUT#./}"
    case "$FEATURE_DIR" in
      docs/product/*) ;;
      *) fail "feature directory must be under docs/product/" ;;
    esac
    FEATURE_DIR="$PROJECT_ROOT/$FEATURE_DIR"
    ;;
esac

case "$FEATURE_DIR" in
  *..*) fail "feature directory path must not contain '..'" ;;
esac

FEATURE_JSON="$FEATURE_DIR/feature_list.json"
CONTRACT="$FEATURE_DIR/sprint-contract.md"
[ -f "$FEATURE_JSON" ] || fail "missing $FEATURE_JSON"
[ -f "$CONTRACT" ] || fail "missing $CONTRACT"

JOURNEY_HEADER='| User story | Journey required | Journey reason | Journey acceptance test ID | Production entry point | Planned test file and method | User actions | Return boundary | Post-return assertion |'
ACCEPTANCE_HEADER='| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |'

grep -Eq '^## Production Journey Planning Contract([[:space:]]|$)' "$CONTRACT" \
  || fail "sprint-contract.md is missing the '## Production Journey Planning Contract' section"
grep -Fq "$JOURNEY_HEADER" "$CONTRACT" \
  || fail "sprint-contract.md must use the production journey planning table"
grep -Fq "$ACCEPTANCE_HEADER" "$CONTRACT" \
  || fail "sprint-contract.md must use the acceptance test traceability table"

trim() {
  value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_backticks() {
  value="$1"
  value="${value#\`}"
  value="${value%\`}"
  printf '%s' "$value"
}

is_placeholder() {
  value="$1"
  case "$value" in
    ""|"N/A"|"n/a"|*"{"*|*"}"*|*"[Class]"*|*"<"*|*">"*) return 0 ;;
    *) return 1 ;;
  esac
}

journey_rows=$(
  awk -F'|' '
    function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); return value }
    /^## Production Journey Planning Contract([[:space:]]|$)/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && /^\|[[:space:]]*User story[[:space:]]*\|/ { next }
    in_section && /^\|[[:space:]]*---/ { next }
    in_section && /^\|/ {
      story = trim($2)
      if (story ~ /^US-[0-9]+$/) {
        print story "\t" trim($3) "\t" trim($4) "\t" trim($5) "\t" trim($6) "\t" trim($7) "\t" trim($8) "\t" trim($9) "\t" trim($10)
      }
      next
    }
  ' "$CONTRACT"
)
[ -n "$journey_rows" ] || fail "production journey planning table has no parseable US-* rows"

acceptance_rows=$(
  awk -F'|' '
    function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); return value }
    /^\|[[:space:]]*Test ID[[:space:]]*\|[[:space:]]*Covers AC[[:space:]]*\|[[:space:]]*Test layer[[:space:]]*\|/ { in_table = 1; next }
    in_table && /^\|[[:space:]]*---/ { next }
    in_table && /^\|/ {
      test_id = trim($2)
      if (test_id ~ /^TC-US-[0-9]+-/) {
        print test_id "\t" trim($3) "\t" trim($4) "\t" trim($5) "\t" trim($6) "\t" trim($7) "\t" trim($8) "\t" trim($9)
      }
      next
    }
    in_table { in_table = 0 }
  ' "$CONTRACT"
)
[ -n "$acceptance_rows" ] || fail "sprint-contract.md has no parseable acceptance Test ID rows"

if ! jq -e '
  (.features | type == "array" and length > 0) and
  all(.features[];
    (.id | type == "string" and test("^US-[0-9]+$"))) and
  all(.features[];
    (.production_journey | type == "object") and
    (.production_journey.required | type == "boolean") and
    (.production_journey.reason | type == "string" and length > 0))
' "$FEATURE_JSON" >/dev/null 2>&1; then
  fail "every feature must declare production_journey.required (boolean) and a non-empty feature-specific production_journey.reason"
fi

feature_rows=$(jq -r '
  .features[] |
  [
    .id,
    (.production_journey.required | tostring),
    .production_journey.reason,
    (.production_journey.acceptance_test_id // ""),
    (.production_journey.production_entry_point // ""),
    (.production_journey.test_file // ""),
    (.production_journey.test_method // ""),
    (.production_journey.user_actions // ""),
    (.production_journey.return_boundary // ""),
    (.production_journey.post_return_assertion // "")
  ] | @tsv
' "$FEATURE_JSON")

feature_count=$(printf '%s\n' "$feature_rows" | wc -l | tr -d '[:space:]')
journey_count=$(printf '%s\n' "$journey_rows" | wc -l | tr -d '[:space:]')
[ "$feature_count" -eq "$journey_count" ] \
  || fail "every feature must have exactly one production journey planning row (features=$feature_count, rows=$journey_count)"

while IFS=$'\t' read -r row_story row_required row_reason row_acceptance_id row_entry row_target row_actions row_boundary row_assertion; do
  [ -n "$row_story" ] || continue
  if ! jq -e --arg id "$row_story" 'any(.features[]; .id == $id)' "$FEATURE_JSON" >/dev/null 2>&1; then
    fail "production journey planning table contains unknown user story $row_story"
  fi
done <<EOF
$journey_rows
EOF

nav_row=$(grep -E '^[[:space:]]*\|[[:space:]]*NAV[[:space:]]*\|' "$CONTRACT" | head -n 1 || true)
nav_required=0
case "$nav_row" in
  *"| Required |"*) nav_required=1 ;;
esac

required_journey_count=0
while IFS=$'\t' read -r feature_id required reason json_acceptance_id json_entry json_file json_method json_actions json_boundary json_assertion; do
  [ -n "$feature_id" ] || continue

  row_count=$(printf '%s\n' "$journey_rows" | awk -F '\t' -v id="$feature_id" '$1 == id { count += 1 } END { print count + 0 }')
  [ "$row_count" -eq 1 ] \
    || fail "$feature_id must have exactly one production journey planning row (found $row_count)"
  journey_row=$(printf '%s\n' "$journey_rows" | awk -F '\t' -v id="$feature_id" '$1 == id { print; exit }')
  IFS=$'\t' read -r story journey_required journey_reason journey_acceptance_id journey_entry journey_target journey_actions journey_boundary journey_assertion <<EOF
$journey_row
EOF
  journey_required=$(strip_backticks "$journey_required")
  journey_acceptance_id=$(strip_backticks "$journey_acceptance_id")
  journey_entry=$(strip_backticks "$journey_entry")
  journey_target=$(strip_backticks "$journey_target")
  journey_actions=$(strip_backticks "$journey_actions")
  journey_boundary=$(strip_backticks "$journey_boundary")
  journey_assertion=$(strip_backticks "$journey_assertion")

  expected_required="No"
  [ "$required" = "true" ] && expected_required="Yes"
  case "$journey_required" in
    "$expected_required") ;;
    *) fail "$feature_id production_journey.required=$required does not match planning row '$journey_required'" ;;
  esac

  [ "$journey_reason" = "$reason" ] \
    || fail "$feature_id journey reason differs between feature_list.json and sprint-contract.md"
  [ -n "$journey_reason" ] && ! is_placeholder "$journey_reason" \
    || fail "$feature_id needs a feature-specific production journey reason"

  if [ "$required" = "true" ]; then
    required_journey_count=$((required_journey_count + 1))
    is_placeholder "$journey_acceptance_id" \
      && fail "$feature_id requires journey_acceptance_id in the production journey planning row"
    is_placeholder "$journey_entry" \
      && fail "$feature_id requires journey_entry in the production journey planning row"
    is_placeholder "$journey_target" \
      && fail "$feature_id requires journey_target in the production journey planning row"
    is_placeholder "$journey_actions" \
      && fail "$feature_id requires journey_actions in the production journey planning row"
    is_placeholder "$journey_boundary" \
      && fail "$feature_id requires journey_boundary in the production journey planning row"
    is_placeholder "$journey_assertion" \
      && fail "$feature_id requires journey_assertion in the production journey planning row"

    [ "$journey_entry" = "$json_entry" ] \
      || fail "$feature_id production entry differs between feature_list.json and sprint-contract.md"
    [ "$journey_actions" = "$json_actions" ] \
      || fail "$feature_id user actions differ between feature_list.json and sprint-contract.md"
    [ "$journey_boundary" = "$json_boundary" ] \
      || fail "$feature_id return boundary differs between feature_list.json and sprint-contract.md"
    [ "$journey_assertion" = "$json_assertion" ] \
      || fail "$feature_id post-return assertion differs between feature_list.json and sprint-contract.md"

    planned_target=$(strip_backticks "$(trim "$journey_target")")
    json_target="$json_file#$json_method"
    [ "$planned_target" = "$json_target" ] \
      || fail "$feature_id planned test target '$planned_target' does not match feature_list.json '$json_target'"
    case "$json_file" in
      app/src/androidTest/*.kt) ;;
      *) fail "$feature_id production journey test file must be under app/src/androidTest/: $json_file" ;;
    esac
    case "$json_file" in
      *Test.kt) ;;
      *) fail "$feature_id production journey test file must end in Test.kt: $json_file" ;;
    esac
    printf '%s' "$json_method" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' \
      || fail "$feature_id has an invalid production journey test method '$json_method'"

    [ "$journey_acceptance_id" = "$json_acceptance_id" ] \
      || fail "$feature_id journey acceptance test ID differs between feature_list.json and sprint-contract.md"
    [ -n "$json_acceptance_id" ] \
      || fail "$feature_id must declare production_journey.acceptance_test_id"
    jq -e --arg feature_id "$feature_id" --arg test_id "$json_acceptance_id" '
      any(.features[]; .id == $feature_id and ((.acceptance_test_ids // []) | index($test_id)))
    ' "$FEATURE_JSON" >/dev/null 2>&1 \
      || fail "$feature_id journey acceptance test $json_acceptance_id is not in acceptance_test_ids"

    acceptance_row=$(printf '%s\n' "$acceptance_rows" | awk -F '\t' -v id="$json_acceptance_id" '$1 == id { print; exit }')
    [ -n "$acceptance_row" ] \
      || fail "$feature_id journey acceptance test $json_acceptance_id has no acceptance-test row"
    IFS=$'\t' read -r acceptance_id covers_ac test_layer test_target scenarios setup assertions command <<EOF
$acceptance_row
EOF
    printf '%s' "$test_layer" | grep -Fq "Instrumented UI" \
      || fail "$json_acceptance_id must be planned as an Instrumented UI acceptance test"
    acceptance_target=$(strip_backticks "$(trim "$test_target")")
    [ "$acceptance_target" = "$json_target" ] \
      || fail "$json_acceptance_id target '$acceptance_target' does not match planned journey target '$json_target'"
  else
    for value in "$journey_acceptance_id" "$journey_entry" "$journey_target" "$journey_actions" "$journey_boundary" "$journey_assertion"; do
      case "$value" in
        ""|"N/A"|"n/a") ;;
        *) fail "$feature_id is marked No but journey details must be empty or N/A" ;;
      esac
    done
    for value in "$json_acceptance_id" "$json_entry" "$json_file" "$json_method" "$json_actions" "$json_boundary" "$json_assertion"; do
      [ -z "$value" ] \
        || fail "$feature_id is marked No but feature_list.json contains journey details"
    done
  fi
done <<EOF
$feature_rows
EOF

[ "$nav_required" -eq 0 ] || [ "$required_journey_count" -gt 0 ] \
  || fail "NAV is Required but no user-story slice is classified as requiring a production journey"

navigation_signal_pattern='navigation|navigate|navhost|picker|saved[[:space:]]*state|savedstate|back[[:space:]]*stack|backstack|destination|re-?entry|post-?[[:space:]-]*return|pop[[:space:]]+back|return(s|ed|ing)?[[:space:]]+to'
while IFS=$'\t' read -r acceptance_id covers_ac test_layer test_target scenarios setup assertions command; do
  [ -n "$acceptance_id" ] || continue
  signal_text="$setup $assertions"
  if printf '%s' "$signal_text" | grep -Eiq "$navigation_signal_pattern"; then
    owner=$(printf '%s' "$acceptance_id" | sed -n 's/^TC-\(US-[0-9][0-9]*\)-.*/\1/p')
    [ -n "$owner" ] || fail "$acceptance_id has a navigation/lifecycle signal but no user-story owner"
    owner_required=$(jq -r --arg id "$owner" '.features[] | select(.id == $id) | .production_journey.required' "$FEATURE_JSON")
    [ "$owner_required" = "true" ] \
      || fail "$acceptance_id contains a navigation/lifecycle signal but $owner is not classified as a production journey"
    printf '%s' "$test_layer" | grep -Fq "Instrumented UI" \
      || fail "$acceptance_id contains a navigation/lifecycle signal and must include an Instrumented UI test layer"
  fi
done <<EOF
$acceptance_rows
EOF

echo "PASS: production journey planning covers $feature_count slice(s); $required_journey_count require a named production-entry instrumented journey."
