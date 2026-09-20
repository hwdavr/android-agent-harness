#!/usr/bin/env bash
# Generate device-keyed Android software-keyboard reference components from
# authentic full-window emulator captures.

set -euo pipefail

usage() {
  echo "Usage: bash harness/scripts/generate-keyboard-reference-components.sh" >&2
  echo "  --device <name> --light-capture <png> --dark-capture <png>" >&2
  echo "  --keyboard-top-px <n> --physical-size <width>x<height>" >&2
  echo "  --density-dpi <n> --logical-size-dp <width>x<height>" >&2
  echo "  --output <reference-components-directory>" >&2
  exit 2
}

DEVICE=""
LIGHT_CAPTURE=""
DARK_CAPTURE=""
KEYBOARD_TOP_PX=""
PHYSICAL_SIZE=""
DENSITY_DPI=""
LOGICAL_SIZE_DP=""
OUTPUT_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --device)
      [ "$#" -ge 2 ] || usage
      DEVICE="$2"
      shift 2
      ;;
    --light-capture)
      [ "$#" -ge 2 ] || usage
      LIGHT_CAPTURE="$2"
      shift 2
      ;;
    --dark-capture)
      [ "$#" -ge 2 ] || usage
      DARK_CAPTURE="$2"
      shift 2
      ;;
    --keyboard-top-px)
      [ "$#" -ge 2 ] || usage
      KEYBOARD_TOP_PX="$2"
      shift 2
      ;;
    --physical-size)
      [ "$#" -ge 2 ] || usage
      PHYSICAL_SIZE="$2"
      shift 2
      ;;
    --density-dpi)
      [ "$#" -ge 2 ] || usage
      DENSITY_DPI="$2"
      shift 2
      ;;
    --logical-size-dp)
      [ "$#" -ge 2 ] || usage
      LOGICAL_SIZE_DP="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || usage
      OUTPUT_DIR="$2"
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

[ -n "$DEVICE" ] && [ -n "$LIGHT_CAPTURE" ] && [ -n "$DARK_CAPTURE" ] \
  && [ -n "$KEYBOARD_TOP_PX" ] && [ -n "$PHYSICAL_SIZE" ] \
  && [ -n "$DENSITY_DPI" ] && [ -n "$LOGICAL_SIZE_DP" ] && [ -n "$OUTPUT_DIR" ] \
  || usage

[ -s "$LIGHT_CAPTURE" ] || { echo "FAIL: light capture is missing or empty: $LIGHT_CAPTURE" >&2; exit 1; }
[ -s "$DARK_CAPTURE" ] || { echo "FAIL: dark capture is missing or empty: $DARK_CAPTURE" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"

DEVICE="$DEVICE" \
LIGHT_CAPTURE="$LIGHT_CAPTURE" \
DARK_CAPTURE="$DARK_CAPTURE" \
KEYBOARD_TOP_PX="$KEYBOARD_TOP_PX" \
PHYSICAL_SIZE="$PHYSICAL_SIZE" \
DENSITY_DPI="$DENSITY_DPI" \
LOGICAL_SIZE_DP="$LOGICAL_SIZE_DP" \
OUTPUT_DIR="$OUTPUT_DIR" \
python3 - <<'PYTHON_SCRIPT'
import json
import os
import re
import sys
from pathlib import Path

from PIL import Image


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_size(value: str, label: str) -> tuple[int, int]:
    match = re.fullmatch(r"([0-9]+)x([0-9]+)", value)
    if not match:
        fail(f"{label} must use WIDTHxHEIGHT syntax: {value}")
    width, height = (int(part) for part in match.groups())
    if width <= 0 or height <= 0:
        fail(f"{label} must contain positive dimensions: {value}")
    return width, height


device = os.environ["DEVICE"]
light_capture = Path(os.environ["LIGHT_CAPTURE"]).resolve()
dark_capture = Path(os.environ["DARK_CAPTURE"]).resolve()
keyboard_top = int(os.environ["KEYBOARD_TOP_PX"])
physical_width, physical_height = parse_size(os.environ["PHYSICAL_SIZE"], "--physical-size")
density_dpi = int(os.environ["DENSITY_DPI"])
logical_width, logical_height = parse_size(os.environ["LOGICAL_SIZE_DP"], "--logical-size-dp")
output_dir = Path(os.environ["OUTPUT_DIR"]).resolve()

if keyboard_top < 0 or keyboard_top >= physical_height:
    fail(f"keyboard top must be within the physical screen: {keyboard_top}")
if density_dpi <= 0:
    fail("--density-dpi must be positive")

keyboard_height = physical_height - keyboard_top

for variant, capture in (("light", light_capture), ("dark", dark_capture)):
    try:
        with Image.open(capture) as image:
            image.load()
            if image.size != (physical_width, physical_height):
                fail(
                    f"{variant} capture is {image.size[0]}x{image.size[1]}, "
                    f"expected {physical_width}x{physical_height}"
                )
            component = image.crop((0, keyboard_top, physical_width, physical_height)).convert("RGB")
            component.save(output_dir / f"keyboard_{variant}.png", format="PNG", optimize=True)
    except OSError as error:
        fail(f"could not read {variant} capture {capture}: {error}")

manifest = {
    "version": 1,
    "platform": "android",
    "device": device,
    "logical_size_dp": {"width": logical_width, "height": logical_height},
    "physical_size_px": {"width": physical_width, "height": physical_height},
    "density_dpi": density_dpi,
    "components": {
        "keyboard": {
            "type": "software_keyboard",
            "logical_bounds_dp": {
                "x": 0,
                "y": round(keyboard_top * 160 / density_dpi, 2),
                "width": round(physical_width * 160 / density_dpi, 2),
                "height": round(keyboard_height * 160 / density_dpi, 2),
            },
            "physical_bounds_px": {
                "x": 0,
                "y": keyboard_top,
                "width": physical_width,
                "height": keyboard_height,
            },
            "dock_position": "bottom",
            "navigation_bar_included": True,
            "variants": {
                "light": "keyboard_light.png",
                "dark": "keyboard_dark.png",
            },
            "capture_method": "UiAutomation.takeScreenshot() from an instrumented VisualFlowTest while the real emulator IME is visible",
        }
    },
}
(output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(
    f"PASS: generated Android keyboard references for {device} "
    f"({physical_width}x{keyboard_height}px component) in {output_dir}"
)
PYTHON_SCRIPT
