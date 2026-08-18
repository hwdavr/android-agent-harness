#!/usr/bin/env bash
# Contract test for check-test-assertions-quality.sh
# Verifies the validator rejects envelope-only test assertions and
# accepts tests that have semantic content assertions.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-test-assertions-quality.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/test-assertions-test.XXXXXX")
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

# --- Positive case: test with semantic assertions → PASS ---
good_test="$fixture_root/good"
mkdir -p "$good_test"
cat > "$good_test/MermaidRendererTest.kt" << 'TESTEOF'
@Test
fun givenFlowchart_whenRendering_thenContainsNodeLabels() {
    val result = MermaidRenderer.renderSvg(code, isDarkTheme = false)
    val svg = (result as RenderResult.Success).svg
    assertTrue(svg.contains("<svg"))
    assertTrue(svg.contains("</svg>"))
    assertTrue(svg.contains(">Client Mobile</text>"))
    assertTrue(svg.contains(">API Gateway</text>"))
    assertTrue(svg.contains("<rect"))
    assertTrue(svg.contains("<line"))
}
TESTEOF
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$good_test")

# --- Positive case: test without any SVG/HTML assertions → PASS (not relevant) ---
unrelated_test="$fixture_root/unrelated"
mkdir -p "$unrelated_test"
cat > "$unrelated_test/SomeViewModelTest.kt" << 'TESTEOF'
@Test
fun givenNote_whenSaving_thenEmitsSuccess() {
    viewModel.saveNote(note)
    assertEquals(EditorUiState.Success, viewModel.uiState.value)
}
TESTEOF
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$unrelated_test")

# --- Negative case: envelope-only assertions → FAIL ---
bad_test="$fixture_root/bad"
mkdir -p "$bad_test"
cat > "$bad_test/DummyRendererTest.kt" << 'TESTEOF'
@Test
fun givenCode_whenRendering_thenReturnsSvg() {
    val svg = renderer.render(code)
    assertTrue(svg.contains("<svg"))
    assertTrue(svg.contains("</svg>"))
}
TESTEOF
expect_failure "envelope-only assertions" \
  bash "$VALIDATOR" "$bad_test"

echo "PASS: test-assertions-quality validator rejects envelope-only and accepts semantic assertions."
