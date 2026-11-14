#!/usr/bin/env python3
"""Compose a side-by-side review image per UI state: approved design (left), actual render (right).

Usage: compose-ui-comparison.py <feature-dir>

Reads the Screen States table of <feature-dir>/UI_contract.md, pairs each state's `Design image`
with `evidence/ui/<state-id>.png`, and writes `evidence/ui/compare/<state-id>.png` plus
`evidence/ui/compare/index.md`. The images are a review aid for the conformance review; nothing
is compared pixel by pixel and the originals are never modified or resized. A pair whose aspect
ratios disagree is a contract error and fails.
"""

import importlib.util
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - environment check
    print("FAIL: compose-ui-comparison.py needs Pillow (python3 -m pip install pillow)", file=sys.stderr)
    sys.exit(2)

SCRIPTS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("check_ui_contract", SCRIPTS / "check-ui-contract.py")
CONTRACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONTRACT)

HEADER_HEIGHT = 120
GUTTER = 48
BACKGROUND = (245, 245, 245)
INK = (20, 20, 20)
ASPECT_TOLERANCE = 0.015


def font(size):
    for name in ("Helvetica.ttc", "Arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def compose(feature_dir):
    contract = feature_dir / "UI_contract.md"
    rows = CONTRACT.table(contract, "Screen States", CONTRACT.STATE_COLUMNS)
    out_dir = feature_dir / "evidence/ui/compare"
    out_dir.mkdir(parents=True, exist_ok=True)
    index = ["# UI comparison index", "", "Design (left) and actual render (right) for each state.", "",
             "| Stage | State | Design | Render | Comparison |", "|---|---|---|---|---|"]
    for row in rows:
        state = row["State ID"]
        design_path = feature_dir / row["Design image"]
        render_path = feature_dir / "evidence/ui" / f"{state}.png"
        for label, path in (("design image", design_path), ("review capture", render_path)):
            if not path.is_file():
                raise ValueError(f"missing {label} for {state}: {path}")
        with Image.open(design_path) as design, Image.open(render_path) as render:
            design, render = design.convert("RGB"), render.convert("RGB")
            ratio_design, ratio_render = design.width / design.height, render.width / render.height
            if abs(ratio_design - ratio_render) / ratio_design > ASPECT_TOLERANCE:
                raise ValueError(
                    f"{state}: design {design.width}x{design.height} and capture {render.width}x{render.height} "
                    "have different aspect ratios; fix the contract or the capture, do not resize")
            height = max(design.height, render.height)
            canvas = Image.new("RGB", (design.width + GUTTER + render.width, height + HEADER_HEIGHT), BACKGROUND)
            canvas.paste(design, (0, HEADER_HEIGHT))
            canvas.paste(render, (design.width + GUTTER, HEADER_HEIGHT))
            draw = ImageDraw.Draw(canvas)
            draw.text((16, 10), f"{row['Plan stage']}  {state}", fill=INK, font=font(34))
            draw.text((16, 62), f"DESIGN  {row['Design image']}  ({design.width}x{design.height})", fill=INK, font=font(24))
            draw.text((design.width + GUTTER + 16, 62),
                      f"ACTUAL  evidence/ui/{state}.png  ({render.width}x{render.height})", fill=INK, font=font(24))
            canvas.save(out_dir / f"{state}.png")
        index.append(f"| {row['Plan stage']} | {state} | `{row['Design image']}` | `evidence/ui/{state}.png` "
                     f"| `evidence/ui/compare/{state}.png` |")
    (out_dir / "index.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    return len(rows)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__.split("\n\n")[0], file=sys.stderr)
        sys.exit(2)
    try:
        count = compose(Path(sys.argv[1]))
    except ValueError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
    print(f"PASS: composed {count} side-by-side comparison(s) in {sys.argv[1]}/evidence/ui/compare/")
