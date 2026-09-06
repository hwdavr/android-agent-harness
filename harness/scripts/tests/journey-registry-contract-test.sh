#!/usr/bin/env bash
# Contract test for the Critical Journey Registry validator and runner.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-journey-registry.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/journey-registry-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_success() {
  local output
  if ! output=$("$@" 2>&1); then
    echo "$output" >&2
    fail_test "command unexpectedly failed: $*"
  fi
}

expect_failure() {
  local expected_exit="$1"
  local expected_text="$2"
  shift 2
  local output
  set +e
  output=$("$@" 2>&1)
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "$output" >&2
    fail_test "command unexpectedly succeeded: $*"
  fi

  if [ "$status" -ne "$expected_exit" ]; then
    echo "$output" >&2
    fail_test "expected exit code $expected_exit, got $status: $*"
  fi

  printf '%s\n' "$output" | grep -Fq "$expected_text" || {
    echo "$output" >&2
    fail_test "output did not contain expected text '$expected_text': $*"
  }
}

# Setup dummy project fixture
mkdir -p "$FIXTURE_ROOT/docs/product"
mkdir -p "$FIXTURE_ROOT/app/src/androidTest/java/com/example/test"
mkdir -p "$FIXTURE_ROOT/app/src/main/java/com/example/notesapp/navigation"

cat << 'EOF' > "$FIXTURE_ROOT/app/src/androidTest/java/com/example/test/DummyJourneyTest.kt"
package com.example.test

import org.junit.Test

class DummyJourneyTest {
    @Test
    fun validJourneyMethod() {
    }
}
EOF

cat << 'EOF' > "$FIXTURE_ROOT/app/src/main/java/com/example/notesapp/navigation/Destinations.kt"
package com.example.notesapp.navigation

sealed class Destinations(val route: String) {
    data object Home : Destinations("home")
    data object Editor : Destinations("editor")
    data object Settings : Destinations("settings")
}
EOF

# Case 1: Valid registry passes validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save -> return to Home"
    introduced_by: test-feature/US-1
    destinations:
      - Home
      - Editor
    test_file: app/src/androidTest/java/com/example/test/DummyJourneyTest.kt
    test_method: validJourneyMethod
    gradle_selector: "com.example.test.DummyJourneyTest#validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --destinations-file "$FIXTURE_ROOT/app/src/main/java/com/example/notesapp/navigation/Destinations.kt" \
  --validate

# Case 2: Missing registry file fails
expect_failure 2 "Journey registry file not found" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/harness/non-existent.yaml" \
  --validate

# Case 3: Missing required field fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - Home
    test_file: app/src/androidTest/java/com/example/test/DummyJourneyTest.kt
    # Missing test_method, gradle_selector, boundary, post_return_assertion
EOF

expect_failure 2 "missing required field 'test_method'" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 4: Non-existent test_file fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - Home
    test_file: app/src/androidTest/java/com/example/test/NoSuchTest.kt
    test_method: validJourneyMethod
    gradle_selector: "com.example.test.NoSuchTest#validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "test_file does not exist" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 5: Non-existent test_method in existing test file fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - Home
    test_file: app/src/androidTest/java/com/example/test/DummyJourneyTest.kt
    test_method: noSuchMethod
    gradle_selector: "com.example.test.DummyJourneyTest#noSuchMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "test_method 'noSuchMethod' not found" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 6: Duplicate journey ID fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - Home
    test_file: app/src/androidTest/java/com/example/test/DummyJourneyTest.kt
    test_method: validJourneyMethod
    gradle_selector: "com.example.test.DummyJourneyTest#validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
  - id: J-DUMMY-JOURNEY
    description: "Another journey with duplicate ID"
    introduced_by: test-feature/US-2
    destinations:
      - Home
    test_file: app/src/androidTest/java/com/example/test/DummyJourneyTest.kt
    test_method: validJourneyMethod
    gradle_selector: "com.example.test.DummyJourneyTest#validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "duplicate journey id 'J-DUMMY-JOURNEY'" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 7: Placeholder values fail validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "{insert description}"
    introduced_by: test-feature/US-1
    destinations:
      - Home
    test_file: app/src/androidTest/java/com/example/test/DummyJourneyTest.kt
    test_method: validJourneyMethod
    gradle_selector: "com.example.test.DummyJourneyTest#validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "has empty or placeholder value" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 8: Coverage check identifies covered and uncovered destinations
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - Home
    test_file: app/src/androidTest/java/com/example/test/DummyJourneyTest.kt
    test_method: validJourneyMethod
    gradle_selector: "com.example.test.DummyJourneyTest#validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

cov_output=$(bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --destinations-file "$FIXTURE_ROOT/app/src/main/java/com/example/notesapp/navigation/Destinations.kt" \
  --check-coverage)

printf '%s\n' "$cov_output" | grep -Fq "[+] Home" || fail_test "Home not reported as covered"
printf '%s\n' "$cov_output" | grep -Fq "[-] Editor" || fail_test "Editor not reported as uncovered"
printf '%s\n' "$cov_output" | grep -Fq "[-] Settings" || fail_test "Settings not reported as uncovered"

# Case 9: --run-one with unknown ID fails with code 2
expect_failure 2 "Journey ID 'J-UNKNOWN' not found in registry" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --run-one J-UNKNOWN

# Case 10: --run-one and --run-all with --dry-run succeed with code 0
expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --run-one J-DUMMY-JOURNEY \
  --dry-run

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --run-all \
  --dry-run

echo "PASS: All 10 journey-registry contract test cases passed."
