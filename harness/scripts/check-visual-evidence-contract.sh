#!/usr/bin/env bash
# Visual evidence contract: UI appearance is approved by a conformance review (review capture at the
# Pen frame size beside the approved design, plus a structural semantics check), never by a
# screenshot golden. Usage:
#   bash harness/scripts/check-visual-evidence-contract.sh <workspace> [--planning|--evaluate]
#   --planning  no retired pixel-golden rows; sliced lane: exactly one final UI slice owns the review
#   --evaluate  ui_verification.json records an approved, passing review for every UI_contract state
# Designed for macOS /bin/bash (Bash 3.2).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_DIR="${1:-}"
MODE="${2:---evaluate}"
ROOT_DIR="${HARNESS_PROJECT_ROOT:-$(pwd)}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [ -z "$FEATURE_DIR" ]; then
  echo "Usage: bash harness/scripts/check-visual-evidence-contract.sh <workspace> [--planning|--evaluate]" >&2
  exit 2
fi
[ "$MODE" = "--planning" ] || [ "$MODE" = "--evaluate" ] || fail "mode must be --planning or --evaluate"

CONTRACT="$FEATURE_DIR/UI_contract.md"
TEST_PLAN="$FEATURE_DIR/test-plan.md"
FEATURE_JSON="$FEATURE_DIR/feature_list.json"

if [ ! -f "$CONTRACT" ]; then
  echo "N/A: no UI_contract.md; the change has no UI scope."
  exit 0
fi
[ -f "$TEST_PLAN" ] || fail "missing $TEST_PLAN"

for planned in "$TEST_PLAN" "$FEATURE_DIR/tasks.md"; do
  [ -f "$planned" ] || continue
  if grep -Eq '\|[[:space:]]*TC-[A-Z0-9-]*-VIS' "$planned"; then
    fail "$planned declares TC-*-VIS pixel rows; screenshot goldens are retired — plan review captures under ## UI State Verification."
  fi
  if grep -Eq '(verify|record|verifyAndRecord)RoborazziDebug' "$planned"; then
    fail "$planned plans a Roborazzi golden command; visual approval is the conformance review, not a pixel gate."
  fi
done

if [ "$MODE" = "--planning" ]; then
  if [ -f "$FEATURE_JSON" ]; then
    jq -e '.features | type == "array" and all(
      (.affects_ui | type == "boolean") and (.requires_visual_verification | type == "boolean"))' \
      "$FEATURE_JSON" >/dev/null ||
      fail "every slice must declare boolean affects_ui and requires_visual_verification fields."
    ui_count=$(jq '[.features[] | select(.affects_ui)] | length' "$FEATURE_JSON")
    owners=$(jq -r '[.features[] | select(.requires_visual_verification) | .id] | join(" ")' "$FEATURE_JSON")
    owner_count=$(jq '[.features[] | select(.requires_visual_verification)] | length' "$FEATURE_JSON")
    if [ "$ui_count" -gt 0 ] && [ "$owner_count" -ne 1 ]; then
      fail "a UI feature must name exactly one slice that owns the conformance review (requires_visual_verification); found: ${owners:-none}"
    fi
    if [ "$owner_count" -eq 1 ]; then
      last=$(jq -r '[.features[] | select(.affects_ui)] | max_by(.priority) | .id' "$FEATURE_JSON")
      [ "$owners" = "$last" ] || fail "conformance review owner $owners must be the final UI slice $last."
    fi
  fi
  echo "PASS: visual verification is planned as a conformance review."
  exit 0
fi

REPORT="$FEATURE_DIR/ui_verification.json"
[ -f "$REPORT" ] || fail "missing $REPORT (record the conformance review before the slice can pass)"
args=("$CONTRACT" --test-plan "$TEST_PLAN" --report "$REPORT" --runtime --project-root "$ROOT_DIR")
if [ -f "$ROOT_DIR/docs/product/design_system.md" ]; then
  args+=(--design-system "$ROOT_DIR/docs/product/design_system.md")
fi
python3 "$SCRIPT_DIR/check-ui-contract.py" "${args[@]}"
echo "PASS: every UI state has an approved conformance review."
