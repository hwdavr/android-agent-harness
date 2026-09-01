#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-evaluation-fix-contract.sh"
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/review-lifecycle-test.XXXXXX")
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

FEATURE_DIR="$FIXTURE_ROOT/docs/product/2026-08-29-fixture"

write_tracker() {
  local status="$1"
  mkdir -p "$FEATURE_DIR"
  printf '%s\n' \
    '# Fixture' \
    '<!-- HARNESS_TRACKER_START -->' \
    '| ID | Feature | Workspace | Status | Updated | Notes |' \
    '|---|---|---|---|---|---|' \
    "| fixture | Fixture | [docs/product/2026-08-29-fixture/](2026-08-29-fixture/) | $status | 2026-08-30 | Contract fixture |" \
    '<!-- HARNESS_TRACKER_END -->' \
    > "$FIXTURE_ROOT/docs/product/product.md"
}

write_feature() {
  local result_text="${1:-1 test passed}"
  local status="${2:-passing}"
  mkdir -p "$FEATURE_DIR" "$FIXTURE_ROOT/app/src/test/com/example/fixture"
  cat > "$FEATURE_DIR/feature_list.json" <<JSON
{
  "features": [{
    "id": "US-1",
    "status": "$status",
    "acceptance_test_ids": ["TC-US-1-01"],
    "evidence": [{
      "test_id": "TC-US-1-01",
      "executed_command": "./gradlew testDebugUnitTest --tests com.example.fixture.FixtureTest",
      "exit_status": 0,
      "result": "$result_text"
    }]
  }]
}
JSON
  printf '%s\n' \
    '# Sprint Contract' \
    '' \
    '| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |' \
    '|---|---|---|---|---|---|---|---|' \
    '| TC-US-1-01 | AC-US-1-01 | JVM unit | app/src/test/com/example/fixture/FixtureTest.kt#primaryAcceptance | N/A — no API | Run fixture behavior. | Fixture expectation passes. | ./gradlew testDebugUnitTest --tests com.example.fixture.FixtureTest |' \
    > "$FEATURE_DIR/sprint-contract.md"
  cat > "$FIXTURE_ROOT/app/src/test/com/example/fixture/FixtureTest.kt" <<'EOF'
package com.example.fixture

import org.junit.Test

class FixtureTest {
    @Test
    fun primaryAcceptance() {
        check(true)
    }
}
EOF
  printf '%s\n' '# Evaluator Rubric' > "$FEATURE_DIR/evaluator-rubric.md"
  printf '%s\n' '# Code Review' > "$FEATURE_DIR/code_review_fixture.md"
  printf '%s\n' '# Test Review' > "$FEATURE_DIR/test_review_fixture.md"
  printf '%s\n' '# Summary' > "$FEATURE_DIR/summary_fixture.md"
}

write_valid_evaluator_rubric() {
  cat > "$FEATURE_DIR/evaluator-rubric.md" <<'EOF'
# Evaluator Rubric

| Category | Question | Score (0-5) | Notes |
| --- | --- | ---: | --- |
| Correctness | | 5 | |
| Verification | | 5 | |
| Scope discipline | | 5 | |
| Reliability | | 5 | |
| Maintainability | | 5 | |
| Handoff readiness | | 5 | |
| Code & Test Review | | 5 | |
| Rule Applicability | | 5 | |

### Overall: 5.0 / 5

## Verdict

**Accept**
EOF
}

write_valid_fix_reports() {
  cat > "$FEATURE_DIR/code_review_fixture.md" <<'EOF'
# Code Review

## Required Findings

1. Fixture finding.
   > **Fix Status:** Fixed ✅ — fixture fix (commit abc123; verified: fixture, exit 0; 2026-08-30).

## Verdict

> **Fix Pass:** 1/1 findings fixed; 0 unresolved (2026-08-30).

**APPROVED**
EOF
  cat > "$FEATURE_DIR/test_review_fixture.md" <<'EOF'
# Test Review

## Fix Status Overlay

| Source ID / finding | Fix Status | Re-verification |
|---|---|---|
| AC-US-1-01 | Fixed ✅ | fixture |

## Fix Pass Summary

**Fixed:** 1/1. **Unresolved:** 0.

## Verdict

**APPROVED**
EOF
  cat > "$FEATURE_DIR/summary_fixture.md" <<'EOF'
# Fix Pass Summary

## Stage Status

| Fix-Stage 1 — Orient | ✅ Complete | |
| Fix-Stage 2 — Setup | ✅ Complete | |
| Fix-Stage 3 — Fix | ✅ Complete | |
| Fix-Stage 4 — Re-verify | ✅ Complete | |
| Fix-Stage 5 — Finalize | ✅ Complete | |
| Fix-Stage 6 — Install | ✅ Complete | |
EOF
}

write_tracker "To be human reviewed"
write_feature
write_valid_evaluator_rubric
write_valid_fix_reports
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-08-29-fixture --evaluation

sed 's/### Overall: 5.0/### Overall: 4.9/' \
  "$FEATURE_DIR/evaluator-rubric.md" > "$FEATURE_DIR/evaluator-rubric.tmp"
mv "$FEATURE_DIR/evaluator-rubric.tmp" "$FEATURE_DIR/evaluator-rubric.md"
expect_failure "does not match arithmetic mean 5.0" \
  bash "$VALIDATOR" docs/product/2026-08-29-fixture --evaluation

write_valid_evaluator_rubric
write_feature "coverage attempt stalled and terminated" "passing"
expect_failure "contradicts success" \
  bash "$VALIDATOR" docs/product/2026-08-29-fixture --evaluation

write_feature
write_valid_evaluator_rubric
write_valid_fix_reports
write_tracker "To be human reviewed"
sed 's/| Fix-Stage 2 — Setup | ✅ Complete |/| Fix-Stage 2 — Setup | ⚠️ Blocked |/' \
  "$FEATURE_DIR/summary_fixture.md" > "$FEATURE_DIR/summary_fixture.tmp"
mv "$FEATURE_DIR/summary_fixture.tmp" "$FEATURE_DIR/summary_fixture.md"
expect_failure "contains a blocked or incomplete fix stage" \
  bash "$VALIDATOR" docs/product/2026-08-29-fixture --fix

write_feature
write_valid_evaluator_rubric
write_valid_fix_reports
write_tracker "To be human reviewed"
sed 's/\*\*APPROVED\*\*/**REVISION REQUIRED**/' \
  "$FEATURE_DIR/code_review_fixture.md" > "$FEATURE_DIR/code_review_fixture.tmp"
mv "$FEATURE_DIR/code_review_fixture.tmp" "$FEATURE_DIR/code_review_fixture.md"
expect_failure "Verdict still reports a non-passing outcome" \
  bash "$VALIDATOR" docs/product/2026-08-29-fixture --fix

write_feature
write_valid_evaluator_rubric
write_valid_fix_reports
write_tracker "To be human reviewed"
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-08-29-fixture --fix

echo "PASS: review lifecycle rejects inconsistent scores, contradictory evidence, and blocked fix-stage advancement."
