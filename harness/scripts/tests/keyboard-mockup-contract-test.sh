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
write_design "$valid" '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' 'Keyboard-visible state: the search results remain visible while typing.'
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$valid")

stage_valid="$fixture_root/stage-valid"
write_design "$stage_valid" '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' 'Keyboard-visible state: the search results remain visible while typing.'
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
write_design "$missing_keyboard_asset" '' 'Keyboard-visible state: the search results remain visible while typing.'
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
  'Keyboard-visible state: the search results remain visible while typing.' \
  '' \
  '- Mockup image: `design/mockup_picker.png`' \
  '- Keyboard-visible mockup: `design/mockup_picker_keyboard.png`' \
  > "$missing_keyboard_file/design.md"
printf 'base mockup' > "$missing_keyboard_file/design/mockup_picker.png"
expect_failure "referenced design asset is missing or empty" "$missing_keyboard_file"

echo "PASS: keyboard mockup validator accepts the required pair and rejects missing state, asset, and file cases."
