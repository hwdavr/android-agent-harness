#!/usr/bin/env bash
# Validates the machine-checkable boundary between harness-evaluation and
# harness-fix. Narrative reports cannot override failed gates or contradictory
# evidence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
FEATURE_INPUT="${1:-}"
MODE="${2:---evaluation}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [ -z "$FEATURE_INPUT" ]; then
  echo "Usage: bash harness/scripts/check-evaluation-fix-contract.sh <feature-directory> [--evaluation|--fix]" >&2
  exit 2
fi
[ "$MODE" = "--evaluation" ] || [ "$MODE" = "--fix" ] \
  || fail "mode must be --evaluation or --fix"

case "$FEATURE_INPUT" in
  /*)
    DOCS_DIR="$FEATURE_INPUT"
    case "$DOCS_DIR" in
      "$PROJECT_ROOT"/docs/product/*) ;;
      *) fail "feature directory must stay under docs/product/" ;;
    esac
    FEATURE_DIR="${DOCS_DIR#"$PROJECT_ROOT"/}"
    ;;
  *)
    FEATURE_DIR="${FEATURE_INPUT#./}"
    case "$FEATURE_DIR" in
      docs/product/*) ;;
      *) fail "feature directory must be under docs/product/" ;;
    esac
    DOCS_DIR="$PROJECT_ROOT/$FEATURE_DIR"
    ;;
esac

case "$FEATURE_DIR" in
  *..*) fail "feature directory path must not contain '..'" ;;
esac
[ -d "$DOCS_DIR" ] || fail "feature directory does not exist: $FEATURE_DIR"

FEATURE_SLUG=$(basename "$DOCS_DIR")
FEATURE_SLUG=$(printf '%s' "$FEATURE_SLUG" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
FEATURE_JSON="$DOCS_DIR/feature_list.json"
CONTRACT="$DOCS_DIR/sprint-contract.md"
RUBRIC="$DOCS_DIR/evaluator-rubric.md"
CODE_REVIEW="$DOCS_DIR/code_review_$FEATURE_SLUG.md"
TEST_REVIEW="$DOCS_DIR/test_review_$FEATURE_SLUG.md"
SUMMARY="$DOCS_DIR/summary_$FEATURE_SLUG.md"
PRODUCT_FILE="$PROJECT_ROOT/docs/product/product.md"

[ -f "$FEATURE_JSON" ] || fail "missing $FEATURE_JSON"
[ -f "$CONTRACT" ] || fail "missing $CONTRACT"
[ -f "$RUBRIC" ] || fail "missing $RUBRIC"
[ -f "$CODE_REVIEW" ] || fail "missing $CODE_REVIEW"
[ -f "$TEST_REVIEW" ] || fail "missing $TEST_REVIEW"
[ -f "$SUMMARY" ] || fail "missing $SUMMARY"
jq empty "$FEATURE_JSON" 2>/dev/null || fail "$FEATURE_JSON is not valid JSON"

TRACKER_ROW=$(grep -F "[${FEATURE_DIR}/]" "$PRODUCT_FILE" | head -n 1 || true)
[ -n "$TRACKER_ROW" ] || fail "product tracker has no row for $FEATURE_DIR"
TRACKER_STATUS=$(printf '%s\n' "$TRACKER_ROW" | awk -F'|' '{print $5}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
[ -n "$TRACKER_STATUS" ] || fail "product tracker row for $FEATURE_DIR has no status"

all_slices_passing() {
  jq -e '.features | type == "array" and length > 0 and all(.[]; .status == "passing")' \
    "$FEATURE_JSON" >/dev/null 2>&1 \
    || fail "all feature slices must be passing before review/fix completion"
}

validate_evidence() {
  local invalid bundle
  invalid=$(jq -r '
    .features[]?
    | (.evidence // [])[]?
    | select(
        ((.test_id // "") | type != "string" or length == 0) or
        ((.executed_command // "") | type != "string" or length == 0) or
        ((.result // "") | type != "string" or length == 0) or
        ((.exit_status // null) != 0) or
        (((.result // "") | ascii_downcase) | test("blocked|unavailable|skipped|stalled|terminated|failed|not run|pending"))
      )
    | .test_id // "<missing-test-id>"
  ' "$FEATURE_JSON")
  [ -z "$invalid" ] \
    || fail "passing evidence is missing fields, non-zero, or contradicts success: $(printf '%s' "$invalid" | tr '\n' ' ')"

  while IFS= read -r bundle; do
    [ -n "$bundle" ] || continue
    [ -d "$bundle" ] || fail "evidence references missing result bundle $bundle"
  done < <(jq -r '.features[]? | (.evidence // [])[]? | .result // "" | (try capture("result bundle (?<path>[^[:space:]]+)").path) // empty' "$FEATURE_JSON")
}

validate_acceptance_evidence() {
  local feature_id acceptance_id test_id
  while IFS=$'\t' read -r feature_id acceptance_id; do
    [ -n "$feature_id" ] || continue
    if printf '%s' "$acceptance_id" | grep -Eq '^TC-[A-Za-z0-9-]+$'; then
      test_id="$acceptance_id"
    else
      test_id=$(awk -F'|' -v wanted="$acceptance_id" '
        { test_id=$2; covered_ac=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", test_id); gsub(/^[[:space:]]+|[[:space:]]+$/, "", covered_ac) }
        covered_ac == wanted && test_id ~ /^TC-[A-Za-z0-9-]+$/ { print test_id; exit }
      ' "$CONTRACT")
    fi
    [ -n "$test_id" ] || fail "$feature_id acceptance ID $acceptance_id has no Test ID in sprint-contract.md"
    jq -e --arg owner "$feature_id" --arg test_id "$test_id" '
      any(.features[]? | select(.id == $owner) | (.evidence // [])[]?;
        .test_id == $test_id and .exit_status == 0)
    ' "$FEATURE_JSON" >/dev/null 2>&1 \
      || fail "$feature_id acceptance ID $acceptance_id has no successful evidence for $test_id"
  done < <(jq -r '.features[]? | .id as $id | (.acceptance_test_ids // [])[] | [$id, .] | @tsv' "$FEATURE_JSON")
}

validate_review_score() {
  local category category_count line score sum="0" count=0 expected overall overall_lines
  local categories="Correctness
Verification
Scope discipline
Reliability
Maintainability
Handoff readiness
Code & Test Review
Rule Applicability"

  while IFS= read -r category; do
    [ -n "$category" ] || continue
    category_count=$(awk -F'|' -v wanted="$category" '
      { value=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value) }
      value == wanted { count += 1 }
      END { print count + 0 }
    ' "$RUBRIC")
    [ "$category_count" -eq 1 ] \
      || fail "evaluator rubric must contain exactly one score row for '$category'"
    line=$(awk -F'|' -v wanted="$category" '
      { value=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value) }
      value == wanted { print; exit }
    ' "$RUBRIC")
    [ -n "$line" ] || fail "evaluator rubric is missing category score '$category'"
    score=$(printf '%s\n' "$line" | awk -F'|' '{value=$4; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); print value}')
    printf '%s' "$score" | grep -Eq '^(0|[1-5])([.][0-9]+)?$' \
      || fail "evaluator rubric category '$category' has invalid score '$score'"
    sum=$(awk -v left="$sum" -v right="$score" 'BEGIN { printf "%.6f", left + right }')
    count=$((count + 1))
  done <<EOF
$categories
EOF

  [ "$count" -eq 8 ] || fail "evaluator rubric must score exactly 8 categories"
  expected=$(awk -v total="$sum" -v count="$count" 'BEGIN { printf "%.1f", total / count }')
  overall_lines=$(grep -Ec '^### Overall:[[:space:]]*[0-5]([.][0-9]+)?[[:space:]]*/[[:space:]]*5[[:space:]]*$' "$RUBRIC" || true)
  [ "$overall_lines" -eq 1 ] || fail "evaluator rubric must contain exactly one numeric '### Overall: <score> / 5' line"
  overall=$(grep -E '^### Overall:[[:space:]]*[0-5]([.][0-9]+)?[[:space:]]*/[[:space:]]*5[[:space:]]*$' "$RUBRIC" | sed -E 's/^### Overall:[[:space:]]*([^[:space:]]+).*/\1/' | head -n 1)
  [ -n "$overall" ] || fail "evaluator rubric must contain one numeric '### Overall: <score> / 5' line"
  awk -v actual="$overall" -v expected="$expected" 'BEGIN { difference=actual-expected; if (difference < 0) difference=-difference; exit (difference <= 0.0001 ? 0 : 1) }' \
    || fail "overall score $overall does not match arithmetic mean $expected of the 8 category scores"

  if awk -v score="$overall" 'BEGIN { exit (score == 5.0 ? 0 : 1) }'; then
    grep -Eiq '^\*\*[[:space:]]*Accept[[:space:]]*\*\*$' "$RUBRIC" \
      || fail "a perfect overall score requires an Accept verdict"
    [ "$TRACKER_STATUS" = "To be human reviewed" ] \
      || fail "a perfect evaluation must route the tracker to 'To be human reviewed' (found '$TRACKER_STATUS')"
  else
    if grep -Eiq '^\*\*[[:space:]]*Accept[[:space:]]*\*\*$' "$RUBRIC"; then
      fail "a sub-perfect evaluation cannot use an Accept verdict"
    fi
    [ "$TRACKER_STATUS" = "To be fixed" ] \
      || fail "a sub-perfect evaluation must route the tracker to 'To be fixed' (found '$TRACKER_STATUS')"
  fi

  if awk -v score="$overall" 'BEGIN { exit (score == 5.0 ? 0 : 1) }'; then
    if awk '
      /^## Visual Verification Hard Gate/ { in_section=1; next }
      in_section && /^## / { exit }
      in_section && /:[[:space:]]*No[[:space:]]*$/ { found=1 }
      END { exit(found ? 0 : 1) }
    ' "$RUBRIC"; then
      fail "a perfect evaluation cannot contain a failed visual hard-gate item"
    fi
    if awk '
      /^## Rule Applicability Hard Gate/ { in_section=1; next }
      in_section && /^## / { exit }
      in_section && /:[[:space:]]*No[[:space:]]*$/ { found=1 }
      END { exit(found ? 0 : 1) }
    ' "$RUBRIC"; then
      fail "a perfect evaluation cannot contain a failed rule-applicability hard-gate item"
    fi
  fi
}

validate_fix_reports() {
  local required_block numbered status_lines overlay test_verdict_block verdict_block
  required_block=$(awk '
    /^## Required Findings/ { in_section=1; next }
    in_section && /^## Verdict/ { exit }
    in_section { print }
  ' "$CODE_REVIEW")
  numbered=$(printf '%s\n' "$required_block" | grep -Ec '^[0-9]+\.' || true)
  [ "$numbered" -gt 0 ] || fail "$CODE_REVIEW has no numbered Required Findings"
  status_lines=$(printf '%s\n' "$required_block" | grep -Ec '^   > \*\*Fix Status:\*\* (Fixed ✅|Won.t fix)' || true)
  [ "$status_lines" -eq "$numbered" ] \
    || fail "$CODE_REVIEW has $numbered findings but only $status_lines in-report fix statuses"
  if printf '%s\n' "$required_block" | grep -Fq 'Unresolved ⚠️'; then
    fail "$CODE_REVIEW still contains an Unresolved finding"
  fi

  overlay=$(awk '
    /^## Fix Status Overlay/ { in_section=1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$TEST_REVIEW")
  printf '%s\n' "$overlay" | grep -Fq 'Fix Status' \
    || fail "$TEST_REVIEW is missing the Fix Status column/overlay"
  if printf '%s\n' "$overlay" | grep -Fq 'Unresolved ⚠️'; then
    fail "$TEST_REVIEW still contains an Unresolved finding"
  fi
  if printf '%s\n' "$overlay" | awk -F'|' '
    /^\|/ && $0 !~ /^\|---/ && $0 !~ /^\|[[:space:]]*Source ID/ {
      status=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      if (status !~ /^Fixed ✅$/ && status !~ /^PASS \(unchanged\)$/ && status !~ /^Won.t fix/) bad=1
    }
    END { exit bad ? 0 : 1 }
  '; then
    fail "$TEST_REVIEW contains a traceability row without an explicit passing fix status"
  fi

  verdict_block=$(awk '/^## Verdict/ { in_section=1; next } in_section && /^## / { exit } in_section { print }' "$CODE_REVIEW")
  printf '%s\n' "$verdict_block" | grep -Fq 'Fix Pass:' \
    || fail "$CODE_REVIEW Verdict is missing the required Fix Pass summary"
  if printf '%s\n' "$verdict_block" | grep -Eiq 'REVISION REQUIRED|^\*\*(BLOCK|REVISE)'; then
    fail "$CODE_REVIEW Verdict still reports a non-passing outcome"
  fi
  grep -Fq '## Fix Pass Summary' "$TEST_REVIEW" \
    || fail "$TEST_REVIEW is missing the required Fix Pass Summary"
  test_verdict_block=$(awk '/^## Verdict/ { in_section=1; next } in_section && /^## / { exit } in_section { print }' "$TEST_REVIEW")
  if printf '%s\n' "$test_verdict_block" | grep -Eiq 'REVISION REQUIRED|^\*\*(BLOCK|REVISE)'; then
    fail "$TEST_REVIEW Verdict still reports a non-passing outcome"
  fi
}

validate_fix_stage_summary() {
  local stage_rows stage_count failed_rows
  stage_rows=$(awk '
    /^## Stage Status/ { in_section=1; next }
    in_section && /^## / { exit }
    in_section && /^\| Fix-Stage/ { print }
  ' "$SUMMARY")
  stage_count=$(printf '%s\n' "$stage_rows" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
  [ "$stage_count" -eq 6 ] || fail "$SUMMARY must record all six Fix-Stage rows"
  failed_rows=$(printf '%s\n' "$stage_rows" | grep -Evc '\|[[:space:]]*✅ Complete[[:space:]]*\|' || true)
  [ "$failed_rows" -eq 0 ] \
    || fail "$SUMMARY contains a blocked or incomplete fix stage; the pipeline cannot advance"
}

all_slices_passing
validate_evidence
validate_acceptance_evidence
HARNESS_PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/check-acceptance-test-traceability.sh" "$DOCS_DIR" --evaluate

if [ "$MODE" = "--evaluation" ]; then
  validate_review_score
  echo "PASS: evaluator score, hard-gate routing, acceptance evidence, and evidence consistency are valid."
else
  [ "$TRACKER_STATUS" = "To be human reviewed" ] \
    || fail "fix completion must route the tracker to 'To be human reviewed' (found '$TRACKER_STATUS')"
  validate_fix_reports
  validate_fix_stage_summary
  echo "PASS: fix reports, stage completion, acceptance evidence, and tracker routing are valid."
fi
