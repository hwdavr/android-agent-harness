#!/usr/bin/env python3
"""Validate persisted OpenPencil identities and explicitly reviewed diff hunks."""

import argparse
import json
import sys
from pathlib import Path


def read_json(path):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
        # `openpencil eval` prints a JSON string when the expression stringifies its result.
        if isinstance(value, str):
            value = json.loads(value)
        return value
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc


def inventory(value, label):
    if not isinstance(value, list) or not value:
        raise ValueError(f"{label} inventory must be a nonempty array")
    result = {}
    for item in value:
        if not isinstance(item, dict):
            raise ValueError(f"{label} inventory item must be an object")
        guid, name, kind, parent = (item.get(k) for k in ("guid", "name", "type", "parent"))
        if not all(isinstance(x, str) and x for x in (guid, name, kind)):
            raise ValueError(f"{label} inventory has missing identity fields")
        if parent is not None and (not isinstance(parent, str) or not parent):
            raise ValueError(f"{label} inventory has invalid parent")
        if guid in result:
            raise ValueError(f"{label} inventory has duplicate GUID: {guid}")
        result[guid] = (name, kind, parent)
    return result


def check(before, after, diff, allowlist):
    old, new = inventory(before, "source"), inventory(after, "candidate")
    for guid, identity in old.items():
        if guid not in new:
            raise ValueError(f"missing original GUID: {guid}")
        if new[guid] != identity:
            raise ValueError(f"original identity changed: {guid}")
    if not isinstance(diff, dict) or diff.get("changed") is not True:
        raise ValueError("diff must report a change")
    pages, body = diff.get("pages"), diff.get("diff")
    if not isinstance(pages, list) or not pages or not isinstance(body, str) or not body.strip():
        raise ValueError("diff must contain pages and a nonempty body")
    if any(not isinstance(p, dict) or p.get("status") not in {"changed", "unchanged", "added", "removed"}
           or not isinstance(p.get("name"), str) or not isinstance(p.get("diff"), str) for p in pages):
        raise ValueError("unsupported page diff structure")
    if not isinstance(allowlist, list) or not allowlist or any(
        not isinstance(h, str) or not h.startswith("@@ ") for h in allowlist
    ):
        raise ValueError("allowlist must be a nonempty array of exact diff hunk headers")
    if len(set(allowlist)) != len(allowlist):
        raise ValueError("allowlist has duplicate hunk headers")
    headers = [line for line in body.splitlines() if line.startswith("@@ ")]
    if not headers or len(set(headers)) != len(headers):
        raise ValueError("diff has missing or duplicate hunk headers")
    if set(headers) != set(allowlist):
        raise ValueError(f"unexpected or missing diff hunks: {sorted(set(headers) ^ set(allowlist))}")
    page_text = "\n".join(p["diff"] for p in pages if p["diff"].strip())
    if page_text != body:
        raise ValueError("page diffs do not match the aggregate diff")
    return len(old), len(headers)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True)
    parser.add_argument("--after", required=True)
    parser.add_argument("--diff", required=True)
    parser.add_argument("--allowlist", required=True)
    args = parser.parse_args()
    try:
        count, hunks = check(*(read_json(getattr(args, name)) for name in
                               ("before", "after", "diff", "allowlist")))
    except ValueError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(f"PASS: {count} original source GUIDs preserved; {hunks} reviewed diff hunks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
