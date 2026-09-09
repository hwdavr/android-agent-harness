#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$PROJECT_ROOT/harness/scripts/check-evidence-receipt.sh"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/evidence-receipt-contract.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output status
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "command unexpectedly passed: $*"
  printf '%s\n' "$output" | rg -Fq "$expected" \
    || fail "failure did not contain '$expected': $output"
}

cat > "$TEMP_ROOT/receipt.json" <<'JSON'
{
  "command": "./gradlew testDebugUnitTest",
  "exit_code": 0,
  "evidence_path": "reports/tests.txt",
  "fingerprints": {
    "source": "source-a",
    "build_config": "config-a",
    "command": "command-a",
    "runtime": "runtime-a"
  }
}
JSON
mkdir -p "$TEMP_ROOT/reports"
printf '%s\n' 'BUILD SUCCESSFUL' > "$TEMP_ROOT/reports/tests.txt"

bash "$VALIDATOR" "$TEMP_ROOT/receipt.json" \
  --source source-a --build-config config-a --command command-a --runtime runtime-a >/dev/null

expect_failure "stale source fingerprint" bash "$VALIDATOR" "$TEMP_ROOT/receipt.json" \
  --source source-b --build-config config-a --command command-a --runtime runtime-a

jq '.exit_code = 1' "$TEMP_ROOT/receipt.json" > "$TEMP_ROOT/failed.json"
expect_failure "receipt exit_code must be 0" bash "$VALIDATOR" "$TEMP_ROOT/failed.json" \
  --source source-a --build-config config-a --command command-a --runtime runtime-a

jq 'del(.fingerprints.runtime)' "$TEMP_ROOT/receipt.json" > "$TEMP_ROOT/missing.json"
expect_failure "missing runtime fingerprint" bash "$VALIDATOR" "$TEMP_ROOT/missing.json" \
  --source source-a --build-config config-a --command command-a --runtime runtime-a

echo "PASS: evidence receipts are reusable only while all required fingerprints remain valid."
