#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
STAGE_CHECKER="$PROJECT_ROOT/harness/scripts/check-stage-artifacts.sh"

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_rejected() {
  local fixture="$1"
  local expected="$2"
  local output
  local status

  set +e
  output=$(HARNESS_PROJECT_ROOT="$fixture" bash "$STAGE_CHECKER" bug-fixing bug-reproduction "$fixture" 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_test "invalid fixture unexpectedly passed: $fixture"
  printf '%s\n' "$output" | rg -Fq "$expected" ||
    fail_test "invalid fixture did not report '$expected': $output"
}

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bug-reproduction-stage-contract.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

VALID_DOCS="$TEMP_ROOT/valid"
MISSING_SECTION_DOCS="$TEMP_ROOT/missing-section"
PASSING_RESULT_DOCS="$TEMP_ROOT/passing-result"
MISSING_FILE_DOCS="$TEMP_ROOT/missing-file"
RENDERED_FALSE_PASS_DOCS="$TEMP_ROOT/rendered-false-pass"
RENDERED_VALID_DOCS="$TEMP_ROOT/rendered-valid"
mkdir -p "$VALID_DOCS/app/src/androidTest/java/example" \
  "$MISSING_SECTION_DOCS" "$PASSING_RESULT_DOCS" "$MISSING_FILE_DOCS" \
  "$RENDERED_FALSE_PASS_DOCS/app/src/androidTest/java/example" \
  "$RENDERED_VALID_DOCS/app/src/androidTest/java/example"

create_summary() {
  local output="$1"
  printf '%s\n' \
    '# Summary' \
    '' \
    '| Stage | Status | Timestamp | Notes |' \
    '|---|---|---|---|' \
    '| Bug Reproduction | ✅ Complete (RED) | 2026-09-05 00:00 | focused test failed as expected |' \
    > "$output"
}

create_spec() {
  local output="$1"
  local result="$2"
  local file="$3"
  printf '%s\n' \
    '# Spec' \
    '' \
    '## Reproduction Test' \
    '' \
    '- Test name: `reproducesSelectionBug`' \
    "- File: \`$file\`" \
    "- Run result: $result" \
    > "$output"
}

create_summary "$VALID_DOCS/summary_v1.md"
printf '%s\n' 'fun reproducesSelectionBug() = Unit' \
  > "$VALID_DOCS/app/src/androidTest/java/example/ReproductionTest.kt"
create_spec "$VALID_DOCS/spec_v1.md" 'FAILED (expected)' \
  'app/src/androidTest/java/example/ReproductionTest.kt'

HARNESS_PROJECT_ROOT="$VALID_DOCS" bash "$STAGE_CHECKER" \
  bug-fixing bug-reproduction "$VALID_DOCS" >/dev/null ||
  fail_test "valid RED reproduction evidence did not pass"

create_rendered_spec() {
  local output="$1"
  local file="$2"
  printf '%s\n' \
    '# Spec' \
    '' \
    '## Reproduction Test' \
    '' \
    '- Test name: `markedTextIsRendered`' \
    "- File: \`$file\`" \
    '- Run result: RED (expected — rendered appearance is unchanged)' \
    > "$output"
}

create_summary "$RENDERED_FALSE_PASS_DOCS/summary_v1.md"
create_rendered_spec "$RENDERED_FALSE_PASS_DOCS/spec_v1.md" \
  'app/src/androidTest/java/example/ReproductionTest.kt'
printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Assert.assertTrue' \
  'import org.junit.Test' \
  '' \
  'class ReproductionTest {' \
  '  @Test' \
  '  fun markedTextIsRendered() {' \
  '    val marks = listOf("bold")' \
  '    assertTrue("bold" in marks)' \
  '  }' \
  '}' \
  > "$RENDERED_FALSE_PASS_DOCS/app/src/androidTest/java/example/ReproductionTest.kt"
assert_rejected "$RENDERED_FALSE_PASS_DOCS" \
  "must capture a Compose node with captureToImage()"

create_summary "$RENDERED_VALID_DOCS/summary_v1.md"
create_rendered_spec "$RENDERED_VALID_DOCS/spec_v1.md" \
  'app/src/androidTest/java/example/ReproductionTest.kt'
printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Assert.assertTrue' \
  'import org.junit.Test' \
  '' \
  'class ReproductionTest {' \
  '  @Test' \
  '  fun markedTextIsRendered() {' \
  '    val plain = onNodeWithTag("plain").captureToImage().asAndroidBitmap()' \
  '    val marked = onNodeWithTag("marked").captureToImage().asAndroidBitmap()' \
  '    assertTrue(plain.differingPixelCount(marked) > 0)' \
  '  }' \
  '}' \
  > "$RENDERED_VALID_DOCS/app/src/androidTest/java/example/ReproductionTest.kt"
HARNESS_PROJECT_ROOT="$RENDERED_VALID_DOCS" bash "$STAGE_CHECKER" \
  bug-fixing bug-reproduction "$RENDERED_VALID_DOCS" >/dev/null ||
  fail_test "valid rendered RED reproduction evidence did not pass"

create_summary "$MISSING_SECTION_DOCS/summary_v1.md"
printf '%s\n' '# Spec' > "$MISSING_SECTION_DOCS/spec_v1.md"
assert_rejected "$MISSING_SECTION_DOCS" "missing a '## Reproduction Test' section"

create_summary "$PASSING_RESULT_DOCS/summary_v1.md"
create_spec "$PASSING_RESULT_DOCS/spec_v1.md" 'PASSED' \
  'app/src/androidTest/java/example/ReproductionTest.kt'
assert_rejected "$PASSING_RESULT_DOCS" "must record FAILED or RED evidence"

create_summary "$MISSING_FILE_DOCS/summary_v1.md"
create_spec "$MISSING_FILE_DOCS/spec_v1.md" 'RED (expected)' \
  'app/src/androidTest/java/example/MissingTest.kt'
assert_rejected "$MISSING_FILE_DOCS" "reproduction test file does not exist"

echo "PASS: bug-reproduction stage gate accepts RED evidence and rejects missing, passing, or absent test artifacts."
