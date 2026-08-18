#!/usr/bin/env bash
# Validates that test files asserting rendered output (SVG, HTML, text
# generation) contain semantic content assertions, not just envelope tags.
#
# Usage: bash harness/scripts/check-test-assertions-quality.sh [test-directory]
#
# Scans Kotlin test files that assert SVG/HTML output for envelope-only
# patterns (e.g. contains("<svg"), contains("</svg>")). If a test file
# has envelope assertions but zero semantic content assertions (e.g.
# contains(">Label</text>"), contains("<rect"), contains("<line")),
# the validator exits nonzero.
#
# Exits 0 if all tests have adequate semantic assertions, 1 otherwise.

set -e

TEST_DIR="${1:-app/src/test}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -d "$TEST_DIR" ] || fail "test directory $TEST_DIR does not exist"

VIOLATIONS_FILE="${TMPDIR:-/tmp}/.test-assertions-violations.$$"
rm -f "$VIOLATIONS_FILE"
trap 'rm -f "$VIOLATIONS_FILE"' EXIT

# Collect test files into a temp file to avoid pipe subshell
FILE_LIST="${TMPDIR:-/tmp}/.test-file-list.$$"
find "$TEST_DIR" \( -name "*Test.kt" -o -name "*IntegrationTest.kt" \) -print > "$FILE_LIST" 2>/dev/null

while IFS= read -r test_file; do
  [ -n "$test_file" ] || continue
  [ -f "$test_file" ] || continue

  # Count envelope-only SVG/HTML assertions (grep -c prints count, use || true to avoid exit on 0 count)
  has_envelope=$(grep -cE 'contains\("</?svg|contains\("</?html|contains\("</?SVG' "$test_file" || true)
  has_envelope="${has_envelope:-0}"

  if [ "$has_envelope" -gt 0 ] 2>/dev/null; then
    # Count semantic content assertions
    has_semantic=$(grep -cE 'contains\(">[^<]+</text>"\)|contains\("<rect"|contains\("<line"|contains\("<polygon"|contains\("<circle"|contains\("<marker"|contains\("<text "|contains\("<path"|contains\("font-size"|contains\("fill="|contains\("stroke="' "$test_file" || true)
    has_semantic="${has_semantic:-0}"

    if [ "$has_semantic" -eq 0 ] 2>/dev/null; then
      echo "FAIL: $test_file has envelope-only assertions without semantic content checks" >&2
      echo "$test_file" >> "$VIOLATIONS_FILE"
    else
      echo "OK: $test_file ($has_envelope envelope + $has_semantic semantic assertions)"
    fi
  fi
done < "$FILE_LIST"

rm -f "$FILE_LIST"

if [ -f "$VIOLATIONS_FILE" ]; then
  VIOLATION_COUNT=$(wc -l < "$VIOLATIONS_FILE" | tr -d ' ')
  echo "" >&2
  echo "Violations:" >&2
  while IFS= read -r vfile; do
    echo "  - $vfile" >&2
  done < "$VIOLATIONS_FILE"
  echo "" >&2
  fail "$VIOLATION_COUNT test file(s) have envelope-only assertions. Add semantic content assertions (e.g. node labels, structural shapes, connectors)."
fi

echo "PASS: all rendering test files have adequate semantic content assertions."
