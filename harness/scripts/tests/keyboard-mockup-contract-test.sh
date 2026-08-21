#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-keyboard-mockup-contract.sh"
STAGE_GATE="$REPO_ROOT/harness/scripts/check-stage-artifacts.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/keyboard-mockup-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

write_design() {
  local feature_dir="$1"
  local include_keyboard_asset="$2"
  local include_keyboard_state="$3"

  mkdir -p "$feature_dir/design"
  printf '%s\n' \
    '# Design' \
    '' \
    '## Screen — Picker' \
    '' \
    'The bottom sheet contains a search text field.' \
    '' \
    '### Visual States' \
    '' \
    "${include_keyboard_state}" \
    '' \
    '### Design Assets' \
    '' \
    '- Mockup image: `design/mockup_picker.png`' \
    "${include_keyboard_asset}" \
    > "$feature_dir/design.md"
  printf 'base mockup' > "$feature_dir/design/mockup_picker.png"
  if [ "$include_keyboard_asset" = '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' ]; then
    printf 'keyboard mockup' > "$feature_dir/design/mockup_picker_keyboard.png"
  fi
}

expect_failure() {
  local expected="$1"
  local feature_dir="$2"
  local output
  if output=$(cd "$REPO_ROOT" && bash "$VALIDATOR" "$feature_dir" 2>&1); then
    echo "FAIL: validator unexpectedly accepted fixture: $feature_dir" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "FAIL: validator did not report '$expected'." >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
}

expect_stage_failure() {
  local expected="$1"
  local feature_dir="$2"
  local output
  if output=$(cd "$REPO_ROOT" && bash "$STAGE_GATE" harness-planning feature-specification "$feature_dir" 2>&1); then
    echo "FAIL: planning stage gate unexpectedly accepted fixture: $feature_dir" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "FAIL: planning stage gate did not report '$expected'." >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
}

valid="$fixture_root/valid"
write_design "$valid" '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' 'Keyboard-visible state: the sheet stays open and the search results remain visible while typing.'
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$valid")

stage_valid="$fixture_root/stage-valid"
write_design "$stage_valid" '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' 'Keyboard-visible state: the sheet stays open and the search results remain visible while typing.'
printf '%s\n' '# Spec' '' '## Screen States' > "$stage_valid/spec.md"
printf '%s\n' 'Project design system: `docs/product/design_system.md`' >> "$stage_valid/design.md"
(cd "$REPO_ROOT" && bash "$STAGE_GATE" harness-planning feature-specification "$stage_valid")

not_applicable="$fixture_root/not-applicable"
mkdir -p "$not_applicable/design"
printf '%s\n' \
  '# Design' \
  '' \
  'The bottom sheet contains read-only status text.' \
  '' \
  '- Mockup image: `design/mockup_status.png`' \
  > "$not_applicable/design.md"
printf 'status mockup' > "$not_applicable/design/mockup_status.png"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$not_applicable")

explicit_no_input="$fixture_root/explicit-no-input"
mkdir -p "$explicit_no_input/design"
printf '%s\n' \
  '# Design' \
  '' \
  'The bottom sheet contains only tappable tile actions and has no text field.' \
  '' \
  '- Mockup image: `design/mockup_actions.png`' \
  > "$explicit_no_input/design.md"
printf 'actions mockup' > "$explicit_no_input/design/mockup_actions.png"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$explicit_no_input")

missing_keyboard_asset="$fixture_root/missing-keyboard-asset"
write_design "$missing_keyboard_asset" '' 'Keyboard-visible state: the sheet stays open and the search results remain visible while typing.'
expect_failure "requires a distinct keyboard-visible mockup asset" "$missing_keyboard_asset"

stage_missing_keyboard_asset="$fixture_root/stage-missing-keyboard-asset"
write_design "$stage_missing_keyboard_asset" '' 'Keyboard-visible state: the search results remain visible while typing.'
printf '%s\n' '# Spec' '' '## Screen States' > "$stage_missing_keyboard_asset/spec.md"
printf '%s\n' 'Project design system: `docs/product/design_system.md`' >> "$stage_missing_keyboard_asset/design.md"
expect_stage_failure "requires a distinct keyboard-visible mockup asset" "$stage_missing_keyboard_asset"

missing_keyboard_state="$fixture_root/missing-keyboard-state"
write_design "$missing_keyboard_state" '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' 'The sheet has a compact layout.'
expect_failure "must describe a keyboard-visible state" "$missing_keyboard_state"

missing_keyboard_file="$fixture_root/missing-keyboard-file"
mkdir -p "$missing_keyboard_file/design"
printf '%s\n' \
  '# Design' \
  '' \
  'The bottom sheet contains a search text field.' \
  '' \
  'Keyboard-visible state: the sheet stays open and the search results remain visible while typing.' \
  '' \
  '- Mockup image: `design/mockup_picker.png`' \
  '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' \
  > "$missing_keyboard_file/design.md"
printf 'base mockup' > "$missing_keyboard_file/design/mockup_picker.png"
expect_failure "referenced design asset is missing or empty" "$missing_keyboard_file"

# A bottom-sheet text-input design must state that the sheet stays open while
# the keyboard is visible (tapping the text input must not dismiss the sheet).
sheet_missing_stay_open="$fixture_root/sheet-missing-stay-open"
mkdir -p "$sheet_missing_stay_open/design"
printf '%s\n' \
  '# Design' \
  '' \
  'The bottom sheet contains a search text field.' \
  '' \
  'Keyboard-visible state: the picker expands to the full available height above the keyboard while typing.' \
  '' \
  '- Mockup image: `design/mockup_picker.png`' \
  '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' \
  > "$sheet_missing_stay_open/design.md"
printf 'base mockup' > "$sheet_missing_stay_open/design/mockup_picker.png"
printf 'keyboard mockup' > "$sheet_missing_stay_open/design/mockup_picker_keyboard.png"
expect_failure "must state that the sheet stays open" "$sheet_missing_stay_open"

# Screen content with text input + bottom toolbar requires the keyboard-visible
# state to state that the bottom toolbar is dismissed (compose-rules.md
# Keyboard / IME Behavior rule).
screen_valid="$fixture_root/screen-valid"
mkdir -p "$screen_valid/design"
printf '%s\n' \
  '# Design' \
  '' \
  '## Screen — Create Note' \
  '' \
  'The screen content includes a title text field and a bottom toolbar.' \
  '' \
  '### Visual States' \
  '' \
  'Keyboard-visible state: the bottom toolbar is dismissed while the keyboard is visible; the title field stays above the keyboard.' \
  '' \
  '### Design Assets' \
  '' \
  '- Mockup image: `design/mockup_create_note.png`' \
  '- Keyboard-visible mockup: `design/mockup_create_note_keyboard.png`' \
  > "$screen_valid/design.md"
printf 'base mockup' > "$screen_valid/design/mockup_create_note.png"
printf 'keyboard mockup' > "$screen_valid/design/mockup_create_note_keyboard.png"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$screen_valid")

screen_missing_dismissal="$fixture_root/screen-missing-toolbar-dismissal"
mkdir -p "$screen_missing_dismissal/design"
printf '%s\n' \
  '# Design' \
  '' \
  '## Screen — Create Note' \
  '' \
  'The screen content includes a title text field and a bottom toolbar.' \
  '' \
  '### Visual States' \
  '' \
  'Keyboard-visible state: the title field stays above the keyboard while typing.' \
  '' \
  '### Design Assets' \
  '' \
  '- Mockup image: `design/mockup_create_note.png`' \
  '- Keyboard-visible mockup: `design/mockup_create_note_keyboard.png`' \
  > "$screen_missing_dismissal/design.md"
printf 'base mockup' > "$screen_missing_dismissal/design/mockup_create_note.png"
printf 'keyboard mockup' > "$screen_missing_dismissal/design/mockup_create_note_keyboard.png"
expect_failure "must state that the bottom toolbar is dismissed" "$screen_missing_dismissal"

# Read-only / display-only text is not text input (code-block editor pattern),
# so it must not trigger the keyboard-mockup requirement.
readonly_field="$fixture_root/readonly-field"
mkdir -p "$readonly_field/design"
printf '%s\n' \
  '# Design' \
  '' \
  '## Screen — Code Block' \
  '' \
  'The screen content renders a read-only monospace text field and the panel attaches above the editor bottom bar.' \
  '' \
  '- Mockup image: `design/mockup_code.png`' \
  > "$readonly_field/design.md"
printf 'code mockup' > "$readonly_field/design/mockup_code.png"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$readonly_field")

# Screen text input with no bottom toolbar is not required to dismiss anything.
screen_no_toolbar="$fixture_root/screen-no-toolbar"
mkdir -p "$screen_no_toolbar/design"
printf '%s\n' \
  '# Design' \
  '' \
  '## Screen — Search' \
  '' \
  'The screen content includes a search field.' \
  '' \
  '- Mockup image: `design/mockup_search.png`' \
  > "$screen_no_toolbar/design.md"
printf 'search mockup' > "$screen_no_toolbar/design/mockup_search.png"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$screen_no_toolbar")

# A modal bottom sheet hides the screen toolbar behind it, so a sheet with text
# input does not require a toolbar-dismissal statement (emoji-picker pattern).
sheet_with_toolbar_no_dismissal="$fixture_root/sheet-with-toolbar-no-dismissal"
mkdir -p "$sheet_with_toolbar_no_dismissal/design"
printf '%s\n' \
  '# Design' \
  '' \
  '## Screen — Editor' \
  '' \
  'The editor bottom bar contains the Insert icon; the bottom sheet contains a search text field.' \
  '' \
  '### Visual States' \
  '' \
  'Keyboard-visible state: the sheet stays open and expands to the full available height above the keyboard while typing.' \
  '' \
  '### Design Assets' \
  '' \
  '- Mockup image: `design/mockup_picker.png`' \
  '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' \
  > "$sheet_with_toolbar_no_dismissal/design.md"
printf 'base mockup' > "$sheet_with_toolbar_no_dismissal/design/mockup_picker.png"
printf 'keyboard mockup' > "$sheet_with_toolbar_no_dismissal/design/mockup_picker_keyboard.png"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$sheet_with_toolbar_no_dismissal")

echo "PASS: keyboard mockup validator accepts the required pairs, rejects missing state/asset/file, missing toolbar-dismissal, and missing sheet-stays-open cases, and skips toolbar-less screens and read-only text."
