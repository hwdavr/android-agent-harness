#!/usr/bin/env bash
# Contract test for Semantic & Visual Evidence Comparator (Level 5 Validation).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/compare-visual-evidence.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/visual-comparison-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_success() {
  local output
  if ! output=$("$@" 2>&1); then
    echo "$output" >&2
    fail_test "command unexpectedly failed: $*"
  fi
}

expect_failure() {
  local expected_exit="$1"
  local expected_text="$2"
  shift 2
  local output
  set +e
  output=$("$@" 2>&1)
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "$output" >&2
    fail_test "command unexpectedly succeeded: $*"
  fi

  if [ "$status" -ne "$expected_exit" ]; then
    echo "$output" >&2
    fail_test "expected exit code $expected_exit, got $status: $*"
  fi

  printf '%s\n' "$output" | grep -Fq "$expected_text" || {
    echo "$output" >&2
    fail_test "output did not contain expected text '$expected_text': $*"
  }
}

mkdir -p "$FIXTURE_ROOT/img"
mkdir -p "$FIXTURE_ROOT/docs/product/test-feature/design"
mkdir -p "$FIXTURE_ROOT/docs/product/test-feature/visual_evidence"

# Generate test images using Python Pillow
python3 - << EOF
from PIL import Image, ImageDraw

# 1. Base image (100x100 white square with a blue rectangle)
img1 = Image.new("RGB", (100, 100), (255, 255, 255))
draw1 = ImageDraw.Draw(img1)
draw1.rectangle([20, 20, 80, 80], fill=(0, 100, 255))
img1.save("$FIXTURE_ROOT/img/base.png")

# 2. Identical clone
img1.save("$FIXTURE_ROOT/img/identical.png")

# 3. Subtle difference (minor anti-aliasing / edge color shift)
img_subtle = img1.copy()
draw_sub = ImageDraw.Draw(img_subtle)
draw_sub.point([20, 20], fill=(0, 95, 250))
img_subtle.save("$FIXTURE_ROOT/img/subtle.png")

# 4. Major mismatch (red rectangle covering 50% of the screen)
img_diff = img1.copy()
draw_diff = ImageDraw.Draw(img_diff)
draw_diff.rectangle([0, 0, 50, 100], fill=(255, 0, 0))
img_diff.save("$FIXTURE_ROOT/img/major_diff.png")

# 5. Feature directory test images
img1.save("$FIXTURE_ROOT/docs/product/test-feature/design/mockup_screen.png")
img1.save("$FIXTURE_ROOT/docs/product/test-feature/visual_evidence/screen.png")
EOF

# Case 1: Identical images pass with 1.0 similarity (exit 0)
expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --reference "$FIXTURE_ROOT/img/base.png" \
  --actual "$FIXTURE_ROOT/img/identical.png" \
  --threshold 0.99

# Case 2: Subtle difference passes standard 0.95 threshold (exit 0)
expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --reference "$FIXTURE_ROOT/img/base.png" \
  --actual "$FIXTURE_ROOT/img/subtle.png" \
  --threshold 0.95

# Case 3: Major visual mismatch fails with exit 1 and creates diff overlay
expect_failure 1 "Overall visual mismatch" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --reference "$FIXTURE_ROOT/img/base.png" \
  --actual "$FIXTURE_ROOT/img/major_diff.png" \
  --diff-output "$FIXTURE_ROOT/img/diff_overlay.png" \
  --threshold 0.95

[ -s "$FIXTURE_ROOT/img/diff_overlay.png" ] || fail_test "Diff overlay image was not created"

# Case 4: Missing reference image fails with exit 2
expect_failure 2 "Reference image not found" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --reference "$FIXTURE_ROOT/img/non_existent.png" \
  --actual "$FIXTURE_ROOT/img/base.png"

# Case 5: Missing actual image fails with exit 2
expect_failure 2 "Actual image not found" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --reference "$FIXTURE_ROOT/img/base.png" \
  --actual "$FIXTURE_ROOT/img/non_existent.png"

# Case 6: Promoting to golden baseline copies actual image to UX/golden-baselines/
expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --promote-golden "$FIXTURE_ROOT/img/base.png" \
  --name "golden_test.png"

[ -s "$FIXTURE_ROOT/UX/golden-baselines/golden_test.png" ] || fail_test "Golden baseline file was not created"

# Case 7: Feature batch mode compares pairs and writes visual_comparison_report.md
expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$FIXTURE_ROOT/docs/product/test-feature" \
  --threshold 0.95

[ -s "$FIXTURE_ROOT/docs/product/test-feature/visual_evidence/visual_comparison_report.md" ] \
  || fail_test "visual_comparison_report.md was not created"

grep -Fq "screen.png" "$FIXTURE_ROOT/docs/product/test-feature/visual_evidence/visual_comparison_report.md" \
  || fail_test "visual_comparison_report.md missing screen.png"

echo "PASS: All 7 visual-comparison contract test cases passed."
