#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORKFLOW_DIR="$PROJECT_ROOT/.agents/workflows"

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

for workflow in harness-generator.md harness-fix.md; do
  workflow_path="$WORKFLOW_DIR/$workflow"
  [ -f "$workflow_path" ] || fail_test "missing workflow: $workflow_path"
  if rg -n -i "do not stop the pipeline|continue to the next item|proceed to the next stage" "$workflow_path"; then
    fail_test "$workflow still allows a failed gate to advance the pipeline"
  fi
done

require_before() {
  local workflow="$1"
  local earlier="$2"
  local later="$3"
  local earlier_line later_line
  earlier_line=$(grep -n -m 1 -F "$earlier" "$WORKFLOW_DIR/$workflow" | cut -d: -f1 || true)
  later_line=$(grep -n -m 1 -F "$later" "$WORKFLOW_DIR/$workflow" | cut -d: -f1 || true)
  [ -n "$earlier_line" ] && [ -n "$later_line" ] && [ "$earlier_line" -lt "$later_line" ] \
    || fail_test "$workflow must place '$earlier' before '$later'"
}

rg -Fq 'Every required stage gate is a hard stop.' "$WORKFLOW_DIR/harness-generator.md" \
  || fail_test "generator workflow does not define hard-stop gate semantics"
rg -q -e 'workflow must stop (before the next stage|the pipeline)' "$WORKFLOW_DIR/harness-generator.md" \
  || fail_test "generator workflow does not stop after failed verification"
rg -Fq 'Every required fix-mode gate is a hard stop.' "$WORKFLOW_DIR/harness-fix.md" \
  || fail_test "fix workflow does not define hard-stop gate semantics"
rg -Fq 'keep the feature non-passing and stop the pipeline' "$WORKFLOW_DIR/harness-fix.md" \
  || fail_test "fix workflow does not stop after failed verification"

require_before harness-generator.md "### Stage 3 — Verify Baseline" "### Stage 4 — Implement"
require_before harness-generator.md "### Stage 4 — Implement" "### Stage 5 — Test"
require_before harness-generator.md "check-acceptance-test-traceability.sh" "### Stage 7 — Update State"
require_before harness-fix.md "check-acceptance-test-traceability.sh" "### Fix-Stage 5 — Finalize"
require_before feature-delivery.md "### Stage 3 — Implementation" "### Stage 4 — Testing"
require_before bug-fixing.md "### Stage 2 — Bug Reproduction" "### Stage 4 — Implementation"

TESTING_SKILL="$PROJECT_ROOT/.agents/skills/android-testing/SKILL.md"
rg -Fq 'Bug fixes perform RED reproduction through the `bug-reproduction` skill' "$TESTING_SKILL" \
  || fail_test "android-testing must route RED reproduction exclusively to bug-reproduction"
if rg -Fq 'Test-First Authoring' "$TESTING_SKILL" || rg -Fq 'bug fixes and new behavior' "$TESTING_SKILL"; then
  fail_test "android-testing still imposes feature-level TDD"
fi

echo "PASS: failed generator and fix gates stop the pipeline."
