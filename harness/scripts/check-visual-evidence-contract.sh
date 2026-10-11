#!/usr/bin/env bash
# Ensures visual acceptance is a deterministic JVM Roborazzi comparison against
# an approved Pen export. Instrumented tests remain behavior evidence only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_DIR="${1:-}"
MODE="${2:---evaluate}"
ROOT_DIR="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [ -z "$FEATURE_DIR" ]; then
  echo "Usage: bash harness/scripts/check-visual-evidence-contract.sh <feature-directory> [--planning|--evaluate]" >&2
  exit 2
fi
[ "$MODE" = "--planning" ] || [ "$MODE" = "--evaluate" ] || fail "mode must be --planning or --evaluate"

FEATURE_JSON="$FEATURE_DIR/feature_list.json"
CONTRACT="$FEATURE_DIR/sprint-contract.md"
[ -f "$FEATURE_JSON" ] || fail "missing $FEATURE_JSON"
[ -f "$CONTRACT" ] || fail "missing $CONTRACT"

VISUAL_OWNER_COUNT=$(jq '[.features[]? | select(.requires_visual_verification == true)] | length' "$FEATURE_JSON")
if [ "$VISUAL_OWNER_COUNT" -eq 0 ]; then
  echo "PASS: no visual-verification owner is declared."
  exit 0
fi
[ "$VISUAL_OWNER_COUNT" -eq 1 ] || fail "feature_list.json must declare exactly one visual-verification owner"

VISUAL_OWNER=$(jq -r '.features[] | select(.requires_visual_verification == true) | .id' "$FEATURE_JSON")
CONTRACT_ROWS=$(grep -E "^\\|[[:space:]]*TC-${VISUAL_OWNER}-VIS-[^|[:space:]]+[[:space:]]*\\|" "$CONTRACT" || true)
[ -n "$CONTRACT_ROWS" ] || fail "visual-verification owner $VISUAL_OWNER has no visual rows in sprint-contract.md"

CONTRACT_IDS=$(printf '%s\n' "$CONTRACT_ROWS" | sed -n 's/^|[[:space:]]*\(TC-[^|[:space:]]*-VIS-[^|[:space:]]*\)[[:space:]]*|.*/\1/p')
[ -n "$CONTRACT_IDS" ] || fail "visual rows for $VISUAL_OWNER have no parseable Test IDs"

extract_target() {
  local row="$1"
  local target
  target=$(printf '%s\n' "$row" | sed -n -E 's/.*`(app\/src\/test\/[^`|[:space:]]*RoborazziTest\.kt#[A-Za-z_][A-Za-z0-9_]*)`.*/\1/p' | head -n 1)
  if [ -z "$target" ]; then
    target=$(printf '%s\n' "$row" | sed -n -E 's/.*(app\/src\/test\/[^|[:space:]]*RoborazziTest\.kt#[A-Za-z_][A-Za-z0-9_]*).*/\1/p' | head -n 1)
  fi
  printf '%s' "$target"
}

for test_id in $CONTRACT_IDS; do
  CONTRACT_ROW=$(printf '%s\n' "$CONTRACT_ROWS" | grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" || true)
  TARGET=$(extract_target "$CONTRACT_ROW")
  [ -n "$TARGET" ] || fail "$test_id must name a dedicated app/src/test/*RoborazziTest.kt#method target"
  printf '%s\n' "$CONTRACT_ROW" | grep -Fq 'verifyRoborazziDebug' \
    || fail "$test_id must declare a verifyRoborazziDebug command"
  printf '%s\n' "$CONTRACT_ROW" | grep -Fq -- '--tests' \
    || fail "$test_id Roborazzi command must scope the named method with --tests"
done

FEATURE_IDS=$(jq -r --arg owner "$VISUAL_OWNER" '
  .features[]
  | select(.id == $owner)
  | (.acceptance_test_ids // [])[]
  | select(test("-VIS-"))
' "$FEATURE_JSON")

for test_id in $CONTRACT_IDS; do
  printf '%s\n' "$FEATURE_IDS" | grep -Fxq "$test_id" \
    || fail "$test_id is declared in sprint-contract.md but missing from feature_list.json acceptance_test_ids"
done
for test_id in $FEATURE_IDS; do
  printf '%s\n' "$CONTRACT_IDS" | grep -Fxq "$test_id" \
    || fail "$test_id is in feature_list.json but missing from sprint-contract.md"
done

VISUAL_COMMANDS=$(jq -r --arg owner "$VISUAL_OWNER" '
  .features[]
  | select(.id == $owner)
  | (.verification // [])[]
  | select(test("verifyRoborazzi(Debug)?"))
' "$FEATURE_JSON")
[ -n "$VISUAL_COMMANDS" ] || fail "visual owner $VISUAL_OWNER has no verifyRoborazziDebug verification command"
while IFS= read -r visual_command; do
  [ -n "$visual_command" ] || continue
  printf '%s\n' "$visual_command" | grep -Fq 'verifyRoborazziDebug' \
    || fail "Roborazzi visual verification commands must run verifyRoborazziDebug"
  printf '%s\n' "$visual_command" | grep -Eq 'recordRoborazziDebug|verifyAndRecordRoborazziDebug' \
    && fail "implementation-recording Roborazzi commands are not acceptance evidence"
done <<EOF
$VISUAL_COMMANDS
EOF

if [ "$MODE" = "--planning" ]; then
  echo "PASS: Roborazzi visual methods and contract rows are aligned for planning."
  exit 0
fi

TARGET_MANIFEST="$FEATURE_DIR/visual_evidence/visual-target.json"
ANCHOR_REPORT="$FEATURE_DIR/visual_evidence/reference-anchor-verification.md"
[ -f "$TARGET_MANIFEST" ] || fail "every visual feature requires visual_evidence/visual-target.json"
[ -f "$ANCHOR_REPORT" ] || fail "missing $ANCHOR_REPORT; visual evidence needs reference-anchor verification"

jq -e '.comparison.engine == "roborazzi"' "$TARGET_MANIFEST" >/dev/null \
  || fail "visual target comparison must use roborazzi engine"
jq -e '.comparison.content_alignment == "exact"' "$TARGET_MANIFEST" >/dev/null \
  || fail "Roborazzi comparison requires exact content within the declared scope"
jq -e '.comparison.scope == "screen" or .comparison.scope == "component"' "$TARGET_MANIFEST" >/dev/null \
  || fail "Roborazzi comparison must declare comparison.scope as screen or component"

PEN_SOURCE=$(jq -r '.pen_source // empty' "$TARGET_MANIFEST")
PEN_NODE_ID=$(jq -r '.pen_node_id // empty' "$TARGET_MANIFEST")
[ -n "$PEN_SOURCE" ] || fail "Pen visual targets must declare pen_source in visual-target.json"
[ -n "$PEN_NODE_ID" ] || fail "Pen visual targets must declare pen_node_id in visual-target.json"
case "$PEN_SOURCE" in
  /*|*..*/*..*) fail "pen_source must stay under the project or sibling UI_design folder: $PEN_SOURCE" ;;
esac
[ -s "$ROOT_DIR/$PEN_SOURCE" ] || fail "pen_source does not exist: $PEN_SOURCE"

grep -Fq "## Reference Anchor Verification" "$ANCHOR_REPORT" \
  || fail "$ANCHOR_REPORT has no '## Reference Anchor Verification' section"
grep -Fq "| Visual Test ID | Reference anchor | JVM proof | Measured relationship | Reference PNG | Result |" "$ANCHOR_REPORT" \
  || fail "$ANCHOR_REPORT has no required Roborazzi reference-anchor table header"

for test_id in $CONTRACT_IDS; do
  CONTRACT_ROW=$(printf '%s\n' "$CONTRACT_ROWS" | grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" || true)
  TARGET=$(extract_target "$CONTRACT_ROW")
  TEST_FILE="${TARGET%%#*}"
  TEST_METHOD="${TARGET#*#}"
  SOURCE_FILE="$ROOT_DIR/$TEST_FILE"
  [ -f "$SOURCE_FILE" ] || fail "$test_id Roborazzi source is missing: $TEST_FILE"
  grep -Eq "^[[:space:]]*((public|private|protected|internal|suspend|inline|operator|infix|override|final|open)[[:space:]]+)*fun[[:space:]]+$TEST_METHOD[[:space:]]*\\(" "$SOURCE_FILE" \
    || fail "$test_id declared Roborazzi method is missing: $TEST_FILE#$TEST_METHOD"
  grep -Fq 'captureRoboImage' "$SOURCE_FILE" \
    || fail "$test_id Roborazzi method source must call captureRoboImage()"

  CONTENT_STATE=$(printf '%s\n' "$CONTRACT_ROW" | sed -n -E 's/.*contentState:[[:space:]]*`([^`]+)`.*/\1/p' | head -n 1)
  [ -n "$CONTENT_STATE" ] || fail "$test_id must declare contentState: \`<state_id>\`"
  STATE_JSON=$(jq -c --arg state "$CONTENT_STATE" '.states[$state] // empty' "$TARGET_MANIFEST")
  [ -n "$STATE_JSON" ] && [ "$STATE_JSON" != "null" ] \
    || fail "$test_id contentState $CONTENT_STATE is not declared in visual-target.json"
  REFERENCE_ASSET=$(printf '%s' "$STATE_JSON" | jq -r '.reference // empty')
  case "$REFERENCE_ASSET" in
    design/mockup_*.png) ;;
    *) fail "$test_id content state must reference an approved design/mockup_*.png asset" ;;
  esac
  [ -s "$FEATURE_DIR/$REFERENCE_ASSET" ] \
    || fail "$test_id references missing or empty Pen export $REFERENCE_ASSET"

  REPORT_ROWS=$(grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" "$ANCHOR_REPORT" || true)
  REPORT_ROW_COUNT=$(printf '%s\n' "$REPORT_ROWS" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
  [ "$REPORT_ROW_COUNT" -eq 1 ] \
    || fail "$ANCHOR_REPORT must contain exactly one reference-anchor row for $test_id"
  REPORT_ROW=$(printf '%s\n' "$REPORT_ROWS" | sed '/^[[:space:]]*$/d')
  printf '%s\n' "$REPORT_ROW" | grep -Eq 'testTag:[[:space:]]*`[^`]+`' \
    || fail "$test_id reference-anchor row must name a visual bounds testTag"
  printf '%s\n' "$REPORT_ROW" | grep -Fq "#$TEST_METHOD" \
    || fail "$test_id reference-anchor row must name $TEST_METHOD"
  printf '%s\n' "$REPORT_ROW" | grep -Eq '[A-Za-z]+Bounds(\.[A-Za-z]+)?[[:space:]]*(==|>=|<=|>|<)' \
    || fail "$test_id reference-anchor row must record a concrete bounds relationship"
  printf '%s\n' "$REPORT_ROW" | grep -Fq "$REFERENCE_ASSET" \
    || fail "$test_id reference-anchor row must cite $REFERENCE_ASSET"
  printf '%s\n' "$REPORT_ROW" | grep -Eq '\|[[:space:]]*PASS[[:space:]]*\|[[:space:]]*$' \
    || fail "$test_id reference-anchor row must end with PASS"

  EVIDENCE_COUNT=$(jq --arg owner "$VISUAL_OWNER" --arg id "$test_id" '
    [
      .features[]
      | select(.id == $owner)
      | (.evidence // [])[]
      | select(.test_id == $id and .exit_status == 0 and ((.executed_command // "") | contains("verifyRoborazziDebug")))
    ] | length
  ' "$FEATURE_JSON")
  [ "$EVIDENCE_COUNT" -gt 0 ] \
    || fail "$test_id has no successful verifyRoborazziDebug evidence in feature_list.json"

  bash "$SCRIPT_DIR/check-rendered-output-contract.sh" \
    --project-root "$ROOT_DIR" \
    --test-file "$TEST_FILE" \
    --test-method "$TEST_METHOD" \
    --claim "$CONTRACT_ROW"
done

echo "PASS: Roborazzi visual methods, Pen exports, successful evidence, and reference-anchor proof are aligned."
