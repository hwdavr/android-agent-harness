#!/usr/bin/env python3
"""Test helper: print the implementation-plan '## Product Requirements' table for a change workspace.

Usage: python3 change_fixture.py <workspace> [approver]
Prints one row each for intent.md, design.md, and every specs/<capability>.md, with the current
SHA-256 (as spec_change.artifact_hash computes it), so fixtures record a valid approval.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import spec_change  # noqa: E402

workspace = Path(sys.argv[1])
approver = sys.argv[2] if len(sys.argv) > 2 else "user, 2026-11-09"
print("| Artifact | Capability file | Requirement IDs | Approved SHA-256 | Approved by / date |")
print("|---|---|---|---|---|")
for name in ("intent.md", "design.md"):
    path = workspace / name
    if path.is_file():
        print(f"| `{name}` | — | — | `{spec_change.artifact_hash(path)}` | {approver} |")
for path in spec_change.delta_files(workspace):
    delta = spec_change.parse_delta(path)
    ids = ", ".join(f"{op} {', '.join(sorted(delta.ids(op)))}" for op in spec_change.OPS if delta.ids(op))
    print(f"| `specs/{path.name}` | `docs/product/requirements/{path.name}` | {ids} | "
          f"`{spec_change.artifact_hash(path)}` | {approver} |")
