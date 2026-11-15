#!/usr/bin/env python3
"""Validate single-lane acceptance rows and their recorded JUnit evidence."""
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def fail(message):
    sys.exit(f"FAIL: {message}")


feature, mode, root = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
contract = (feature / "test-plan.md").read_text()
section = re.search(r"(?ms)^## Acceptance Test Cases\s*$\n(.*?)(?=^## |\Z)", contract)
if not section:
    fail("missing Acceptance Test Cases section")
if '| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |' not in section.group(1):
    fail("invalid acceptance table header")
rows = []
for line in section.group(1).splitlines():
    cells = [cell.strip().strip('`') for cell in line.strip().strip('|').split('|')]
    if cells and cells[0].startswith('TC-') and not re.fullmatch(r"TC-[0-9]+", cells[0]):
        fail(f"invalid single-lane acceptance test ID: {cells[0]}")
    if cells and re.fullmatch(r"TC-[0-9]+", cells[0]):
        if len(cells) != 8 or any(not cell for cell in cells):
            fail(f"invalid acceptance row: {line}")
        rows.append(cells)
if not rows or len({row[0] for row in rows}) != len(rows):
    fail("missing or duplicate single-lane acceptance test IDs")
evidence = {}
if mode == "--evaluate":
    try:
        entries = json.loads((feature / "acceptance-evidence.json").read_text())
        evidence = {entry['test_id']: entry for entry in entries}
        if len(evidence) != len(entries):
            fail("duplicate acceptance evidence IDs")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        fail(f"invalid acceptance-evidence.json: {exc}")

for test_id, ac, layer, target, scenarios, setup, assertions, command in rows:
    if '#' not in target:
        fail(f"{test_id} must name a test file and method")
    filename, method = target.split('#', 1)
    if not re.fullmatch(r"app/src/(?:test|androidTest)/[\w/]+\.kt", filename) or not re.fullmatch(r"[A-Za-z_]\w*", method):
        fail(f"{test_id} has invalid test target")
    suite = Path(filename).stem
    if re.search(r"\b(?:opens?|opening|navigates? to)\s+(?:the\s+)?(?:existing\s+)?(?:target\s+)?(?:editor\s+)?route\b", setup + ' ' + assertions, re.I):
        journey = re.search(r"(?ms)^## Production Journey Boundary\s*$\n(.*?)(?=^## |\Z)", contract)
        if not journey or filename not in journey.group(1) or method not in journey.group(1):
            fail(f"{test_id} route claim is not owned by the production journey")
    if 'androidTest' in filename:
        if 'harness/scripts/run-android-instrumented-tests.sh' not in command or not re.search(rf"--class\s+[^\s`]*{re.escape(suite)}(?:#{method})?(?:[\s`]|$)", command):
            fail(f"{test_id} must use a suite-scoped instrumented runner")
    elif not re.search(r"(?:^|\s)(?:\./)?gradlew\s", command) or '--tests' not in command or suite not in command or not re.search(r"test\w*UnitTest", command):
        fail(f"{test_id} must use a suite-scoped Gradle unit test")
    if re.search(r"(?:record|verify|compare|verifyAndRecord)Roborazzi", command):
        fail(f"{test_id} runs a Roborazzi golden task")
    paths = re.findall(r"sharedContracts/test-scenarios/[\w.-]+\.json", scenarios)
    if not paths and scenarios != 'N/A — no API':
        fail(f"{test_id} has invalid shared scenarios")
    if mode != '--planning':
        try:
            source = (root / filename).read_text()
        except OSError:
            fail(f"{test_id} declared test source is missing")
        match = re.search(rf"(?m)^\s*(?:(?:public|private|internal|suspend)\s+)*fun\s+{re.escape(method)}\s*\(", source)
        preceding = source[:match.start()].splitlines()[-8:] if match else []
        if not match or not re.search(r"@(?:Test|ParameterizedTest|TestFactory|TestTemplate)\b", '\n'.join(preceding)):
            fail(f"{test_id} declared test method is missing or unannotated")
        body = source[match.end():]
        body = re.split(r"\n\s*(?:public |private |internal )?fun\s+\w+\s*\(", body, maxsplit=1)[0]
        for path in paths:
            if not (root / path).is_file() or Path(path).name not in body:
                fail(f"{test_id} declared scenario is missing or not referenced")
        result = subprocess.run(['bash', str(Path(__file__).parent / 'check-rendered-output-contract.sh'), '--project-root', str(root), '--test-file', str(root / filename), '--test-method', method, '--claim', setup + ' ' + assertions], check=False)
        if result.returncode:
            fail(f"{test_id} rendered-output contract failed")
    if mode == '--evaluate':
        entry = evidence.get(test_id, {})
        if entry.get('exit_status') != 0 or not isinstance(entry.get('test_count'), int) or entry['test_count'] < 1:
            fail(f"{test_id} has no successful nonempty test evidence")
        executed = entry.get('executed_command', '')
        if suite not in executed or ('--tests' not in executed and '--class' not in executed):
            fail(f"{test_id} evidence command is not scoped to {suite}")
        report = Path(entry.get('junit_xml', ''))
        if report.is_absolute() or '..' in report.parts:
            fail(f"{test_id} has invalid JUnit report path")
        try:
            tree = ET.parse(root / report)
            cases = [case for case in tree.iter('testcase') if case.get('name') == method and case.get('classname', '').split('.')[-1] == suite]
        except (OSError, ET.ParseError, ValueError):
            fail(f"{test_id} JUnit report is missing or invalid")
        if len(cases) != 1 or any(cases[0].find(name) is not None for name in ('failure', 'error', 'skipped')):
            fail(f"{test_id} has no passing JUnit test case")
print(f"PASS: {len(rows)} single-lane acceptance test row(s) have valid traceability in {mode} mode.")
