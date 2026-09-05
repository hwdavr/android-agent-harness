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
                                 (golden baselines bind; design mockups are informational)
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

def load_reference_map(visual_evidence_dir):
    """Load optional reference-map.json: {capture filename: reference path relative to the feature dir, or null (anchor-only)}."""
    map_path = visual_evidence_dir / "reference-map.json"
    if not map_path.is_file():
        return {}
    try:
        raw = json.loads(map_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"FAIL: Could not parse {map_path}: {e}", file=sys.stderr)
        sys.exit(2)
    if not isinstance(raw, dict):
        print(f"FAIL: {map_path} must be a JSON object mapping capture filenames to reference paths or null", file=sys.stderr)
        sys.exit(2)
    return raw

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
    golden_root = golden_dir.resolve()

    def is_golden_reference(p):
        try:
            p.resolve().relative_to(golden_root)
            return True
        except ValueError:
            return False

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
    config_error = False
    comparison_records = []

    reference_map = load_reference_map(visual_evidence_dir)
    actual_names = {p.name for p in actual_images}
    for mapped_name in reference_map:
        if mapped_name not in actual_names:
            print(f"FAIL: reference-map.json maps unknown capture '{mapped_name}'; visual_evidence/ has no such PNG", file=sys.stderr)
            config_error = True

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
        file_name = act_img_path.name
        base_tokens = set(re.findall(r"[a-z0-9]+", base_name.lower()))
        ref_candidate = None
        match_via = None
        mask_regions = None

        targets = []

        if file_name in reference_map:
            mapped = reference_map[file_name]
            if mapped is None:
                # Explicit anchor-only declaration: no pixel reference applies to this state.
                print(f"  [ANCHOR_ONLY] {file_name}: declared anchor-only in reference-map.json (no pixel reference)")
                comparison_records.append({
                    "actual": file_name,
                    "reference": "—",
                    "gate_role": "—",
                    "score": None,
                    "diff_percentage": None,
                    "status": "ANCHOR_ONLY",
                    "diff_image": "—",
                    "matched_via": "explicit-map(null)"
                })
                continue

            cand = None
            if isinstance(mapped, str):
                c = f_dir / mapped
                if not c.is_file():
                    print(f"FAIL: reference-map.json maps {file_name} to missing reference '{mapped}'", file=sys.stderr)
                    config_error = True
                    continue
                cand = c
                mask_regions = None
            elif isinstance(mapped, dict):
                ref_val = mapped.get("reference")
                mask_regions = mapped.get("mask")
                if not isinstance(ref_val, str) or not ref_val:
                    print(f"FAIL: reference-map.json object entry for {file_name} must contain a string 'reference'", file=sys.stderr)
                    config_error = True
                    continue
                if mask_regions is not None and not isinstance(mask_regions, list):
                    print(f"FAIL: reference-map.json 'mask' for {file_name} must be a list of regions", file=sys.stderr)
                    config_error = True
                    continue
                c = f_dir / ref_val
                if not c.is_file():
                    print(f"FAIL: reference-map.json maps {file_name} to missing reference '{ref_val}'", file=sys.stderr)
                    config_error = True
                    continue
                cand = c
            else:
                print(f"FAIL: reference-map.json entry for {file_name} must be null, a reference path string, or an object with 'reference' and optional 'mask'", file=sys.stderr)
                config_error = True
                continue

            is_gold = is_golden_reference(cand)
            targets.append({
                "ref": cand,
                "match_via": "explicit-map",
                "gate_role": "binding" if is_gold else "informational",
                "mask": mask_regions,
                "is_golden": is_gold
            })
        else:
            # 1. Exact-name golden baseline: binding regression reference.
            golden_exact = golden_dir / f"{base_name}.png"
            if golden_exact.is_file():
                targets.append({
                    "ref": golden_exact,
                    "match_via": "golden-baseline",
                    "gate_role": "binding",
                    "mask": None,
                    "is_golden": True
                })

            # 2. Deterministic token matching against design mockups (informational):
            # highest token overlap first, then the most parsimonious reference
            # (fewest tokens absent from the capture name), then reference name
            # order. Never depends on glob order.
            candidates = []
            if design_dir.is_dir():
                for p in design_dir.glob("*.png"):
                    p_tokens = set(re.findall(r"[a-z0-9]+", p.stem.lower()))
                    p_tokens.discard("mockup")
                    overlap = len(base_tokens & p_tokens)
                    if overlap > 0:
                        candidates.append((overlap, len(p_tokens - base_tokens), p.stem, p))
            if candidates:
                candidates.sort(key=lambda c: (-c[0], c[1], c[2]))
                targets.append({
                    "ref": candidates[0][3],
                    "match_via": "token-match",
                    "gate_role": "informational",
                    "mask": None,
                    "is_golden": False
                })
            elif default_ref is not None:
                targets.append({
                    "ref": default_ref,
                    "match_via": "anchor-default",
                    "gate_role": "informational",
                    "mask": None,
                    "is_golden": False
                })

        if not targets:
            print(f"  [NO_REFERENCE] No reference found for {file_name}; add an approved design/ mockup, promote a golden baseline, or add a visual_evidence/reference-map.json entry (or declare it anchor-only with null)", file=sys.stderr)
            comparison_records.append({
                "actual": file_name,
                "reference": "—",
                "gate_role": "—",
                "score": None,
                "diff_percentage": None,
                "status": "NO_REFERENCE",
                "diff_image": "—",
                "matched_via": "—"
            })
            config_error = True
            continue

        has_golden = any(t["is_golden"] for t in targets)
        has_multiple = len(targets) > 1

        for target in targets:
            ref_candidate = target["ref"]
            gate_role = target["gate_role"]
            binding = (gate_role == "binding")
            match_via = target["match_via"]
            mask_regions = target["mask"]

            try:
                ref_img = Image.open(ref_candidate)
                act_img = Image.open(act_img_path)
                res = compare_images(ref_img, act_img, mask_regions=mask_regions)

                if has_multiple and not target["is_golden"]:
                    diff_file = visual_evidence_dir / f"{base_name}_mockup_diff.png"
                else:
                    diff_file = visual_evidence_dir / f"{base_name}_diff.png"
                res["diff_overlay"].save(diff_file)

                if binding:
                    status_str = "PASS" if res["passed"] else "FAIL"
                    if not res["passed"]:
                        all_passed = False
                    print(f"  [{status_str}] {file_name} vs {ref_candidate.name} ({match_via}, binding golden regression) -> score: {res['similarity_score']:.4f} (diff: {res['diff_percentage']}%)")
                else:
                    # Mockup comparisons are informational: mock copy and AI-mockup
                    # rendering can never pixel-match a real implementation.
                    status_str = "INFO"
                    print(f"  [INFO] {file_name} vs {ref_candidate.name} ({match_via}, informational) -> score: {res['similarity_score']:.4f} (diff: {res['diff_percentage']}%)")

                comparison_records.append({
                    "actual": file_name,
                    "reference": ref_candidate.name,
                    "gate_role": gate_role,
                    "score": res["similarity_score"],
                    "diff_percentage": res["diff_percentage"],
                    "status": status_str,
                    "diff_image": diff_file.name,
                    "matched_via": match_via
                })
            except Exception as e:
                print(f"  [ERROR] Failed to compare {file_name} vs {ref_candidate.name}: {e}", file=sys.stderr)
                comparison_records.append({
                    "actual": file_name,
                    "reference": ref_candidate.name,
                    "gate_role": gate_role,
                    "score": None,
                    "diff_percentage": None,
                    "status": "ERROR",
                    "diff_image": "—",
                    "matched_via": match_via
                })
                all_passed = False

    # Write summary report markdown
    report_md = visual_evidence_dir / "visual_comparison_report.md"
    overall = "PASS" if (all_passed and not config_error) else "FAIL"
    md_lines = [
        "# Visual Comparison Evaluation Report\n",
        f"**Feature Directory**: `{f_dir.name}`\n",
        f"**Threshold**: `{threshold}` (binding on golden-baseline regression comparisons; design-mockup comparisons are informational)\n",
        f"**Overall Status**: `{overall}`\n\n",
        "| Actual Screenshot | Reference Design | Gate Role | Matched Via | Similarity Score | Diff % | Diff Overlay | Status |\n",
        "|---|---|---|---|---|---|---|---|\n"
    ]
    for r in comparison_records:
        score_str = f"{r['score']:.4f}" if r["score"] is not None else "—"
        diff_str = f"{r['diff_percentage']}%" if r["diff_percentage"] is not None else "—"
        ref_cell = f"`{r['reference']}`" if r["reference"] != "—" else "—"
        if r["diff_image"] != "—":
            diff_cell = f"[`{r['diff_image']}`]({r['diff_image']})"
        else:
            diff_cell = "—"
        md_lines.append(f"| `{r['actual']}` | {ref_cell} | {r['gate_role']} | {r['matched_via']} | {score_str} | {diff_str} | {diff_cell} | **{r['status']}** |\n")

    report_md.write_text("".join(md_lines), encoding="utf-8")
    print(f"\n  Consolidated report written to: {report_md}")
    print("======================================================")

    if config_error:
        sys.exit(2)
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
