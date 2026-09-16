#!/usr/bin/env bash
# Fail when a visual evidence screenshot is clearly rendered in the opposite
# global appearance from the one declared by the visual contract. This is a
# guard against a dark emulator capture being mislabeled as light (or vice
# versa); it intentionally ignores ambiguous/content-heavy screenshots.

set -euo pipefail

usage() {
  echo "Usage: bash harness/scripts/check-visual-theme.sh --expected <light|dark> --image <path>" >&2
  exit 2
}

EXPECTED=""
IMAGE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --expected)
      [ "$#" -ge 2 ] || usage
      EXPECTED="$2"
      shift 2
      ;;
    --image)
      [ "$#" -ge 2 ] || usage
      IMAGE="$2"
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

case "$EXPECTED" in
  light|dark) ;;
  *) echo "FAIL: --expected must be light or dark" >&2; exit 2 ;;
esac
[ -n "$IMAGE" ] || usage
[ -s "$IMAGE" ] || {
  echo "FAIL: visual screenshot is missing or empty: $IMAGE" >&2
  exit 1
}

EXPECTED="$EXPECTED" IMAGE="$IMAGE" python3 - <<'PY'
import os
import sys
from PIL import Image, ImageStat

path = os.environ["IMAGE"]
try:
    image = Image.open(path).convert("RGB")
except Exception as error:
    print(f"FAIL: could not read visual screenshot {path}: {error}", file=sys.stderr)
    raise SystemExit(1)

# Keep the check deliberately conservative: only an overwhelmingly dark/light
# frame is classified. This catches a global appearance inversion without
# rejecting a valid light screen that contains a dark chart or image.
sample = image.resize((64, 64), Image.Resampling.BILINEAR)
mean_rgb = ImageStat.Stat(sample).mean
luminance = (0.2126 * mean_rgb[0] + 0.7152 * mean_rgb[1] + 0.0722 * mean_rgb[2]) / 255.0
expected = os.environ["EXPECTED"]

if expected == "light" and luminance < 0.25:
    print(f"FAIL: screenshot appears dark (mean luminance {luminance:.3f}); expected light: {path}", file=sys.stderr)
    raise SystemExit(1)
if expected == "dark" and luminance > 0.75:
    print(f"FAIL: screenshot appears light (mean luminance {luminance:.3f}); expected dark: {path}", file=sys.stderr)
    raise SystemExit(1)

print(f"PASS: screenshot appearance is compatible with {expected} (mean luminance {luminance:.3f}): {path}")
PY
