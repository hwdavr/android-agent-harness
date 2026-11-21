#!/usr/bin/env python3
"""Shared parsing for change workspaces: intent.md, design.md, and specs/<capability>.md deltas.

A change workspace `.scratch/<YYYY-MM-DD>-<feature-id>/` holds:
  intent.md            what is wanted, why, and under which constraints (Stage 1 Plan)
  design.md            lane, user stories, flow/navigation, screen states, product decisions
  specs/<cap>.md       requirement delta for docs/product/requirements/<cap>.md

Delta file format (spec-delta-template.md):
  ## ADDED Requirements / ## MODIFIED Requirements / ## REMOVED Requirements
  ### Requirement: FR-### <Name>
  The app SHALL ...
  #### Scenario: AC-### <name>
  - **WHEN** ... - **THEN** ...

Living capability files (capability-spec-template.md) use the same requirement and scenario
headings under `## Requirements`. archive-change.py merges deltas into them.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from pathlib import Path

OPS = ("ADDED", "MODIFIED", "REMOVED")
OP_HEADING = re.compile(r"^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*$", re.M)
LEVEL2 = re.compile(r"^## (.+?)\s*$", re.M)
REQ_HEADING = re.compile(r"^### Requirement:\s*(FR-\d{3})\b[ \t]*(.*)$", re.M)
SCENARIO_HEADING = re.compile(r"^#### Scenario:\s*(AC-\d{3})\b[ \t]*(.*)$", re.M)
SC_DEF = re.compile(r"\*\*(SC-\d{3})\*\*")
US_HEADING = re.compile(r"^#{2,4}\s+(US-\d+)\b", re.M)
STATUS_LINE = re.compile(r"^\*\*Status\*\*:.*$\n?", re.M)
CITATION = re.compile(r"(?:([a-z0-9][a-z0-9-]*)\.md)?#?(FR-\d{3})")
WORKSPACE_NAME = re.compile(r"^(\d{4}-\d{2}-\d{2})-([a-z0-9][a-z0-9-]*)$")


@dataclass
class Requirement:
    fr: str
    name: str
    text: str                       # from the `### Requirement:` line to the next requirement/section
    scenarios: list[str] = field(default_factory=list)


@dataclass
class Delta:
    path: Path
    capability: str
    title: str = ""
    user_goal: str = ""
    ops: dict[str, list[Requirement]] = field(default_factory=lambda: {op: [] for op in OPS})
    errors: list[str] = field(default_factory=list)

    def ids(self, *ops: str) -> set[str]:
        return {req.fr for op in (ops or OPS) for req in self.ops[op]}

    def scenarios(self, *ops: str) -> set[str]:
        return {ac for op in (ops or OPS) for req in self.ops[op] for ac in req.scenarios}


def feature_id_for(workspace: Path) -> str:
    match = WORKSPACE_NAME.match(workspace.name)
    if not match:
        raise ValueError(f"workspace '{workspace.name}' must be named <YYYY-MM-DD>-<feature-id>")
    return match.group(2)


def sections(text: str) -> list[tuple[str, str]]:
    """(heading, body) for each level-2 section, in order."""
    parts = LEVEL2.split(text)
    return [(parts[i].strip(), parts[i + 1]) for i in range(1, len(parts), 2)]


def section(text: str, heading: str) -> str | None:
    for title, body in sections(text):
        if re.sub(r"\s*\*\(.*\)\*\s*$", "", title) == heading:
            return body
    return None


def split_requirements(body: str) -> tuple[str, list[Requirement]]:
    """Split a section body into its preamble and `### Requirement:` blocks."""
    matches = list(REQ_HEADING.finditer(body))
    preamble = body[: matches[0].start()] if matches else body
    reqs = []
    for i, m in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        text = body[m.start():end].rstrip() + "\n"
        reqs.append(Requirement(m.group(1), m.group(2).strip(), text,
                                [s.group(1) for s in SCENARIO_HEADING.finditer(text)]))
    return preamble, reqs


def parse_delta(path: Path) -> Delta:
    text = path.read_text(encoding="utf-8")
    delta = Delta(path=path, capability=path.stem)
    title = re.search(r"^# (.+)$", text, re.M)
    delta.title = title.group(1).strip() if title else ""
    goal = re.search(r"^\*\*User goal\*\*:\s*(.+)$", text, re.M)
    delta.user_goal = goal.group(1).strip() if goal else ""
    seen_ops: list[str] = []
    for heading, body in sections(text):
        op_match = re.fullmatch(r"(ADDED|MODIFIED|REMOVED|RENAMED) Requirements", heading)
        if not op_match:
            delta.errors.append(f"{path.name}: unexpected section '## {heading}'; use ADDED, MODIFIED, or REMOVED Requirements")
            continue
        op = op_match.group(1)
        if op == "RENAMED":
            delta.errors.append(f"{path.name}: RENAMED is not supported; MODIFIED the requirement with its new name")
            continue
        if op in seen_ops:
            delta.errors.append(f"{path.name}: '## {op} Requirements' appears more than once")
        seen_ops.append(op)
        preamble, reqs = split_requirements(body)
        if not reqs:
            delta.errors.append(f"{path.name}: '## {op} Requirements' has no '### Requirement: FR-###' entry")
        for req in reqs:
            if op != "REMOVED" and not req.scenarios:
                delta.errors.append(f"{path.name}: {op} {req.fr} needs at least one '#### Scenario: AC-###'")
            if op != "REMOVED" and not re.search(r"\bSHALL\b", req.text):
                delta.errors.append(f"{path.name}: {op} {req.fr} must state its behavior with SHALL")
            if op == "REMOVED" and not re.search(r"^\*\*Reason\*\*:\s*\S", req.text, re.M):
                delta.errors.append(f"{path.name}: REMOVED {req.fr} needs a '**Reason**:' line")
        delta.ops[op].extend(reqs)
    all_ids = [req.fr for op in OPS for req in delta.ops[op]]
    for dup in sorted({i for i in all_ids if all_ids.count(i) > 1}):
        delta.errors.append(f"{path.name}: {dup} appears in more than one delta entry")
    acs = [ac for op in OPS for req in delta.ops[op] for ac in req.scenarios]
    for dup in sorted({i for i in acs if acs.count(i) > 1}):
        delta.errors.append(f"{path.name}: {dup} is defined more than once")
    if not any(delta.ops.values()) and not delta.errors:
        delta.errors.append(f"{path.name}: defines no requirement delta")
    return delta


def delta_files(workspace: Path) -> list[Path]:
    specs = workspace / "specs"
    return sorted(p for p in specs.glob("*.md")) if specs.is_dir() else []


def capability_path(root: Path, capability: str) -> Path:
    return root / "docs" / "product" / "requirements" / f"{capability}.md"


def artifact_hash(path: Path) -> str:
    """SHA-256 of an approved artifact. intent.md ignores its **Status** line so that approval and
    archiving do not change the recorded hash."""
    text = path.read_text(encoding="utf-8")
    if path.name == "intent.md":
        text = STATUS_LINE.sub("", text)
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def intent_status(workspace: Path) -> str:
    path = workspace / "intent.md"
    if not path.is_file():
        return ""
    m = re.search(r"^\*\*Status\*\*:\s*(.+)$", path.read_text(encoding="utf-8"), re.M)
    return m.group(1).strip() if m else ""


def design_lane(workspace: Path) -> str:
    path = workspace / "design.md"
    if not path.is_file():
        return ""
    m = re.search(r"^\*\*Lane\*\*:\s*`?(single|sliced)`?", path.read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else ""


def design_stories(workspace: Path, default_capability: str | None) -> tuple[dict[str, set[str]], list[str]]:
    """US-n -> {'<capability>#FR-###'} from design.md User Scenarios; plus errors."""
    path = workspace / "design.md"
    stories: dict[str, set[str]] = {}
    errors: list[str] = []
    if not path.is_file():
        return stories, errors
    text = path.read_text(encoding="utf-8")
    body = section(text, "User Scenarios") or ""
    heads = list(US_HEADING.finditer(body))
    for i, m in enumerate(heads):
        story = m.group(1)
        chunk = body[m.start(): heads[i + 1].start() if i + 1 < len(heads) else len(body)]
        req = re.search(r"^\*\*Requirements\*\*:(.*)$", chunk, re.M)
        stories.setdefault(story, set())
        if not req:
            errors.append(f"design.md: {story} must list its **Requirements**")
            continue
        for cap, fr in CITATION.findall(req.group(1)):
            cap = cap or default_capability
            if not cap:
                errors.append(f"design.md: {story} cites {fr} without its capability; write <capability>.md#{fr}")
                continue
            stories[story].add(f"{cap}#{fr}")
    return stories, errors


def capability_requirements(text: str) -> tuple[str, str, list[Requirement], str] | None:
    """Split a living capability file into (before, preamble, requirements, after) around
    `## Requirements`. Returns None when the section is missing."""
    match = re.search(r"^## Requirements\s*$", text, re.M)
    if not match:
        return None
    start = match.end()
    nxt = re.search(r"^## ", text[start:], re.M)
    end = start + nxt.start() if nxt else len(text)
    preamble, reqs = split_requirements(text[start:end])
    return text[: match.end()], preamble, reqs, text[end:]


def is_structured(text: str) -> bool:
    return bool(REQ_HEADING.search(text))
