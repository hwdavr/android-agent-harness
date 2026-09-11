#!/usr/bin/env bash
# Ensures every planning design that updates an existing surface has an unchanged,
# source-fed emulator screenshot produced by a named instrumented test.

set -e

FEATURE_DIR="${1:-}"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(pwd)}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

trim_field() {
  printf '%s' "$1" |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^`//; s/`$//'
}

if [ -z "$FEATURE_DIR" ]; then
  echo "Usage: bash harness/scripts/check-existing-screen-baseline-contract.sh <feature-directory>" >&2
  exit 2
fi

DESIGN="$FEATURE_DIR/design.md"
[ -f "$DESIGN" ] || fail "missing $DESIGN"

updated_surfaces=$(awk -F'|' '
  function trim(value) {
    gsub(/^[[:space:]]+/, "", value)
    gsub(/[[:space:]]+$/, "", value)
    return value
  }
  /^[[:space:]]*\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
    surface = trim($3)
    status = trim($4)
    if (tolower(status) == "updated") print surface
  }
' "$DESIGN")

if [ -z "$updated_surfaces" ]; then
  echo "PASS: design updates no existing surfaces."
  exit 0
fi

grep -Fq "## Existing Surface Baseline" "$DESIGN" ||
  fail "design updates existing screen(s) but is missing the '## Existing Surface Baseline' section"

while IFS= read -r surface; do
  [ -n "$surface" ] || continue
  baseline_line=$(grep -F "| $surface | Required |" "$DESIGN" | head -n 1 || true)
  [ -n "$baseline_line" ] ||
    fail "updated surface '$surface' has no Required Existing Surface Baseline row"

  IFS='|' read -r ignored row_surface decision test_file test_method test_capture baseline_asset execution_evidence ignored_tail <<EOF
$baseline_line
EOF

  row_surface=$(trim_field "$row_surface")
  decision=$(trim_field "$decision")
  test_file=$(trim_field "$test_file")
  test_method=$(trim_field "$test_method")
  test_capture=$(trim_field "$test_capture")
  baseline_asset=$(trim_field "$baseline_asset")
  execution_evidence=$(trim_field "$execution_evidence")

  [ "$row_surface" = "$surface" ] ||
    fail "Existing Surface Baseline row must use the exact updated surface name '$surface'"
  [ "$decision" = "Required" ] ||
    fail "updated surface '$surface' must mark its baseline Required"
  case "$test_file" in
    app/src/androidTest/*) ;;
    *) fail "updated surface '$surface' must name an app/src/androidTest source test" ;;
  esac
  printf '%s' "$test_method" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' ||
    fail "updated surface '$surface' has an invalid baseline test method '$test_method'"
  printf '%s' "$test_capture" | grep -Eq '^[A-Za-z0-9._-]+\.png$' ||
    fail "updated surface '$surface' must name a test-produced PNG capture"
  case "$baseline_asset" in
    design/*) ;;
    *) fail "updated surface '$surface' must use a pulled design/baseline_*.png asset" ;;
  esac
  [ -s "$FEATURE_DIR/$baseline_asset" ] ||
    fail "updated surface '$surface' baseline asset is missing or empty: $FEATURE_DIR/$baseline_asset"

  test_path="$PROJECT_ROOT/$test_file"
  [ -f "$test_path" ] ||
    fail "updated surface '$surface' baseline test file does not exist: $test_file"
  grep -Eq "fun[[:space:]]+$test_method[[:space:]]*\\(" "$test_path" ||
    fail "updated surface '$surface' baseline test method is missing: $test_method"
  grep -Eq 'takeScreenshot[[:space:]]*\(|captureToImage[[:space:]]*\(' "$test_path" ||
    fail "updated surface '$surface' baseline test must capture inside the active test"
  grep -Fq '/sdcard/Download/' "$test_path" ||
    fail "updated surface '$surface' baseline test must export its in-test capture to /sdcard/Download/"

  method_body=$(awk -v method="$test_method" '
    $0 ~ "fun[[:space:]]+" method "[[:space:]]*\\(" { found = 1 }
    found { print }
    found && /^    }[[:space:]]*$/ { exit }
  ' "$test_path")
  capture_stem=${test_capture%.png}
  printf '%s\n' "$method_body" | grep -Fq "$capture_stem" ||
    fail "updated surface '$surface' test method '$test_method' does not request '$test_capture'"

  printf '%s\n' "$execution_evidence" | grep -Eiq 'emulator-[0-9]+' ||
    fail "updated surface '$surface' baseline evidence must name an emulator runtime"
  printf '%s\n' "$execution_evidence" | grep -Eiq 'pass|successful|exit[[:space:]]*0' ||
    fail "updated surface '$surface' baseline evidence must record a passing execution"
done <<EOF
$updated_surfaces
EOF

echo "PASS: every updated surface has a source-fed emulator baseline."
