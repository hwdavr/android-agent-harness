#!/usr/bin/env python3
"""Validate one-to-one UI state design and plan mappings."""

import argparse
import json
import re
import sys
from pathlib import Path


STATE_COLUMNS = [
    "Screen", "State ID", "Design source", "Design node ID", "Design image",
    "Runtime fixture", "Comparison", "Content difference", "Plan stage",
]
SPEC_COLUMNS = ["Screen", "State ID", "Requirement", "Acceptance Criteria"]
PLAN_COLUMNS = ["Stage ID", "Implementation", "Verification"]


def fail(message):
    raise ValueError(message)


def clean(value):
    return value.strip().strip("`").strip()


def table(path, heading, columns):
    if not path.is_file():
        fail(f"missing {path}")
    lines = path.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index(f"## {heading}") + 1
    except ValueError:
        fail(f"{path} is missing ## {heading}")
    rows = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = [clean(cell) for cell in line[1:-1].split("|")]
        if all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        rows.append(cells)
    if not rows or rows[0] != columns:
        fail(f"{path} ## {heading} needs columns: {', '.join(columns)}")
    if len(rows) < 2:
        fail(f"{path} ## {heading} has no state rows")
    for row in rows[1:]:
        if len(row) != len(columns) or any(not cell or "<" in cell or ">" in cell for cell in row):
            fail(f"{path} ## {heading} has an incomplete or placeholder row")
    return [dict(zip(columns, row)) for row in rows[1:]]


def existing_path(contract, value):
    if Path(value).is_absolute() or (".." in Path(value).parts and not value.startswith("../UI_design/")):
        fail(f"unsafe design path: {value}")
    candidates = [contract.parent / value, Path.cwd() / value]
    return next((path for path in candidates if path.is_file() and path.stat().st_size > 0), None)


def validate(contract, spec, plan, report):
    rows = table(contract, "Screen States", STATE_COLUMNS)
    states = set()
    nodes = set()
    images = set()
    fixtures = set()
    stages = set()
    for row in rows:
        key = (row["Screen"], row["State ID"])
        if key in states:
            fail(f"duplicate screen/state: {key[0]} / {key[1]}")
        states.add(key)
        source = row["Design source"]
        node = row["Design node ID"]
        if not existing_path(contract, source):
            fail(f"missing or empty design source: {source}")
        if source.endswith(".pen") and node.lower() == "external":
            fail(f"Pen state {key[1]} needs a Pen node ID")
        if not source.endswith(".pen") and node.lower() != "external":
            fail(f"external design state {key[1]} must use node ID external")
        node_key = (source, node)
        if node_key in nodes:
            fail(f"design node reused across states: {source} / {node}")
        nodes.add(node_key)
        image = row["Design image"]
        if not image.startswith("design/") or not image.endswith(".png") or not existing_path(contract, image):
            fail(f"missing or empty design PNG: {image}")
        if image in images:
            fail(f"design image reused across states: {image}")
        images.add(image)
        fixture = row["Runtime fixture"]
        if fixture in fixtures:
            fail(f"runtime fixture reused across states: {fixture}")
        fixtures.add(fixture)
        if row["Comparison"] not in ("exact", "structural"):
            fail(f"invalid comparison for {key[1]}: {row['Comparison']}")
        difference = row["Content difference"]
        if row["Comparison"] == "structural" and (difference.lower() in ("none", "n/a") or len(difference) < 12):
            fail(f"structural state {key[1]} needs a concrete content difference")
        if row["Comparison"] == "exact" and difference.lower() not in ("none", "n/a"):
            fail(f"exact state {key[1]} cannot declare differing visible content")
        stage = row["Plan stage"]
        if not re.fullmatch(r"UI-[0-9]+", stage) or stage in stages:
            fail(f"invalid or duplicate plan stage: {stage}")
        stages.add(stage)

    if spec:
        spec_rows = table(spec, "Screen States", SPEC_COLUMNS)
        spec_states = {(row["Screen"], row["State ID"]) for row in spec_rows}
        if len(spec_states) != len(spec_rows) or states != spec_states:
            fail(f"UI contract states differ from spec: missing {sorted(spec_states - states)}, extra {sorted(states - spec_states)}")
    if plan:
        plan_rows = table(plan, "UI State Stages", PLAN_COLUMNS)
        plan_stages = {row["Stage ID"] for row in plan_rows}
        if len(plan_stages) != len(plan_rows) or stages != plan_stages:
            fail(f"UI plan stages differ from contract: missing {sorted(stages - plan_stages)}, extra {sorted(plan_stages - stages)}")
    if report:
        if not report.is_file():
            fail(f"missing {report}")
        data = json.loads(report.read_text(encoding="utf-8"))
        results = data.get("state_results", [])
        if not isinstance(results, list) or any(not isinstance(item, dict) for item in results):
            fail("state_results must be an array of objects")
        result_keys = {(item.get("screen"), item.get("state_id")) for item in results if isinstance(item, dict)}
        if len(result_keys) != len(results) or result_keys != states:
            fail(f"UI verification states differ from contract: missing {states - result_keys}, extra {result_keys - states}")
        evidence_path = report.parent / data.get("runtime_evidence", "")
        if not evidence_path.is_file():
            fail(f"missing runtime evidence: {evidence_path}")
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        runtime_screens = {item.get("name"): item.get("screenshot") for item in evidence.get("screens", [])}
        used_runtime = set()
        by_key = {(row["Screen"], row["State ID"]): row for row in rows}
        for item in results:
            key = (item["screen"], item["state_id"])
            row = by_key[key]
            if item.get("design_image") != row["Design image"] or item.get("comparison") != row["Comparison"]:
                fail(f"UI verification reference or comparison differs for {key[0]} / {key[1]}")
            runtime = item.get("runtime_screen")
            if not runtime or runtime not in runtime_screens or runtime in used_runtime:
                fail(f"UI state {key[1]} needs a unique runtime evidence screen")
            used_runtime.add(runtime)
            if item.get("result") != "PASS" or len(item.get("assertion", "")) < 12:
                fail(f"UI state {key[1]} needs a passing concrete assertion")
            parity = "verified" if row["Comparison"] == "exact" else "not-claimed"
            if item.get("pixel_parity") != parity:
                fail(f"UI state {key[1]} needs pixel_parity: {parity}")
    print(f"PASS: {len(states)} UI state(s) have unique design, fixture, comparison, and plan mappings.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("contract", type=Path)
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        validate(args.contract, args.spec, args.plan, args.report)
    except (ValueError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
