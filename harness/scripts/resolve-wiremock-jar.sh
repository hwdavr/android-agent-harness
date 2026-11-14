#!/usr/bin/env bash
# Resolve the WireMock standalone JAR used by api-mocking / exploratory QA.
#
# Order:
#   1. HLS_WIREMOCK_JAR, when it names an existing file.
#   2. Exactly one wiremock-standalone-*.jar under HLS_ROOT (the HarnessLens checkout).
#
# Prints the resolved path on stdout. Diagnostics go to stderr.
# Exit codes: 0 resolved, 1 missing or ambiguous.

set -euo pipefail

warn() {
  printf '%s\n' "$1" >&2
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

configured="${HLS_WIREMOCK_JAR:-}"
if [ -n "$configured" ]; then
  if [ -f "$configured" ]; then
    printf '%s\n' "$configured"
    exit 0
  fi
  warn "WARN: HLS_WIREMOCK_JAR is missing: $configured; falling back to HLS_ROOT."
fi

hls_root="${HLS_ROOT:-}"
candidates=()
if [ -n "$hls_root" ] && [ -d "$hls_root" ]; then
  while IFS= read -r jar; do
    [ -n "$jar" ] && candidates+=("$jar")
  done < <(find "$hls_root" -maxdepth 3 -type f -name 'wiremock-standalone-*.jar' 2>/dev/null | LC_ALL=C sort)
fi

case "${#candidates[@]}" in
  1)
    printf '%s\n' "${candidates[0]}"
    ;;
  0)
    fail "HLS_WIREMOCK_JAR (${configured:-unset}) does not identify a file, and no wiremock-standalone-*.jar was found under HLS_ROOT (${hls_root:-unset}). Download WireMock 3 standalone and set HLS_WIREMOCK_JAR."
    ;;
  *)
    warn "FAIL: Multiple WireMock standalone JARs under HLS_ROOT; set HLS_WIREMOCK_JAR to choose one:"
    printf '  %s\n' "${candidates[@]}" >&2
    exit 1
    ;;
esac
