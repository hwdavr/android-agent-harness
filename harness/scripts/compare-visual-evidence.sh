#!/usr/bin/env bash
# Semantic & Visual Evidence Comparator (Validation Level 5)
# Compares actual runtime UI screenshots against explicitly mapped approved mockups,
# normalizes system insets, applies approved dynamic-region masks, generates visual
# diff overlays, and classifies defects.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

MODE=""
REFERENCE_PATH=""
ACTUAL_PATH=""
DIFF_OUTPUT=""
FEATURE_DIR=""
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
                                 (each capture requires an explicit approved mockup map)

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

class ReferenceConfigurationError(Exception):
    pass

REQUIRED_DYNAMIC_KINDS = {"time", "user-content", "identifier", "keyboard"}
VALID_DYNAMIC_HANDLING = {"mask", "fixture", "cropped-system-insets", "not-present"}

def configuration_error(message):
    raise ReferenceConfigurationError(message)

def valid_mask(region, label):
    if not isinstance(region, dict):
        configuration_error(f"{label} must be an object with x, y, w, h, and rationale")
    for key in ("x", "y", "w", "h"):
        if not isinstance(region.get(key), (int, float)):
            configuration_error(f"{label}.{key} must be a number")
    if region["w"] <= 0 or region["h"] <= 0:
        configuration_error(f"{label} width and height must be positive")
    if not isinstance(region.get("rationale"), str) or not region["rationale"].strip():
        configuration_error(f"{label} must state an approval rationale")
    return {key: region[key] for key in ("x", "y", "w", "h")}

def image_luminance(path):
    sample = Image.open(path).convert("RGB").resize((64, 64), Image.Resampling.BILINEAR)
    pixels = list(sample.getdata())
    return sum((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0 for r, g, b in pixels) / len(pixels)

def validate_appearance(reference_path, appearance, label):
    luminance = image_luminance(reference_path)
    if appearance == "light" and luminance < 0.25:
        configuration_error(f"{label} is dark (mean luminance {luminance:.3f}) but its metadata requires light appearance")
    if appearance == "dark" and luminance > 0.75:
        configuration_error(f"{label} is light (mean luminance {luminance:.3f}) but its metadata requires dark appearance")

def validate_logical_size(image_path, target, label):
    size = target.get("logical_size_dp") or target.get("logical_size_pt")
    if not isinstance(size, dict):
        configuration_error(f"{label}.logical_size_dp must be an object")
    width, height = size.get("width"), size.get("height")
    if not isinstance(width, (int, float)) or not isinstance(height, (int, float)) or width <= 0 or height <= 0:
        configuration_error(f"{label}.logical_size_dp must contain positive numeric width and height")
    with Image.open(image_path) as image:
        scale_x = image.width / width
        scale_y = image.height / height
    if abs(scale_x - scale_y) > 0.03:
        unit = "dp" if "logical_size_dp" in target else "pt"
        configuration_error(f"{label} image dimensions do not match declared logical device size {width}x{height} {unit}")
    return width, height

def validate_dynamic_regions(state, label):
    masks = state.get("mask")
    if not isinstance(masks, list):
        configuration_error(f"{label}.mask must be a list, including when no static mask is needed")
    approved_masks = [valid_mask(mask, f"{label}.mask[{index}]") for index, mask in enumerate(masks)]

    dynamic_regions = state.get("dynamic_regions")
    if not isinstance(dynamic_regions, list):
        configuration_error(f"{label}.dynamic_regions must be a list")
    seen_kinds = set()
    for index, dynamic_region in enumerate(dynamic_regions):
        dynamic_label = f"{label}.dynamic_regions[{index}]"
        if not isinstance(dynamic_region, dict):
            configuration_error(f"{dynamic_label} must be an object")
        kind = dynamic_region.get("kind")
        handling = dynamic_region.get("handling")
        if kind not in REQUIRED_DYNAMIC_KINDS or kind in seen_kinds:
            configuration_error(f"{dynamic_label}.kind must be one unique required dynamic kind")
        seen_kinds.add(kind)
        if handling not in VALID_DYNAMIC_HANDLING:
            configuration_error(f"{dynamic_label}.handling must be mask, fixture, cropped-system-insets, or not-present")
        if not isinstance(dynamic_region.get("rationale"), str) or not dynamic_region["rationale"].strip():
            configuration_error(f"{dynamic_label} must state an approval rationale")
        if handling == "mask":
            mask_data = dynamic_region.get("mask")
            if not isinstance(mask_data, dict):
                configuration_error(f"{dynamic_label}.mask is required when handling is mask")
            approved_masks.append(valid_mask(mask_data, f"{dynamic_label}.mask"))

    missing_kinds = REQUIRED_DYNAMIC_KINDS - seen_kinds
    if missing_kinds:
        configuration_error(f"{label}.dynamic_regions is missing {', '.join(sorted(missing_kinds))}")

    return approved_masks

def validate_target_manifest(feature_dir, target_path):
    try:
        raw = json.loads(target_path.read_text(encoding="utf-8"))
    except Exception as error:
        configuration_error(f"could not parse visual target manifest: {error}")
    if not isinstance(raw, dict) or raw.get("version") != 1:
        configuration_error("visual target manifest must use version 1")
    required = ["target_id", "appearance", "device", "locale", "states"]
    missing = [key for key in required if key not in raw]
    if "logical_size_dp" not in raw and "logical_size_pt" not in raw:
        missing.append("logical_size_dp")
    if missing:
        configuration_error(f"visual target manifest is missing {', '.join(missing)}")
    appearance = raw["appearance"]
    if appearance not in {"light", "dark"}:
        configuration_error("visual target appearance must be light or dark")
    locale = raw["locale"]
    if not isinstance(locale, str) or not re.fullmatch(r"[A-Za-z]{2,3}-[A-Za-z]{2}", locale):
        configuration_error("visual target locale must be a concrete BCP-47 language-region value")
    states = raw["states"]
    if not isinstance(states, dict) or not states:
        configuration_error("visual target states must be a non-empty object")
    for state_id, state in states.items():
        if not isinstance(state, dict):
            configuration_error(f"visual target state {state_id} must be an object")
        for key in ("reference", "content_state", "dynamic_regions"):
            if key not in state:
                configuration_error(f"visual target state {state_id} is missing {key}")
        ref_path = (feature_dir / state["reference"]).resolve()
        if not ref_path.name.startswith("mockup_"):
            configuration_error(f"visual target state {state_id} reference must name an approved design/mockup_*.png asset")
        if not ref_path.is_file() or ref_path.stat().st_size == 0:
            configuration_error(f"visual target state {state_id} reference is missing or empty: {state['reference']}")
        validate_appearance(ref_path, appearance, f"visual target mockup {state['reference']}")
    return raw

def load_reference_map(visual_evidence_dir):
    map_path = visual_evidence_dir / "reference-map.json"
    if not map_path.is_file():
        configuration_error(f"missing {map_path}; each runtime capture requires an explicit approved mockup mapping")
    try:
        raw = json.loads(map_path.read_text(encoding="utf-8"))
    except Exception as error:
        configuration_error(f"could not parse {map_path}: {error}")
    if not isinstance(raw, dict) or raw.get("version") != 1 or "captures" not in raw:
        configuration_error(f"{map_path} must be a version 1 object with target_manifest and captures")
    if not isinstance(raw.get("captures"), dict):
        configuration_error(f"{map_path}.captures must be an object mapping screenshot filenames to explicit state mappings")
    target_manifest = raw.get("target_manifest")
    if not isinstance(target_manifest, str) or not target_manifest.strip() or ".." in Path(target_manifest).parts:
        configuration_error(f"{map_path}.target_manifest must name a manifest under visual_evidence/")
    target_path = (visual_evidence_dir / target_manifest).resolve()
    try:
        target_path.relative_to(visual_evidence_dir.resolve())
    except ValueError:
        configuration_error(f"{map_path}.target_manifest must stay under visual_evidence/")
    if not target_path.is_file():
        configuration_error(f"visual target manifest is missing: {target_manifest}")
    target = validate_target_manifest(visual_evidence_dir.parent, target_path)
    return raw["captures"], target

def validate_mapping(feature_dir, actual_path, entry, target):
    file_name = actual_path.name
    label = f"reference-map.json entry for {file_name}"
    if not isinstance(entry, dict):
        configuration_error(f"{label} must be an object; string, null, and inferred mappings are prohibited")
    if set(entry) != {"state_id"}:
        configuration_error(f"{label} must contain only the explicit state_id; target metadata belongs in visual-target.json")
    state_id = entry.get("state_id")
    if not isinstance(state_id, str) or not state_id.strip():
        configuration_error(f"{label}.state_id must be a non-empty stable content state ID")
    state = target["states"].get(state_id)
    if not isinstance(state, dict):
        configuration_error(f"{label}.state_id '{state_id}' is not declared in visual-target.json")
    reference = state["reference"]
    reference_path = (feature_dir / reference).resolve()
    design_root = (feature_dir / "design").resolve()
    try:
        reference_path.relative_to(design_root)
    except ValueError:
        configuration_error(f"{label}.reference must stay under design/")
    if reference_path.suffix.lower() != ".png" or not reference_path.is_file() or reference_path.stat().st_size == 0:
        configuration_error(f"{label}.reference is missing or empty: {reference}")

    logical_width, logical_height = validate_logical_size(reference_path, target, label)
    validate_logical_size(actual_path, target, f"runtime capture {file_name}")
    approved_masks = validate_dynamic_regions(state, label)

    return {
        "reference_path": reference_path,
        "reference": reference,
        "state_id": state_id,
        "content_state": state["content_state"],
        "mask_regions": approved_masks,
        "logical_size": (logical_width, logical_height),
    }

def run_feature():
    f_dir = Path(feature_dir_str).resolve()
    if not f_dir.is_dir():
        print(f"FAIL: Feature directory not found: {f_dir}", file=sys.stderr)
        sys.exit(2)

    visual_evidence_dir = f_dir / "visual_evidence"
    if not visual_evidence_dir.is_dir():
        print("PASS: No visual_evidence directory in feature workspace; visual evaluation skipped.")
        sys.exit(0)
    actual_images = sorted(
        image for image in visual_evidence_dir.glob("*.png") if not image.name.endswith("_diff.png")
    )
    if not actual_images:
        print("PASS: No actual screenshots in visual_evidence/; visual evaluation skipped.")
        sys.exit(0)

    print("======================================================")
    print("  Batch Visual Comparison — Approved Mockup Gate")
    print("======================================================")
    print(f"  Feature directory: {f_dir}")
    print(f"  Actual screenshots found: {len(actual_images)}")

    try:
        reference_map, target_manifest = load_reference_map(visual_evidence_dir)
        actual_names = {image.name for image in actual_images}
        mapped_names = set(reference_map)
        unknown = sorted(mapped_names - actual_names)
        missing = sorted(actual_names - mapped_names)
        if unknown:
            configuration_error(f"reference-map.json maps unknown capture(s): {', '.join(unknown)}")
        if missing:
            configuration_error(f"reference-map.json has no explicit mapping for capture(s): {', '.join(missing)}")
        mappings = {image.name: validate_mapping(f_dir, image, reference_map[image.name], target_manifest) for image in actual_images}
    except ReferenceConfigurationError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(2)

    all_passed = True
    comparison_records = []
    for actual_path in actual_images:
        mapping = mappings[actual_path.name]
        reference_path = mapping["reference_path"]
        diff_file = visual_evidence_dir / f"{actual_path.stem}_diff.png"
        try:
            with Image.open(reference_path) as reference_image, Image.open(actual_path) as actual_image:
                result = compare_images(reference_image, actual_image, mask_regions=mapping["mask_regions"])
            result["diff_overlay"].save(diff_file)
            status = "PASS" if result["passed"] else "FAIL"
            all_passed = all_passed and result["passed"]
            print(f"  [{status}] {actual_path.name} vs {reference_path.name} (state={mapping['state_id']}; explicit-mockup-map, binding) -> score: {result['similarity_score']:.4f} (diff: {result['diff_percentage']}%)")
            comparison_records.append({
                "actual": actual_path.name,
                "reference": mapping["reference"],
                "score": result["similarity_score"],
                "diff_percentage": result["diff_percentage"],
                "status": status,
                "diff_image": diff_file.name,
            })
        except Exception as error:
            print(f"  [ERROR] Failed to compare {actual_path.name} vs {reference_path.name}: {error}", file=sys.stderr)
            all_passed = False
            comparison_records.append({
                "actual": actual_path.name,
                "reference": mapping["reference"],
                "score": None,
                "diff_percentage": None,
                "status": "ERROR",
                "diff_image": "—",
            })

    report_md = visual_evidence_dir / "visual_comparison_report.md"
    overall = "PASS" if all_passed else "FAIL"
    size_obj = target_manifest.get("logical_size_dp") or target_manifest.get("logical_size_pt", {"width": 0, "height": 0})
    size_unit = "dp" if "logical_size_dp" in target_manifest else "pt"
    md_lines = [
        "# Visual Comparison Evaluation Report\n",
        f"**Feature Directory**: `{f_dir.name}`\n",
        f"**Visual Target Manifest**: `visual_evidence/visual-target.json` (target `{target_manifest['target_id']}`, {target_manifest['appearance']}, {target_manifest['device']}, {size_obj.get('width', 0)}x{size_obj.get('height', 0)} {size_unit}, `{target_manifest['locale']}`)\n",
        f"**Threshold**: `{threshold}` (binding approved mockup comparison; structural-anchor proof is separately binding in `check-visual-evidence-contract.sh`)\n",
        f"**Overall Status**: `{overall}`\n\n",
        "| Actual Screenshot | Approved Mockup | Gate Role | Matched Via | Similarity Score | Diff % | Diff Overlay | Status |\n",
        "|---|---|---|---|---|---|---|---|\n",
    ]
    for record in comparison_records:
        score = f"{record['score']:.4f}" if record["score"] is not None else "—"
        diff = f"{record['diff_percentage']}%" if record["diff_percentage"] is not None else "—"
        diff_cell = f"[`{record['diff_image']}`]({record['diff_image']})" if record["diff_image"] != "—" else "—"
        md_lines.append(
            f"| `{record['actual']}` | `{Path(record['reference']).name}` | binding | explicit-mockup-map | {score} | {diff} | {diff_cell} | **{record['status']}** |\n"
        )
    report_md.write_text("".join(md_lines), encoding="utf-8")
    print(f"\n  Consolidated report written to: {report_md}")
    print("======================================================")
    sys.exit(0 if all_passed else 1)

if mode == "pair":
    run_pair()
elif mode == "feature":
    run_feature()
else:
    print(f"FAIL: Unknown mode '{mode}'", file=sys.stderr)
    sys.exit(2)
PYTHON_SCRIPT
