#!/usr/bin/env python3
"""Validate one-to-one UI state design and plan mappings."""

import argparse
import json
import re
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from kotlin_ast_checker import KotlinFile


STATE_COLUMNS = [
    "Screen", "State ID", "Design source", "Design node ID", "Design node role",
    "Design image", "Viewport", "Required regions", "State controls", "Runtime fixture",
    "Comparison", "Content difference", "Plan stage",
]
SPEC_COLUMNS = ["Screen", "State ID", "Requirement", "Acceptance Criteria"]
PLAN_COLUMNS = ["Stage ID", "Implementation", "Roborazzi target", "Verification"]
IME_COLUMNS = [
    "Screen", "Input tag", "Window viewport", "Keyboard closed state", "Keyboard open state",
    "Dismissed state", "Layout policy", "Required visible tags",
]
IME_BOUNDARY_COLUMNS = [
    "Screen", "Input tag", "Production activity", "Open test", "Dismiss test", "Command", "Result XML",
]
EDITABLE_INPUT = re.compile(
    r"\b(?:search(?![ -]*(?:results|history|button|icon)\b)|(?:basic)?textfield|"
    r"text[ -]*(?:box|field|input)|input[ -]*field|editable)\b", re.I,
)
INSTRUMENTED_TARGET = re.compile(r"app/src/androidTest/[A-Za-z0-9_./]+Test\.kt#[A-Za-z_][A-Za-z0-9_]*$")
ROBORAZZI_TARGET = re.compile(
    r"app/src/test/java/[A-Za-z0-9_./]+/roborazzi/[A-Za-z0-9_./]+RoborazziTest\.kt#[A-Za-z_][A-Za-z0-9_]*$"
)


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
    parts = Path(value).parts
    sibling_pen = len(parts) == 3 and parts[0] == ".." and parts[1] == "UI_design" and parts[2].endswith(".pen")
    if Path(value).is_absolute() or (".." in parts and not sibling_pen):
        fail(f"unsafe design path: {value}")
    candidates = [contract.parent / value, Path.cwd() / value]
    return next((path for path in candidates if path.is_file() and path.stat().st_size > 0), None)


def png_dimensions(path):
    with path.open("rb") as image:
        header = image.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        fail(f"design image is not a valid PNG: {path}")
    return struct.unpack(">II", header[16:24])


def viewport(value, state_id):
    match = re.fullmatch(r"([1-9][0-9]{1,4})\s*[x×]\s*([1-9][0-9]{1,4})", value)
    if not match:
        fail(f"state {state_id} needs a viewport in WIDTHxHEIGHT form")
    width, height = (int(part) for part in match.groups())
    if min(width, height) < 240 or width * height < 76800:
        fail(f"state {state_id} viewport is too small for a complete screen: {value}")
    return width, height


def complete_regions(value, state_id):
    regions = {region.strip().lower() for region in value.split(";") if region.strip()}
    required = {"primary-content", "state-controls", "persistent-controls"}
    missing = sorted(required - regions)
    if missing:
        fail(f"state {state_id} is missing required visible regions: {', '.join(missing)}")


def ime_states(contract, rows):
    input_screens = {
        row["Screen"] for row in rows
        if EDITABLE_INPUT.search(row["State controls"])
        and not re.search(r"\bread[ -]*only\b|\bno text input\b", row["State controls"], re.I)
    }
    has_inventory = "## IME State Coverage" in contract.read_text(encoding="utf-8").splitlines()
    if not has_inventory:
        if input_screens:
            fail("editable text input requires ## IME State Coverage with closed, open, and dismissed designs")
        return []
    inventory = table(contract, "IME State Coverage", IME_COLUMNS)
    by_state = {(row["Screen"], row["State ID"]): row for row in rows}
    seen = set()
    for item in inventory:
        key = (item["Screen"], item["Input tag"])
        if key in seen:
            fail(f"duplicate IME input: {key}")
        seen.add(key)
        dimensions = viewport(item["Window viewport"], item["Input tag"])
        for label, column in (("keyboard-closed", "Keyboard closed state"),
                              ("keyboard-open", "Keyboard open state"), ("dismissed", "Dismissed state")):
            state = by_state.get((item["Screen"], item[column]))
            if state is None:
                fail(f"unknown {label} state: {item[column]}")
            if viewport(state["Viewport"], state["State ID"]) != dimensions:
                fail(f"IME {label} design must use the full window viewport {item['Window viewport']}")
            has_ime = "system-ime" in {region.strip() for region in state["Required regions"].split(";")}
            if label == "keyboard-open" and not has_ime:
                fail(f"keyboard-open design {item[column]} must include system-ime")
            if label != "keyboard-open" and has_ime:
                fail(f"IME {label} design must not include system-ime")
        if item["Keyboard open state"] in (item["Keyboard closed state"], item["Dismissed state"]):
            fail("keyboard-open design must be distinct from the closed and dismissed states")
        if item["Layout policy"] not in {"resize", "pan", "overlay"}:
            fail("IME Layout policy must be resize, pan, or overlay")
        visible = {tag.strip() for tag in item["Required visible tags"].split(";")}
        if item["Input tag"] not in visible:
            fail("IME Required visible tags must include the focused Input tag")
    missing = input_screens - {item["Screen"] for item in inventory}
    if missing:
        fail(f"editable screens missing IME coverage: {sorted(missing)}")
    return inventory


def ime_runtime(inventory, test_plan, runtime, project_root):
    if not inventory or test_plan is None:
        if runtime and inventory:
            fail("IME runtime validation requires --test-plan")
        return
    boundary = table(test_plan, "IME Production Boundary", IME_BOUNDARY_COLUMNS)
    expected = {(item["Screen"], item["Input tag"]) for item in inventory}
    actual = {(item["Screen"], item["Input tag"]) for item in boundary}
    if len(actual) != len(boundary) or expected != actual:
        fail("IME Production Boundary must cover every declared input exactly once")
    for item in boundary:
        for column in ("Open test", "Dismiss test"):
            target = item[column]
            if not INSTRUMENTED_TARGET.fullmatch(target) or ".." in Path(target.split("#")[0]).parts:
                fail(f"IME {column} requires an instrumented Test.kt#method target")
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.]*", item["Production activity"]):
            fail("IME Production activity must name the shipped Activity")
        command = item["Command"]
        if "connected" not in command or "AndroidTest" not in command or "android.testInstrumentationRunnerArguments.class=" not in command:
            fail("IME Command must select the instrumented boundary class")
        result_ref = Path(item["Result XML"])
        if result_ref.is_absolute() or ".." in result_ref.parts:
            fail("IME Result XML must stay under the project or artifact directory")
        if not runtime:
            continue
        for transition, column in (("open", "Open test"), ("dismiss", "Dismiss test")):
            file, method = item[column].split("#")
            check = subprocess.run([
                sys.executable, str(Path(__file__).with_name("kotlin_ast_checker.py")), "ime-boundary",
                "--project-root", str(project_root), "--test-file", file, "--test-method", method,
                "--production-entry", item["Production activity"], "--transition", transition,
            ], capture_output=True, text=True)
            if check.returncode:
                fail(check.stdout + check.stderr)
        result_path = next((path for path in (test_plan.parent / result_ref, project_root / result_ref) if path.is_file()), None)
        if result_path is None:
            fail(f"missing IME result XML: {result_ref}; runtime is Blocked")
        try:
            result = ET.parse(result_path).getroot()
        except ET.ParseError as error:
            fail(f"invalid IME result XML: {error}")
        for column in ("Open test", "Dismiss test"):
            file, method = item[column].split("#")
            class_name = Path(file).stem
            package = KotlinFile(project_root / file).package_name
            qualified_class = f"{package}.{class_name}" if package else class_name
            selector = re.search(r"android\.testInstrumentationRunnerArguments\.class=([^\s]+)", command)
            selections = selector.group(1).strip("\"'").split(",") if selector else []
            if qualified_class not in selections and f"{qualified_class}#{method}" not in selections:
                fail(f"IME Command does not select {qualified_class}#{method}")
            cases = [case for case in result.iter("testcase")
                     if case.get("name", "").split("[")[0] == method
                     and case.get("classname", "") == qualified_class]
            if not cases or any(any(case.find(tag) is not None for tag in ("failure", "error", "skipped")) for case in cases):
                fail(f"IME runtime {class_name}#{method} did not pass with a non-zero executed count")


def validate(contract, spec, plan, report, test_plan=None, runtime=False, project_root=None):
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
        role = row["Design node role"]
        if not existing_path(contract, source):
            fail(f"missing or empty design source: {source}")
        if source.endswith(".pen"):
            if node.lower() == "external" or role != "screen-frame":
                fail(f"Pen state {key[1]} needs a top-level screen-frame node")
        elif node.lower() != "external" or role != "external-screen":
            fail(f"external design state {key[1]} must use node ID external and role external-screen")
        node_key = (source, node)
        if node_key in nodes:
            fail(f"design node reused across states: {source} / {node}")
        nodes.add(node_key)
        image = row["Design image"]
        image_path = existing_path(contract, image)
        if not image.startswith("design/") or not image.endswith(".png") or not image_path:
            fail(f"missing or empty design PNG: {image}")
        viewport_width, viewport_height = viewport(row["Viewport"], key[1])
        image_width, image_height = png_dimensions(image_path)
        expected_ratio = viewport_width / viewport_height
        actual_ratio = image_width / image_height
        if abs(actual_ratio - expected_ratio) / expected_ratio > 0.015:
            fail(
                f"state {key[1]} design PNG aspect ratio {image_width}x{image_height} "
                f"does not match viewport {viewport_width}x{viewport_height}"
            )
        complete_regions(row["Required regions"], key[1])
        controls = row["State controls"].strip().lower()
        if controls in ("none", "n/a") or len(controls) < 8:
            fail(f"state {key[1]} needs named state-specific controls")
        if image in images:
            fail(f"design image reused across states: {image}")
        images.add(image)
        fixture = row["Runtime fixture"]
        if fixture in fixtures:
            fail(f"runtime fixture reused across states: {fixture}")
        fixtures.add(fixture)
        if row["Comparison"] not in ("exact", "structural", "roborazzi"):
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

    inventory = ime_states(contract, rows)
    ime_runtime(inventory, test_plan, runtime, (project_root or Path.cwd()).resolve())
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
        states_by_stage = {row["Plan stage"]: row for row in rows}
        roborazzi_targets = set()
        for plan_row in plan_rows:
            stage = plan_row["Stage ID"]
            target = plan_row["Roborazzi target"]
            if not ROBORAZZI_TARGET.fullmatch(target):
                fail(f"UI state {stage} needs a valid Roborazzi target under app/src/test/java/**/roborazzi/ ending in RoborazziTest.kt#method")
            if target in roborazzi_targets:
                fail(f"Roborazzi target reused across UI plan stages: {target}")
            roborazzi_targets.add(target)
            verification = plan_row["Verification"]
            if "./gradlew app:verifyRoborazziDebug" not in verification:
                fail(f"UI state {stage} needs a method-scoped verifyRoborazziDebug command")
            design_image = states_by_stage[stage]["Design image"]
            if design_image not in verification:
                fail(f"UI state {stage} verification must cite its approved design image: {design_image}")
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
        evidence_ref = data.get("runtime_evidence", "")
        if not isinstance(evidence_ref, str) or not evidence_ref.startswith("evidence/") or ".." in Path(evidence_ref).parts:
            fail("runtime evidence path must stay under evidence/")
        evidence_path = report.parent / evidence_ref
        if not evidence_path.is_file():
            fail(f"missing runtime evidence: {evidence_path}")
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        is_roborazzi = evidence.get("producer", {}).get("kind") == "RoborazziTest"
        runtime_screens = {
            item.get("name"): item.get("reference")
            for item in evidence.get("states", [])
        } if is_roborazzi else {
            item.get("name"): item.get("screenshot")
            for item in evidence.get("screens", [])
        }
        used_runtime = set()
        by_key = {(row["Screen"], row["State ID"]): row for row in rows}
        for item in results:
            key = (item["screen"], item["state_id"])
            row = by_key[key]
            expected_comparison = "roborazzi" if is_roborazzi else row["Comparison"]
            if item.get("design_image") != row["Design image"] or item.get("comparison") != expected_comparison:
                fail(f"UI verification reference or comparison differs for {key[0]} / {key[1]}")
            runtime = item.get("runtime_screen")
            if not runtime or runtime not in runtime_screens or runtime in used_runtime:
                fail(f"UI state {key[1]} needs a unique runtime evidence screen")
            used_runtime.add(runtime)
            if item.get("result") != "PASS" or len(item.get("assertion", "")) < 12:
                fail(f"UI state {key[1]} needs a passing concrete assertion")
            parity = "verified" if is_roborazzi or row["Comparison"] == "exact" else "not-claimed"
            if item.get("pixel_parity") != parity:
                fail(f"UI state {key[1]} needs pixel_parity: {parity}")
    print(f"PASS: {len(states)} complete UI state(s) have unique screen-frame, viewport, coverage, fixture, comparison, and plan mappings.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("contract", type=Path)
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--test-plan", type=Path)
    parser.add_argument("--runtime", action="store_true")
    parser.add_argument("--project-root", type=Path)
    args = parser.parse_args()
    try:
        validate(args.contract, args.spec, args.plan, args.report, args.test_plan, args.runtime, args.project_root)
    except (ValueError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
