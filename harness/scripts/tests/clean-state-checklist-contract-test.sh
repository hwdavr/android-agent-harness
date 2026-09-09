#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TEMPLATE="$PROJECT_ROOT/harness/templates/clean-state-checklist-template.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

rg -Fq '## Core Checks' "$TEMPLATE" || fail "clean-state template is missing core checks"
for trigger in API ROOM NAV UI PLATFORM OBS RESET ADR; do
  rg -Fq "Conditional: $trigger" "$TEMPLATE" \
    || fail "clean-state template is missing the $trigger conditional marker"
done
rg -Fq 'N/A — <feature-specific reason>' "$TEMPLATE" \
  || fail "clean-state template does not require explicit N/A rationale"

for forbidden in 'JSON log payloads' 'VERBOSE to ASSERT' 'documentId' \
  'every IPC channel and background service invocation is logged'; do
  if rg -Fq "$forbidden" "$TEMPLATE"; then
    fail "clean-state template contains contradictory logging guidance: $forbidden"
  fi
done

rg -Fq '.agents/rules/observability.md' "$TEMPLATE" \
  || fail "clean-state observability checks must reference the authoritative rule"

echo "PASS: clean-state checks distinguish core and conditional scope without logging conflicts."
