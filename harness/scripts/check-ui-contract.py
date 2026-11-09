#!/usr/bin/env python3
"""Validate the per-state UI contract and its plan, test-plan, and conformance-review mappings.

Visual appearance is approved by a conformance review: each state is rendered at its contract
viewport (the Pen frame's dp size and density), shown beside the approved design, and approved by
the user, plus a structural check on the semantics tree. No screenshot golden is compared.
Every state names the registered design-system components it reuses.
"""

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
    "Design image", "Viewport", "Required regions", "State controls", "Reused components",
    "Runtime fixture", "Plan stage",
]
DESIGN_COLUMNS = ["Design source", "Design node ID", "Design node role", "Design image"]
SPEC_COLUMNS = ["Screen", "State ID", "Requirement", "Acceptance Criteria"]
PLAN_COLUMNS = ["Stage ID", "Reused registered components", "Implementation"]
VERIFY_COLUMNS = ["Stage ID", "Review capture (test#method)", "Structural check (test#method)", "Command"]
REGISTRY_COLUMNS = ["Component", "Pen component", "Composable", "Required testTag", "Wraps Material"]
IME_COLUMNS = [
    "Screen", "Input tag", "Window viewport", "Keyboard closed state", "Keyboard open state",
    "Dismissed state", "Layout policy", "Keyboard behavior", "Required visible tags",
]
IME_BOUNDARY_COLUMNS = [
    "Screen", "Input tag", "Production activity", "Open test", "Dismiss test", "Command", "Result XML",
]
EDITABLE_INPUT = re.compile(
    r"\b(?:search(?![ -]*(?:results|history|button|icon)\b)|(?:basic)?textfield|"
    r"text[ -]*(?:box|field|input)|input[ -]*field|editable)\b", re.I,
)
INSTRUMENTED_TARGET = re.compile(r"app/src/androidTest/[A-Za-z0-9_./]+Test\.kt#[A-Za-z_][A-Za-z0-9_]*$")
JVM_TARGET = re.compile(r"app/src/test/java/[A-Za-z0-9_./]+Test\.kt#[A-Za-z_][A-Za-z0-9_]*$")
REVIEW_TARGET = re.compile(
    r"app/src/test/java/[A-Za-z0-9_./]+/review/[A-Za-z0-9_]+ReviewCaptureTest\.kt#[A-Za-z_][A-Za-z0-9_]*$"
)
NONE_WITH_REASON = re.compile(r"^None — \S.{4,}$")


def fail(message):
    raise ValueError(message)


def clean(value):
    return value.strip().strip("`").strip()


def heading_index(lines, heading):
    """Index of the level-2/3 heading line titled `heading` (a trailing note is allowed)."""
    pattern = re.compile(rf"^(#{{2,3}}) {re.escape(heading)}(\s|$)")
    for index, line in enumerate(lines):
        if pattern.match(line):
            return index
    return None


def table(path, heading, columns):
    if not path.is_file():
        fail(f"missing {path}")
    lines = path.read_text(encoding="utf-8").splitlines()
    start = heading_index(lines, heading)
    if start is None:
        fail(f"{path} is missing ## {heading}")
    level = len(lines[start].split(" ", 1)[0])
    rows = []
    for line in lines[start + 1:]:
        if re.match(rf"^#{{1,{level}}} ", line):
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


def component_names(value):
    """Registered component names in a cell, or an empty set for `None — <reason>`."""
    value = value.strip()
    if NONE_WITH_REASON.match(value):
        return set()
    names = {clean(part) for part in re.split(r"[,;]", value) if clean(part)}
    if not names:
        fail(f"reused components cell is empty: '{value}'")
    return names


def registry(design_system):
    rows = table(design_system, "Component Registry", REGISTRY_COLUMNS)
    names = set()
    for row in rows:
        names.add(row["Component"])
        names.add(row["Composable"].split("/")[-1].split("#")[-1].removesuffix(".kt"))
    return names


# Native design-tool sources (UX/design-tool.json): pen.dev `.pen`, OpenPencil `.fig`.
DESIGN_SOURCE_SUFFIXES = (".pen", ".fig")


def existing_path(contract, value):
    parts = Path(value).parts
    sibling_source = (len(parts) == 3 and parts[0] == ".." and parts[1] == "UI_design"
                      and parts[2].endswith(DESIGN_SOURCE_SUFFIXES))
    if Path(value).is_absolute() or (".." in parts and not sibling_source):
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
    has_inventory = heading_index(contract.read_text(encoding="utf-8").splitlines(), "IME State Coverage") is not None
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
        behavior = item["Keyboard behavior"]
        if behavior not in {"screen-no-toolbar", "screen-toolbar-dismissed", "sheet-stays-open"}:
            fail("IME Keyboard behavior must be screen-no-toolbar, screen-toolbar-dismissed, or sheet-stays-open")
        input_states = {item[column] for column in ("Keyboard closed state", "Keyboard open state", "Dismissed state")}
        controls = " ".join(row["State controls"] for row in rows
                            if row["Screen"] == item["Screen"] and row["State ID"] in input_states)
        if re.search(r"bottom[ -]*sheet", controls, re.I) and behavior != "sheet-stays-open":
            fail("bottom-sheet input must declare sheet-stays-open")
        if not re.search(r"bottom[ -]*sheet", controls, re.I) and re.search(r"bottom[ -]*(?:tool)?bar", controls, re.I) and behavior != "screen-toolbar-dismissed":
            fail("screen input with a bottom toolbar must declare screen-toolbar-dismissed")
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
        if "harness/scripts/run-android-instrumented-tests.sh" not in command or "--class" not in command:
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
            selections = [value.rstrip("`.,;") for value in re.findall(r"--class\s+([^\s]+)", command)]
            if f"{qualified_class}#{method}" not in selections:
                fail(f"IME Command does not select {qualified_class}#{method}")
            cases = [case for case in result.iter("testcase")
                     if case.get("name", "").split("[")[0] == method
                     and case.get("classname", "") == qualified_class]
            if not cases or any(any(case.find(tag) is not None for tag in ("failure", "error", "skipped")) for case in cases):
                fail(f"IME runtime {class_name}#{method} did not pass with a non-zero executed count")


def validate(contract, spec, plan, report, test_plan=None, runtime=False, project_root=None,
             inventory_only=False, design_system=None):
    if inventory_only and (plan or report or runtime):
        fail("--inventory cannot validate planning or runtime evidence")
    project_root = (project_root or Path.cwd()).resolve()
    rows = table(contract, "Screen States", STATE_COLUMNS)
    known_components = registry(design_system) if design_system else None
    states, nodes, images, fixtures, stages = set(), set(), set(), set(), set()
    reused_by_stage = {}
    for row in rows:
        key = (row["Screen"], row["State ID"])
        if key in states:
            fail(f"duplicate screen/state: {key[0]} / {key[1]}")
        states.add(key)
        deferrable = DESIGN_COLUMNS + ["Screen", "State ID"] + (["Reused components"] if inventory_only else [])
        unresolved = [column for column in STATE_COLUMNS
                      if column not in deferrable and row[column].lower() in {"pending", "tbd", "todo"}]
        if unresolved:
            fail(f"state {key[1]} has unresolved state inventory: {', '.join(unresolved)}")
        viewport_width, viewport_height = viewport(row["Viewport"], key[1])
        pending = [row[column] == "Pending" for column in DESIGN_COLUMNS]
        if any(pending) and not all(pending):
            fail(f"state {key[1]} must complete all design reference fields or mark all four Pending")
        if all(pending) and not inventory_only:
            fail(f"state {key[1]} has pending design references; complete the design before UX approval or planning")
        source, node, role = row["Design source"], row["Design node ID"], row["Design node role"]
        if not all(pending) and not existing_path(contract, source):
            fail(f"missing or empty design source: {source}")
        if not all(pending) and source.endswith(DESIGN_SOURCE_SUFFIXES):
            if node.lower() == "external" or role != "screen-frame":
                fail(f"design-tool state {key[1]} needs a top-level screen-frame node")
        elif not all(pending) and (node.lower() != "external" or role != "external-screen"):
            fail(f"external design state {key[1]} must use node ID external and role external-screen")
        if not all(pending):
            if (source, node) in nodes:
                fail(f"design node reused across states: {source} / {node}")
            nodes.add((source, node))
            image = row["Design image"]
            image_path = existing_path(contract, image)
            if not image.startswith("design/") or not image.endswith(".png") or not image_path:
                fail(f"missing or empty design PNG: {image}")
            image_width, image_height = png_dimensions(image_path)
            expected_ratio = viewport_width / viewport_height
            if abs(image_width / image_height - expected_ratio) / expected_ratio > 0.015:
                fail(f"state {key[1]} design PNG aspect ratio {image_width}x{image_height} "
                     f"does not match viewport {viewport_width}x{viewport_height}")
            if image in images:
                fail(f"design image reused across states: {image}")
            images.add(image)
        complete_regions(row["Required regions"], key[1])
        controls = row["State controls"].strip().lower()
        if controls in ("none", "n/a") or len(controls) < 8:
            fail(f"state {key[1]} needs named state-specific controls")
        if row["Reused components"] != "Pending":
            reused = component_names(row["Reused components"])
            if known_components is not None:
                unknown = sorted(reused - known_components)
                if unknown:
                    fail(f"state {key[1]} reuses unregistered components {unknown}; add them to the "
                         f"design-system Component Registry with approval, or record `None — <reason>`")
            reused_by_stage[row["Plan stage"]] = reused
        fixture = row["Runtime fixture"]
        if fixture in fixtures:
            fail(f"runtime fixture reused across states: {fixture}")
        fixtures.add(fixture)
        stage = row["Plan stage"]
        if not re.fullmatch(r"UI-[0-9]+", stage) or stage in stages:
            fail(f"invalid or duplicate plan stage: {stage}")
        stages.add(stage)

    inventory = ime_states(contract, rows)
    ime_runtime(inventory, test_plan, runtime, project_root)
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
        for plan_row in plan_rows:
            stage = plan_row["Stage ID"]
            if component_names(plan_row["Reused registered components"]) != reused_by_stage.get(stage, set()):
                fail(f"UI plan stage {stage} reused components differ from UI_contract.md")
    verification = {}
    if plan and test_plan:
        verification = verification_targets(test_plan, stages)
    if plan and runtime:
        validate_component_usage(plan, reused_by_stage, project_root)
    if report:
        if not test_plan:
            fail("conformance review validation requires --test-plan")
        verification = verification or verification_targets(test_plan, stages)
        validate_report(report, rows, verification, runtime, project_root)
    if inventory_only:
        print(f"PASS: {len(states)} UI state(s) defined before Pen design; only design references may be Pending.")
    else:
        print(f"PASS: {len(states)} complete UI state(s) have unique screen-frame, viewport, regions, "
              f"registered components, fixture, and plan mappings.")


def validate_component_usage(plan, reused_by_stage, project_root):
    """Each reused registered component is called from a UI-layer file the plan changes."""
    lines = plan.read_text(encoding="utf-8").splitlines()
    start = heading_index(lines, "Project Structure")
    ui_files = []
    if start is not None:
        for line in lines[start + 1:]:
            if re.match(r"^#{1,3} ", line):
                break
            cells = [clean(cell) for cell in line.strip().strip("|").split("|")] if line.startswith("|") else []
            if len(cells) >= 2 and cells[0] == "UI":
                ui_files += [clean(part) for part in cells[1].split(",") if clean(part)]
    sources = ""
    for name in ui_files:
        candidates = [project_root / name] + list((project_root / "app" / "src" / "main").rglob(Path(name).name))
        path = next((c for c in candidates if c.is_file()), None)
        if path is None:
            fail(f"UI file named in the plan's Project Structure does not exist: {name}")
        sources += path.read_text(encoding="utf-8")
    for stage, components in sorted(reused_by_stage.items()):
        for component in sorted(components):
            if not re.search(rf"\b{re.escape(component)}\s*\(", sources):
                fail(f"UI state {stage} lists {component}, but no UI file in the plan's Project Structure calls it")


def verification_targets(test_plan, stages):
    rows = table(test_plan, "UI State Verification", VERIFY_COLUMNS)
    found = {row["Stage ID"] for row in rows}
    if len(found) != len(rows) or found != stages:
        fail(f"test-plan UI State Verification differs from contract: missing {sorted(stages - found)}, extra {sorted(found - stages)}")
    seen, targets = set(), {}
    for row in rows:
        stage = row["Stage ID"]
        review, structural, command = (row["Review capture (test#method)"], row["Structural check (test#method)"],
                                       row["Command"])
        if not REVIEW_TARGET.fullmatch(review):
            fail(f"UI state {stage} review capture must be app/src/test/java/<package>/review/<Feature>ReviewCaptureTest.kt#<method>")
        if not (JVM_TARGET.fullmatch(structural) or INSTRUMENTED_TARGET.fullmatch(structural)):
            fail(f"UI state {stage} structural check must be a JVM or instrumented Test.kt#method target")
        for target in (review, structural):
            if target in seen:
                fail(f"verification target reused across UI states: {target}")
            seen.add(target)
            test_class = Path(target.split("#")[0]).stem
            if test_class not in command:
                fail(f"UI state {stage} command must run {test_class}")
        if INSTRUMENTED_TARGET.fullmatch(structural) and "harness/scripts/run-android-instrumented-tests.sh" not in command:
            fail(f"UI state {stage} needs the direct AndroidJUnitRunner wrapper for its instrumented structural check")
        targets[stage] = {"review": review, "structural": structural}
    return targets


def validate_report(report, rows, targets, runtime, project_root):
    if not report.is_file():
        fail(f"missing {report}")
    data = json.loads(report.read_text(encoding="utf-8"))
    results = data.get("state_results", [])
    if not isinstance(results, list) or any(not isinstance(item, dict) for item in results):
        fail("state_results must be an array of objects")
    by_key = {(row["Screen"], row["State ID"]): row for row in rows}
    result_keys = {(item.get("screen"), item.get("state_id")) for item in results}
    if len(result_keys) != len(results) or result_keys != set(by_key):
        fail(f"UI verification states differ from contract: missing {set(by_key) - result_keys}, extra {result_keys - set(by_key)}")
    captures = set()
    for item in results:
        key = (item["screen"], item["state_id"])
        row, stage = by_key[key], by_key[key]["Plan stage"]
        if item.get("design_image") != row["Design image"]:
            fail(f"UI verification design image differs for {key[1]}")
        capture_ref = item.get("review_capture", "")
        if not isinstance(capture_ref, str) or not capture_ref.startswith("evidence/") or ".." in Path(capture_ref).parts:
            fail(f"UI state {key[1]} review_capture must stay under evidence/")
        capture = report.parent / capture_ref
        if not capture.is_file():
            fail(f"missing review capture for {key[1]}: {capture}")
        if capture_ref in captures:
            fail(f"review capture reused across states: {capture_ref}")
        captures.add(capture_ref)
        width, height = png_dimensions(capture)
        vw, vh = viewport(row["Viewport"], key[1])
        if abs(width / height - vw / vh) / (vw / vh) > 0.015:
            fail(f"UI state {key[1]} review capture {width}x{height} was not rendered at the contract viewport {row['Viewport']}")
        if item.get("review_capture_test") != targets[stage]["review"]:
            fail(f"UI state {key[1]} review_capture_test must be {targets[stage]['review']}")
        if item.get("structural_check") != targets[stage]["structural"] or item.get("structural_result") != "PASS":
            fail(f"UI state {key[1]} needs a passing structural_check {targets[stage]['structural']}")
        if item.get("review_decision") != "approved" or not item.get("approved_by") or \
                not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(item.get("approved_on", ""))):
            fail(f"UI state {key[1]} needs review_decision 'approved' with approved_by and approved_on (YYYY-MM-DD)")
        if item.get("result") != "PASS":
            fail(f"UI state {key[1]} result must be PASS")
        if runtime:
            for target in (targets[stage]["review"], targets[stage]["structural"]):
                if not (project_root / target.split("#")[0]).is_file():
                    fail(f"UI state {key[1]} test source does not exist: {target}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("contract", type=Path)
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--test-plan", type=Path)
    parser.add_argument("--design-system", type=Path, help="Validate reused components against its Component Registry")
    parser.add_argument("--runtime", action="store_true")
    parser.add_argument("--project-root", type=Path)
    parser.add_argument("--inventory", action="store_true", help="Validate complete state behavior before Pen assets exist")
    args = parser.parse_args()
    try:
        validate(args.contract, args.spec, args.plan, args.report, args.test_plan, args.runtime,
                 args.project_root, args.inventory, args.design_system)
    except (ValueError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
