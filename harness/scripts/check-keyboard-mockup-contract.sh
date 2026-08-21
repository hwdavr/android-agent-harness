#!/usr/bin/env bash
# Ensures planning designs show the keyboard-visible variant of any surface
# (bottom sheet or screen content) that contains text input. When the design
# declares a bottom toolbar on screen content with text input (no modal bottom
# sheet), the keyboard-visible state must dismiss the bottom toolbar, per the
# Keyboard / IME Behavior rule in .agents/rules/compose-rules.md.

set -e

FEATURE_DIR="${1:-}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [ -z "$FEATURE_DIR" ]; then
  echo "Usage: bash harness/scripts/check-keyboard-mockup-contract.sh <feature-directory>" >&2
  exit 2
fi

DESIGN="$FEATURE_DIR/design.md"
[ -f "$DESIGN" ] || fail "missing $DESIGN"

HAS_SHEET=$(grep -Eiq 'bottom[[:space:]-]*sheet|modal[[:space:]-]*bottom[[:space:]-]*sheet|modalbottomsheet' "$DESIGN" && echo 1 || echo 0)
HAS_TOOLBAR=$(grep -Eiq 'bottom[[:space:]-]*(tool)?bar|bottom[[:space:]-]*toolbar' "$DESIGN" && echo 1 || echo 0)

if [ "$HAS_SHEET" -eq 0 ] && [ "$HAS_TOOLBAR" -eq 0 ]; then
  echo "PASS: design has no bottom-sheet surface or bottom toolbar."
  exit 0
fi

TEXT_INPUT_LINES=$(
  grep -Ei 'text[[:space:]-]*(box|field|input)|textfield|input[[:space:]-]*field|search[[:space:]-]*field' "$DESIGN" |
    grep -Eiv '(^|[[:space:][:punct:]])(no|without|does[[:space:]]+not|do[[:space:]]+not|not[[:space:]]+applicable|none|has[[:space:]]+no|contains[[:space:]]+no|includes[[:space:]]+no|presents[[:space:]]+no|uses[[:space:]]+no|provides[[:space:]]+no|read[[:space:]-]*only|readonly)([[:space:][:punct:]]|$)' ||
    true
)

if [ -z "$TEXT_INPUT_LINES" ]; then
  echo "PASS: design has no text-input control."
  exit 0
fi

KEYBOARD_STATE_LINES=$(grep -Eiv 'mockup|design/' "$DESIGN" || true)
if ! printf '%s\n' "$KEYBOARD_STATE_LINES" | grep -Eiq 'keyboard[[:space:]-]*(visible|shown|state|layout)|ime[[:space:]-]*(visible|shown|state|layout)|when[[:space:]]+(the[[:space:]]+)?(keyboard|ime)|while[[:space:]]+typing'; then
  fail "text-input design must describe a keyboard-visible state"
fi

# A bottom-sheet text-input design must keep the sheet open while the keyboard
# is visible — tapping the text input must not dismiss the sheet (compose-rules.md
# Keyboard / IME Behavior — Bottom Sheets with Text Input).
if [ "$HAS_SHEET" -eq 1 ]; then
  if ! printf '%s\n' "$KEYBOARD_STATE_LINES" | grep -Eiq '(keeps?|remains?|stays?)[^.]*(sheet|open|keyboard|ime)|(sheet|open|keyboard|ime)[^.]*(keeps?|remains?|stays?|not[[:space:]]+dismiss)'; then
    fail "bottom-sheet text-input design must state that the sheet stays open while the keyboard is visible (tapping the text input must not dismiss the sheet)"
  fi
fi

# When the text input is on screen content with a bottom toolbar (no modal
# bottom sheet to cover it), the keyboard-visible state must dismiss the
# toolbar. A modal sheet hides the screen's toolbar anyway, so no dismissal
# statement is required there.
if [ "$HAS_TOOLBAR" -eq 1 ] && [ "$HAS_SHEET" -eq 0 ]; then
  if ! printf '%s\n' "$KEYBOARD_STATE_LINES" | grep -Eiq '(dismiss|hide|hidden|collaps|remov)[^.]*(bottom[[:space:]-]*(tool)?bar|bottom[[:space:]-]*toolbar|toolbar)|(bottom[[:space:]-]*(tool)?bar|bottom[[:space:]-]*toolbar|toolbar)[^.]*(dismiss|hid|collaps|remov)'; then
    fail "text-input design with a bottom toolbar must state that the bottom toolbar is dismissed while the keyboard is visible"
  fi
fi

ASSET_PATHS=$(grep -Eo '`design/[^`[:space:]]+\.(png|jpg|jpeg|webp)`' "$DESIGN" | sed 's/^`//; s/`$//' || true)
[ -n "$ASSET_PATHS" ] || fail "text-input design must reference design mockup assets"

keyboard_asset_count=0
non_keyboard_asset_count=0
while IFS= read -r asset_path; do
  [ -n "$asset_path" ] || continue
  [ -s "$FEATURE_DIR/$asset_path" ] || fail "referenced design asset is missing or empty: $FEATURE_DIR/$asset_path"
  if printf '%s\n' "$asset_path" | grep -Eiq '(keyboard|ime)'; then
    keyboard_asset_count=$((keyboard_asset_count + 1))
  else
    non_keyboard_asset_count=$((non_keyboard_asset_count + 1))
  fi
done <<EOF
$ASSET_PATHS
EOF

[ "$keyboard_asset_count" -gt 0 ] || fail "text-input design requires a distinct keyboard-visible mockup asset with 'keyboard' or 'ime' in its path"
[ "$non_keyboard_asset_count" -gt 0 ] || fail "text-input design requires a non-keyboard mockup as well as the keyboard-visible mockup"

echo "PASS: text-input design includes distinct base and keyboard-visible mockups."
