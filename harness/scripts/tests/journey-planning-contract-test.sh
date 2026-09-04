#!/usr/bin/env bash
# Contract test for planning-time production journey ownership.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-journey-planning-contract.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/journey-planning-contract.XXXXXX")"
FEATURE_DIR="$FIXTURE_ROOT/docs/product/2026-09-01-fixture"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$(HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" "$@" 2>&1); then
    fail_test "validator unexpectedly accepted fixture"
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    fail_test "validator did not report '$expected'"
  }
}

write_fixture() {
  rm -rf "$FEATURE_DIR"
  mkdir -p "$FEATURE_DIR"

  printf '%s\n' \
    '{' \
    '  "features": [' \
    '    {' \
    '      "id": "US-1",' \
    '      "acceptance_test_ids": ["TC-US-1-01"],' \
    '      "production_journey": {' \
    '        "required": true,' \
    '        "reason": "This slice crosses the production picker and returns to the editor.",' \
    '        "acceptance_test_id": "TC-US-1-01",' \
    '        "production_entry_point": "AppNavigationHost",' \
    '        "test_file": "app/src/androidTest/java/example/JourneyTest.kt",' \
    '        "test_method": "returnsToEditor",' \
    '        "user_actions": "Open the picker and select a target note.",' \
    '        "return_boundary": "Selecting the target pops back to the editor.",' \
    '        "post_return_assertion": "The linked label is visible in the editor after return."' \
    '      }' \
    '    },' \
    '    {' \
    '      "id": "US-2",' \
    '      "acceptance_test_ids": ["TC-US-2-01"],' \
    '      "production_journey": {' \
    '        "required": false,' \
    '        "reason": "This slice changes local formatting state without a navigation or return boundary.",' \
    '        "acceptance_test_id": null,' \
    '        "production_entry_point": null,' \
    '        "test_file": null,' \
    '        "test_method": null,' \
    '        "user_actions": null,' \
    '        "return_boundary": null,' \
    '        "post_return_assertion": null' \
    '      }' \
    '    }' \
    '  ]' \
    '}' \
    > "$FEATURE_DIR/feature_list.json"

  printf '%s\n' \
    '# Sprint Contract' \
    '' \
    '## Rule Applicability Contract' \
    '' \
    '| Rule ID | Rule document | Decision | Slice evidence |' \
    '|---|---|---|---|' \
    '| NAV | navigation-rules.md | Required | journey |' \
    '' \
    '## Production Journey Planning Contract' \
    '' \
    '| User story | Journey required | Journey reason | Journey acceptance test ID | Production entry point | Planned test file and method | User actions | Return boundary | Post-return assertion |' \
    '|---|---|---|---|---|---|---|---|---|' \
    '| US-1 | Yes | This slice crosses the production picker and returns to the editor. | `TC-US-1-01` | `AppNavigationHost` | `app/src/androidTest/java/example/JourneyTest.kt#returnsToEditor` | Open the picker and select a target note. | Selecting the target pops back to the editor. | The linked label is visible in the editor after return. |' \
    '| US-2 | No | This slice changes local formatting state without a navigation or return boundary. | N/A | N/A | N/A | N/A | N/A | N/A |' \
    '' \
    '## User Scenarios & Testing' \
    '' \
    '### US-1: Picker return' \
    '' \
    '## Acceptance Test Cases' \
    '' \
    '| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |' \
    '|---|---|---|---|---|---|---|---|' \
    '| TC-US-1-01 | AC-US-1-01 | Instrumented UI | app/src/androidTest/java/example/JourneyTest.kt#returnsToEditor | N/A — no API | Open the picker, select a target, and return to the editor. | The linked label is visible after return. | ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.JourneyTest |' \
    '| TC-US-2-01 | AC-US-2-01 | JVM unit | app/src/test/java/example/FormattingTest.kt#togglesBold | N/A — no API | Toggle the local formatting state. | The mark is applied. | ./gradlew testDebugUnitTest --tests example.FormattingTest |' \
    > "$FEATURE_DIR/sprint-contract.md"
}

write_fixture
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture

sed '/^## Production Journey Planning Contract/,$d' \
  "$FEATURE_DIR/sprint-contract.md" \
  > "$FEATURE_DIR/sprint-contract.tmp"
mv "$FEATURE_DIR/sprint-contract.tmp" "$FEATURE_DIR/sprint-contract.md"
expect_failure "is missing the '## Production Journey Planning Contract' section" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture

write_fixture
sed 's/| US-1 | Yes |/| US-1 | No |/' \
  "$FEATURE_DIR/sprint-contract.md" \
  > "$FEATURE_DIR/sprint-contract.tmp"
mv "$FEATURE_DIR/sprint-contract.tmp" "$FEATURE_DIR/sprint-contract.md"
expect_failure "does not match planning row 'No'" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture

write_fixture
sed 's/| TC-US-1-01 | AC-US-1-01 | Instrumented UI |/| TC-US-1-01 | AC-US-1-01 | JVM unit |/' \
  "$FEATURE_DIR/sprint-contract.md" \
  > "$FEATURE_DIR/sprint-contract.tmp"
mv "$FEATURE_DIR/sprint-contract.tmp" "$FEATURE_DIR/sprint-contract.md"
expect_failure "must be planned as an Instrumented UI acceptance test" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture

echo "PASS: planning contract requires journey classification, mirrored ownership, and an instrumented owner for navigation signals."
