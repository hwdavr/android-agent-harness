#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <receipt.json> --source <fingerprint> --build-config <fingerprint> --command <fingerprint> --runtime <fingerprint>" >&2
  exit 2
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ "$#" -eq 9 ] || usage
RECEIPT="$1"
shift

SOURCE_FINGERPRINT=""
BUILD_CONFIG_FINGERPRINT=""
COMMAND_FINGERPRINT=""
RUNTIME_FINGERPRINT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) SOURCE_FINGERPRINT="${2:-}" ;;
    --build-config) BUILD_CONFIG_FINGERPRINT="${2:-}" ;;
    --command) COMMAND_FINGERPRINT="${2:-}" ;;
    --runtime) RUNTIME_FINGERPRINT="${2:-}" ;;
    *) usage ;;
  esac
  shift 2
done

command -v jq >/dev/null 2>&1 || fail "jq is required"
[ -f "$RECEIPT" ] || fail "receipt not found: $RECEIPT"
jq -e . "$RECEIPT" >/dev/null 2>&1 || fail "invalid receipt JSON: $RECEIPT"

EXIT_CODE="$(jq -r '.exit_code // empty' "$RECEIPT")"
[ "$EXIT_CODE" = "0" ] || fail "receipt exit_code must be 0"

RECORDED_COMMAND="$(jq -r '.command // empty' "$RECEIPT")"
[ -n "$RECORDED_COMMAND" ] || fail "receipt command is missing"

EVIDENCE_PATH="$(jq -r '.evidence_path // empty' "$RECEIPT")"
[ -n "$EVIDENCE_PATH" ] || fail "receipt evidence_path is missing"
case "$EVIDENCE_PATH" in
  /*) RESOLVED_EVIDENCE="$EVIDENCE_PATH" ;;
  *) RESOLVED_EVIDENCE="$(cd "$(dirname "$RECEIPT")" && pwd)/$EVIDENCE_PATH" ;;
esac
[ -s "$RESOLVED_EVIDENCE" ] || fail "receipt evidence is missing or empty: $RESOLVED_EVIDENCE"

check_fingerprint() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(jq -r --arg key "$key" '.fingerprints[$key] // empty' "$RECEIPT")"
  [ -n "$actual" ] || fail "missing $key fingerprint"
  [ "$actual" = "$expected" ] || fail "stale $key fingerprint: expected '$expected', found '$actual'"
}

check_fingerprint source "$SOURCE_FINGERPRINT"
check_fingerprint build_config "$BUILD_CONFIG_FINGERPRINT"
check_fingerprint command "$COMMAND_FINGERPRINT"
check_fingerprint runtime "$RUNTIME_FINGERPRINT"

echo "PASS: evidence receipt is current: $RECEIPT"
