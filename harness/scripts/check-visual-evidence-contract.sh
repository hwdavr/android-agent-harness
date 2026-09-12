#!/usr/bin/env bash
# Ensures every final visual verification command is declared in the sprint
# contract, has successful connected-test evidence, and is accompanied by
# reference-anchor proof before a feature passes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_DIR="${1:-}"
MODE="${2:---evaluate}"

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
ROOT_DIR="${HARNESS_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
[ -f "$FEATURE_JSON" ] || fail "missing $FEATURE_JSON"
[ -f "$CONTRACT" ] || fail "missing $CONTRACT"

VISUAL_OWNER_COUNT=$(jq '[.features[]? | select(.requires_visual_verification == true)] | length' "$FEATURE_JSON")
if [ "$VISUAL_OWNER_COUNT" -eq 0 ]; then
  echo "PASS: no visual-verification owner is declared."
  exit 0
fi
[ "$VISUAL_OWNER_COUNT" -eq 1 ] || fail "feature_list.json must declare exactly one visual-verification owner"

VISUAL_OWNER=$(jq -r '.features[] | select(.requires_visual_verification == true) | .id' "$FEATURE_JSON")
CONTRACT_ROWS=$(grep -E "^\|[[:space:]]*TC-${VISUAL_OWNER}-VIS-[^|[:space:]]+[[:space:]]*\|" "$CONTRACT" || true)
[ -n "$CONTRACT_ROWS" ] || fail "visual-verification owner $VISUAL_OWNER has no visual rows in sprint-contract.md"

CONTRACT_IDS=$(printf '%s\n' "$CONTRACT_ROWS" | sed -n 's/^|[[:space:]]*\(TC-[^|[:space:]]*-VIS-[^|[:space:]]*\)[[:space:]]*|.*/\1/p')
[ -n "$CONTRACT_IDS" ] || fail "visual rows for $VISUAL_OWNER have no parseable Test IDs"

VISUAL_DETAIL_ROWS=$(printf '%s\n' "$CONTRACT_ROWS" | grep -E 'VisualFlowTest(\.kt)?#[A-Za-z_][A-Za-z0-9_]*' || true)
[ -n "$VISUAL_DETAIL_ROWS" ] \
  || fail "visual rows for $VISUAL_OWNER must name a dedicated *VisualFlowTest.kt method"
while IFS= read -r contract_row; do
  [ -n "$contract_row" ] || continue
  printf '%s\n' "$contract_row" | grep -Eq 'VisualFlowTest(\.kt)?#[A-Za-z_][A-Za-z0-9_]*' \
    || fail "every visual row for $VISUAL_OWNER must name a dedicated *VisualFlowTest.kt method"
  printf '%s\n' "$contract_row" | grep -Eq -- "-Pandroid\.testInstrumentationRunnerArguments\.class=[^[:space:]\"']*VisualFlowTest#[A-Za-z_][A-Za-z0-9_]*" \
    || fail "every visual row for $VISUAL_OWNER must declare a method-scoped VisualFlowTest command"
done <<EOF
$CONTRACT_ROWS
EOF

FEATURE_IDS=$(jq -r --arg owner "$VISUAL_OWNER" '
  .features[]
  | select(.id == $owner)
  | (.acceptance_test_ids // [])[]
  | select(test("-VIS-"))
' "$FEATURE_JSON")

for test_id in $CONTRACT_IDS; do
  printf '%s\n' "$FEATURE_IDS" | grep -Fxq "$test_id" \
    || fail "$test_id is declared in sprint-contract.md but missing from feature_list.json acceptance_test_ids"

  EVIDENCE_COUNT=$(jq --arg owner "$VISUAL_OWNER" --arg id "$test_id" '
    [
      .features[]
      | select(.id == $owner)
      | (.evidence // [])[]
      | select(.test_id == $id and .exit_status == 0 and ((.executed_command // "") | contains("connectedDebugAndroidTest")))
    ] | length
  ' "$FEATURE_JSON")
  if [ "$MODE" = "--evaluate" ]; then
    [ "$EVIDENCE_COUNT" -gt 0 ] \
      || fail "$test_id has no successful connected-test evidence in feature_list.json"
  fi
done

for test_id in $FEATURE_IDS; do
  printf '%s\n' "$CONTRACT_IDS" | grep -Fxq "$test_id" \
    || fail "$test_id is in feature_list.json but missing from sprint-contract.md"
done

VISUAL_COMMANDS=$(jq -r --arg owner "$VISUAL_OWNER" '
  .features[]
  | select(.id == $owner)
  | (.verification // [])[]
  | select(test("connectedDebugAndroidTest")
    and test("testInstrumentationRunnerArguments.class=.*VisualFlowTest#[A-Za-z_][A-Za-z0-9_]*"))
' "$FEATURE_JSON")
[ -n "$VISUAL_COMMANDS" ] \
  || fail "visual owner $VISUAL_OWNER has no method-scoped VisualFlowTest verification command"
VISUAL_METHODS=""
while IFS= read -r command; do
  [ -n "$command" ] || continue
  method=$(printf '%s\n' "$command" | sed -n 's/.*#\([^[:space:]\"]*\).*/\1/p')
  [ -n "$method" ] || continue
  VISUAL_METHODS="$VISUAL_METHODS
$method"
  printf '%s\n' "$CONTRACT_ROWS" | grep -Fq "$method" \
    || fail "visual verification method $method is not named by a $VISUAL_OWNER visual row"
done <<EOF
$VISUAL_COMMANDS
EOF

CONTRACT_METHODS=$(printf '%s\n' "$CONTRACT_ROWS" | sed -n 's/.*#\([^`|[:space:]]*\).*/\1/p')
[ -n "$CONTRACT_METHODS" ] || fail "visual rows for $VISUAL_OWNER have no parseable test methods"
for method in $CONTRACT_METHODS; do
  printf '%s\n' "$VISUAL_METHODS" | grep -Fxq "$method" \
    || fail "visual contract method $method is not listed in feature_list.json verification"
done

# A component-only composition cannot prove app-shell chrome. Make shell claims explicit at
# planning time and require the named visual test source to invoke the declared production root.
for test_id in $CONTRACT_IDS; do
  CONTRACT_ROW=$(printf '%s\n' "$CONTRACT_ROWS" | grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" || true)
  if ! printf '%s\n' "$CONTRACT_ROW" | grep -Eqi \
    'app[[:space:]-]*shell|full[[:space:]-]*page[[:space:]-]*shell|bottom[[:space:]-]*navigation|navigationbar|system[[:space:]-]*bar'; then
    continue
  fi

  printf '%s\n' "$CONTRACT_ROW" | grep -Fq "Capture scope: app-shell" \
    || fail "$test_id claims app-shell chrome and must declare Capture scope: app-shell"
  PRODUCTION_ROOT=$(printf '%s\n' "$CONTRACT_ROW" |
    sed -n 's/.*production root:[[:space:]]*`\([A-Za-z_][A-Za-z0-9_]*\)`.*/\1/p' | head -n 1)
  [ -n "$PRODUCTION_ROOT" ] \
    || fail "$test_id app-shell visual row must name production root: \`<ComposableOrActivity>\`"

  VISUAL_TARGET=$(printf '%s\n' "$CONTRACT_ROW" |
    sed -n -E 's/.*`([^`]*VisualFlowTest(\.kt)?#[A-Za-z_][A-Za-z0-9_]*)`.*/\1/p' | head -n 1)
  if [ -z "$VISUAL_TARGET" ]; then
    VISUAL_TARGET=$(printf '%s\n' "$CONTRACT_ROW" |
      sed -n -E 's/.*(app\/src\/androidTest\/[^|[:space:]]*VisualFlowTest(\.kt)?#[A-Za-z_][A-Za-z0-9_]*).*/\1/p' | head -n 1)
  fi
  [ -n "$VISUAL_TARGET" ] \
    || fail "$test_id app-shell visual row must name a VisualFlowTest.kt#method target"
  VISUAL_FILE="${VISUAL_TARGET%%#*}"
  [ -f "$ROOT_DIR/$VISUAL_FILE" ] \
    || fail "$test_id app-shell visual test source is missing: $VISUAL_FILE"
  grep -Eq "$PRODUCTION_ROOT[[:space:]]*[<(]" "$ROOT_DIR/$VISUAL_FILE" \
    || fail "$test_id app-shell visual test $VISUAL_FILE must invoke declared production root $PRODUCTION_ROOT"
done

if [ "$MODE" = "--evaluate" ]; then
  GOLDEN_DIR="$ROOT_DIR/UX/golden-baselines"
  ANCHOR_REPORT="$FEATURE_DIR/visual_evidence/reference-anchor-verification.md"
  [ -f "$ANCHOR_REPORT" ] || fail "missing $ANCHOR_REPORT; visual evidence needs reference-anchor verification"
  grep -Fq "## Reference Anchor Verification" "$ANCHOR_REPORT" \
    || fail "$ANCHOR_REPORT has no '## Reference Anchor Verification' section"
  grep -Fq "| Visual Test ID | Reference anchor | Runtime proof | Measured relationship | Actual screenshot | Result |" "$ANCHOR_REPORT" \
    || fail "$ANCHOR_REPORT has no required reference-anchor table header"

  REFERENCE_ASSET=$(sed -n 's/^\*\*Reference design\*\*: `\(design\/[^`]*\)`[[:space:]]*$/\1/p' "$ANCHOR_REPORT" | head -n 1)
  [ -n "$REFERENCE_ASSET" ] \
    || fail "$ANCHOR_REPORT must declare one backticked design/ reference asset"
  case "$REFERENCE_ASSET" in
    *..*) fail "$ANCHOR_REPORT reference asset must stay under design/" ;;
  esac
  [ -s "$FEATURE_DIR/$REFERENCE_ASSET" ] \
    || fail "$ANCHOR_REPORT references missing or empty design asset $REFERENCE_ASSET"

  SEEN_SCREENSHOT_PATHS=""
  for test_id in $CONTRACT_IDS; do
    CONTRACT_ROW=$(printf '%s\n' "$CONTRACT_ROWS" | grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" || true)
    VISUAL_TARGET=$(printf '%s\n' "$CONTRACT_ROW" | sed -n -E 's/.*`([^`]*VisualFlowTest(\.kt)?#[A-Za-z_][A-Za-z0-9_]*)`.*/\1/p' | head -n 1)
    if [ -z "$VISUAL_TARGET" ]; then
      VISUAL_TARGET=$(printf '%s\n' "$CONTRACT_ROW" | sed -n -E 's/.*(app\/src\/androidTest\/[^|[:space:]]*VisualFlowTest(\.kt)?#[A-Za-z_][A-Za-z0-9_]*).*/\1/p' | head -n 1)
    fi
    [ -n "$VISUAL_TARGET" ] \
      || fail "$test_id visual row must name a VisualFlowTest.kt#method target"
    VISUAL_FILE="${VISUAL_TARGET%%#*}"
    VISUAL_METHOD="${VISUAL_TARGET#*#}"
    case "$VISUAL_FILE" in
      app/src/androidTest/*.kt) ;;
      *) fail "$test_id visual test must be under app/src/androidTest/: $VISUAL_FILE" ;;
    esac
    bash "$SCRIPT_DIR/check-rendered-output-contract.sh" \
      --project-root "$ROOT_DIR" \
      --test-file "$VISUAL_FILE" \
      --test-method "$VISUAL_METHOD" \
      --claim "$CONTRACT_ROW"
    SCREENSHOT_PATH=$(printf '%s\n' "$CONTRACT_ROW" | grep -oE 'visual_evidence/[[:alnum:]_./-]+\.png' | head -n 1 || true)
    [ -n "$SCREENSHOT_PATH" ] \
      || fail "$test_id has no visual_evidence PNG artifact path in sprint-contract.md"
    if printf '%s\n' "$SEEN_SCREENSHOT_PATHS" | grep -Fxq "$SCREENSHOT_PATH"; then
      fail "${SCREENSHOT_PATH} is used by more than one visual row"
    fi
    SEEN_SCREENSHOT_PATHS="${SEEN_SCREENSHOT_PATHS}${SCREENSHOT_PATH}"$'\n'
    case "$SCREENSHOT_PATH" in
      *..*) fail "$test_id visual evidence path must stay under visual_evidence/" ;;
    esac
    [ -s "$FEATURE_DIR/$SCREENSHOT_PATH" ] \
      || fail "$test_id is missing non-empty screenshot $SCREENSHOT_PATH"
    SCREENSHOT_SIZE=$(wc -c < "$FEATURE_DIR/$SCREENSHOT_PATH" | tr -d ' ')
    MIN_SCREENSHOT_BYTES=5120
    [ "$SCREENSHOT_SIZE" -ge "$MIN_SCREENSHOT_BYTES" ] \
      || fail "$test_id screenshot $SCREENSHOT_PATH is only ${SCREENSHOT_SIZE} bytes (minimum ${MIN_SCREENSHOT_BYTES}); likely a blank or transparent capture"

    # Golden promotion is part of slice approval: every contract screenshot that is
    # not declared anchor-only must have a promoted golden baseline so the pixel
    # regression gate has a binding reference.
    REFERENCE_MAP="$FEATURE_DIR/visual_evidence/reference-map.json"
    MAP_ENTRY_TYPE="missing"
    if [ -f "$REFERENCE_MAP" ]; then
      MAP_ENTRY_TYPE=$(jq -r --arg f "$(basename "$SCREENSHOT_PATH")" \
        'if type == "object" and has($f) then (.[$f] | type) else "missing" end' \
        "$REFERENCE_MAP" 2>/dev/null || echo "missing")
    fi
    if [ "$MAP_ENTRY_TYPE" != "null" ]; then
      GOLDEN_BASELINE="$GOLDEN_DIR/$(basename "$SCREENSHOT_PATH")"
      [ -s "$GOLDEN_BASELINE" ] \
        || fail "$test_id screenshot $SCREENSHOT_PATH has no promoted golden baseline at $GOLDEN_BASELINE; approve the capture and promote it: bash harness/scripts/compare-visual-evidence.sh --promote-golden \"$FEATURE_DIR/$SCREENSHOT_PATH\" --name \"$(basename "${SCREENSHOT_PATH%.png}")\""
    fi

    REPORT_ROWS=$(grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" "$ANCHOR_REPORT" || true)
    REPORT_ROW_COUNT=$(printf '%s\n' "$REPORT_ROWS" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    [ "$REPORT_ROW_COUNT" -eq 1 ] \
      || fail "$ANCHOR_REPORT must contain exactly one reference-anchor row for $test_id"
    REPORT_ROW=$(printf '%s\n' "$REPORT_ROWS" | sed '/^[[:space:]]*$/d')
    printf '%s\n' "$REPORT_ROW" | grep -Eq 'testTag:[[:space:]]*`[^`]+`' \
      || fail "$test_id reference-anchor row must name a visual bounds testTag"
    VISUAL_TAG=$(printf '%s\n' "$REPORT_ROW" | sed -n 's/.*testTag:[[:space:]]*`\([^`]*\)`.*/\1/p')
    case "$VISUAL_TAG" in
      *_handle|*-handle)
        fail "$test_id reference-anchor row must name the handle's visual shape identifier, not interactive target $VISUAL_TAG"
        ;;
    esac
    printf '%s\n' "$REPORT_ROW" | grep -Eq '`[^`]*#[A-Za-z_][A-Za-z0-9_]*`' \
      || fail "$test_id reference-anchor row must name the runtime test method"
    printf '%s\n' "$REPORT_ROW" | grep -Eq '[A-Za-z]+Bounds(\.[A-Za-z]+)?[[:space:]]*(==|>=|<=|>|<)' \
      || fail "$test_id reference-anchor row must record a concrete bounds relationship"
    printf '%s\n' "$REPORT_ROW" | grep -Fq "$SCREENSHOT_PATH" \
      || fail "$test_id reference-anchor row must cite $SCREENSHOT_PATH"
    printf '%s\n' "$REPORT_ROW" | grep -Eq '\|[[:space:]]*PASS[[:space:]]*\|[[:space:]]*$' \
      || fail "$test_id reference-anchor row must end with PASS"
  done

  if [ -f "$SCRIPT_DIR/compare-visual-evidence.sh" ]; then
    echo "Running perceptual visual comparison checks..."
    bash "$SCRIPT_DIR/compare-visual-evidence.sh" --feature "$FEATURE_DIR" --crop-insets --project-root "$ROOT_DIR" \
      || fail "perceptual visual comparison failed"
  fi
fi

echo "PASS: visual methods, contract rows, acceptance IDs, connected evidence, screenshots, and reference-anchor proof are aligned."
