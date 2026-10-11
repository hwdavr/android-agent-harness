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

# Rendered rich-text evidence regression: a state-only mark assertion must not
# satisfy an acceptance row that claims visible text styling.
write_rendered_fixture() {
  rm -rf "$FEATURE_DIR"
  mkdir -p "$FEATURE_DIR" "$FIXTURE_ROOT/app/src/androidTest/java/example"

  printf '%s\n' \
    '{' \
    '  "features": [{' \
    '    "id": "US-1",' \
    '    "status": "passing",' \
    '    "acceptance_test_ids": ["TC-US-1-01"],' \
    '    "evidence": [{' \
    '      "test_id": "TC-US-1-01",' \
    '      "executed_command": "./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.RenderedTest",' \
    '      "exit_status": 0,' \
    '      "result": "Rendered-output fixture passed"' \
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
    '| TC-US-1-01 | AC-US-1-01 | Instrumented UI | `app/src/androidTest/java/example/RenderedTest.kt#markedTextIsRendered` | N/A — no API | Render marked text in the production editor. | Following text visibly inherits Bold and differs from the plain text. | ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.RenderedTest |' \
    > "$FEATURE_DIR/sprint-contract.md"
}

write_rendered_fixture
printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Assert.assertTrue' \
  'import org.junit.Test' \
  '' \
  'class RenderedTest {' \
  '  @Test' \
  '  fun markedTextIsRendered() {' \
  '    val marks = listOf("bold")' \
  '    assertTrue("bold" in marks)' \
  '  }' \
  '}' \
  > "$FIXTURE_ROOT/app/src/androidTest/java/example/RenderedTest.kt"
expect_failure "must capture a Compose node with captureToImage()" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture --test US-1

write_rendered_fixture
printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Assert.assertTrue' \
  'import org.junit.Test' \
  '' \
  'class RenderedTest {' \
  '  @Test' \
  '  fun markedTextIsRendered() {' \
  '    val plain = onNodeWithTag("plain").captureToImage().asAndroidBitmap()' \
  '    val marked = onNodeWithTag("marked").captureToImage().asAndroidBitmap()' \
  '    assertTrue(plain.differingPixelCount(marked) > 0)' \
  '  }' \
  '}' \
  > "$FIXTURE_ROOT/app/src/androidTest/java/example/RenderedTest.kt"
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" \
  docs/product/2026-09-01-fixture --test US-1 >/dev/null
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" \
  docs/product/2026-09-01-fixture --evaluate >/dev/null

# Route-open ownership regression: an acceptance row that claims opening or
# navigating to a route must be the named production-journey owner.
write_journey_fixture() {
  rm -rf "$FEATURE_DIR"
  mkdir -p "$FEATURE_DIR"

  printf '%s\n' \
    '{' \
    '  "features": [{' \
    '    "id": "US-1",' \
    '    "acceptance_test_ids": ["TC-US-1-01", "TC-US-1-02"],' \
    '    "production_journey": {' \
    '      "required": true,' \
    '      "reason": "This slice crosses the production picker and returns to the editor.",' \
    '      "acceptance_test_id": "TC-US-1-01",' \
    '      "production_entry_point": "AppNavigationHost",' \
    '      "test_file": "app/src/androidTest/java/example/JourneyTest.kt",' \
    '      "test_method": "returnsToEditor",' \
    '      "user_actions": "Open the picker and select a target note.",' \
    '      "return_boundary": "Selecting the target pops back to the editor.",' \
    '      "post_return_assertion": "The linked label is visible in the editor after return."' \
    '    }' \
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
    '| TC-US-1-01 | AC-US-1-01 | Instrumented UI | app/src/androidTest/java/example/JourneyTest.kt#returnsToEditor | N/A — no API | Open the picker, select a target, and return to the editor. | The linked label is visible after return. | ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.JourneyTest |' \
    '| TC-US-1-02 | AC-US-1-02 | Instrumented UI | app/src/androidTest/java/example/LinkScreenTest.kt#opensTarget | N/A — no API | Render a valid inserted link and tap its semantic link node. | Label is tappable and styled. | ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=example.LinkScreenTest |' \
    > "$FEATURE_DIR/sprint-contract.md"
}

ROUTE_OPEN_CLAIM='and opens the existing target Editor route'

# The named journey owner may claim the route-open outcome.
write_journey_fixture
sed "s/The linked label is visible after return./The linked label is visible after return $ROUTE_OPEN_CLAIM./" \
  "$FEATURE_DIR/sprint-contract.md" \
  > "$FEATURE_DIR/sprint-contract.tmp"
mv "$FEATURE_DIR/sprint-contract.tmp" "$FEATURE_DIR/sprint-contract.md"
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture --planning

# A non-owner row claiming the same outcome must be rejected.
write_journey_fixture
sed "s/Label is tappable and styled./Label is tappable $ROUTE_OPEN_CLAIM./" \
  "$FEATURE_DIR/sprint-contract.md" \
  > "$FEATURE_DIR/sprint-contract.tmp"
mv "$FEATURE_DIR/sprint-contract.tmp" "$FEATURE_DIR/sprint-contract.md"
expect_failure "TC-US-1-02 claims an open/navigate-to-route outcome but is not the named production-journey owner" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture --planning

# Control: the identical row without route-open language stays accepted.
write_journey_fixture
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture --planning

echo "PASS: acceptance traceability validator rejects missing methods, scenario drift, and unscoped evidence."
