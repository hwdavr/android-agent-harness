#!/usr/bin/env bash
# Contract test for the production journey boundary checker.
# The negative fixture mirrors the misleading editor test: it mutates a
# ViewModel directly and never enters the production navigation graph.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-journey-test-contract.sh"
STAGE_GATE="$REPO_ROOT/harness/scripts/check-stage-artifacts.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/journey-test-contract.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    fail_test "validator unexpectedly accepted fixture"
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    fail_test "validator did not report '$expected'"
  }
}

mkdir -p "$fixture_root/app/src/androidTest/java/example"

printf '%s\n' \
  'package example' \
  '' \
  'import androidx.compose.ui.test.assertIsDisplayed' \
  'import androidx.compose.ui.test.junit4.createComposeRule' \
  'import androidx.compose.ui.test.onNodeWithTag' \
  'import androidx.compose.ui.test.performClick' \
  'import org.junit.Rule' \
  'import org.junit.Test' \
  '' \
  'class FixtureJourneyTest {' \
  '    @get:Rule val composeRule = createComposeRule()' \
  '' \
  '    @Test' \
  '    fun pickerSelectionReturnsToEditor() {' \
  '        composeRule.setContent {' \
  '            AppNavigationHost()' \
  '        }' \
  '        composeRule.onNodeWithTag("editor_link_action").performClick()' \
  '        composeRule.onNodeWithTag("note_link_picker_note_target").performClick()' \
  '        composeRule.onNodeWithTag("editor_note_link_link-1").assertIsDisplayed()' \
  '    }' \
  '}' \
  > "$fixture_root/app/src/androidTest/java/example/FixtureJourneyTest.kt"

bash "$VALIDATOR" \
  --project-root "$fixture_root" \
  --test-file "$fixture_root/app/src/androidTest/java/example/FixtureJourneyTest.kt" \
  --test-method pickerSelectionReturnsToEditor \
  --production-entry AppNavigationHost

printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Test' \
  '' \
  'class MisleadingEditorTest {' \
  '    @Test' \
  '    fun linkSurvivesReturn() {' \
  '        val viewModel = editorViewModel()' \
  '        viewModel.uiStateInternal.value = loadedState()' \
  '        viewModel.load("source-note")' \
  '        viewModel.applyLinkToSelection("target-note", "Target")' \
  '        assertEquals("target-note", viewModel.linkTargetId())' \
  '    }' \
  '}' \
  > "$fixture_root/app/src/androidTest/java/example/MisleadingEditorTest.kt"

expect_failure "must render a production graph through setContent" \
  bash "$VALIDATOR" \
    --project-root "$fixture_root" \
    --test-file "$fixture_root/app/src/androidTest/java/example/MisleadingEditorTest.kt" \
    --test-method linkSurvivesReturn \
    --production-entry AppNavigationHost

mkdir -p "$fixture_root/docs/current"
printf '%s\n' '# Summary' > "$fixture_root/docs/current/summary_v1.md"
printf '%s\n' \
  '# Test Plan' \
  '' \
  '## Rule Applicability Test Reconciliation' \
  '' \
  '| Rule ID | Rule document | Decision | Test/evidence |' \
  '|---|---|---|---|' \
  '| NAV | navigation-rules.md | Required | production journey |' \
  '' \
  '## Production Journey Boundary' \
  '' \
  '- Test file: `app/src/androidTest/java/example/FixtureJourneyTest.kt`' \
  '- Test method: `pickerSelectionReturnsToEditor`' \
  '- Production entry point: `AppNavigationHost`' \
  '- User actions: open the link picker and select the target note' \
  '- Return boundary: selecting the target pops the picker destination' \
  '- Post-return assertion: the linked label is visible in the editor' \
  > "$fixture_root/docs/current/test_plan_v1.md"

(cd "$fixture_root" && HARNESS_PROJECT_ROOT="$fixture_root" bash "$STAGE_GATE" bug-fixing testing docs/current)

sed '/^## Production Journey Boundary/,$d' \
  "$fixture_root/docs/current/test_plan_v1.md" \
  > "$fixture_root/docs/current/test_plan_v1.tmp"
mv "$fixture_root/docs/current/test_plan_v1.tmp" "$fixture_root/docs/current/test_plan_v1.md"
expect_failure "requires a '## Production Journey Boundary' section" \
  bash -c "cd '$fixture_root' && HARNESS_PROJECT_ROOT='$fixture_root' bash '$STAGE_GATE' bug-fixing testing docs/current"

echo "PASS: production journey contract accepts real entry/gesture/return evidence and rejects direct-ViewModel false passes."
