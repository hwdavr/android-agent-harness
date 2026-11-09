#!/usr/bin/env bash
# Validates the shape of a workspace's ui_verification.json conformance review.
# Cross-checks against UI_contract.md and test-plan.md live in check-ui-contract.py --report.
# Usage: bash harness/scripts/check-ui-verification-artifact.sh <workspace>
set -euo pipefail

WORKSPACE="${1:-}"
[ -n "$WORKSPACE" ] || { echo "Usage: $0 <workspace>" >&2; exit 2; }
REPORT="$WORKSPACE/ui_verification.json"

python3 - "$REPORT" <<'PY'
import json, re, sys
from pathlib import Path

path = Path(sys.argv[1])
def fail(message):
    print(f"FAIL: {path}: {message}", file=sys.stderr)
    sys.exit(1)

if not path.is_file():
    fail("missing conformance review report")
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except json.JSONDecodeError as error:
    fail(f"invalid JSON: {error}")
if not isinstance(data, dict):
    fail("report must be a JSON object")

retired = sorted({"visual_target", "runtime_evidence", "evidence_contract", "design_anchors_schema",
                  "runtime_evidence_schema", "normalization", "region_decomposition"} & set(data))
if retired:
    fail(f"retired pixel-comparison fields present: {', '.join(retired)}; use the conformance review template")
if not isinstance(data.get("version"), int):
    fail("version must be an integer")
capture = data.get("capture")
if not isinstance(capture, dict) or any(not capture.get(key) for key in ("renderer", "density", "theme", "locale")):
    fail("capture must declare renderer, density, theme, and locale")
checks = data.get("build_and_static_checks")
if not isinstance(checks, dict) or not checks or any(value != "PASS" for value in checks.values()):
    fail("every build_and_static_checks entry must be PASS")

results = data.get("state_results")
if not isinstance(results, list) or not results:
    fail("state_results must be a non-empty array")
required = ("screen", "state_id", "design_image", "review_capture", "review_capture_test", "structural_check",
            "structural_result", "reused_components", "review_decision", "approved_by", "approved_on", "result")
for index, item in enumerate(results):
    if not isinstance(item, dict):
        fail(f"state_results[{index}] must be an object")
    missing = [key for key in required if key not in item]
    if missing:
        fail(f"state_results[{index}] is missing {', '.join(missing)}")
    label = item.get("state_id", index)
    if "pixel_parity" in item or "comparison" in item:
        fail(f"state {label} uses retired pixel-comparison fields")
    if any(isinstance(item[key], str) and ("<" in item[key] or ">" in item[key]) for key in required):
        fail(f"state {label} still contains template placeholders")
    if not isinstance(item["reused_components"], list):
        fail(f"state {label} reused_components must be an array")
    if item["review_decision"] not in ("approved", "changes-requested"):
        fail(f"state {label} review_decision must be approved or changes-requested")
    passing = item["review_decision"] == "approved" and item["structural_result"] == "PASS"
    if item["result"] == "PASS" and not passing:
        fail(f"state {label} cannot PASS without an approved review and a passing structural check")
    if item["result"] != "PASS":
        fail(f"state {label} has not passed the conformance review (result {item['result']})")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(item["approved_on"])):
        fail(f"state {label} approved_on must be YYYY-MM-DD")
print(f"PASS: {path} records an approved conformance review for {len(results)} state(s).")
PY
