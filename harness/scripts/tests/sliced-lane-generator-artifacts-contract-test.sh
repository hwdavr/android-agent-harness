#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAGE_GATE="$PROJECT_ROOT/harness/scripts/check-stage-artifacts.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sliced-lane-generator-artifacts.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    fail "command unexpectedly succeeded: $*"
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    fail "failure did not contain: $expected"
  }
}

missing_summary="$FIXTURE_ROOT/.scratch/2026-11-09-missing-summary"
mkdir -p "$missing_summary"
expect_failure "no 'summary_US-1.md'" \
  bash "$STAGE_GATE" sliced-lane-generator orient "$missing_summary" US-1

with_summary="$FIXTURE_ROOT/.scratch/2026-11-09-with-summary"
mkdir -p "$with_summary"
touch "$with_summary/summary_US-1.md"
bash "$STAGE_GATE" sliced-lane-generator orient "$with_summary" US-1 >/dev/null

expect_failure "no 'summary_US-2.md'" \
  bash "$STAGE_GATE" sliced-lane-generator orient "$with_summary" US-2

expect_failure "requires the selected slice id" \
  bash "$STAGE_GATE" sliced-lane-generator orient "$with_summary"

echo "PASS: sliced-lane-generator Stage 1 requires the exact selected-slice summary file."
