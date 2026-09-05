#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-rendered-output-contract.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rendered-output-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

SOURCE_DIR="$FIXTURE_ROOT/app/src/androidTest/java/example"
SOURCE_FILE="$SOURCE_DIR/RenderedOutputTest.kt"
mkdir -p "$SOURCE_DIR"

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "FAIL: rendered-output validator unexpectedly accepted fixture" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    echo "FAIL: validator did not report '$expected'" >&2
    exit 1
  }
}

printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Assert.assertTrue' \
  'import org.junit.Test' \
  '' \
  'class RenderedOutputTest {' \
  '  @Test' \
  '  fun markedTextIsRendered() {' \
  '    val marks = listOf("bold")' \
  '    assertTrue("bold" in marks)' \
  '  }' \
  '}' \
  > "$SOURCE_FILE"

expect_failure "must capture a Compose node with captureToImage()" \
  bash "$VALIDATOR" \
    --project-root "$FIXTURE_ROOT" \
    --test-file "$SOURCE_FILE" \
    --test-method markedTextIsRendered \
    --claim "following text visibly inherits Bold"

expect_failure "must capture a Compose node with captureToImage()" \
  bash "$VALIDATOR" \
    --project-root "$FIXTURE_ROOT" \
    --test-file "$SOURCE_FILE" \
    --test-method markedTextIsRendered \
    --claim "renders rich text"

printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Assert.assertTrue' \
  'import org.junit.Test' \
  '' \
  'class RenderedOutputTest {' \
  '  @Test' \
  '  fun markedTextIsRendered() {' \
  '    // captureToImage() and differingPixelCount() in a comment are not evidence.' \
  '    val note = "differingPixelCount()"' \
  '    assertTrue(note.isNotEmpty())' \
  '  }' \
  '}' \
  > "$SOURCE_FILE"

expect_failure "must capture a Compose node with captureToImage()" \
  bash "$VALIDATOR" \
    --project-root "$FIXTURE_ROOT" \
    --test-file "$SOURCE_FILE" \
    --test-method markedTextIsRendered \
    --claim "marked text appearance differs"

printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Assert.assertTrue' \
  'import org.junit.Test' \
  '' \
  'class RenderedOutputTest {' \
  '  @Test' \
  '  fun markedTextIsRendered() {' \
  '    val plain = onNodeWithTag("plain").captureToImage().asAndroidBitmap()' \
  '    val marked = onNodeWithTag("marked").captureToImage().asAndroidBitmap()' \
  '    assertTrue(plain.differingPixelCount(marked) > 0)' \
  '  }' \
  '}' \
  > "$SOURCE_FILE"

bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --test-file "$SOURCE_FILE" \
  --test-method markedTextIsRendered \
  --claim "marked text appearance differs" >/dev/null

printf '%s\n' \
  'package example' \
  '' \
  'import org.junit.Assert.assertTrue' \
  'import org.junit.Test' \
  '' \
  'class RenderedOutputTest {' \
  '  @Test' \
  '  fun toolbarIsVisible() {' \
  '    assertTrue(true)' \
  '  }' \
  '}' \
  > "$SOURCE_FILE"

bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --test-file "$SOURCE_FILE" \
  --test-method toolbarIsVisible \
  --claim "toolbar is visible" \
  --require-source >/dev/null

bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --test-file "$SOURCE_FILE" \
  --test-method toolbarIsVisible \
  --claim "The toolbar pixel screenshot matches the approved chrome" \
  --require-source >/dev/null

bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --test-file "$SOURCE_FILE" \
  --test-method toolbarIsVisible \
  --claim "newly typed text inherits exactly Bold" \
  --require-source >/dev/null

echo "PASS: rendered-output contract rejects state-only and comment-only rich-text evidence, accepts a real pixel comparison, and does not over-block unrelated UI claims."
