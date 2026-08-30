#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-visual-evidence-contract.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/visual-evidence-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

write_valid_fixture() {
  local feature_dir="$1"
  mkdir -p "$feature_dir/design" "$feature_dir/visual_evidence"
  printf 'reference mockup' > "$feature_dir/design/mockup_picker.png"
  printf '%6000s' 'x' > "$feature_dir/visual_evidence/emoji_picker_content.png"
  printf '%s\n' \
    '# Sprint Contract' \
    '' \
    '### US-3: Visual picker' \
    '' \
    '| Test ID | Covers AC | Test layer | Test file and method | Setup and action | Required assertions | Exact command |' \
    '|---|---|---|---|---|---|---|' \
    '| TC-US-3-VIS-001 | AC-US-3-03 | Visual verification | app/src/androidTest/java/example/EmojiPickerVisualFlowTest.kt#emojiPickerContentLightTheme | fixture | screenshot saved at visual_evidence/emoji_picker_content.png | env ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.EmojiPickerVisualFlowTest#emojiPickerContentLightTheme |' \
    > "$feature_dir/sprint-contract.md"
  printf '%s\n' \
    '{' \
    '  "features": [{' \
    '    "id": "US-3",' \
    '    "requires_visual_verification": true,' \
    '    "acceptance_test_ids": ["TC-US-3-VIS-001"],' \
    '    "verification": [' \
    '      "env ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.EmojiPickerVisualFlowTest#emojiPickerContentLightTheme"' \
    '    ],' \
    '    "evidence": [{"test_id": "TC-US-3-VIS-001", "exit_status": 0, "executed_command": "env ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest"}]' \
    '  }]' \
    '}' \
    > "$feature_dir/feature_list.json"
  printf '%s\n' \
    '# Visual Reference Anchor Verification' \
    '' \
    '**Reference design**: `design/mockup_picker.png`' \
    '' \
    '## Reference Anchor Verification' \
    '' \
    '| Visual Test ID | Reference anchor | Runtime proof | Measured relationship | Actual screenshot | Result |' \
    '|---|---|---|---|---|---|' \
    '| TC-US-3-VIS-001 | Picker visual top edge aligns to the reference safe-area anchor. | `EmojiPickerVisualFlowTest#emojiPickerContentLightTheme`; testTag: `emoji_picker_visual` | `pickerBounds.top == safeAreaBounds.top + 16dp` | `visual_evidence/emoji_picker_content.png` | PASS |' \
    > "$feature_dir/visual_evidence/reference-anchor-verification.md"
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "FAIL: validator unexpectedly accepted fixture" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "FAIL: validator did not report '$expected'." >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
}

valid="$fixture_root/valid"
write_valid_fixture "$valid"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$valid")

missing_anchor_report="$fixture_root/missing-anchor-report"
write_valid_fixture "$missing_anchor_report"
mv "$missing_anchor_report/visual_evidence/reference-anchor-verification.md" \
  "$missing_anchor_report/visual_evidence/reference-anchor-verification.missing"
expect_failure "missing $missing_anchor_report/visual_evidence/reference-anchor-verification.md" \
  bash "$VALIDATOR" "$missing_anchor_report"

missing_anchor_tag="$fixture_root/missing-anchor-tag"
write_valid_fixture "$missing_anchor_tag"
sed 's/testTag:/boundsTag:/' "$missing_anchor_tag/visual_evidence/reference-anchor-verification.md" \
  > "$missing_anchor_tag/visual_evidence/reference-anchor-verification.tmp"
mv "$missing_anchor_tag/visual_evidence/reference-anchor-verification.tmp" \
  "$missing_anchor_tag/visual_evidence/reference-anchor-verification.md"
expect_failure "must name a visual bounds testTag" bash "$VALIDATOR" "$missing_anchor_tag"

target_only_handle_anchor="$fixture_root/target-only-handle-anchor"
write_valid_fixture "$target_only_handle_anchor"
sed 's/emoji_picker_visual/emoji_picker_handle/' \
  "$target_only_handle_anchor/visual_evidence/reference-anchor-verification.md" \
  > "$target_only_handle_anchor/visual_evidence/reference-anchor-verification.tmp"
mv "$target_only_handle_anchor/visual_evidence/reference-anchor-verification.tmp" \
  "$target_only_handle_anchor/visual_evidence/reference-anchor-verification.md"
expect_failure "must name the handle's visual shape identifier, not interactive target emoji_picker_handle" \
  bash "$VALIDATOR" "$target_only_handle_anchor"

missing_screenshot="$fixture_root/missing-screenshot"
write_valid_fixture "$missing_screenshot"
mv "$missing_screenshot/visual_evidence/emoji_picker_content.png" \
  "$missing_screenshot/visual_evidence/emoji_picker_content.missing"
expect_failure "is missing non-empty screenshot visual_evidence/emoji_picker_content.png" \
  bash "$VALIDATOR" "$missing_screenshot"

tiny_screenshot="$fixture_root/tiny-screenshot"
write_valid_fixture "$tiny_screenshot"
printf 'too small' > "$tiny_screenshot/visual_evidence/emoji_picker_content.png"
expect_failure "likely a blank or transparent capture" \
  bash "$VALIDATOR" "$tiny_screenshot"

missing_contract_row="$fixture_root/missing-contract-row"
write_valid_fixture "$missing_contract_row"
jq '.features[0].verification += ["env ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.EmojiPickerVisualFlowTest#emojiPickerExpandsToAvailableHeightWhenKeyboardIsVisible"]' \
  "$missing_contract_row/feature_list.json" > "$missing_contract_row/feature_list.tmp"
mv "$missing_contract_row/feature_list.tmp" "$missing_contract_row/feature_list.json"
expect_failure "is not named by a US-3 visual row" bash "$VALIDATOR" "$missing_contract_row"

missing_feature_id="$fixture_root/missing-feature-id"
write_valid_fixture "$missing_feature_id"
jq '.features[0].acceptance_test_ids = []' \
  "$missing_feature_id/feature_list.json" > "$missing_feature_id/feature_list.tmp"
mv "$missing_feature_id/feature_list.tmp" "$missing_feature_id/feature_list.json"
expect_failure "missing from feature_list.json acceptance_test_ids" bash "$VALIDATOR" "$missing_feature_id"

missing_evidence="$fixture_root/missing-evidence"
write_valid_fixture "$missing_evidence"
jq '.features[0].evidence[0].exit_status = 1' \
  "$missing_evidence/feature_list.json" > "$missing_evidence/feature_list.tmp"
mv "$missing_evidence/feature_list.tmp" "$missing_evidence/feature_list.json"
expect_failure "has no successful connected-test evidence" bash "$VALIDATOR" "$missing_evidence"

missing_verification="$fixture_root/missing-verification"
write_valid_fixture "$missing_verification"
jq '.features[0].verification = []' \
  "$missing_verification/feature_list.json" > "$missing_verification/feature_list.tmp"
mv "$missing_verification/feature_list.tmp" "$missing_verification/feature_list.json"
expect_failure "no method-scoped VisualFlowTest verification command" bash "$VALIDATOR" "$missing_verification"

functional_visual_class="$fixture_root/functional-visual-class"
write_valid_fixture "$functional_visual_class"
sed 's/EmojiPickerVisualFlowTest/FormattingToolbarTest/g' \
  "$functional_visual_class/sprint-contract.md" \
  > "$functional_visual_class/sprint-contract.tmp"
mv "$functional_visual_class/sprint-contract.tmp" "$functional_visual_class/sprint-contract.md"
expect_failure "must name a dedicated *VisualFlowTest.kt method" \
  bash "$VALIDATOR" "$functional_visual_class"

class_scoped_visual_command="$fixture_root/class-scoped-visual-command"
write_valid_fixture "$class_scoped_visual_command"
sed 's/EmojiPickerVisualFlowTest#emojiPickerContentLightTheme/EmojiPickerVisualFlowTest/' \
  "$class_scoped_visual_command/feature_list.json" \
  > "$class_scoped_visual_command/feature_list.tmp"
mv "$class_scoped_visual_command/feature_list.tmp" \
  "$class_scoped_visual_command/feature_list.json"
expect_failure "no method-scoped VisualFlowTest verification command" \
  bash "$VALIDATOR" "$class_scoped_visual_command"

duplicate_screenshot="$fixture_root/duplicate-screenshot"
write_valid_fixture "$duplicate_screenshot"
sed -i.bak \
  '/TC-US-3-VIS-001/a\
| TC-US-3-VIS-001 | AC-US-3-03 | Visual verification | app/src/androidTest/java/example/EmojiPickerVisualFlowTest.kt#emojiPickerContentLightTheme | fixture | screenshot saved at visual_evidence/emoji_picker_content.png | env ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.EmojiPickerVisualFlowTest#emojiPickerContentLightTheme |' \
  "$duplicate_screenshot/sprint-contract.md"
rm -f "$duplicate_screenshot/sprint-contract.md.bak"
expect_failure "is used by more than one visual row" \
  bash "$VALIDATOR" "$duplicate_screenshot"

echo "PASS: visual evidence validator rejects missing anchor proof, blank screenshots, and aligns methods, contract rows, screenshots, and evidence."
