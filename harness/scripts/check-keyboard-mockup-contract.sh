#!/usr/bin/env bash
# Ensures planning designs show the keyboard-visible variant of any bottom
# sheet that contains text input.

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

if ! grep -Eiq 'bottom[[:space:]-]*sheet|modal[[:space:]-]*bottom[[:space:]-]*sheet|modalbottomsheet' "$DESIGN"; then
  echo "PASS: design has no bottom-sheet surface."
  exit 0
fi

TEXT_INPUT_LINES=$(
  grep -Ei 'text[[:space:]-]*(box|field|input)|textfield|input[[:space:]-]*field|search[[:space:]-]*field' "$DESIGN" |
    grep -Eiv '(^|[[:space:][:punct:]])(no|without|does[[:space:]]+not|do[[:space:]]+not|not[[:space:]]+applicable|none|has[[:space:]]+no|contains[[:space:]]+no|includes[[:space:]]+no|presents[[:space:]]+no|uses[[:space:]]+no|provides[[:space:]]+no)([[:space:][:punct:]]|$)' ||
    true
)

if [ -z "$TEXT_INPUT_LINES" ]; then
  echo "PASS: bottom-sheet design has no text-input control."
  exit 0
fi

KEYBOARD_STATE_LINES=$(grep -Eiv 'mockup|design/' "$DESIGN" || true)
if ! printf '%s\n' "$KEYBOARD_STATE_LINES" | grep -Eiq 'keyboard[[:space:]-]*(visible|shown|state|layout)|ime[[:space:]-]*(visible|shown|state|layout)|when[[:space:]]+(the[[:space:]]+)?(keyboard|ime)|while[[:space:]]+typing'; then
  fail "bottom-sheet text-input design must describe a keyboard-visible state"
fi

ASSET_PATHS=$(grep -Eo '`design/[^`[:space:]]+\.(png|jpg|jpeg|webp)`' "$DESIGN" | sed 's/^`//; s/`$//' || true)
[ -n "$ASSET_PATHS" ] || fail "bottom-sheet text-input design must reference design mockup assets"

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

[ "$keyboard_asset_count" -gt 0 ] || fail "bottom-sheet text-input design requires a distinct keyboard-visible mockup asset with 'keyboard' or 'ime' in its path"
[ "$non_keyboard_asset_count" -gt 0 ] || fail "bottom-sheet text-input design requires a non-keyboard mockup as well as the keyboard-visible mockup"

echo "PASS: bottom-sheet text-input design includes distinct base and keyboard-visible mockups."
