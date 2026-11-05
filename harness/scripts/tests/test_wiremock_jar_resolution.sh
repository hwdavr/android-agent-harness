#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")/.." && pwd)"
resolver="$script_dir/resolve-wiremock-jar.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/harnesslens" "$tmp_dir/configured"
touch "$tmp_dir/harnesslens/wiremock-standalone-3.13.2.jar"
touch "$tmp_dir/configured/wiremock.jar"

resolved="$(
    HLS_WIREMOCK_JAR="$tmp_dir/missing.jar" \
        HLS_ROOT="$tmp_dir/harnesslens" bash "$resolver" 2>"$tmp_dir/fallback.log"
)"
[[ "$resolved" == "$tmp_dir/harnesslens/wiremock-standalone-3.13.2.jar" ]]
grep -q 'HLS_WIREMOCK_JAR is missing' "$tmp_dir/fallback.log"

resolved="$(
    HLS_WIREMOCK_JAR="$tmp_dir/configured/wiremock.jar" \
        HLS_ROOT="$tmp_dir/harnesslens" bash "$resolver"
)"
[[ "$resolved" == "$tmp_dir/configured/wiremock.jar" ]]

touch "$tmp_dir/harnesslens/wiremock-standalone-3.13.1.jar"
if HLS_WIREMOCK_JAR="$tmp_dir/missing.jar" \
    HLS_ROOT="$tmp_dir/harnesslens" bash "$resolver" >"$tmp_dir/ambiguous.out" 2>"$tmp_dir/ambiguous.log"; then
    printf '%s\n' 'Expected ambiguous JAR resolution to fail.' >&2
    exit 1
fi
grep -q 'Multiple WireMock standalone JARs' "$tmp_dir/ambiguous.log"

if HLS_WIREMOCK_JAR="$tmp_dir/missing.jar" \
    HLS_ROOT="$tmp_dir/no-jar" bash "$resolver" >"$tmp_dir/missing.out" 2>"$tmp_dir/missing.log"; then
    printf '%s\n' 'Expected missing WireMock JAR resolution to fail.' >&2
    exit 1
fi
grep -q 'does not identify a file' "$tmp_dir/missing.log"

printf '%s\n' 'WireMock JAR resolution contract passed.'
