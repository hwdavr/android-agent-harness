#!/usr/bin/env bash
# Contract test for check-visual-evidence-contract.sh: planning rejects retired pixel goldens and,
# in the sliced lane, requires one final UI slice owning the conformance review; --evaluate
# requires a recorded review.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$ROOT/harness/scripts/check-visual-evidence-contract.sh"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/visual-evidence-test.XXXXXX")"
W="$FIXTURE/.scratch/2026-11-09-ui"
trap 'rm -rf "$FIXTURE"' EXIT

fail_test() { echo "FAIL: $1" >&2; exit 1; }
run() { HARNESS_PROJECT_ROOT="$FIXTURE" bash "$VALIDATOR" "$W" "$@"; }
expect_failure() {
  local expected="$1" output
  shift
  if output=$(run "$@" 2>&1); then fail_test "accepted a fixture that should fail: $expected"; fi
  printf '%s\n' "$output" | grep -Fq -- "$expected" || { echo "$output" >&2; fail_test "missing diagnostic: $expected"; }
}
slices() {  # json array body
  printf '{"features": [%s]}\n' "$1" > "$W/feature_list.json"
}

mkdir -p "$W"
run --planning | grep -Fq "N/A: no UI_contract.md" || fail_test "non-UI workspace must be N/A"

printf '# UI Contract\n' > "$W/UI_contract.md"
printf '# Test Plan\n\n## UI State Verification\n\n| Stage ID | Review capture (test#method) | Structural check (test#method) | Command |\n' > "$W/test-plan.md"
run --planning >/dev/null || fail_test "single-lane UI planning without slices was rejected"

cp "$W/test-plan.md" "$FIXTURE/test-plan.orig"
printf '| TC-US-1-VIS-001 | AC-001 | Visual verification |\n' >> "$W/test-plan.md"
expect_failure "declares TC-*-VIS pixel rows" --planning
cp "$FIXTURE/test-plan.orig" "$W/test-plan.md"
printf 'Run ./gradlew app:verifyRoborazziDebug\n' >> "$W/test-plan.md"
expect_failure "plans a Roborazzi golden command" --planning
cp "$FIXTURE/test-plan.orig" "$W/test-plan.md"

slices '{"id":"US-1","priority":1,"affects_ui":true,"requires_visual_verification":false},{"id":"US-2","priority":2,"affects_ui":true,"requires_visual_verification":true}'
run --planning >/dev/null || fail_test "final UI slice owning the review was rejected"
slices '{"id":"US-1","priority":1,"affects_ui":true,"requires_visual_verification":true},{"id":"US-2","priority":2,"affects_ui":true,"requires_visual_verification":false}'
expect_failure "must be the final UI slice US-2" --planning
slices '{"id":"US-1","priority":1,"affects_ui":true,"requires_visual_verification":false},{"id":"US-2","priority":2,"affects_ui":true,"requires_visual_verification":false}'
expect_failure "exactly one slice that owns the conformance review" --planning
slices '{"id":"US-1","priority":1,"affects_ui":true}'
expect_failure "boolean affects_ui and requires_visual_verification" --planning

expect_failure "missing $W/ui_verification.json" --evaluate

echo "PASS: visual evidence is planned and evaluated as a conformance review, never a pixel golden."
