#!/usr/bin/env python3
"""Apply the harness artifact retention rule (.agents/rules/artifact-retention.md).

Dry-run by default; pass --apply to delete. Never touches git-tracked files, the
written record of a workspace (Markdown, JSON, YAML, design files), or evidence
that an open workspace still references.

  python3 harness/scripts/prune-harness-artifacts.py                 # report only
  python3 harness/scripts/prune-harness-artifacts.py --apply         # prune
  python3 harness/scripts/prune-harness-artifacts.py --apply \
      --rotate-log ~/Library/Logs/com.notesapp.harness-generator.log  # also rotate the scheduler log

Exit codes: 0 success, 1 configuration error (tracker missing or unreadable).
"""

import argparse
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

TRACKER_START = "<!-- HARNESS_TRACKER_START -->"
TRACKER_END = "<!-- HARNESS_TRACKER_END -->"
TRACKER_HEADER = "| ID | Feature | Workspace | Status | Updated | Notes |"

# Raw runtime output that a Complete workspace no longer needs. The written record
# (summaries, plans, contracts, feature_list.json, ui_verification.json, receipts)
# is never in this list.
BULKY_SUFFIXES = (".log", ".apk", ".aab", ".mp4", ".webm", ".ndjson", ".hprof", ".trace", ".logcat")
# Files scanned for QA-run references inside open workspaces. Logs count: an evidence
# receipt can point at a log that in turn names the run it came from.
TEXT_SUFFIXES = (".md", ".json", ".yaml", ".yml", ".txt", ".log")
QA_AREAS_WITH_RUN_SUBDIRS = ("android-instrumented",)


def fail(message):
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def human(size):
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} GB"


def path_size(path):
    if path.is_file() or path.is_symlink():
        return path.lstat().st_size
    return sum(p.lstat().st_size for p in path.rglob("*") if p.is_file() and not p.is_symlink())


def newest_mtime(path):
    if path.is_file():
        return path.stat().st_mtime
    mtimes = [p.stat().st_mtime for p in path.rglob("*") if p.is_file() and not p.is_symlink()]
    return max(mtimes, default=path.stat().st_mtime)


def git_tracked(root):
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z", ".scratch", ".qa-artifacts"],
            check=True, capture_output=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return {root / p for p in out.decode().split("\0") if p}


def read_tracker(root):
    product = root / "docs/product/product.md"
    if not product.is_file():
        fail(f"{product} does not exist; cannot tell which workspaces are Complete.")
    text = product.read_text(encoding="utf-8")
    if text.count(TRACKER_START) != 1 or text.count(TRACKER_END) != 1:
        fail("Harness Feature Tracker markers are missing or duplicated.")
    block = text.split(TRACKER_START, 1)[1].split(TRACKER_END, 1)[0]
    rows, in_table = {}, False
    for line in block.splitlines():
        if line.strip() == TRACKER_HEADER:
            in_table = True
            continue
        if not in_table or not line.startswith("|") or set(line) <= set("|-: "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4:
            continue
        match = re.search(r"\.scratch/([^/)\s`|]+)", cells[2])
        if match:
            rows[match.group(1)] = cells[3]
    if not in_table:
        fail("Harness Feature Tracker header not found.")
    return rows


def open_workspace_text(root, statuses):
    """Concatenated text of every workspace that is not Complete (tracked or not)."""
    chunks = []
    scratch = root / ".scratch"
    if not scratch.is_dir():
        return ""
    for workspace in sorted(p for p in scratch.iterdir() if p.is_dir()):
        if statuses.get(workspace.name) == "Complete":
            continue
        for f in workspace.rglob("*"):
            if f.is_file() and f.suffix in TEXT_SUFFIXES and f.stat().st_size < 5_000_000:
                try:
                    chunks.append(f.read_text(encoding="utf-8", errors="ignore"))
                except OSError:
                    pass
    return "\n".join(chunks)


def plan_scratch(root, statuses, tracked, min_age):
    """Bulky untracked files inside Complete workspaces."""
    plan, scratch, now = [], root / ".scratch", time.time()
    for name, status in sorted(statuses.items()):
        workspace = scratch / name
        if status != "Complete" or not workspace.is_dir():
            continue
        for f in sorted(workspace.rglob("*")):
            if not f.is_file() or f.suffix.lower() not in BULKY_SUFFIXES:
                continue
            if tracked is not None and f in tracked:
                continue
            if now - f.stat().st_mtime < min_age:
                continue
            plan.append((f, f"Complete workspace {name}"))
    return plan


def qa_runs(qa_root):
    runs = []
    if not qa_root.is_dir():
        return runs
    for entry in qa_root.iterdir():
        if entry.name.startswith("."):
            continue
        if entry.is_dir() and entry.name in QA_AREAS_WITH_RUN_SUBDIRS:
            runs.extend(p for p in entry.iterdir() if p.is_dir())
        elif entry.is_dir():
            runs.append(entry)
    return runs


def plan_qa(root, open_text, tracked, keep_runs, min_age):
    """Old .qa-artifacts runs that no open workspace references."""
    plan, now = [], time.time()
    groups = {}
    for run in qa_runs(root / ".qa-artifacts"):
        groups.setdefault(run.parent, []).append(run)
    for parent, runs in groups.items():
        runs.sort(key=newest_mtime, reverse=True)
        for index, run in enumerate(runs):
            rel = run.relative_to(root).as_posix()
            if index < keep_runs:
                continue
            if now - newest_mtime(run) < min_age:
                continue
            if rel in open_text or f"/{run.name}" in open_text or f"`{run.name}`" in open_text:
                continue
            if tracked is not None and any(t == run or run in t.parents for t in tracked):
                continue
            plan.append((run, "unreferenced QA run beyond the newest kept runs"))
    return plan


def rotate_log(log_path, max_bytes, keep, apply):
    log_path = Path(log_path).expanduser()
    if not log_path.is_file() or log_path.stat().st_size <= max_bytes:
        return
    print(f"ROTATE {log_path} ({human(log_path.stat().st_size)} > {human(max_bytes)}; keep {keep})")
    if not apply:
        return
    for i in range(keep, 0, -1):
        older = log_path.with_name(f"{log_path.name}.{i}")
        if i == keep and older.exists():
            older.unlink()
        elif older.exists():
            older.rename(log_path.with_name(f"{log_path.name}.{i + 1}"))
    if keep > 0:
        shutil.copy2(log_path, log_path.with_name(f"{log_path.name}.1"))
    # Truncate in place: launchd keeps the file open in append mode.
    with open(log_path, "r+") as handle:
        handle.truncate(0)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--apply", action="store_true", help="delete; default is a dry run")
    parser.add_argument("--keep-runs", type=int, default=5, help="newest QA runs kept per area (default 5)")
    parser.add_argument("--min-age-days", type=float, default=14, help="never prune anything newer (default 14)")
    parser.add_argument("--rotate-log", help="scheduler log to rotate")
    parser.add_argument("--log-max-mb", type=float, default=5)
    parser.add_argument("--log-keep", type=int, default=3)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    min_age = args.min_age_days * 86400
    statuses = read_tracker(root)
    tracked = git_tracked(root)
    open_text = open_workspace_text(root, statuses)

    plan = plan_scratch(root, statuses, tracked, min_age)
    plan += plan_qa(root, open_text, tracked, args.keep_runs, min_age)

    verb = "DELETE" if args.apply else "WOULD DELETE"
    total = 0
    for path, reason in plan:
        size = path_size(path)
        total += size
        print(f"{verb} {path.relative_to(root)} ({human(size)}) — {reason}")
        if args.apply:
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink()

    if args.rotate_log:
        rotate_log(args.rotate_log, int(args.log_max_mb * 1024 * 1024), args.log_keep, args.apply)

    mode = "pruned" if args.apply else "prunable (dry run; pass --apply)"
    print(f"OK  {len(plan)} item(s), {human(total)} {mode}.")


if __name__ == "__main__":
    main()
