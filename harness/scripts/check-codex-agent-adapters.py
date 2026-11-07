#!/usr/bin/env python3
"""Check Codex agent adapter names, model assignments, and role profiles."""

from __future__ import annotations

import argparse
import re
import sys
import tomllib
from pathlib import Path, PurePosixPath

EXPECTED = {
    "planner": ("gpt-6.1-sol", ".agents/agents/planner.md"),
    "implementer": ("gpt-6.1-terra", ".agents/agents/generator.md"),
    "tester": ("gpt-6-luna", ".agents/agents/tester.md"),
    "evaluator": ("gpt-6.1-sol", ".agents/agents/evaluator.md"),
}
PROFILE_REFERENCE = re.compile(r"(?<![A-Za-z0-9_./-])\.agents/[A-Za-z0-9_./-]+\.md")


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    adapter_dir = root / ".codex" / "agents"
    for role, (model, profile) in EXPECTED.items():
        adapter = adapter_dir / f"{role}.toml"
        if not adapter.is_file():
            errors.append(f"missing adapter: {adapter.relative_to(root)}")
            continue
        try:
            data = tomllib.loads(adapter.read_text(encoding="utf-8"))
        except (OSError, tomllib.TOMLDecodeError) as exc:
            errors.append(f"invalid TOML in {adapter.relative_to(root)}: {exc}")
            continue
        if data.get("name") != role:
            errors.append(f"{role}: name must be {role!r}")
        description = data.get("description")
        if not isinstance(description, str) or not description.strip():
            errors.append(f"{role}: description must be non-empty text")
        if data.get("model") != model:
            errors.append(f"{role}: model must be {model!r}")
        instructions = data.get("developer_instructions")
        if not isinstance(instructions, str) or not instructions.strip():
            errors.append(f"{role}: developer_instructions must be non-empty text")
            continue
        refs = PROFILE_REFERENCE.findall(instructions)
        if profile not in refs:
            errors.append(f"{role}: instructions must reference {profile}")
        for ref in refs:
            relative = PurePosixPath(ref)
            if relative.is_absolute() or ".." in relative.parts:
                errors.append(f"{role}: profile reference is not portable: {ref}")
            elif not (root / Path(*relative.parts)).is_file():
                errors.append(f"{role}: referenced profile does not exist: {ref}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("PASS: four adapter TOMLs match required names, non-empty descriptions, models, and portable role profile references.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
