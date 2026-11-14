#!/usr/bin/env bash
# Stage artifacts live only in the consumer project's dated .scratch/ workspaces:
# docs/current/ is retired, and records inside the shared harness submodule are rejected.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAGE_GATE="$PROJECT_ROOT/harness/scripts/check-stage-artifacts.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/project-doc-location-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_rejected() {  # directory, expected diagnostic, label
  local output
  if output="$(HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$STAGE_GATE" sliced-lane-generator orient "$1" US-1 2>&1)"; then
    fail "$3 was accepted"
  fi
  printf '%s\n' "$output" | grep -Fq "$2" || fail "$3 failed without the expected diagnostic: $output"
}

WORKSPACE="$FIXTURE_ROOT/.scratch/2026-11-09-change"
mkdir -p "$WORKSPACE" "$FIXTURE_ROOT/docs/current" \
  "$FIXTURE_ROOT/.harness/.scratch/2026-11-09-change" \
  "$FIXTURE_ROOT/android-agent-harness/.scratch/2026-11-09-change" \
  "$FIXTURE_ROOT/.scratch/change"
for dir in "$WORKSPACE" "$FIXTURE_ROOT/docs/current" "$FIXTURE_ROOT/.harness/.scratch/2026-11-09-change" \
  "$FIXTURE_ROOT/android-agent-harness/.scratch/2026-11-09-change" "$FIXTURE_ROOT/.scratch/change"; do
  printf '%s\n' '# Summary' > "$dir/summary_US-1.md"
done

HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$STAGE_GATE" sliced-lane-generator orient "$WORKSPACE" US-1 >/dev/null ||
  fail "a dated workspace under the consumer project's .scratch/ was rejected"

expect_rejected "$FIXTURE_ROOT/docs/current" "docs/current/ is retired" "the retired docs/current/ directory"
expect_rejected "$FIXTURE_ROOT/.scratch/change" "must be named <YYYY-MM-DD>-<feature-id>" "an undated workspace"
expect_rejected "$FIXTURE_ROOT/.harness/.scratch/2026-11-09-change" "owned by the shared harness submodule" \
  "a workspace inside the .harness submodule"
expect_rejected "$FIXTURE_ROOT/android-agent-harness/.scratch/2026-11-09-change" "owned by the shared harness submodule" \
  "a workspace inside the android-agent-harness checkout"

echo "PASS: stage artifact gate accepts only dated consumer .scratch/ workspaces."
