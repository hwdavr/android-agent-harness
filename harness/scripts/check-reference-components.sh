#!/usr/bin/env bash
# Validate a device-keyed Android reference-component manifest and its assets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
DEVICE=""
APPEARANCE=""

usage() {
  echo "Usage: bash harness/scripts/check-reference-components.sh --device <name> [--appearance <light|dark>] [--project-root <path>]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || usage
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --device)
      [ "$#" -ge 2 ] || usage
      DEVICE="$2"
      shift 2
      ;;
    --appearance)
      [ "$#" -ge 2 ] || usage
      APPEARANCE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "FAIL: unknown option '$1'" >&2
      usage
      ;;
  esac
done

[ -n "$DEVICE" ] || usage
[ -z "$APPEARANCE" ] || [ "$APPEARANCE" = "light" ] || [ "$APPEARANCE" = "dark" ] || usage

COMPONENT_DIR="$PROJECT_ROOT/docs/product/reference_components/$DEVICE"
MANIFEST="$COMPONENT_DIR/manifest.json"
[ -s "$MANIFEST" ] || { echo "FAIL: missing reference-component manifest: $MANIFEST" >&2; exit 1; }

PROJECT_ROOT="$PROJECT_ROOT" COMPONENT_DIR="$COMPONENT_DIR" MANIFEST="$MANIFEST" APPEARANCE="$APPEARANCE" \
python3 - <<'PYTHON_SCRIPT'
import json
import os
import sys
from pathlib import Path

from PIL import Image


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


component_dir = Path(os.environ["COMPONENT_DIR"]).resolve()
manifest_path = Path(os.environ["MANIFEST"]).resolve()
requested_appearance = os.environ["APPEARANCE"]

try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except Exception as error:
    fail(f"could not parse {manifest_path}: {error}")

if manifest.get("version") != 1 or manifest.get("platform") != "android":
    fail("reference-component manifest must use version 1 and platform android")
if manifest.get("device") != component_dir.name:
    fail("reference-component manifest device must match its directory name")

physical_size = manifest.get("physical_size_px")
logical_size = manifest.get("logical_size_dp")
keyboard = (manifest.get("components") or {}).get("keyboard")
if not isinstance(physical_size, dict) or not isinstance(logical_size, dict):
    fail("manifest must declare logical_size_dp and physical_size_px")
if not all(isinstance(physical_size.get(key), int) and physical_size[key] > 0 for key in ("width", "height")):
    fail("physical_size_px must contain positive integer width and height")
if not all(isinstance(logical_size.get(key), (int, float)) and logical_size[key] > 0 for key in ("width", "height")):
    fail("logical_size_dp must contain positive width and height")
if not isinstance(keyboard, dict) or keyboard.get("type") != "software_keyboard":
    fail("manifest must declare components.keyboard as software_keyboard")

bounds = keyboard.get("physical_bounds_px")
if not isinstance(bounds, dict) or not all(isinstance(bounds.get(key), int) for key in ("x", "y", "width", "height")):
    fail("keyboard.physical_bounds_px must contain integer x, y, width, and height")
if bounds["x"] != 0 or bounds["width"] != physical_size["width"]:
    fail("keyboard must span the full physical screen width")
if bounds["y"] < 0 or bounds["height"] <= 0 or bounds["y"] + bounds["height"] != physical_size["height"]:
    fail("keyboard must dock to the physical screen bottom")

variants = keyboard.get("variants")
if not isinstance(variants, dict) or set(variants) != {"light", "dark"}:
    fail("keyboard variants must declare both light and dark assets")

for appearance, relative_path in variants.items():
    if not isinstance(relative_path, str) or not relative_path or Path(relative_path).name != relative_path or ".." in Path(relative_path).parts:
        fail(f"keyboard {appearance} variant path must be a simple filename")
    asset = component_dir / relative_path
    if not asset.is_file() or asset.stat().st_size == 0:
        fail(f"missing or empty keyboard {appearance} reference asset: {asset}")
    try:
        with Image.open(asset) as image:
            if image.size != (bounds["width"], bounds["height"]):
                fail(
                    f"keyboard {appearance} asset is {image.size[0]}x{image.size[1]}, "
                    f"expected {bounds['width']}x{bounds['height']}"
                )
            image.verify()
    except OSError as error:
        fail(f"keyboard {appearance} asset is not a readable image: {error}")

if requested_appearance:
    asset = component_dir / variants[requested_appearance]
    if not asset.is_file():
        fail(f"requested {requested_appearance} keyboard reference asset is missing: {asset}")

print(f"PASS: Android software-keyboard reference components are valid for {component_dir.name}")
PYTHON_SCRIPT
