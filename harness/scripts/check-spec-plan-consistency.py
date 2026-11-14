#!/usr/bin/env python3
"""Analyze gate (Spec Kit /analyze): cross-artifact consistency for one dated feature workspace.

Single lane (no user stories): the approved feature block(s), implementation-plan.md, and
test-plan.md agree — every AC-### has a primary acceptance test, Rule Applicability is complete.

Every Required rule has planned work and a planned verification (test-plan.md). In the sliced lane
each Required rule other than the standing ARCH/IMPL/TEST also tags at least one task in tasks.md.

Sliced lane (two or more user stories): additionally tasks.md and feature_list.json agree with the
stories, the Spec Coverage Matrix, the per-story acceptance tests, and the journey contract; every
task belongs to exactly one slice, and each slice's tasks match in both files.

--pre-approval runs every check except the approval fields (block **Status** Approved and the
recorded block SHA-256), so the package can be analyzed before it is presented for approval.

Usage:
  python3 harness/scripts/check-spec-plan-consistency.py <feature-dir> [--project-root <dir>] [--pre-approval]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

RULE_IDS = ["ARCH", "IMPL", "TEST", "SUI", "L10N", "NAV", "API", "OBS", "ANL", "SEC"]
# Always-loaded rules that apply to every line of code: verified by Final checks and review, so a
# Required row needs planned work and a test mapping but no dedicated tagged task.
STANDING_RULES = {"ARCH", "IMPL", "TEST"}
RULE_TAG = re.compile(r"\[(" + "|".join(RULE_IDS) + r")\]")
FR_DEF = re.compile(r"^#{3,6}\s+(FR-\d{3})\b", re.M)
AC_DEF = re.compile(r"\*\*(AC-\d{3})\*\*")
SC_DEF = re.compile(r"\*\*(SC-\d{3})\*\*")
US_DEF = re.compile(r"^#{3,6}\s+(US-\d+)\b", re.M)
TC_ID = re.compile(r"^TC-[A-Z0-9-]+$")
SHA = re.compile(r"^[0-9a-f]{64}$")


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []

    def fail(self, message: str) -> None:
        self.failures.append(message)


def section(text: str, heading: str) -> str:
    """Body of the level-2 section whose title starts with `heading`, up to the next level-2 heading."""
    match = re.search(rf"^## {re.escape(heading)}\b.*$", text, re.M)
    if not match:
        return ""
    rest = text[match.end():]
    nxt = re.search(r"^## ", rest, re.M)
    return rest[: nxt.start()] if nxt else rest


def subsections(body: str) -> dict[str, str]:
    """Level-3 subsections keyed by their leading US-n ID."""
    parts = re.split(r"^### (US-\d+)\b.*$", body, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}


def table_rows(body: str) -> list[list[str]]:
    rows = []
    for line in body.splitlines():
        line = line.strip()
        if not line.startswith("|") or re.match(r"^\|[\s:|-]+\|$", line):
            continue
        rows.append([c.strip() for c in line.strip("|").split("|")])
    return rows


def unquote(cell: str) -> str:
    return cell.strip().strip("`").strip()


def duplicates(values: list[str]) -> list[str]:
    seen, dup = set(), set()
    for v in values:
        (dup if v in seen else seen).add(v)
    return sorted(dup)


def extract_block(text: str, feature_id: str) -> tuple[str | None, str]:
    start, end = f"<!-- feature: {feature_id} -->", f"<!-- /feature: {feature_id} -->"
    if text.count(start) != 1 or text.count(end) != 1:
        return None, (f"expected exactly one '{start}' and one '{end}' marker "
                      f"(found {text.count(start)} and {text.count(end)})")
    s, e = text.index(start) + len(start), text.index(end)
    if e < s:
        return None, "closing marker precedes opening marker"
    return text[s:e], ""


class Spec:
    """Requirement IDs and stories collected from every capability file the plan lists."""

    def __init__(self) -> None:
        self.required: dict[str, dict[str, set[str]]] = {}  # capability name -> kind -> IDs in block
        self.known_acs: set[str] = set()                     # every AC defined in those files
        self.stories: dict[str, set[str]] = {}               # US-n -> FRs it owns
        self.files: list[str] = []


def read_requirements(r: Report, plan: str, feature_id: str, root: Path, pre_approval: bool = False) -> Spec:
    spec = Spec()
    rows = [row for row in table_rows(section(plan, "Product Requirements"))
            if row and "docs/product/requirements/" in row[0]]
    if not rows:
        r.fail("implementation-plan.md '## Product Requirements' needs a row per capability file")
    for row in rows:
        if len(row) < 4:
            r.fail(f"Product Requirements row has too few columns: {row}")
            continue
        rel, block_cell, recorded = unquote(row[0]), unquote(row[1]), unquote(row[3])
        path = root / rel
        if not path.is_file():
            r.fail(f"capability file not found: {rel}")
            continue
        text = path.read_text(encoding="utf-8")
        spec.files.append(rel)
        spec.known_acs |= set(AC_DEF.findall(text))
        for pattern in (FR_DEF, AC_DEF, SC_DEF):
            for dup in duplicates(pattern.findall(text)):
                r.fail(f"{rel}: {dup} is defined more than once; IDs are never reused")

        if block_cell.lower().startswith("none"):
            if not re.search(r"FR-\d{3}", block_cell):
                r.fail(f"{rel}: a row without a feature block must cite the restored FR-###")
            continue
        if block_cell != feature_id:
            r.fail(f"{rel}: feature block '{block_cell}' does not match feature ID '{feature_id}'")
        block, error = extract_block(text, feature_id)
        if block is None:
            r.fail(f"{rel}: {error}")
            continue
        actual = hashlib.sha256(block.encode("utf-8")).hexdigest()
        if pre_approval:
            pass
        elif not SHA.match(recorded):
            r.fail(f"{rel}: approved block SHA-256 is not recorded in implementation-plan.md (current: {actual})")
        elif recorded != actual:
            r.fail(f"{rel}: feature block changed after approval (recorded {recorded}, current {actual}); re-approve the specification")
        if "[NEEDS CLARIFICATION" in block:
            r.fail(f"{rel}: feature block still contains [NEEDS CLARIFICATION] markers")
        if not pre_approval and not re.search(r"^\*\*Status\*\*:.*\bApproved\b", block, re.M):
            r.fail(f"{rel}: feature block **Status** is not Approved")

        frs = set(FR_DEF.findall(block))
        if not frs:
            r.fail(f"{rel}: feature block defines no FR-### requirement")
        spec.required[path.name] = {"FR": frs, "AC": set(AC_DEF.findall(block)), "SC": set(SC_DEF.findall(block))}
        for story in US_DEF.findall(block):
            body = re.search(rf"^#{{3,6}}\s+{story}\b.*?(?=^#{{3,6}}\s|\Z)", block, re.M | re.S).group(0)
            req = re.search(r"^\*\*Requirements\*\*:(.*)$", body, re.M)
            if not req:
                r.fail(f"{rel}: {story} must list its **Requirements**")
                spec.stories.setdefault(story, set())
                continue
            listed = set(re.findall(r"FR-\d{3}", req.group(1)))
            for fr in sorted(listed - frs):
                r.fail(f"{rel}: {story} lists {fr}, which this feature block does not define")
            spec.stories.setdefault(story, set()).update(listed)
    return spec


def check_rules(r: Report, plan: str) -> dict[str, str]:
    """Validate the ten Rule Applicability rows; return {rule: decision}."""
    rows = table_rows(section(plan, "Rule Applicability"))
    header = rows[0] if rows else []
    column = next((i for i, cell in enumerate(header) if cell.startswith("Decision")), 2)
    work_column = next((i for i, cell in enumerate(header) if cell.startswith("Planned work")), len(header) - 1)
    rules = {unquote(row[0]): row for row in rows[1:] if row}
    decisions: dict[str, str] = {}
    for rule in RULE_IDS:
        row = rules.get(rule)
        if not row or len(row) <= column:
            r.fail(f"implementation-plan.md Rule Applicability is missing the {rule} row")
            continue
        decision = row[column]
        if not (decision == "Required" or re.match(r"^Not applicable — \S", decision)
                or re.match(r"^Exception — approved by \S", decision)):
            r.fail(f"implementation-plan.md Rule Applicability {rule} has an unsupported decision: '{decision}'")
            continue
        decisions[rule] = "Required" if decision == "Required" else decision.split(" —")[0]
        if decision == "Required":
            work = row[work_column] if len(row) > work_column else ""
            if not work or work.startswith("<"):
                r.fail(f"implementation-plan.md Rule Applicability {rule} is Required but has no planned work and evidence")
    return decisions


def check_rule_test_mapping(r: Report, test_plan: str, decisions: dict[str, str]) -> None:
    """Every Required rule maps to a planned verification in test-plan.md."""
    rows = table_rows(section(test_plan, "Rule Applicability Test Mapping"))
    mapped = {unquote(row[0]): row[1] for row in rows if len(row) > 1 and unquote(row[0]) in RULE_IDS}
    for rule in RULE_IDS:
        if decisions.get(rule) != "Required":
            continue
        verification = mapped.get(rule, "")
        if not verification or verification.startswith("<"):
            r.fail(f"test-plan.md Rule Applicability Test Mapping has no planned verification for Required rule {rule}")


def test_cases(r: Report, rows: list[list[str]], where: str, into: dict[str, set[str]]) -> list[str]:
    ids = []
    for row in rows:
        if row and TC_ID.match(unquote(row[0])):
            tc = unquote(row[0])
            if tc in into:
                r.fail(f"test-plan.md defines acceptance test {tc} more than once")
            covers = set(re.findall(r"AC-\d{3}", row[1] if len(row) > 1 else ""))
            if not covers:
                r.fail(f"test-plan.md {where} {tc} does not name the AC-### it covers")
            into[tc] = covers
            ids.append(tc)
    return ids


def check_coverage(r: Report, spec: Spec, covers: dict[str, set[str]]) -> None:
    covered = set().union(*covers.values()) if covers else set()
    for cap, kinds in spec.required.items():
        for ac in sorted(kinds["AC"] - covered):
            r.fail(f"test-plan.md has no acceptance test covering {cap}#{ac}")
    for tc, acs in sorted(covers.items()):
        for ac in sorted(acs - spec.known_acs):
            r.fail(f"test-plan.md {tc} cites {ac}, which no listed capability file defines")


def check_single(r: Report, spec: Spec, test_plan: str, workspace: Path, decisions: dict[str, str]) -> None:
    if spec.stories:
        r.fail(f"single lane must not define user stories (found {', '.join(sorted(spec.stories))}); "
               "use the sliced lane or remove the User Scenarios section")
    for name in ("tasks.md", "feature_list.json"):
        if (workspace / name).exists():
            r.fail(f"single lane does not use {name}; remove it or switch the plan to the sliced lane")
    covers: dict[str, set[str]] = {}
    body = section(test_plan, "Acceptance Test Cases")
    if subsections(body):
        r.fail("single lane keeps one flat '## Acceptance Test Cases' table, without '### US-n' subsections")
    if not test_cases(r, table_rows(body), "Acceptance Test Cases", covers):
        r.fail("test-plan.md '## Acceptance Test Cases' defines no TC-* acceptance test")
    check_coverage(r, spec, covers)


def check_sliced(r: Report, spec: Spec, test_plan: str, workspace: Path, decisions: dict[str, str]) -> None:
    stories = set(spec.stories)
    if len(stories) < 2:
        r.fail("sliced lane needs two or more user stories; a single deliverable change uses the single lane")
    owned = set().union(*spec.stories.values()) if spec.stories else set()
    for cap, kinds in spec.required.items():
        for fr in sorted(kinds["FR"] - owned):
            r.fail(f"{cap}: {fr} is not owned by any user story")

    # Acceptance tests per story in test-plan.md.
    covers: dict[str, set[str]] = {}
    tc_story: dict[str, str] = {}
    per_story = subsections(section(test_plan, "Acceptance Test Cases"))
    for story in sorted(stories - set(per_story)):
        r.fail(f"test-plan.md '## Acceptance Test Cases' has no '### {story}' subsection")
    for story, body in per_story.items():
        if story not in stories:
            r.fail(f"test-plan.md '### {story}' is not a user story in any approved feature block")
        for tc in test_cases(r, table_rows(body), story, covers):
            tc_story[tc] = story
    check_coverage(r, spec, covers)

    # Spec Coverage Matrix.
    matrix = [row for row in table_rows(section(test_plan, "Spec Coverage Matrix"))[1:] if row]
    for cap, kinds in spec.required.items():
        for kind in ("FR", "AC", "SC"):
            for req_id in sorted(kinds[kind]):
                hits = [row for row in matrix if len(row) >= 6 and unquote(row[0]) == req_id
                        and Path(unquote(row[1])).name == cap]
                if not hits:
                    r.fail(f"test-plan.md Spec Coverage Matrix is missing {cap}#{req_id}")
                    continue
                handling, story, test = hits[0][5], unquote(hits[0][3]), unquote(hits[0][4])
                if handling.startswith("Out of scope"):
                    if not re.match(r"^Out of scope — \S", handling):
                        r.fail(f"test-plan.md {cap}#{req_id} out-of-scope handling needs a reason")
                    continue
                if handling != "In scope":
                    r.fail(f"test-plan.md {cap}#{req_id} handling must be 'In scope' or 'Out of scope — <reason>'")
                    continue
                if story not in stories:
                    r.fail(f"test-plan.md {cap}#{req_id} maps to unknown user story '{story}'")
                if test not in tc_story:
                    r.fail(f"test-plan.md {cap}#{req_id} primary test '{test}' is not an acceptance test case")
                elif tc_story[test] != story:
                    r.fail(f"test-plan.md {cap}#{req_id} test {test} belongs to {tc_story[test]}, not {story}")

    journeys = {unquote(row[0]): row for row in table_rows(section(test_plan, "Production Journey Planning Contract"))
                if row and re.match(r"^US-\d+$", unquote(row[0]))}
    for story in sorted(stories - set(journeys)):
        r.fail(f"test-plan.md Production Journey Planning Contract has no row for {story}")

    tasks_by_story = check_tasks_md(r, stories, workspace, decisions)
    check_feature_list(r, stories, tc_story, journeys, workspace, tasks_by_story)


STORY_SECTION = re.compile(r"^## (US-\d+):[^\n]*\n(.*?)(?=^## |\Z)", re.M | re.S)
TASK_ROW = re.compile(r"^- \[([ xX])\] (T\d{3})\b(.*)$", re.M)


def expand_task_ids(cell: str) -> set[str]:
    """T001, T001-T004, T001–T004, comma lists -> a set of task IDs."""
    ids: set[str] = set()
    for first, last in re.findall(r"T(\d{3})\s*[–—-]\s*T(\d{3})", cell):
        ids.update(f"T{n:03d}" for n in range(int(first), int(last) + 1))
    ids.update(re.findall(r"T\d{3}", re.sub(r"T\d{3}\s*[–—-]\s*T\d{3}", "", cell)))
    return ids


def check_tasks_md(r: Report, stories: set[str], workspace: Path,
                   decisions: dict[str, str]) -> dict[str, dict[str, bool]]:
    """tasks.md: a Slices table, then one '## US-n:' section per slice owning every task.

    Returns {story: {task id: checked}} for the feature_list.json comparison.
    """
    tasks_path = workspace / "tasks.md"
    if not tasks_path.is_file():
        r.fail(f"missing {tasks_path} (required in the sliced lane)")
        return {}
    tasks = tasks_path.read_text(encoding="utf-8")
    sections = [(m.group(1), m.group(2), m.span()) for m in STORY_SECTION.finditer(tasks)]
    order = [story for story, _, _ in sections]
    for dup in duplicates(order):
        r.fail(f"tasks.md has more than one section for {dup}")
    for story in sorted(stories - set(order)):
        r.fail(f"tasks.md has no '## {story}:' section")
    for story in sorted(set(order) - stories):
        r.fail(f"tasks.md section {story} is not a user story in any approved feature block")

    by_story: dict[str, dict[str, bool]] = {}
    tagged: set[str] = set()
    for index, (story, body, _) in enumerate(sections):
        if not re.search(rf"^\*\*Slice\*\*:\s*`{story}`", body, re.M):
            r.fail(f"tasks.md section {story} must declare '**Slice**: `{story}`'")
        if index != 0 and re.search(r"^### Prerequisites\b", body, re.M):
            r.fail(f"tasks.md section {story} has '### Prerequisites'; only the first slice ({order[0]}) may")
        if index != len(sections) - 1 and re.search(r"^### Final checks\b", body, re.M):
            r.fail(f"tasks.md section {story} has '### Final checks'; only the last slice ({order[-1]}) may")
        by_story.setdefault(story, {})
        for m in TASK_ROW.finditer(body):
            task_id, rest = m.group(2), m.group(3)
            labels = re.findall(r"\[(US-\d+)\]", rest)
            if not labels:
                r.fail(f"tasks.md {task_id} has no [US-n] label; every task belongs to a slice")
            elif labels != [story]:
                r.fail(f"tasks.md {task_id} is in the {story} section but labelled {', '.join(labels)}")
            by_story[story][task_id] = m.group(1) in "xX"
            for tag in RULE_TAG.findall(rest):
                if decisions.get(tag) != "Required":
                    r.fail(f"tasks.md {task_id} is tagged [{tag}], but Rule Applicability does not mark {tag} Required")
                tagged.add(tag)

    for rule in RULE_IDS:
        if decisions.get(rule) == "Required" and rule not in STANDING_RULES and rule not in tagged:
            r.fail(f"tasks.md has no task tagged [{rule}] for Required rule {rule}")

    spans = [span for _, _, span in sections]
    all_ids = [m.group(2) for m in TASK_ROW.finditer(tasks)]
    if not all_ids:
        r.fail("tasks.md has no '- [ ] T### …' tasks")
    for dup in duplicates(all_ids):
        r.fail(f"tasks.md reuses task ID {dup}")
    for m in TASK_ROW.finditer(tasks):
        if not any(a <= m.start() < b for a, b in spans):
            r.fail(f"tasks.md {m.group(2)} is outside every slice section")

    overview = {unquote(row[0]): row for row in table_rows(section(tasks, "Slices"))
                if row and re.match(r"^US-\d+$", unquote(row[0]))}
    for story in sorted(stories - set(overview)):
        r.fail(f"tasks.md Slices table has no row for {story}")
    for story in sorted(set(overview) - stories):
        r.fail(f"tasks.md Slices table lists {story}, which is not a user story")
    for story, row in overview.items():
        if story not in by_story:
            continue
        listed = expand_task_ids(row[3]) if len(row) > 3 else set()
        actual = set(by_story[story])
        if listed != actual:
            r.fail(f"tasks.md Slices table tasks for {story} ({', '.join(sorted(listed)) or 'none'}) "
                   f"do not match its section ({', '.join(sorted(actual)) or 'none'})")
    return by_story


def check_feature_list(r: Report, stories: set[str], tc_story: dict[str, str], journeys: dict,
                       workspace: Path, tasks_by_story: dict[str, dict[str, bool]]) -> None:
    list_path = workspace / "feature_list.json"
    if not list_path.is_file():
        r.fail(f"missing {list_path} (required in the sliced lane)")
        return
    try:
        features = json.loads(list_path.read_text(encoding="utf-8")).get("features")
    except (json.JSONDecodeError, AttributeError) as exc:
        r.fail(f"{list_path} is not a valid slice contract: {exc}")
        return
    if not isinstance(features, list) or not features:
        r.fail("feature_list.json must contain a non-empty 'features' array")
        return
    slice_ids = [f.get("id") for f in features if isinstance(f, dict)]
    for dup in duplicates([s for s in slice_ids if s]):
        r.fail(f"feature_list.json repeats slice {dup}")
    if set(slice_ids) != stories:
        r.fail(f"feature_list.json slices {sorted(map(str, slice_ids))} do not match user stories {sorted(stories)}")
    for feature in features:
        if not isinstance(feature, dict):
            continue
        sid = feature.get("id")
        expected = {tc for tc, story in tc_story.items() if story == sid}
        listed = set(feature.get("acceptance_test_ids") or [])
        for tc in sorted(expected - listed):
            r.fail(f"feature_list.json {sid} is missing acceptance test {tc}")
        for tc in sorted(listed - expected):
            r.fail(f"feature_list.json {sid} lists {tc}, which test-plan.md does not define for {sid}")
        row, pj = journeys.get(sid), feature.get("production_journey")
        if row and isinstance(pj, dict) and len(row) > 1:
            if bool(pj.get("required")) != row[1].strip().lower().startswith("yes"):
                r.fail(f"feature_list.json {sid} production_journey.required disagrees with test-plan.md")
        check_slice_tasks(r, sid, feature.get("tasks"), tasks_by_story.get(sid))


def check_slice_tasks(r: Report, sid: str, listed, md_tasks: dict[str, bool] | None) -> None:
    """The slice's `tasks` array lists the same tasks as its tasks.md section, with matching progress."""
    if not isinstance(listed, list) or not listed:
        r.fail(f"feature_list.json {sid} needs a non-empty 'tasks' array (id, title, file, done)")
        return
    ids = []
    for task in listed:
        if not isinstance(task, dict) or not re.fullmatch(r"T\d{3}", str(task.get("id", ""))):
            r.fail(f"feature_list.json {sid} has a task without a T### id")
            continue
        ids.append(task["id"])
        if not isinstance(task.get("done"), bool):
            r.fail(f"feature_list.json {sid} {task['id']} needs a boolean 'done'")
        if not task.get("title") or not task.get("file"):
            r.fail(f"feature_list.json {sid} {task['id']} needs 'title' and 'file'")
    for dup in duplicates(ids):
        r.fail(f"feature_list.json {sid} repeats task {dup}")
    if md_tasks is None:
        return
    for task_id in sorted(set(md_tasks) - set(ids)):
        r.fail(f"feature_list.json {sid} is missing task {task_id} from tasks.md")
    for task_id in sorted(set(ids) - set(md_tasks)):
        r.fail(f"feature_list.json {sid} lists {task_id}, which is not in its tasks.md section")
    for task in listed:
        if isinstance(task, dict) and task.get("id") in md_tasks and isinstance(task.get("done"), bool):
            if task["done"] != md_tasks[task["id"]]:
                r.fail(f"{task['id']} is {'done' if task['done'] else 'not done'} in feature_list.json "
                       f"but {'checked' if md_tasks[task['id']] else 'unchecked'} in tasks.md")


def check(workspace: Path, root: Path, pre_approval: bool = False) -> Report:
    r = Report()
    plan_path, test_plan_path = workspace / "implementation-plan.md", workspace / "test-plan.md"
    for p in (plan_path, test_plan_path):
        if not p.is_file():
            r.fail(f"missing {p}")
    if r.failures:
        return r
    plan = plan_path.read_text(encoding="utf-8")
    test_plan = test_plan_path.read_text(encoding="utf-8")

    m = re.search(r"^\*\*Feature ID\*\*:\s*`?([a-z0-9][a-z0-9-]*)`?\s*$", plan, re.M)
    if not m:
        r.fail("implementation-plan.md must declare '**Feature ID**: `<feature-id>`'")
        return r
    feature_id = m.group(1)
    if not workspace.name.endswith(feature_id):
        r.fail(f"workspace '{workspace.name}' does not end with feature ID '{feature_id}'")
    m = re.search(r"^\*\*Lane\*\*:\s*`?(single|sliced)`?\s*(\*\(.*\)\*)?\s*$", plan, re.M)
    if not m:
        r.fail("implementation-plan.md must declare '**Lane**: single' or '**Lane**: sliced'")
        return r

    spec = read_requirements(r, plan, feature_id, root, pre_approval)
    decisions = check_rules(r, plan)
    check_rule_test_mapping(r, test_plan, decisions)
    (check_single if m.group(1) == "single" else check_sliced)(r, spec, test_plan, workspace, decisions)
    return r


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("feature_dir")
    parser.add_argument("--project-root", default=os.environ.get("HARNESS_PROJECT_ROOT", os.getcwd()))
    parser.add_argument("--pre-approval", action="store_true",
                        help="skip the approval fields (block Status and recorded SHA-256)")
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    workspace = Path(args.feature_dir)
    workspace = (workspace if workspace.is_absolute() else root / workspace).resolve()
    report = check(workspace, root, args.pre_approval)
    for message in report.failures:
        print(f"FAIL: {message}", file=sys.stderr)
    if report.failures:
        print(f"FAIL: analyze gate found {len(report.failures)} inconsistency(ies) in {workspace.name}", file=sys.stderr)
        return 1
    suffix = " (pre-approval: block Status and SHA-256 not yet required)" if args.pre_approval else ""
    print(f"OK: requirements and plans are consistent for {workspace.name}{suffix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
