#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAGE_GATE="$PROJECT_ROOT/harness/scripts/check-stage-artifacts.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/project-doc-location-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

mkdir -p "$FIXTURE_ROOT/docs/current" \
  "$FIXTURE_ROOT/android-agent-harness/docs/current"
printf '%s\n' '# Summary' > "$FIXTURE_ROOT/docs/current/summary_fixture.md"
printf '%s\n' '# Misplaced Summary' > \
  "$FIXTURE_ROOT/android-agent-harness/docs/current/summary_fixture.md"

HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$STAGE_GATE" \
  harness-generator orient "$FIXTURE_ROOT/docs/current" fixture >/dev/null ||
  fail "stage artifacts under the consumer project's root docs/ were rejected"

mkdir -p "$FIXTURE_ROOT/.scratch/change" \
  "$FIXTURE_ROOT/android-agent-harness/.scratch/change"
printf '%s\n' '# Summary' > "$FIXTURE_ROOT/.scratch/change/summary_fixture.md"
printf '%s\n' '# Misplaced Summary' > \
  "$FIXTURE_ROOT/android-agent-harness/.scratch/change/summary_fixture.md"
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$STAGE_GATE" \
  harness-generator orient "$FIXTURE_ROOT/.scratch/change" fixture >/dev/null ||
  fail "stage artifacts under the consumer project's root .scratch/ were rejected"

if OUTPUT="$(HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$STAGE_GATE" \
  harness-generator orient \
  "$FIXTURE_ROOT/android-agent-harness/.scratch/change" fixture 2>&1)"; then
  fail "stage artifacts under the shared submodule .scratch/ were accepted"
fi
printf '%s\n' "$OUTPUT" | grep -Fq "is owned by the shared android-agent-harness submodule" ||
  fail "misplaced scratch records failed without the ownership diagnostic: $OUTPUT"

set +e
OUTPUT="$(HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$STAGE_GATE" \
  harness-generator orient \
  "$FIXTURE_ROOT/android-agent-harness/docs/current" fixture 2>&1)"
STATUS=$?
set -e

[ "$STATUS" -ne 0 ] ||
  fail "stage artifacts under the shared submodule docs/ were accepted"
printf '%s\n' "$OUTPUT" | grep -Fq "is owned by the shared android-agent-harness submodule" ||
  fail "misplaced project docs failed without the ownership diagnostic: $OUTPUT"

echo "PASS: stage artifact gate accepts consumer root docs and rejects shared submodule docs."
