#!/usr/bin/env python3
"""Archive a delivered change: merge its specs/ deltas into the living capability files.

For each `specs/<capability>.md` in the workspace:
  ## ADDED Requirements     appended to docs/product/requirements/<capability>.md `## Requirements`
                            (creates the capability file when it does not exist yet)
  ## MODIFIED Requirements  replaces the `### Requirement: FR-###` block with the same ID
  ## REMOVED Requirements   deletes the `### Requirement: FR-###` block (its ID is never reused)

Then it updates each capability's **Updated** date, links the workspace under `## References`, and
sets intent.md **Status** to `Archived — <date>`. The workspace stays where it is.

Every merge is computed and validated before any file is written; one failure writes nothing.
MODIFIED and REMOVED need the capability file in capability-spec-template.md format.

Usage:
  python3 harness/scripts/archive-change.py <workspace> [--project-root DIR] [--date YYYY-MM-DD] [--dry-run]
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec_change as sc  # noqa: E402


class ArchiveError(Exception):
    pass


def new_capability(delta: sc.Delta, date: str) -> str:
    if not delta.title or not delta.user_goal:
        raise ArchiveError(f"specs/{delta.path.name}: a new capability needs '# <Title>' and '**User goal**:' lines")
    return (f"# {delta.title}\n\n**Capability ID**: `{delta.capability}`\n**Updated**: {date}\n\n"
            f"## User goal\n\n{delta.user_goal}\n\n## Requirements\n\n## References\n\n"
            f"- [Product index and lifecycle tracker](../product.md)\n")


def merge(text: str, delta: sc.Delta) -> tuple[str, list[str]]:
    parts = sc.capability_requirements(text)
    if parts is None:
        raise ArchiveError(f"{delta.capability}.md has no '## Requirements' section")
    before, preamble, reqs, after = parts
    rel = f"specs/{delta.path.name}"
    if (delta.ops["MODIFIED"] or delta.ops["REMOVED"]) and not reqs:
        raise ArchiveError(f"{rel}: MODIFIED/REMOVED need {delta.capability}.md in capability-spec-template.md "
                           f"format ('### Requirement: FR-###'); convert it first")
    by_id = {req.fr: req for req in reqs}
    if len(by_id) != len(reqs):
        raise ArchiveError(f"{delta.capability}.md defines a requirement ID more than once")
    log: list[str] = []
    for req in delta.ops["MODIFIED"]:
        if req.fr not in by_id:
            raise ArchiveError(f"{rel}: MODIFIED {req.fr} is not in {delta.capability}.md")
        by_id[req.fr] = req
        log.append(f"MODIFIED {req.fr} {req.name}")
    for req in delta.ops["REMOVED"]:
        if req.fr not in by_id:
            raise ArchiveError(f"{rel}: REMOVED {req.fr} is not in {delta.capability}.md")
        del by_id[req.fr]
        log.append(f"REMOVED {req.fr}")
    ordered = [by_id[r.fr] for r in reqs if r.fr in by_id]
    existing_acs = {ac for r in ordered for ac in r.scenarios}
    for req in delta.ops["ADDED"]:
        if req.fr in by_id or req.fr in {r.fr for r in reqs}:
            raise ArchiveError(f"{rel}: ADDED {req.fr} already exists in {delta.capability}.md")
        clash = set(req.scenarios) & existing_acs
        if clash:
            raise ArchiveError(f"{rel}: ADDED {req.fr} reuses scenario ID(s) {', '.join(sorted(clash))}")
        ordered.append(req)
        existing_acs |= set(req.scenarios)
        log.append(f"ADDED {req.fr} {req.name}")
    if not reqs and preamble.strip() and delta.ops["ADDED"]:
        log.append("note: legacy table kept above the new requirements; convert the file when convenient")
    head = before.rstrip("\n") + "\n\n" + (preamble.strip() + "\n\n" if preamble.strip() else "")
    body = "\n".join(req.text.rstrip() + "\n" for req in ordered)
    return head + body + ("\n" + after.lstrip("\n") if after.strip() else ""), log


def touch(text: str, workspace: Path, feature_id: str, date: str) -> str:
    text = re.sub(r"^\*\*Updated\*\*:.*$", f"**Updated**: {date}", text, count=1, flags=re.M)
    if f".scratch/{workspace.name}/" in text:
        return text
    line = f"- [{workspace.name}](<../../../.scratch/{workspace.name}/>) — `{feature_id}` change, archived {date}."
    match = re.search(r"^## References\s*$", text, re.M)
    if not match:
        return text.rstrip() + f"\n\n## References\n\n{line}\n"
    nxt = re.search(r"^## ", text[match.end():], re.M)
    end = match.end() + nxt.start() if nxt else len(text)
    return text[:end].rstrip() + "\n" + line + "\n" + ("\n" + text[end:] if nxt else "")


def validate(text: str, name: str, delta: sc.Delta) -> None:
    if re.search(r"^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements", text, re.M):
        raise ArchiveError(f"{name}: delta heading left after merge")
    frs = sc.REQ_HEADING.findall(text)
    ids = [fr for fr, _ in frs]
    acs = sc.SCENARIO_HEADING.findall(text)
    ac_ids = [ac for ac, _ in acs]
    for kind, values in (("requirement", ids), ("scenario", ac_ids)):
        dup = sorted({v for v in values if values.count(v) > 1})
        if dup:
            raise ArchiveError(f"{name}: {kind} ID(s) {', '.join(dup)} defined more than once after merge")
    missing = (delta.ids("ADDED", "MODIFIED") - set(ids)) | (delta.ids("REMOVED") & set(ids))
    if missing:
        raise ArchiveError(f"{name}: merge did not apply {', '.join(sorted(missing))}")


def archive(workspace: Path, root: Path, date: str, dry_run: bool) -> int:
    feature_id = sc.feature_id_for(workspace)
    intent = workspace / "intent.md"
    if not intent.is_file():
        raise ArchiveError(f"{workspace.name} has no intent.md")
    status = sc.intent_status(workspace)
    if "Archived" in status:
        raise ArchiveError(f"{workspace.name} is already archived ({status})")
    if "Approved" not in status:
        raise ArchiveError(f"intent.md **Status** must be Approved before archiving (found '{status or 'none'}')")
    paths = sc.delta_files(workspace)
    if not paths:
        raise ArchiveError(f"{workspace.name}/specs/ has no requirement delta to archive")
    deltas = [sc.parse_delta(p) for p in paths]
    errors = [e for d in deltas for e in d.errors]
    if errors:
        raise ArchiveError("\n".join(errors))
    tasks = workspace / "tasks.md"
    if tasks.is_file() and re.search(r"^- \[ \] T\d{3}", tasks.read_text(encoding="utf-8"), re.M):
        print("WARN: tasks.md still has unchecked tasks; archive only delivered scope.", file=sys.stderr)

    writes: dict[Path, str] = {}
    created: list[str] = []
    print(f"Archive {workspace.name}")
    for delta in deltas:
        target = sc.capability_path(root, delta.capability)
        if target.is_file():
            text = target.read_text(encoding="utf-8")
        else:
            if delta.ids("MODIFIED", "REMOVED"):
                raise ArchiveError(f"specs/{delta.path.name}: MODIFIED/REMOVED need an existing {target.name}")
            text = new_capability(delta, date)
            created.append(target.name)
        merged, log = merge(text, delta)
        merged = touch(merged, workspace, feature_id, date)
        validate(merged, target.name, delta)
        writes[target] = merged
        print(f"  {target.relative_to(root).as_posix()}" + (" (new)" if target.name in created else ""))
        for entry in log:
            print(f"    {entry}")

    intent_text = intent.read_text(encoding="utf-8")
    writes[intent] = re.sub(r"^\*\*Status\*\*:.*$", f"**Status**: Archived — {date}", intent_text,
                            count=1, flags=re.M)
    if dry_run:
        print("Dry run: nothing written.")
        return 0
    for path, text in writes.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    print(f"OK: merged {len(deltas)} delta file(s); intent.md is Archived — {date}.")
    for name in created:
        print(f"NEXT: add requirements/{name} to docs/product/product.md, then run check-product-docs.py.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("workspace")
    parser.add_argument("--project-root", default=os.environ.get("HARNESS_PROJECT_ROOT", os.getcwd()))
    parser.add_argument("--date", default=dt.date.today().isoformat())
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.date):
        print("FAIL: --date must be YYYY-MM-DD", file=sys.stderr)
        return 1
    root = Path(args.project_root).resolve()
    workspace = Path(args.workspace)
    workspace = (workspace if workspace.is_absolute() else root / workspace).resolve()
    if not workspace.is_dir():
        print(f"FAIL: workspace does not exist: {workspace}", file=sys.stderr)
        return 1
    try:
        return archive(workspace, root, args.date, args.dry_run)
    except (ArchiveError, ValueError) as exc:
        for line in str(exc).splitlines():
            print(f"FAIL: {line}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
