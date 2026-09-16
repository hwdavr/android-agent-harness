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
  local output status
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "$output" >&2
    fail_test "command unexpectedly succeeded: $*"
  fi
  [ "$status" -eq "$expected_exit" ] || {
    echo "$output" >&2
    fail_test "expected exit code $expected_exit, got $status: $*"
  }
  printf '%s\n' "$output" | grep -Fq "$expected_text" || {
    echo "$output" >&2
    fail_test "output did not contain expected text '$expected_text': $*"
  }
}

write_valid_map() {
  local feature_dir="$1"
  local reference="$2"
  printf '%s\n' \
    '{' \
    '  "version": 1,' \
    '  "target_id": "test-target",' \
    '  "appearance": "light",' \
    '  "device": "Test Phone",' \
    '  "logical_size_dp": { "width": 100, "height": 200 },' \
    '  "locale": "en-US",' \
    '  "states": {' \
    '    "fixture-state": {' \
    '      "content_state_id": "fixture-state",' \
    "      \"reference\": \"$reference\", " \
    '      "content_state": "Deterministic fixture content.",' \
    '      "mask": [],' \
    '      "dynamic_regions": [' \
    '        { "kind": "time", "handling": "cropped-system-insets", "rationale": "Insets are cropped." },' \
    '        { "kind": "user-content", "handling": "fixture", "rationale": "Fixture data is deterministic." },' \
    '        { "kind": "identifier", "handling": "fixture", "rationale": "Fixture identifiers are deterministic." },' \
    '        { "kind": "keyboard", "handling": "not-present", "rationale": "No keyboard in this state." }' \
    '      ]' \
    '    }' \
    '  }' \
    '}' > "$feature_dir/visual_evidence/visual-target.json"
  printf '%s\n' \
    '{' \
    '  "version": 1,' \
    '  "target_manifest": "visual-target.json",' \
    '  "captures": {' \
    '    "screen_state.png": { "state_id": "fixture-state" }' \
    '  }' \
    '}' > "$feature_dir/visual_evidence/reference-map.json"
}

mkdir -p "$FIXTURE_ROOT/img" "$FIXTURE_ROOT/docs/product/test-feature/design" "$FIXTURE_ROOT/docs/product/test-feature/visual_evidence"
python3 - <<EOF
from PIL import Image, ImageDraw

root = "$FIXTURE_ROOT"
base = Image.new("RGB", (100, 200), (255, 255, 255))
draw = ImageDraw.Draw(base)
draw.rectangle([20, 20, 80, 120], fill=(0, 100, 255))
base.save(f"{root}/img/base.png")
base.save(f"{root}/img/identical.png")
major = base.copy()
ImageDraw.Draw(major).rectangle([0, 0, 60, 200], fill=(255, 0, 0))
major.save(f"{root}/img/major.png")
base.save(f"{root}/docs/product/test-feature/design/mockup_screen.png")
base.save(f"{root}/docs/product/test-feature/visual_evidence/screen_state.png")
dark = Image.new("RGB", (100, 200), (20, 20, 20))
dark.save(f"{root}/docs/product/test-feature/design/mockup_dark.png")
EOF

# Pair mode remains available for targeted local diagnosis.
expect_success bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --reference "$FIXTURE_ROOT/img/base.png" --actual "$FIXTURE_ROOT/img/identical.png" --threshold 0.99
expect_failure 1 "Overall visual mismatch" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --reference "$FIXTURE_ROOT/img/base.png" --actual "$FIXTURE_ROOT/img/major.png" --diff-output "$FIXTURE_ROOT/img/diff.png" --threshold 0.95
[ -s "$FIXTURE_ROOT/img/diff.png" ] || fail_test "pair-mode diff overlay was not created"
expect_failure 2 "Reference image not found" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --reference "$FIXTURE_ROOT/img/missing.png" --actual "$FIXTURE_ROOT/img/base.png"
expect_failure 2 "Actual image not found" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --reference "$FIXTURE_ROOT/img/base.png" --actual "$FIXTURE_ROOT/img/missing.png"

FEATURE="$FIXTURE_ROOT/docs/product/test-feature"

# Every capture needs a mandatory, explicit, object-shaped map entry. File names
# alone can never choose a reference.
expect_failure 2 "missing" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE"
write_valid_map "$FEATURE" "design/mockup_screen.png"
expect_success bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE" --threshold 0.95
REPORT="$FEATURE/visual_evidence/visual_comparison_report.md"
grep -Fq '| `screen_state.png` | `mockup_screen.png` | binding | explicit-mockup-map | 1.0000 |' "$REPORT" \
  || fail_test "explicit mockup mapping must be recorded as a binding comparison"

# Target metadata cannot be duplicated in the filename map.
jq '.captures["screen_state.png"] += {"reference": "design/mockup_screen.png"}' \
  "$FEATURE/visual_evidence/reference-map.json" > "$FEATURE/visual_evidence/reference-map.tmp"
mv "$FEATURE/visual_evidence/reference-map.tmp" "$FEATURE/visual_evidence/reference-map.json"
expect_failure 2 "target metadata belongs in visual-target.json" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE"
write_valid_map "$FEATURE" "design/mockup_screen.png"

# A legacy string/null map and inferred token matching are rejected.
printf '%s\n' '{"version":1,"target_manifest":"visual-target.json","captures":{"screen_state.png":"design/mockup_screen.png"}}' > "$FEATURE/visual_evidence/reference-map.json"
expect_failure 2 "must be an object; string, null, and inferred mappings are prohibited" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE"
write_valid_map "$FEATURE" "design/mockup_screen.png"
cp "$FEATURE/visual_evidence/screen_state.png" "$FEATURE/visual_evidence/another_screen.png"
expect_failure 2 "has no explicit mapping for capture(s): another_screen.png" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE"
rm "$FEATURE/visual_evidence/another_screen.png"

# A map cannot point at a source baseline or an arbitrary design image.
write_valid_map "$FEATURE" "design/baseline_screen.png"
expect_failure 2 "must name an approved design/mockup_*.png asset" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE"

# Appearance metadata is checked against the actual mapped mockup image.
write_valid_map "$FEATURE" "design/mockup_dark.png"
expect_failure 2 "is dark" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE"

# All required dynamic categories must be handled explicitly in the shared target.
write_valid_map "$FEATURE" "design/mockup_screen.png"
python3 - <<EOF
import json
path = "$FEATURE/visual_evidence/visual-target.json"
data = json.load(open(path))
data["states"]["fixture-state"]["dynamic_regions"].pop()
open(path, "w").write(json.dumps(data))
EOF
expect_failure 2 "is missing keyboard" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE"

# An approved dynamic mask is applied after inset normalization and therefore
# removes only the declared dynamic region from the pixel score.
write_valid_map "$FEATURE" "design/mockup_screen.png"
python3 - <<EOF
import json
from PIL import Image
path = "$FEATURE/visual_evidence/visual-target.json"
data = json.load(open(path))
state = data["states"]["fixture-state"]
state["dynamic_regions"][1] = {
  "kind": "user-content", "handling": "mask", "rationale": "The supplied test deliberately varies this fixture region.",
  "mask": {"x": 0, "y": 0, "w": 100, "h": 200, "rationale": "Approved contract-test dynamic mask."}
}
open(path, "w").write(json.dumps(data))
Image.new("RGB", (100, 200), (10, 120, 10)).save("$FEATURE/visual_evidence/screen_state.png")
EOF
expect_success bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE" --threshold 0.95
grep -Fq '| `screen_state.png` | `mockup_screen.png` | binding | explicit-mockup-map | 1.0000 |' "$REPORT" \
  || fail_test "approved masks must remove only declared dynamic regions"

# A mockup mismatch is now binding, even if any unrelated historical image matches.
write_valid_map "$FEATURE" "design/mockup_screen.png"
cp "$FIXTURE_ROOT/img/major.png" "$FEATURE/visual_evidence/screen_state.png"
expect_failure 1 "explicit-mockup-map, binding" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --feature "$FEATURE" --threshold 0.95

echo "PASS: All approved-mockup visual-comparison contract cases passed."
