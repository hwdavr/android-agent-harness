#!/usr/bin/env bash
# Render the canonical visual-target manifest into the prompt context used by
# the mockup generator. The emulator preflight consumes the same manifest.

set -euo pipefail

usage() {
  echo "Usage: bash harness/scripts/visual-target-prompt.sh --target <visual-target.json> --state <content-state-id>" >&2
  exit 2
}

TARGET_PATH=""
STATE_ID=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target|--visual-target)
      [ "$#" -ge 2 ] || usage
      TARGET_PATH="$2"
      shift 2
      ;;
    --state|--content-state)
      [ "$#" -ge 2 ] || usage
      STATE_ID="$2"
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

[ -n "$TARGET_PATH" ] || usage
[ -n "$STATE_ID" ] || usage
[ -f "$TARGET_PATH" ] || {
  echo "FAIL: visual target manifest not found: $TARGET_PATH" >&2
  exit 2
}

TARGET_PATH="$TARGET_PATH" STATE_ID="$STATE_ID" python3 - <<'PYTHON_SCRIPT'
import json
import os
import re
import sys
from pathlib import Path

target_path = Path(os.environ["TARGET_PATH"]).resolve()
state_id = os.environ["STATE_ID"]

try:
    manifest = json.loads(target_path.read_text(encoding="utf-8"))
except Exception as error:
    print(f"FAIL: could not parse visual target manifest {target_path}: {error}", file=sys.stderr)
    sys.exit(2)

if not isinstance(manifest, dict) or manifest.get("version") != 1:
    print("FAIL: visual target manifest must use version 1", file=sys.stderr)
    sys.exit(2)

required = ["target_id", "appearance", "device", "locale", "states"]
missing = [key for key in required if key not in manifest]
if "logical_size_dp" not in manifest and "logical_size_pt" not in manifest:
    missing.append("logical_size_dp")
if missing:
    print(f"FAIL: visual target manifest is missing {', '.join(missing)}", file=sys.stderr)
    sys.exit(2)

appearance = manifest["appearance"]
device = manifest["device"]
locale = manifest["locale"]
logical_size = manifest.get("logical_size_dp") or manifest.get("logical_size_pt")
size_unit = "dp" if "logical_size_dp" in manifest else "pt"

if appearance not in {"light", "dark"}:
    print("FAIL: visual target appearance must be light or dark", file=sys.stderr)
    sys.exit(2)
if not isinstance(device, str) or not device.strip():
    print("FAIL: visual target device must be a non-empty string", file=sys.stderr)
    sys.exit(2)
if not isinstance(locale, str) or not re.fullmatch(r"[A-Za-z]{2,3}-[A-Za-z]{2}", locale):
    print("FAIL: visual target locale must be a concrete BCP-47 language-region value", file=sys.stderr)
    sys.exit(2)
if not isinstance(logical_size, dict) or not all(isinstance(logical_size.get(key), (int, float)) and logical_size[key] > 0 for key in ("width", "height")):
    print(f"FAIL: visual target logical_size_{size_unit} must contain positive width and height", file=sys.stderr)
    sys.exit(2)

states = manifest["states"]
if not isinstance(states, dict) or not states:
    print("FAIL: visual target states must be a non-empty object", file=sys.stderr)
    sys.exit(2)
state = states.get(state_id)
if not isinstance(state, dict):
    print(f"FAIL: visual target has no content state '{state_id}'", file=sys.stderr)
    sys.exit(2)

for key in ("reference", "content_state", "dynamic_regions"):
    if key not in state:
        print(f"FAIL: visual target state '{state_id}' is missing {key}", file=sys.stderr)
        sys.exit(2)

keyboard_region = next((r for r in state["dynamic_regions"] if r.get("kind") == "keyboard"), None)
keyboard_ref = ""
if keyboard_region and keyboard_region.get("handling") != "not-present":
    ref_comp_path = f"docs/product/reference_components/{device}/keyboard_{appearance}.png"
    keyboard_ref = f" For keyboard rendering, use the authentic emulator reference component: {ref_comp_path}."

print(
    "Create or edit a high-fidelity Android Jetpack Compose Material 3 mockup for the canonical visual target. "
    f"Target ID: {manifest['target_id']}. Appearance: {appearance}. Device: {device}. "
    f"Logical size: {logical_size['width']}x{logical_size['height']} {size_unit}. Locale: {locale}. "
    f"Content state ID: {state_id}. Content state: {state['content_state']} "
    f"Approved reference asset: {state['reference']}. "
    "Preserve the approved design-system tokens, hierarchy, and component patterns. "
    "Do not add a device frame. Resolve every dynamic region exactly as approved: "
    + ", ".join(
        f"{region.get('kind')}={region.get('handling')} ({region.get('rationale')})"
        for region in state["dynamic_regions"]
    )
    + "."
    + keyboard_ref
)
PYTHON_SCRIPT
