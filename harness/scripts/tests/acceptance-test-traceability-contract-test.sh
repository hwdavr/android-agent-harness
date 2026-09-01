#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-acceptance-test-traceability.sh"
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/acceptance-traceability-test.XXXXXX")
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
  mkdir -p "$FEATURE_DIR" "$FIXTURE_ROOT/app/src/test/java/example" "$FIXTURE_ROOT/sharedContracts/test-scenarios"

  printf '%s\n' \
    '{' \
    '  "features": [{' \
    '    "id": "US-1",' \
    '    "status": "passing",' \
    '    "acceptance_test_ids": ["TC-US-1-01"],' \
    '    "evidence": [{' \
    '      "test_id": "TC-US-1-01",' \
    '      "executed_command": "./gradlew testDebugUnitTest --tests example.FixtureIntegrationTest",' \
    '      "exit_status": 0,' \
    '      "result": "Fixture test passed"' \
    '    }]' \
    '  }]' \
    '}' \
    > "$FEATURE_DIR/feature_list.json"

  printf '%s\n' \
    '# Sprint Contract' \
    '' \
    '## Acceptance Test Cases' \
    '' \
    '| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |' \
    '|---|---|---|---|---|---|---|---|' \
    '| TC-US-1-01 | AC-US-1-01 | JVM integration | app/src/test/java/example/FixtureIntegrationTest.kt#loadsSharedScenario | sharedContracts/test-scenarios/fixture_001.json | Load the shared response through the production fixture path. | The shared scenario is decoded and the domain result is asserted. | ./gradlew testDebugUnitTest --tests example.FixtureIntegrationTest |' \
    > "$FEATURE_DIR/sprint-contract.md"

  printf '%s\n' \
    'package example' \
    '' \
    'import org.junit.Test' \
    '' \
    'class FixtureIntegrationTest {' \
    '  @Test' \
    '  fun loadsSharedScenario() {' \
    '    val scenario = "fixture_001.json"' \
    '    check(scenario.isNotEmpty())' \
    '  }' \
    '}' \
    > "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.kt"
  printf '%s\n' '{"id":"fixture_001"}' > "$FIXTURE_ROOT/sharedContracts/test-scenarios/fixture_001.json"
}

write_fixture
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture --planning
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture --test US-1
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture --evaluate

sed 's/fun loadsSharedScenario()/fun missingSharedScenario()/' \
  "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.kt" \
  > "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.tmp"
mv "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.tmp" \
  "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.kt"
expect_failure "declared test method is missing" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture --test US-1

write_fixture
sed 's/fixture_001.json/other_fixture.json/' \
  "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.kt" \
  > "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.tmp"
mv "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.tmp" \
  "$FIXTURE_ROOT/app/src/test/java/example/FixtureIntegrationTest.kt"
expect_failure "does not reference declared shared scenario fixture_001.json" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture --test US-1

write_fixture
sed 's/--tests example.FixtureIntegrationTest//' "$FEATURE_DIR/feature_list.json" \
  > "$FEATURE_DIR/feature_list.tmp"
mv "$FEATURE_DIR/feature_list.tmp" "$FEATURE_DIR/feature_list.json"
expect_failure "has no successful evidence command scoped to FixtureIntegrationTest" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture --evaluate

echo "PASS: acceptance traceability validator rejects missing methods, scenario drift, and unscoped evidence."
