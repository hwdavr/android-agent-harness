#!/usr/bin/env bash
# Contract test for check-declared-assets.sh
# Verifies the validator accepts present assets and rejects missing ones.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-declared-assets.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/declared-assets-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "FAIL: validator unexpectedly accepted fixture" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "FAIL: validator did not report '$expected'." >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
}

# --- Positive case: no asset references → PASS ---
no_assets="$fixture_root/no-assets"
mkdir -p "$no_assets"
printf '%s\n' '# Spec' '## Overview' 'A simple feature with no offline assets.' \
  > "$no_assets/spec.md"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$no_assets")

# --- Positive case: asset reference + file exists → PASS ---
present_asset="$fixture_root/present-asset"
mkdir -p "$present_asset"
printf '%s\n' '# Spec' '## Overview' \
  'The WebView loads `file:///android_asset/mermaid/mermaid.min.js` offline.' \
  > "$present_asset/spec.md"
# The actual asset should already exist from the bug fix
if [ -f "$REPO_ROOT/app/src/main/assets/mermaid/mermaid.min.js" ]; then
  (cd "$REPO_ROOT" && bash "$VALIDATOR" "$present_asset")
else
  echo "SKIP: mermaid.min.js not on disk — skipping positive-present test"
fi

# --- Negative case: asset reference + file missing → FAIL ---
missing_asset="$fixture_root/missing-asset"
mkdir -p "$missing_asset"
printf '%s\n' '# Spec' '## Overview' \
  'The WebView loads `file:///android_asset/nonexistent/engine.js` offline.' \
  > "$missing_asset/spec.md"
expect_failure "declared asset" \
  bash "$VALIDATOR" "$missing_asset"

# --- Negative case: asset reference in sprint-contract.md + missing → FAIL ---
missing_contract_asset="$fixture_root/missing-contract-asset"
mkdir -p "$missing_contract_asset"
printf '%s\n' '# Sprint Contract' '## Overview' \
  'Uses `file:///android_asset/charts/chart-engine.js` for rendering.' \
  > "$missing_contract_asset/sprint-contract.md"
printf '%s\n' '# Spec' > "$missing_contract_asset/spec.md"
expect_failure "declared asset" \
  bash "$VALIDATOR" "$missing_contract_asset"

echo "PASS: declared-assets validator accepts present assets and rejects missing ones."
