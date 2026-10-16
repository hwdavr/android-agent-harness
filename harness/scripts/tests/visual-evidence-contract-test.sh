#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-visual-evidence-contract.sh"
fixture_parent=$(mktemp -d "${TMPDIR:-/tmp}/visual-evidence-test.XXXXXX")
fixture_root="$fixture_parent/project"
mkdir -p "$fixture_root"
trap 'rm -rf "$fixture_parent"' EXIT
export HARNESS_PROJECT_ROOT="$fixture_root"

write_valid_fixture() {
  local feature_dir="$1"
  mkdir -p "$feature_dir/design" "$feature_dir/visual_evidence"
  mkdir -p "$fixture_parent/UI_design"
  printf '{"version":"2.21","children":[]}\n' > "$fixture_parent/UI_design/source.pen"
  mkdir -p "$fixture_root/app/src/test/java/example/roborazzi"
  printf '%s\n' \
    'package example' \
    '' \
    'import org.junit.Test' \
    '' \
    'class EmojiPickerRoborazziTest {' \
    '  @Test' \
    '  fun emojiPickerContentLightTheme() {' \
    '    captureRoboImage("design/mockup_picker.png")' \
    '  }' \
    '}' \
    > "$fixture_root/app/src/test/java/example/roborazzi/EmojiPickerRoborazziTest.kt"
  printf 'approved Pen component export' > "$feature_dir/design/mockup_picker.png"
  printf '%s\n' \
    '{' \
    '  "version": 2,' \
    '  "appearance": "light",' \
    '  "logical_size_dp": { "width": 108, "height": 234 },' \
    '  "locale": "en-US",' \
    '  "pen_source": "../UI_design/source.pen",' \
    '  "pen_node_id": "design-frame",' \
    '  "comparison": {"engine":"roborazzi","content_alignment":"exact","scope":"component"},' \
    '  "states": {' \
    '    "picker-content": {' \
    '      "content_state_id": "picker-content",' \
    '      "reference": "design/mockup_picker.png",' \
    '      "content_state": "Deterministic picker component.",' \
    '      "dynamic_regions": []' \
    '    }' \
    '  }' \
    '}' > "$feature_dir/visual_evidence/visual-target.json"
  printf '%s\n' \
    '# Sprint Contract' \
    '' \
    '### US-3: Visual picker' \
    '' \
    '| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |' \
    '|---|---|---|---|---|---|---|---|' \
    '| TC-US-3-VIS-001 | AC-US-3-03 | Visual verification | `app/src/test/java/example/roborazzi/EmojiPickerRoborazziTest.kt#emojiPickerContentLightTheme` | N/A — no API | Comparison scope: component; contentState: `picker-content` | captureRoboImage compares the deterministic picker to the approved Pen component. | ./gradlew app:verifyRoborazziDebug --tests "example.EmojiPickerRoborazziTest.emojiPickerContentLightTheme" |' \
    > "$feature_dir/sprint-contract.md"
  printf '%s\n' \
    '{' \
    '  "features": [{' \
    '    "id": "US-3",' \
    '    "requires_visual_verification": true,' \
    '    "acceptance_test_ids": ["TC-US-3-VIS-001"],' \
    '    "verification": ["./gradlew app:verifyRoborazziDebug --tests \"example.EmojiPickerRoborazziTest.emojiPickerContentLightTheme\""],' \
    '    "evidence": [{"test_id":"TC-US-3-VIS-001","exit_status":0,"executed_command":"./gradlew app:verifyRoborazziDebug --tests \"example.EmojiPickerRoborazziTest.emojiPickerContentLightTheme\""}]' \
    '  }]' \
    '}' > "$feature_dir/feature_list.json"
  printf '%s\n' \
    '# Visual Reference Anchor Verification' \
    '' \
    '## Reference Anchor Verification' \
    '' \
    '| Visual Test ID | Reference anchor | JVM proof | Measured relationship | Reference PNG | Result |' \
    '|---|---|---|---|---|---|' \
    '| TC-US-3-VIS-001 | Picker top edge aligns to the approved component. | `EmojiPickerRoborazziTest#emojiPickerContentLightTheme`; comparisonScope: component; testTag: `emoji_picker_visual` | `pickerBounds.top == safeAreaBounds.top + 16dp` | `design/mockup_picker.png` | PASS |' \
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
    printf '%s\n' "$output" >&2
    echo "FAIL: validator did not report '$expected'." >&2
    exit 1
  }
}

valid="$fixture_root/valid"
write_valid_fixture "$valid"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$valid")

outdated_instrumented="$fixture_root/outdated-instrumented"
write_valid_fixture "$outdated_instrumented"
sed -i.bak \
  -e 's#app/src/test/java/example/roborazzi/EmojiPickerRoborazziTest.kt#app/src/androidTest/java/example/EmojiPickerVisualFlowTest.kt#g' \
  -e 's/EmojiPickerRoborazziTest/EmojiPickerVisualFlowTest/g' \
  -e 's|./gradlew app:verifyRoborazziDebug --tests "example.EmojiPickerVisualFlowTest.emojiPickerContentLightTheme"|./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.EmojiPickerVisualFlowTest#emojiPickerContentLightTheme|g' \
  "$outdated_instrumented/sprint-contract.md"
expect_failure "must name a dedicated app/src/test/java/**/roborazzi/*RoborazziTest.kt#method target" \
  bash "$VALIDATOR" "$outdated_instrumented"

structural_target="$fixture_root/structural-target"
write_valid_fixture "$structural_target"
jq '.comparison = {"engine":"structural","content_alignment":"different","scope":"screen"}' \
  "$structural_target/visual_evidence/visual-target.json" > "$structural_target/visual_evidence/visual-target.tmp"
mv "$structural_target/visual_evidence/visual-target.tmp" "$structural_target/visual_evidence/visual-target.json"
expect_failure "visual target comparison must use roborazzi engine" \
  bash "$VALIDATOR" "$structural_target"

missing_capture="$fixture_root/missing-capture"
write_valid_fixture "$missing_capture"
sed -i.bak 's/captureRoboImage("design\/mockup_picker.png")/check(true)/' \
  "$fixture_root/app/src/test/java/example/roborazzi/EmojiPickerRoborazziTest.kt"
expect_failure "Roborazzi method source must call captureRoboImage()" \
  bash "$VALIDATOR" "$missing_capture"
write_valid_fixture "$fixture_root/restore-capture"

missing_evidence="$fixture_root/missing-evidence"
write_valid_fixture "$missing_evidence"
jq '.features[0].evidence = []' "$missing_evidence/feature_list.json" > "$missing_evidence/feature_list.tmp"
mv "$missing_evidence/feature_list.tmp" "$missing_evidence/feature_list.json"
expect_failure "has no successful verifyRoborazziDebug evidence" \
  bash "$VALIDATOR" "$missing_evidence"

wrong_scope="$fixture_root/wrong-scope"
write_valid_fixture "$wrong_scope"
jq '.comparison.scope = "partial"' "$wrong_scope/visual_evidence/visual-target.json" > "$wrong_scope/visual_evidence/visual-target.tmp"
mv "$wrong_scope/visual_evidence/visual-target.tmp" "$wrong_scope/visual_evidence/visual-target.json"
expect_failure "must declare comparison.scope as screen or component" \
  bash "$VALIDATOR" "$wrong_scope"

echo "PASS: visual evidence requires JVM Roborazzi tests and rejects the obsolete instrumented capture path."
