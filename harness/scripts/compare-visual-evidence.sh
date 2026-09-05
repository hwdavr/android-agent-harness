#!/usr/bin/env bash
# Semantic & Visual Evidence Comparator (Validation Level 5)
# Compares actual runtime UI screenshots against reference designs or golden baselines,
# normalizes system insets, generates visual diff overlays, and classifies defects.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

MODE=""
REFERENCE_PATH=""
ACTUAL_PATH=""
DIFF_OUTPUT=""
FEATURE_DIR=""
GOLDEN_NAME=""
THRESHOLD="0.95"
CROP_INSETS=0
MASK_JSON=""

usage() {
  cat << 'EOF' >&2
Usage: bash harness/scripts/compare-visual-evidence.sh [OPTIONS]

Modes:
  --reference <ref.png> --actual <act.png> [--diff-output <diff.png>]
                                 Compare a single image pair
  --feature <feature_dir>        Batch evaluate all visual evidence for a feature
  --promote-golden <act.png> --name <screen_name>
                                 Promote an actual screenshot to UX/golden-baselines/

Options:
  --threshold <float>            Minimum similarity score to pass (default: 0.95)
  --crop-insets                  Crop Android status bar and navigation bar insets
  --diff-output <path>           Destination path for visual diff overlay image
  --mask-json <path_or_str>      JSON array of regions to mask/ignore: [{"x":0,"y":0,"w":100,"h":50}]
  --project-root <path>          Project root directory

Exit codes:
  0: Pass (similarity >= threshold, no critical violations)
  1: Fail (visual mismatch or regression detected)
  2: Error (missing files, syntax error)
EOF
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --reference)
      [ $# -ge 2 ] || usage
      REFERENCE_PATH="$2"
      shift 2
      ;;
    --actual)
      [ $# -ge 2 ] || usage
      ACTUAL_PATH="$2"
      shift 2
      ;;
    --diff-output)
      [ $# -ge 2 ] || usage
      DIFF_OUTPUT="$2"
      shift 2
      ;;
    --feature)
      [ $# -ge 2 ] || usage
      MODE="feature"
      FEATURE_DIR="$2"
      shift 2
      ;;
    --promote-golden)
      [ $# -ge 2 ] || usage
      MODE="promote-golden"
      ACTUAL_PATH="$2"
      shift 2
      ;;
    --name)
      [ $# -ge 2 ] || usage
      GOLDEN_NAME="$2"
      shift 2
      ;;
    --threshold)
      [ $# -ge 2 ] || usage
      THRESHOLD="$2"
      shift 2
      ;;
    --crop-insets)
      CROP_INSETS=1
      shift
      ;;
    --mask-json)
      [ $# -ge 2 ] || usage
      MASK_JSON="$2"
      shift 2
      ;;
    --project-root)
      [ $# -ge 2 ] || usage
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      usage
      ;;
  esac
done

if [ -z "$MODE" ]; then
  if [ -n "$REFERENCE_PATH" ] && [ -n "$ACTUAL_PATH" ]; then
    MODE="pair"
  else
    usage
  fi
fi

if [ -n "$REFERENCE_PATH" ] && [[ "$REFERENCE_PATH" != /* ]]; then
  REFERENCE_PATH="$PROJECT_ROOT/$REFERENCE_PATH"
fi
if [ -n "$ACTUAL_PATH" ] && [[ "$ACTUAL_PATH" != /* ]]; then
  ACTUAL_PATH="$PROJECT_ROOT/$ACTUAL_PATH"
fi
if [ -n "$DIFF_OUTPUT" ] && [[ "$DIFF_OUTPUT" != /* ]]; then
  DIFF_OUTPUT="$PROJECT_ROOT/$DIFF_OUTPUT"
fi
if [ -n "$FEATURE_DIR" ] && [[ "$FEATURE_DIR" != /* ]]; then
  FEATURE_DIR="$PROJECT_ROOT/$FEATURE_DIR"
fi

export PROJECT_ROOT
export MODE
export REFERENCE_PATH
export ACTUAL_PATH
export DIFF_OUTPUT
export FEATURE_DIR
export GOLDEN_NAME
export THRESHOLD
export CROP_INSETS
export MASK_JSON

python3 - << 'PYTHON_SCRIPT'
import json
import math
import os
import re
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageEnhance
except ImportError:
    print("FAIL: Pillow (PIL) is required for visual comparison. Please ensure python3-pil is installed.", file=sys.stderr)
    sys.exit(2)

project_root = Path(os.environ["PROJECT_ROOT"]).resolve()
mode = os.environ["MODE"]
ref_path_str = os.environ.get("REFERENCE_PATH", "")
act_path_str = os.environ.get("ACTUAL_PATH", "")
diff_output_str = os.environ.get("DIFF_OUTPUT", "")
feature_dir_str = os.environ.get("FEATURE_DIR", "")
golden_name = os.environ.get("GOLDEN_NAME", "")
threshold = float(os.environ.get("THRESHOLD", "0.95"))
crop_insets = os.environ.get("CROP_INSETS", "0") == "1"
mask_json_str = os.environ.get("MASK_JSON", "")

def crop_system_insets(img):
    # If image is tall aspect ratio (height >= 1.6 * width, like a phone screen)
    if img.height >= 1.6 * img.width:
        top = int(img.height * 0.04)     # status bar (~4%)
        bottom = int(img.height * 0.97)  # navigation gesture bar (~3%)
        return img.crop((0, top, img.width, bottom))
    return img

def compare_images(ref_img, act_img, mask_regions=None, tolerance=0.08):
    if crop_insets:
        ref_img = crop_system_insets(ref_img)
        act_img = crop_system_insets(act_img)

    # Normalize dimensions to reference
    if ref_img.size != act_img.size:
        act_img = act_img.resize(ref_img.size, Image.Resampling.LANCZOS)

    ref_rgba = ref_img.convert("RGBA")
    act_rgba = act_img.convert("RGBA")

    # Apply masks if provided
    if mask_regions:
        draw_mask = ImageDraw.Draw(ref_rgba)
        draw_act = ImageDraw.Draw(act_rgba)
        for r in mask_regions:
            box = (r.get("x", 0), r.get("y", 0), r.get("x", 0) + r.get("w", 0), r.get("y", 0) + r.get("h", 0))
            draw_mask.rectangle(box, fill=(128, 128, 128, 255))
            draw_act.rectangle(box, fill=(128, 128, 128, 255))

    width, height = ref_rgba.size
    total_pixels = width * height

    ref_data = list(ref_rgba.getdata())
    act_data = list(act_rgba.getdata())

    mismatched_coords = []
    for idx in range(total_pixels):
        r1, g1, b1, _ = ref_data[idx]
        r2, g2, b2, _ = act_data[idx]
        dist = math.sqrt((r1 - r2)**2 + (g1 - g2)**2 + (b1 - b2)**2) / 441.67
        if dist > tolerance:
            x = idx % width
            y = idx // width
            mismatched_coords.append((x, y))

    mismatched_count = len(mismatched_coords)
    diff_pct = (mismatched_count / total_pixels) * 100.0 if total_pixels > 0 else 0.0
    similarity = 1.0 - (diff_pct / 100.0)

    # Generate high-contrast visual diff overlay
    diff_overlay = act_rgba.copy()
    enhancer = ImageEnhance.Brightness(diff_overlay)
    diff_overlay = enhancer.enhance(0.45)
    enhancer_c = ImageEnhance.Color(diff_overlay)
    diff_overlay = enhancer_c.enhance(0.5)

    diff_draw = ImageDraw.Draw(diff_overlay)
    # Paint mismatched pixels in neon pink/magenta
    for (x, y) in mismatched_coords:
        diff_draw.point((x, y), fill=(255, 0, 127, 240))

    # Cluster bounding boxes of mismatch regions (simple grid binning)
    cell_size = 40
    grid = {}
    for (x, y) in mismatched_coords:
        gx, gy = x // cell_size, y // cell_size
        grid[(gx, gy)] = grid.get((gx, gy), 0) + 1

    dense_clusters = [k for k, v in grid.items() if v > (cell_size * cell_size * 0.15)]
    violations = []

    if diff_pct > 5.0:
        violations.append({
            "severity": "high",
            "component": "ScreenContent",
            "issue": f"Overall visual mismatch ({diff_pct:.1f}%) exceeds acceptable tolerance"
        })
    elif diff_pct > (1.0 - threshold) * 100.0:
        violations.append({
            "severity": "medium",
            "component": "VisualLayout",
            "issue": f"Visual divergence ({diff_pct:.1f}%) is below similarity threshold ({threshold * 100:.0f}%)"
        })

    for (gx, gy) in dense_clusters[:5]:
        box = (gx * cell_size, gy * cell_size, (gx + 1) * cell_size, (gy + 1) * cell_size)
        diff_draw.rectangle(box, outline=(255, 220, 0, 255), width=2)

    passed = (similarity >= threshold) and not any(v["severity"] == "high" for v in violations)

    return {
        "passed": passed,
        "similarity_score": round(similarity, 4),
        "diff_percentage": round(diff_pct, 2),
        "mismatched_pixels": mismatched_count,
        "total_pixels": total_pixels,
        "violations": violations,
        "diff_overlay": diff_overlay
    }

def run_pair():
    ref_p = Path(ref_path_str).resolve()
    act_p = Path(act_path_str).resolve()

    if not ref_p.is_file():
        print(f"FAIL: Reference image not found: {ref_p}", file=sys.stderr)
        sys.exit(2)
    if not act_p.is_file():
        print(f"FAIL: Actual image not found: {act_p}", file=sys.stderr)
        sys.exit(2)

    try:
        ref_img = Image.open(ref_p)
        act_img = Image.open(act_p)
    except Exception as e:
        print(f"FAIL: Failed to open images: {e}", file=sys.stderr)
        sys.exit(2)

    mask_regions = None
    if mask_json_str:
        try:
            if Path(mask_json_str).is_file():
                mask_regions = json.loads(Path(mask_json_str).read_text())
            else:
                mask_regions = json.loads(mask_json_str)
        except Exception as e:
            print(f"WARNING: Could not parse mask JSON: {e}", file=sys.stderr)

    result = compare_images(ref_img, act_img, mask_regions=mask_regions)

    if diff_output_str:
        out_p = Path(diff_output_str).resolve()
        out_p.parent.mkdir(parents=True, exist_ok=True)
        result["diff_overlay"].save(out_p)

    verdict = "PASS" if result["passed"] else "FAIL"

    print("======================================================")
    print("  Semantic & Visual Comparison Result")
    print("======================================================")
    print(f"  Reference:        {ref_p}")
    print(f"  Actual:           {act_p}")
    if diff_output_str:
        print(f"  Diff Overlay:     {diff_output_str}")
    print(f"  Similarity Score: {result['similarity_score']:.4f} (Threshold: {threshold:.2f})")
    print(f"  Diff Percentage:  {result['diff_percentage']:.2f}%")
    print(f"  Mismatched Pixels:{result['mismatched_pixels']} / {result['total_pixels']}")
    print(f"  Result:           {verdict}")

    if result["violations"]:
        print("\n  VIOLATIONS:")
        for v in result["violations"]:
            print(f"    - [{v['severity'].upper()}] {v['component']}: {v['issue']}")
    else:
        print("\n  VIOLATIONS: None (Perceptually conforming)")

    print("======================================================")
    sys.exit(0 if result["passed"] else 1)

def run_promote_golden():
    act_p = Path(act_path_str).resolve()
    if not act_p.is_file():
        print(f"FAIL: Actual image not found: {act_p}", file=sys.stderr)
        sys.exit(2)
    if not golden_name:
        print("FAIL: --name <screen_name> required for --promote-golden", file=sys.stderr)
        sys.exit(2)

    golden_dir = project_root / "UX" / "golden-baselines"
    golden_dir.mkdir(parents=True, exist_ok=True)
    clean_name = golden_name if golden_name.endswith(".png") else f"{golden_name}.png"
    target_p = golden_dir / clean_name

    img = Image.open(act_p)
    img.save(target_p)

    print("======================================================")
    print("  Promoted to Golden Baseline")
    print("======================================================")
    print(f"  Source: {act_p}")
    print(f"  Golden: {target_p}")
    print("======================================================")
    sys.exit(0)

def run_feature():
    f_dir = Path(feature_dir_str).resolve()
    if not f_dir.is_dir():
        print(f"FAIL: Feature directory not found: {f_dir}", file=sys.stderr)
        sys.exit(2)

    visual_evidence_dir = f_dir / "visual_evidence"
    if not visual_evidence_dir.is_dir():
        print("PASS: No visual_evidence directory in feature workspace; visual evaluation skipped.")
        sys.exit(0)

    # Find reference designs in design/ or UX/golden-baselines
    design_dir = f_dir / "design"
    golden_dir = project_root / "UX" / "golden-baselines"

    actual_images = list(visual_evidence_dir.glob("*.png"))
    # filter out existing *_diff.png
    actual_images = [img for img in actual_images if not img.name.endswith("_diff.png")]

    if not actual_images:
        print("PASS: No actual screenshots in visual_evidence/; visual evaluation skipped.")
        sys.exit(0)

    print("======================================================")
    print("  Batch Visual Comparison — Feature Evaluation")
    print("======================================================")
    print(f"  Feature directory: {f_dir}")
    print(f"  Actual screenshots found: {len(actual_images)}")

    all_passed = True
    comparison_records = []

    anchor_md = visual_evidence_dir / "reference-anchor-verification.md"
    default_ref = None
    if anchor_md.is_file():
        m = re.search(r"\*\*Reference design\*\*:\s*`?([^`\n]+)`?", anchor_md.read_text(encoding="utf-8"))
        if m:
            ref_rel = m.group(1).strip()
            cand = f_dir / ref_rel
            if cand.is_file():
                default_ref = cand

    for act_img_path in actual_images:
        base_name = act_img_path.stem
        base_tokens = set(re.findall(r"[a-z0-9]+", base_name.lower()))
        best_match = None
        best_overlap = 0

        # Try matching by token overlap in design/
        if design_dir.is_dir():
            for p in design_dir.glob("*.png"):
                p_tokens = set(re.findall(r"[a-z0-9]+", p.stem.lower()))
                p_tokens.discard("mockup")
                overlap = len(base_tokens & p_tokens)
                if overlap > best_overlap:
                    best_overlap = overlap
                    best_match = p

        ref_candidate = best_match or default_ref

        if not ref_candidate and golden_dir.is_dir():
            for p in golden_dir.glob("*.png"):
                if base_name in p.stem or p.stem in base_name:
                    ref_candidate = p
                    break

        if not ref_candidate:
            print(f"  [SKIP] No matching reference found for {act_img_path.name}")
            continue

        try:
            ref_img = Image.open(ref_candidate)
            act_img = Image.open(act_img_path)
            res = compare_images(ref_img, act_img)
            diff_file = visual_evidence_dir / f"{base_name}_diff.png"
            res["diff_overlay"].save(diff_file)

            status_str = "PASS" if res["passed"] else "FAIL"
            print(f"  [{status_str}] {act_img_path.name} vs {ref_candidate.name} -> score: {res['similarity_score']:.4f} (diff: {res['diff_percentage']}%)")

            if not res["passed"]:
                all_passed = False

            comparison_records.append({
                "actual": act_img_path.name,
                "reference": ref_candidate.name,
                "score": res["similarity_score"],
                "diff_percentage": res["diff_percentage"],
                "status": status_str,
                "diff_image": diff_file.name
            })
        except Exception as e:
            print(f"  [SKIP] Skipping {act_img_path.name}: {e}")

    # Write summary report markdown
    report_md = visual_evidence_dir / "visual_comparison_report.md"
    md_lines = [
        "# Visual Comparison Evaluation Report\n",
        f"**Feature Directory**: `{f_dir.name}`\n",
        f"**Threshold**: `{threshold}`\n",
        f"**Overall Status**: `{'PASS' if all_passed else 'FAIL'}`\n\n",
        "| Actual Screenshot | Reference Design | Similarity Score | Diff % | Diff Overlay | Status |\n",
        "|---|---|---|---|---|---|\n"
    ]
    for r in comparison_records:
        md_lines.append(f"| `{r['actual']}` | `{r['reference']}` | {r['score']:.4f} | {r['diff_percentage']}% | [`{r['diff_image']}`]({r['diff_image']}) | **{r['status']}** |\n")

    report_md.write_text("".join(md_lines), encoding="utf-8")
    print(f"\n  Consolidated report written to: {report_md}")
    print("======================================================")

    sys.exit(0 if all_passed else 1)

if mode == "pair":
    run_pair()
elif mode == "promote-golden":
    run_promote_golden()
elif mode == "feature":
    run_feature()
else:
    print(f"FAIL: Unknown mode '{mode}'", file=sys.stderr)
    sys.exit(2)
PYTHON_SCRIPT
