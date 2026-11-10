#!/usr/bin/env python3
"""Check Codex agent adapter names, model assignments, and role profiles."""

from __future__ import annotations

import argparse
import re
import os
import sys
from pathlib import Path, PurePosixPath

try:  # Python 3.11+
    import tomllib as _toml

    TOMLDecodeError = _toml.TOMLDecodeError
    toml_loads = _toml.loads
except ModuleNotFoundError:  # pragma: no cover - exercised on older interpreters
    try:
        import tomli as _toml  # type: ignore[no-redef]

        TOMLDecodeError = _toml.TOMLDecodeError
        toml_loads = _toml.loads
    except ModuleNotFoundError:
        _toml = None

        class TOMLDecodeError(ValueError):
            """Raised by the fallback parser for TOML outside the adapter subset."""

        _BARE_KEY = re.compile(r"^([A-Za-z0-9_-]+)\s*=\s*(.*)$")
        _ESCAPES = {'"': '"', "\\": "\\", "n": "\n", "t": "\t", "r": "\r", "b": "\b", "f": "\f"}

        def _unescape(text: str, line_no: int) -> str:
            out: list[str] = []
            i = 0
            while i < len(text):
                ch = text[i]
                if ch == "\\":
                    nxt = text[i + 1 : i + 2]
                    if nxt == "\n":  # line-ending backslash trims following whitespace
                        i += 2
                        while i < len(text) and text[i] in " \t\n":
                            i += 1
                        continue
                    if nxt not in _ESCAPES:
                        raise TOMLDecodeError(f"unsupported escape at line {line_no}")
                    out.append(_ESCAPES[nxt])
                    i += 2
                    continue
                out.append(ch)
                i += 1
            return "".join(out)

        def toml_loads(text: str) -> dict:  # type: ignore[misc]
            """Parse the flat key/string subset used by Codex agent adapters."""
            data: dict = {}
            lines = text.splitlines()
            index = 0
            while index < len(lines):
                line_no = index + 1
                raw = lines[index].strip()
                index += 1
                if not raw or raw.startswith("#"):
                    continue
                match = _BARE_KEY.match(raw)
                if not match:
                    raise TOMLDecodeError(f"unsupported TOML at line {line_no}: {raw[:40]}")
                key, value = match.group(1), match.group(2).strip()
                if key in data:
                    raise TOMLDecodeError(f"duplicate key {key!r} at line {line_no}")
                for quote in ('"""', "'''"):
                    if value.startswith(quote):
                        body = value[3:]
                        if body.startswith("\n"):
                            body = body[1:]
                        chunks = [body]
                        while quote not in chunks[-1]:
                            if index >= len(lines):
                                raise TOMLDecodeError(f"unterminated multi-line string for {key!r}")
                            chunks.append(lines[index])
                            index += 1
                        joined = "\n".join(chunks)
                        if not chunks[0] and len(chunks) > 1:
                            joined = "\n".join(chunks[1:])
                        content, _, rest = joined.partition(quote)
                        if rest.strip() and not rest.strip().startswith("#"):
                            raise TOMLDecodeError(f"trailing text after {key!r}")
                        data[key] = _unescape(content, line_no) if quote == '"""' else content
                        break
                else:
                    string = re.fullmatch(r'"((?:[^"\\]|\\.)*)"\s*(#.*)?', value)
                    literal = re.fullmatch(r"'([^']*)'\s*(#.*)?", value)
                    if string:
                        data[key] = _unescape(string.group(1), line_no)
                    elif literal:
                        data[key] = literal.group(1)
                    elif value in ("true", "false"):
                        data[key] = value == "true"
                    elif re.fullmatch(r"[+-]?[0-9]+", value):
                        data[key] = int(value)
                    else:
                        raise TOMLDecodeError(f"unsupported value for {key!r} at line {line_no}")
            return data

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
            data = toml_loads(adapter.read_text(encoding="utf-8"))
        except (OSError, TOMLDecodeError) as exc:
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
    parser.add_argument("root", nargs="?", type=Path, default=Path(os.path.abspath(__file__)).parents[2])
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
