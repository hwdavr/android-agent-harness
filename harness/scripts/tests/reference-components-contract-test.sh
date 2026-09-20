#!/usr/bin/env bash
# Contract tests for device-keyed Android software-keyboard references.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-reference-components.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/reference-components-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "$output" >&2
    fail_test "command unexpectedly succeeded: $*"
  fi
  printf '%s\n' "$output" | grep -Fq -- "$expected" || {
    echo "$output" >&2
    fail_test "output did not contain '$expected': $*"
  }
}

COMPONENT_DIR="$FIXTURE_ROOT/docs/product/reference_components/Test Phone"
mkdir -p "$COMPONENT_DIR"
printf '%s\n' \
  '{' \
  '  "version": 1,' \
  '  "platform": "android",' \
  '  "device": "Test Phone",' \
  '  "logical_size_dp": { "width": 411, "height": 914 },' \
  '  "physical_size_px": { "width": 1080, "height": 2400 },' \
  '  "density_dpi": 420,' \
  '  "components": {' \
  '    "keyboard": {' \
  '      "type": "software_keyboard",' \
  '      "physical_bounds_px": { "x": 0, "y": 1700, "width": 1080, "height": 700 },' \
  '      "variants": { "light": "keyboard_light.png", "dark": "keyboard_dark.png" }' \
  '    }' \
  '  }' \
  '}' > "$COMPONENT_DIR/manifest.json"

python3 - "$COMPONENT_DIR" <<'PYTHON_SCRIPT'
from pathlib import Path
import sys
from PIL import Image

directory = Path(sys.argv[1])
for name, color in (("keyboard_light.png", (245, 245, 245)), ("keyboard_dark.png", (30, 30, 34))):
    Image.new("RGB", (1080, 700), color).save(directory / name)
PYTHON_SCRIPT

rm "$COMPONENT_DIR/keyboard_light.png"
expect_failure "missing or empty keyboard light reference asset" bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --device "Test Phone"

# Restore the asset and prove the valid fixture passes.
python3 - "$COMPONENT_DIR" <<'PYTHON_SCRIPT'
from pathlib import Path
import sys
from PIL import Image

Image.new("RGB", (1080, 700), (245, 245, 245)).save(Path(sys.argv[1]) / "keyboard_light.png")
PYTHON_SCRIPT
bash "$VALIDATOR" --project-root "$FIXTURE_ROOT" --device "Test Phone" --appearance light

echo "PASS: reference-component contract rejects missing assets and accepts a valid Android keyboard manifest."
