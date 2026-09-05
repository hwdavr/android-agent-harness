#!/usr/bin/env bash
# Harness Observability Metrics Validator and Aggregator
# Validates execution metrics in summary files and aggregates repository performance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

MODE=""
TARGET_FILE=""
SUMMARY_DIR=""
STRICT=0

usage() {
  cat << 'EOF' >&2
Usage: bash harness/scripts/check-harness-metrics.sh [OPTIONS] <MODE>

Options:
  --project-root <path>  Root directory of the project
  --summary-dir <path>   Directory to scan for summary files (for --report)
  --strict               Disallow placeholders in validate mode

Modes (must specify exactly one):
  --validate <file>      Validate that a summary file has well-formed observability metrics
  --report               Scan repository summary files and generate aggregate performance dashboard

Exit codes:
  0: Validation passed or report successfully generated
  1: Report found metrics anomalies
  2: Validation error, missing file, or invalid arguments
EOF
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project-root)
      [ $# -ge 2 ] || usage
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --summary-dir)
      [ $# -ge 2 ] || usage
      SUMMARY_DIR="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --validate)
      [ $# -ge 2 ] || usage
      MODE="validate"
      TARGET_FILE="$2"
      shift 2
      ;;
    --report)
      MODE="report"
      shift
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

[ -n "$MODE" ] || usage

if [ -n "$TARGET_FILE" ] && [[ "$TARGET_FILE" != /* ]]; then
  TARGET_FILE="$PROJECT_ROOT/$TARGET_FILE"
fi

if [ -n "$SUMMARY_DIR" ] && [[ "$SUMMARY_DIR" != /* ]]; then
  SUMMARY_DIR="$PROJECT_ROOT/$SUMMARY_DIR"
fi

export PROJECT_ROOT
export TARGET_FILE
export SUMMARY_DIR
export MODE
export STRICT

python3 - << 'PYTHON_SCRIPT'
import json
import os
import re
import sys
from pathlib import Path

project_root = Path(os.environ["PROJECT_ROOT"]).resolve()
mode = os.environ["MODE"]
target_file_str = os.environ.get("TARGET_FILE", "")
summary_dir_str = os.environ.get("SUMMARY_DIR", "")
strict = os.environ.get("STRICT", "0") == "1"

def is_placeholder(val):
    if not val:
        return True
    s = str(val).strip()
    if s in {"", "N/A", "n/a", "null", "None"}:
        return True
    if re.search(r"\{[^{}]*\}", s):
        return True
    if re.search(r"<[^<>]*>", s):
        return True
    return False

def extract_metrics_block(content):
    # Look for ```json:metrics ... ``` or ```json ... ``` under Observability section
    match = re.search(r"```(?:json:metrics|json)\s*\n([\s\S]*?)\n```", content)
    if not match:
        return None, "No json:metrics block found in summary"
    json_text = match.group(1).strip()
    try:
        data = json.loads(json_text)
        return data, None
    except json.JSONDecodeError as e:
        return None, f"Failed to parse json:metrics: {e}"

def validate_summary_file(path, is_strict=False):
    violations = []
    p = Path(path).resolve()
    if not p.is_file():
        return False, [f"Summary file not found: {p}"]

    content = p.read_text(encoding="utf-8")
    if "## Observability & Execution Metrics" not in content:
        violations.append("Missing section header: '## Observability & Execution Metrics'")

    data, err = extract_metrics_block(content)
    if err:
        violations.append(err)
        return False, violations

    required_keys = [
        ("model", str),
        ("total_duration_sec", (int, float)),
        ("files_read_count", int),
        ("files_modified_count", int),
        ("commands_executed", int),
        ("first_pass_command_rate", (int, float)),
        ("gate_retries_total", int),
        ("stages", dict),
    ]

    for key, expected_type in required_keys:
        if key not in data:
            violations.append(f"json:metrics missing required key '{key}'")
        else:
            val = data[key]
            if not isinstance(val, expected_type):
                violations.append(f"json:metrics key '{key}' expected {expected_type}, got {type(val).__name__}")
            elif is_strict and isinstance(val, str) and is_placeholder(val):
                violations.append(f"json:metrics key '{key}' contains placeholder value '{val}'")

    if "first_pass_command_rate" in data:
        rate = data["first_pass_command_rate"]
        if isinstance(rate, (int, float)) and not (0.0 <= rate <= 100.0):
            violations.append(f"first_pass_command_rate must be between 0 and 100, got {rate}")

    return len(violations) == 0, violations

def format_duration(seconds):
    seconds = int(seconds)
    mins = seconds // 60
    secs = seconds % 60
    if mins > 0:
        return f"{mins}m {secs:02d}s"
    return f"{secs}s"

def run_validate():
    target_path = Path(target_file_str)
    valid, violations = validate_summary_file(target_path, is_strict=strict)
    if not valid:
        print("======================================================", file=sys.stderr)
        print("  Summary Observability Metrics Validation FAILED", file=sys.stderr)
        print("======================================================", file=sys.stderr)
        print(f"  File: {target_path}", file=sys.stderr)
        for v in violations:
            print(f"  FAIL: {v}", file=sys.stderr)
        sys.exit(2)

    print("======================================================")
    print("  Summary Observability Metrics Validation PASSED")
    print("======================================================")
    print(f"  File: {target_path}")
    print("  All required execution metrics are present and well-formed.")
    sys.exit(0)

def run_report():
    scan_roots = []
    if summary_dir_str:
        scan_roots.append(Path(summary_dir_str))
    else:
        for sub in ["docs/product", "docs/changes", "docs/current"]:
            d = project_root / sub
            if d.is_dir():
                scan_roots.append(d)

    summary_files = []
    for root in scan_roots:
        for p in root.rglob("summary*.md"):
            if p.is_file():
                summary_files.append(p)

    records = []
    skipped_count = 0

    for p in summary_files:
        is_valid, _ = validate_summary_file(p, is_strict=True)
        if is_valid:
            data, _ = extract_metrics_block(p.read_text(encoding="utf-8"))
            data["_file"] = str(p.relative_to(project_root) if p.is_relative_to(project_root) else p)
            records.append(data)
        else:
            skipped_count += 1

    print("======================================================")
    print("  Harness Execution Observability & Performance Report")
    print("======================================================")
    print(f"  Scanned summary files: {len(summary_files)}")
    print(f"  Tracked summaries with metrics: {len(records)} (legacy/untracked: {skipped_count})\n")

    if not records:
        print("  No metrics recorded yet in scanned summary files.")
        print("  To add metrics, update summary files using 'summary-observability-template.md'.")
        print("======================================================")
        sys.exit(0)

    total_duration = sum(r.get("total_duration_sec", 0) for r in records)
    total_commands = sum(r.get("commands_executed", 0) for r in records)
    total_retries = sum(r.get("gate_retries_total", 0) for r in records)
    total_read = sum(r.get("files_read_count", 0) for r in records)
    total_mod = sum(r.get("files_modified_count", 0) for r in records)

    avg_duration = total_duration / len(records)
    avg_first_pass = sum(r.get("first_pass_command_rate", 100.0) for r in records) / len(records)

    print("  GLOBAL HIGHLIGHTS:")
    print(f"    Total Delivered Slices:    {len(records)}")
    print(f"    Total Wall-Clock Time:     {format_duration(total_duration)}")
    print(f"    Avg Duration per Slice:    {format_duration(avg_duration)}")
    print(f"    Avg First-Pass Rate:       {avg_first_pass:.1f}%")
    print(f"    Total Commands Executed:   {total_commands}")
    print(f"    Total Gate Retries:        {total_retries}")
    print(f"    Avg Files Read/Modified:   {total_read / len(records):.1f} / {total_mod / len(records):.1f}\n")

    # Model Breakdown
    models = {}
    for r in records:
        m = r.get("model", "Unknown")
        if m not in models:
            models[m] = {"count": 0, "duration": 0, "first_pass_sum": 0.0}
        models[m]["count"] += 1
        models[m]["duration"] += r.get("total_duration_sec", 0)
        models[m]["first_pass_sum"] += r.get("first_pass_command_rate", 100.0)

    print("  MODEL PERFORMANCE BREAKDOWN:")
    print(f"    {'Model':<25} {'Tasks':<8} {'Avg Duration':<15} {'First-Pass Rate':<15}")
    print(f"    {'-'*25} {'-'*8} {'-'*15} {'-'*15}")
    for m, stat in sorted(models.items(), key=lambda x: x[1]["count"], reverse=True):
        m_avg_dur = format_duration(stat["duration"] / stat["count"])
        m_avg_fp = stat["first_pass_sum"] / stat["count"]
        print(f"    {m:<25} {stat['count']:<8} {m_avg_dur:<15} {m_avg_fp:.1f}%")
    print()

    # Stage Averages
    stage_durations = {}
    stage_counts = {}
    for r in records:
        stages = r.get("stages", {})
        for s_name, s_data in stages.items():
            if isinstance(s_data, dict):
                dur = s_data.get("duration_sec", 0)
                stage_durations[s_name] = stage_durations.get(s_name, 0) + dur
                stage_counts[s_name] = stage_counts.get(s_name, 0) + 1

    if stage_durations:
        print("  AVERAGE STAGE DURATIONS:")
        print(f"    {'Stage':<20} {'Avg Duration':<15}")
        print(f"    {'-'*20} {'-'*15}")
        for s_name, total_dur in stage_durations.items():
            cnt = stage_counts[s_name]
            print(f"    {s_name:<20} {format_duration(total_dur / cnt):<15}")
        print()

    # Top Failure Causes
    all_causes = {}
    for r in records:
        for cause in r.get("gate_failure_causes", []):
            all_causes[cause] = all_causes.get(cause, 0) + 1

    if all_causes:
        print("  TOP GATE RETRY CAUSES:")
        for cause, freq in sorted(all_causes.items(), key=lambda x: x[1], reverse=True):
            print(f"    - {cause:<25} ({freq} occurrences)")
    else:
        print("  TOP GATE RETRY CAUSES: None (100% clean passes)")

    print("======================================================")
    sys.exit(0)

if mode == "validate":
    run_validate()
elif mode == "report":
    run_report()
else:
    print(f"FAIL: Unknown mode '{mode}'", file=sys.stderr)
    sys.exit(2)
PYTHON_SCRIPT
