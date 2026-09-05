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

# Case 8: Reference matching is deterministic — a state-qualified capture must pair
# with the most parsimonious reference, never an arbitrary tie-break (regression:
# formula_sheet_default.png was paired with mockup_formula_sheet_keyboard.png).
TIE_FEATURE="$FIXTURE_ROOT/docs/product/tie-feature"
mkdir -p "$TIE_FEATURE/design" "$TIE_FEATURE/visual_evidence"
python3 - << EOF
from PIL import Image, ImageDraw

tie = "$TIE_FEATURE"
# Create the state-variant mockup FIRST so filesystem iteration order favors it,
# reproducing the incident's arbitrary tie-break conditions.
kb = Image.new("RGB", (100, 200), (255, 255, 255))
d = ImageDraw.Draw(kb)
d.rectangle([10, 10, 90, 90], fill=(0, 100, 255))
d.rectangle([0, 150, 100, 200], fill=(200, 200, 200))
kb.save(f"{tie}/design/mockup_screen_keyboard.png")
base = Image.new("RGB", (100, 200), (255, 255, 255))
d = ImageDraw.Draw(base)
d.rectangle([10, 10, 90, 90], fill=(0, 100, 255))
base.save(f"{tie}/design/mockup_screen.png")
base.save(f"{tie}/visual_evidence/screen_default.png")
kb.save(f"{tie}/visual_evidence/screen_keyboard.png")
EOF

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$TIE_FEATURE" \
  --threshold 0.95

TIE_REPORT="$TIE_FEATURE/visual_evidence/visual_comparison_report.md"
grep -Fq '| `screen_default.png` | `mockup_screen.png` |' "$TIE_REPORT" \
  || fail_test "screen_default.png must pair with the parsimonious mockup_screen.png, not a state variant"
grep -Fq '| `screen_keyboard.png` | `mockup_screen_keyboard.png` |' "$TIE_REPORT" \
  || fail_test "screen_keyboard.png must pair with mockup_screen_keyboard.png"

# Case 9: A capture with no resolvable reference fails loudly (regression: silent
# [SKIP] let the batch exit 0 with completely unevaluated evidence).
NOREF_FEATURE="$FIXTURE_ROOT/docs/product/noref-feature"
mkdir -p "$NOREF_FEATURE/design" "$NOREF_FEATURE/visual_evidence"
python3 - << EOF
from PIL import Image, ImageDraw

nore = "$NOREF_FEATURE"
base = Image.new("RGB", (100, 200), (255, 255, 255))
d = ImageDraw.Draw(base)
d.rectangle([10, 10, 90, 90], fill=(0, 100, 255))
base.save(f"{nore}/design/mockup_screen.png")
unrelated = Image.new("RGB", (100, 200), (10, 120, 10))
unrelated.save(f"{nore}/visual_evidence/unrelated_thing.png")
EOF

expect_failure 2 "NO_REFERENCE" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$NOREF_FEATURE"

# Case 10: An explicit reference-map.json entry overrides token matching.
MAP_FEATURE="$FIXTURE_ROOT/docs/product/map-feature"
mkdir -p "$MAP_FEATURE/design" "$MAP_FEATURE/visual_evidence"
python3 - << EOF
from PIL import Image, ImageDraw

mp = "$MAP_FEATURE"
base = Image.new("RGB", (100, 200), (255, 255, 255))
d = ImageDraw.Draw(base)
d.rectangle([10, 10, 90, 90], fill=(0, 100, 255))
base.save(f"{mp}/design/mockup_screen.png")
variant = Image.new("RGB", (100, 200), (255, 255, 255))
d = ImageDraw.Draw(variant)
d.rectangle([10, 10, 90, 90], fill=(255, 0, 0))
variant.save(f"{mp}/design/mockup_screen_state.png")
base.save(f"{mp}/visual_evidence/screen_state.png")
EOF
printf '{\n  "screen_state.png": "design/mockup_screen.png"\n}\n' \
  > "$MAP_FEATURE/visual_evidence/reference-map.json"

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$MAP_FEATURE" \
  --threshold 0.95

grep -Fq '| `screen_state.png` | `mockup_screen.png` | informational | explicit-map |' "$MAP_FEATURE/visual_evidence/visual_comparison_report.md" \
  || fail_test "explicit reference-map.json entry must override token matching in the report"

# Case 11: A null mapping declares anchor-only — no pixel comparison, batch passes.
printf '{\n  "screen_state.png": null\n}\n' \
  > "$MAP_FEATURE/visual_evidence/reference-map.json"

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$MAP_FEATURE" \
  --threshold 0.95

grep -Fq '| `screen_state.png` | — | — | explicit-map(null) | — | — | — | **ANCHOR_ONLY** |' \
  "$MAP_FEATURE/visual_evidence/visual_comparison_report.md" \
  || fail_test "null-mapped capture must be recorded as ANCHOR_ONLY in the report"

# Case 12: Malformed, dangling, and stale reference-map.json entries fail loudly.
printf 'not json\n' > "$MAP_FEATURE/visual_evidence/reference-map.json"
expect_failure 2 "Could not parse" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$MAP_FEATURE"

printf '["screen_state.png"]\n' > "$MAP_FEATURE/visual_evidence/reference-map.json"
expect_failure 2 "must be a JSON object" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$MAP_FEATURE"

printf '{\n  "screen_state.png": "design/nonexistent.png"\n}\n' \
  > "$MAP_FEATURE/visual_evidence/reference-map.json"
expect_failure 2 "missing reference" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$MAP_FEATURE"

printf '{\n  "bogus_capture.png": "design/mockup_screen.png"\n}\n' \
  > "$MAP_FEATURE/visual_evidence/reference-map.json"
expect_failure 2 "unknown capture" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$MAP_FEATURE"

# Case 13: An exact-name golden baseline is the binding regression reference —
# an identical capture passes and is recorded as binding.
GOLDEN_FEATURE="$FIXTURE_ROOT/docs/product/golden-feature"
mkdir -p "$GOLDEN_FEATURE/design" "$GOLDEN_FEATURE/visual_evidence" \
  "$FIXTURE_ROOT/UX/golden-baselines"
python3 - << EOF
from PIL import Image, ImageDraw

g = "$GOLDEN_FEATURE"
base = Image.new("RGB", (100, 200), (255, 255, 255))
d = ImageDraw.Draw(base)
d.rectangle([10, 10, 90, 90], fill=(0, 100, 255))
base.save(f"{g}/design/mockup_screen.png")
base.save(f"{g}/visual_evidence/screen_state.png")
base.save("$FIXTURE_ROOT/UX/golden-baselines/screen_state.png")
EOF

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$GOLDEN_FEATURE" \
  --threshold 0.95

grep -Fq '| `screen_state.png` | `screen_state.png` | binding | golden-baseline |' \
  "$GOLDEN_FEATURE/visual_evidence/visual_comparison_report.md" \
  || fail_test "exact-name golden must be recorded as the binding regression reference"

# Case 14: A drifted capture fails the binding golden regression comparison (exit 1).
python3 - << EOF
from PIL import Image, ImageDraw

g = "$GOLDEN_FEATURE"
drift = Image.new("RGB", (100, 200), (255, 255, 255))
d = ImageDraw.Draw(drift)
d.rectangle([0, 0, 100, 100], fill=(255, 0, 0))
drift.save(f"{g}/visual_evidence/screen_state.png")
EOF

expect_failure 1 "golden-baseline" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$GOLDEN_FEATURE" \
  --threshold 0.95

# Case 15: Mockup-only comparison is informational — even a total mismatch never
# fails the batch (mock copy and AI-mockup rendering are not gated).
WILD_FEATURE="$FIXTURE_ROOT/docs/product/wild-feature"
mkdir -p "$WILD_FEATURE/design" "$WILD_FEATURE/visual_evidence"
python3 - << EOF
from PIL import Image, ImageDraw

w = "$WILD_FEATURE"
base = Image.new("RGB", (100, 200), (255, 255, 255))
d = ImageDraw.Draw(base)
d.rectangle([10, 10, 90, 90], fill=(0, 100, 255))
base.save(f"{w}/design/mockup_screen.png")
wild = Image.new("RGB", (100, 200), (10, 120, 10))
wild.save(f"{w}/visual_evidence/screen_wild.png")
EOF

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$WILD_FEATURE" \
  --threshold 0.95

grep -F '| `screen_wild.png` | `mockup_screen.png` | informational | token-match |' \
  "$WILD_FEATURE/visual_evidence/visual_comparison_report.md" \
  | grep -Fq '**INFO**' \
  || fail_test "a totally mismatched mockup comparison must be an INFO row, not a failure"

# Case 16: Mask regions from a reference-map.json object entry are excluded from
# the comparison (masked differences do not count toward the diff).
python3 - << EOF
from PIL import Image

mp = "$MAP_FEATURE"
wild = Image.new("RGB", (100, 200), (10, 120, 10))
wild.save(f"{mp}/visual_evidence/screen_state.png")
EOF
printf '{\n  "screen_state.png": {"reference": "design/mockup_screen.png", "mask": [{"x": 0, "y": 0, "w": 100, "h": 200}]}\n}\n' \
  > "$MAP_FEATURE/visual_evidence/reference-map.json"

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --feature "$MAP_FEATURE" \
  --threshold 0.95

grep -F '| `screen_state.png` | `mockup_screen.png` | informational | explicit-map | 1.0000 |' \
  "$MAP_FEATURE/visual_evidence/visual_comparison_report.md" \
  || fail_test "masked regions must be excluded from the comparison score"

echo "PASS: All 16 visual-comparison contract test cases passed."
