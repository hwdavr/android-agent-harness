#!/usr/bin/env python3
"""AST-backed checks for the Kotlin-facing repository harness validators.

The harness is intentionally dependency-free.  This module tokenizes Kotlin
source and builds the structural part of its syntax tree that the repository's
rules need: declarations, calls, properties, imports, annotations, and paired
delimited scopes.  Comments and string/character literals are single tokens,
so rule visitors never inspect their contents as Kotlin code.

By default, repository-root scans are limited to changed, staged, or untracked
Kotlin files; pass ``--all`` for an explicit full-source baseline scan.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Iterator, Optional, Sequence


KEYWORDS = {
    "as",
    "break",
    "by",
    "catch",
    "class",
    "companion",
    "const",
    "constructor",
    "continue",
    "data",
    "do",
    "else",
    "enum",
    "false",
    "finally",
    "for",
    "fun",
    "if",
    "import",
    "in",
    "interface",
    "is",
    "object",
    "open",
    "operator",
    "out",
    "override",
    "package",
    "private",
    "protected",
    "public",
    "sealed",
    "super",
    "suspend",
    "this",
    "throw",
    "true",
    "try",
    "typealias",
    "typeof",
    "val",
    "var",
    "vararg",
    "when",
    "where",
    "while",
}

CALL_KEYWORD_EXCLUSIONS = KEYWORDS | {
    "actual",
    "expect",
    "field",
    "file",
    "init",
    "param",
    "property",
    "receiver",
    "return",
    "set",
    "setparam",
}

MULTI_CHAR_OPERATORS = (
    "===",
    "!==",
    "...",
    "::",
    "?.",
    "!!",
    "==",
    "!=",
    ">=",
    "<=",
    "->",
    "+=",
    "-=",
    "*=",
    "/=",
    "%=",
    "&&",
    "||",
    "++",
    "--",
    "..",
    "..<",
)


@dataclass(frozen=True)
class Token:
    kind: str
    text: str
    line: int
    column: int
    start: int
    end: int

    @property
    def is_identifier(self) -> bool:
        return self.kind in {"identifier", "keyword"}

    @property
    def is_string(self) -> bool:
        return self.kind == "string"


def _is_identifier_start(char: str) -> bool:
    return char == "_" or char.isalpha()


def _is_identifier_part(char: str) -> bool:
    return char == "_" or char.isalnum()


def _advance_position(text: str, line: int, column: int) -> tuple[int, int]:
    newlines = text.count("\n")
    if newlines:
        return line + newlines, len(text.rsplit("\n", 1)[-1]) + 1
    return line, column + len(text)


def lex_kotlin(source: str) -> list[Token]:
    """Lex Kotlin while keeping source locations and hiding non-code text."""

    tokens: list[Token] = []
    index = 0
    line = 1
    column = 1
    length = len(source)

    def consume(end: int, kind: str, text: Optional[str] = None) -> None:
        nonlocal index, line, column
        value = source[index:end] if text is None else text
        tokens.append(Token(kind, value, line, column, index, end))
        line, column = _advance_position(source[index:end], line, column)
        index = end

    while index < length:
        char = source[index]

        if char.isspace():
            end = index + 1
            while end < length and source[end].isspace():
                end += 1
            line, column = _advance_position(source[index:end], line, column)
            index = end
            continue

        if source.startswith("//", index):
            end = source.find("\n", index)
            if end < 0:
                end = length
            line, column = _advance_position(source[index:end], line, column)
            index = end
            continue

        if source.startswith("/*", index):
            end = index + 2
            depth = 1
            while end < length and depth:
                if source.startswith("/*", end):
                    depth += 1
                    end += 2
                elif source.startswith("*/", end):
                    depth -= 1
                    end += 2
                else:
                    end += 1
            line, column = _advance_position(source[index:end], line, column)
            index = end
            continue

        if source.startswith('"""', index):
            end = source.find('"""', index + 3)
            if end < 0:
                end = length
            else:
                end += 3
            raw_value = source[index + 3 : end - 3] if end <= length and source[end - 3 : end] == '"""' else source[index + 3 : end]
            consume(end, "string", raw_value)
            continue

        if char == '"':
            end = index + 1
            escaped = False
            while end < length:
                current = source[end]
                if current == '"' and not escaped:
                    end += 1
                    break
                if current == "\n" and not escaped:
                    break
                if current == "\\" and not escaped:
                    escaped = True
                else:
                    escaped = False
                end += 1
            raw_value = source[index + 1 : end - 1] if end > index and source[end - 1 : end] == '"' else source[index + 1 : end]
            consume(end, "string", raw_value)
            continue

        if char == "'":
            end = index + 1
            escaped = False
            while end < length:
                current = source[end]
                if current == "'" and not escaped:
                    end += 1
                    break
                if current == "\\" and not escaped:
                    escaped = True
                else:
                    escaped = False
                end += 1
            consume(end, "character")
            continue

        if char == "`":
            end = source.find("`", index + 1)
            end = length if end < 0 else end + 1
            consume(end, "identifier", source[index + 1 : end - 1] if end <= length and source[end - 1 : end] == "`" else source[index + 1 : end])
            continue

        if _is_identifier_start(char):
            end = index + 1
            while end < length and _is_identifier_part(source[end]):
                end += 1
            value = source[index:end]
            consume(end, "keyword" if value in KEYWORDS else "identifier", value)
            continue

        if char.isdigit():
            end = index + 1
            while end < length and (source[end].isalnum() or source[end] in "._"):
                end += 1
            consume(end, "number")
            continue

        matched_operator = next((operator for operator in MULTI_CHAR_OPERATORS if source.startswith(operator, index)), None)
        if matched_operator is not None:
            consume(index + len(matched_operator), "operator", matched_operator)
            continue

        consume(index + 1, "punctuation", char)

    return tokens


@dataclass
class FunctionNode:
    name: str
    keyword_index: int
    name_index: int
    parameter_open: Optional[int]
    parameter_close: Optional[int]
    body_open: Optional[int]
    body_close: Optional[int]
    expression_end: int
    annotations: set[str] = field(default_factory=set)
    parent_class: Optional["ClassNode"] = None

    @property
    def body_start(self) -> int:
        return self.body_open if self.body_open is not None else self.keyword_index

    @property
    def body_end(self) -> int:
        if self.body_close is not None:
            return self.body_close
        return self.expression_end


@dataclass
class ClassNode:
    name: str
    keyword_index: int
    name_index: int
    body_open: Optional[int]
    body_close: Optional[int]
    annotations: set[str] = field(default_factory=set)
    modifiers: set[str] = field(default_factory=set)
    header_end: int = 0

    @property
    def body_start(self) -> int:
        return self.body_open if self.body_open is not None else self.keyword_index

    @property
    def body_end(self) -> int:
        if self.body_close is not None:
            return self.body_close
        return self.header_end


@dataclass
class CallNode:
    name: str
    name_index: int
    open_index: int
    close_index: int
    chain_start: int
    qualifier: tuple[str, ...]

    @property
    def start_index(self) -> int:
        return self.chain_start


@dataclass
class PropertyNode:
    name: str
    declaration_index: int
    name_index: int
    type_start: Optional[int]
    type_end: Optional[int]
    initializer_start: Optional[int]
    initializer_end: Optional[int]
    enclosing_class: Optional[ClassNode] = None
    enclosing_function: Optional[FunctionNode] = None


@dataclass
class ImportNode:
    path: str
    import_index: int


def _build_delimiter_pairs(tokens: Sequence[Token]) -> dict[int, int]:
    pairs: dict[int, int] = {}
    stack: list[tuple[str, int]] = []
    closing = {")": "(",
        "]": "[",
        "}": "{",
    }
    for index, token in enumerate(tokens):
        if token.text in ("(", "[", "{"):
            stack.append((token.text, index))
        elif token.text in closing:
            expected = closing[token.text]
            if stack and stack[-1][0] == expected:
                _, opening_index = stack.pop()
                pairs[opening_index] = index
                pairs[index] = opening_index
    return pairs


def _previous_boundary(tokens: Sequence[Token], index: int) -> int:
    boundary_tokens = {";", "{", "}"}
    while index >= 0 and tokens[index].text not in boundary_tokens:
        index -= 1
    return index + 1


def _annotations_before(tokens: Sequence[Token], index: int) -> set[str]:
    annotations: set[str] = set()
    start = _previous_boundary(tokens, index - 1)
    cursor = start
    while cursor < index:
        if tokens[cursor].text == "@" and cursor + 1 < index and tokens[cursor + 1].is_identifier:
            annotation_parts = [tokens[cursor + 1].text]
            next_index = cursor + 2
            while next_index + 1 < index and tokens[next_index].text == "." and tokens[next_index + 1].is_identifier:
                annotation_parts.append(tokens[next_index + 1].text)
                next_index += 2
            annotations.add(annotation_parts[-1])
            annotations.add(".".join(annotation_parts))
        cursor += 1
    return annotations


def _find_next_identifier(tokens: Sequence[Token], start: int, end: int) -> Optional[int]:
    for index in range(start, min(end, len(tokens))):
        if tokens[index].is_identifier and tokens[index].text not in KEYWORDS:
            return index
    return None


def _line_end_index(tokens: Sequence[Token], start: int) -> int:
    if start >= len(tokens):
        return start
    line = tokens[start].line
    index = start
    while index + 1 < len(tokens) and tokens[index + 1].line == line:
        index += 1
    return index


class KotlinFile:
    """A small syntax tree facade for one Kotlin source file."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.source = path.read_text(encoding="utf-8")
        self.tokens = lex_kotlin(self.source)
        self.pairs = _build_delimiter_pairs(self.tokens)
        self.classes = self._parse_classes()
        self.functions = self._parse_functions()
        self.calls = self._parse_calls()
        self.properties = self._parse_properties()
        self.imports = self._parse_imports()
        self.package_name = self._parse_package_name()
        self._assign_enclosing_nodes()

    def line(self, token_index: int) -> int:
        if not self.tokens:
            return 1
        token_index = max(0, min(token_index, len(self.tokens) - 1))
        return self.tokens[token_index].line

    def token_text(self, start: int, end: int) -> str:
        return " ".join(token.text for token in self.tokens[start:end])

    def _parse_classes(self) -> list[ClassNode]:
        classes: list[ClassNode] = []
        for keyword_index, token in enumerate(self.tokens):
            if token.text != "class":
                continue
            name_index = _find_next_identifier(self.tokens, keyword_index + 1, len(self.tokens))
            if name_index is None:
                continue
            body_open = None
            search_end = len(self.tokens)
            for index in range(name_index + 1, len(self.tokens)):
                if self.tokens[index].text in {";", "class", "fun"} and self.tokens[index].line > token.line:
                    search_end = index
                    break
                if self.tokens[index].text == "{":
                    body_open = index
                    break
            body_close = self.pairs.get(body_open) if body_open is not None else None
            header_end = body_open if body_open is not None else search_end
            modifier_start = _previous_boundary(self.tokens, keyword_index - 1)
            modifiers = {
                candidate.text
                for candidate in self.tokens[modifier_start:keyword_index]
                if candidate.text in {"data", "enum", "sealed", "private", "protected", "public", "internal", "open", "abstract"}
            }
            classes.append(
                ClassNode(
                    name=self.tokens[name_index].text,
                    keyword_index=keyword_index,
                    name_index=name_index,
                    body_open=body_open,
                    body_close=body_close,
                    annotations=_annotations_before(self.tokens, keyword_index),
                    modifiers=modifiers,
                    header_end=header_end,
                )
            )
        return classes

    def _parse_functions(self) -> list[FunctionNode]:
        functions: list[FunctionNode] = []
        for keyword_index, token in enumerate(self.tokens):
            if token.text != "fun":
                continue
            parameter_open = None
            name_index = None
            for index in range(keyword_index + 1, len(self.tokens)):
                if self.tokens[index].text in {"{", "}", ";"}:
                    break
                if self.tokens[index].text == "(":
                    parameter_open = index
                    if index > keyword_index + 1 and self.tokens[index - 1].is_identifier:
                        name_index = index - 1
                    break
            if parameter_open is None or name_index is None:
                continue
            parameter_close = self.pairs.get(parameter_open)
            if parameter_close is None:
                continue
            body_open = None
            expression_end = parameter_close
            cursor = parameter_close + 1
            while cursor < len(self.tokens):
                if self.tokens[cursor].text == "{":
                    body_open = cursor
                    break
                if self.tokens[cursor].text == "=":
                    expression_end = _line_end_index(self.tokens, cursor)
                    break
                if self.tokens[cursor].text in {";", "}"}:
                    expression_end = cursor
                    break
                if self.tokens[cursor].line > self.tokens[parameter_close].line and self.tokens[cursor].text == "fun":
                    expression_end = cursor
                    break
                cursor += 1
            body_close = self.pairs.get(body_open) if body_open is not None else None
            if body_open is not None and body_close is not None:
                expression_end = body_close
            functions.append(
                FunctionNode(
                    name=self.tokens[name_index].text,
                    keyword_index=keyword_index,
                    name_index=name_index,
                    parameter_open=parameter_open,
                    parameter_close=parameter_close,
                    body_open=body_open,
                    body_close=body_close,
                    expression_end=expression_end,
                    annotations=_annotations_before(self.tokens, keyword_index),
                )
            )
        return functions

    def _parse_calls(self) -> list[CallNode]:
        calls: list[CallNode] = []
        for open_index, token in enumerate(self.tokens):
            if token.text != "(" or open_index == 0:
                continue
            name_index = open_index - 1
            if not self.tokens[name_index].is_identifier:
                continue
            name = self.tokens[name_index].text
            if name in CALL_KEYWORD_EXCLUSIONS:
                continue
            close_index = self.pairs.get(open_index)
            if close_index is None:
                continue
            chain_start = name_index
            qualifier: list[str] = []
            cursor = name_index - 1
            while cursor >= 1 and self.tokens[cursor].text in {".", "?."} and self.tokens[cursor - 1].is_identifier:
                qualifier.insert(0, self.tokens[cursor - 1].text)
                chain_start = cursor - 1
                cursor -= 2
            if cursor >= 0 and self.tokens[cursor].text == "fun":
                continue
            calls.append(
                CallNode(
                    name=name,
                    name_index=name_index,
                    open_index=open_index,
                    close_index=close_index,
                    chain_start=chain_start,
                    qualifier=tuple(qualifier),
                )
            )
        return calls

    def _parse_properties(self) -> list[PropertyNode]:
        properties: list[PropertyNode] = []
        for declaration_index, token in enumerate(self.tokens):
            if token.text not in {"val", "var"} or declaration_index + 1 >= len(self.tokens):
                continue
            name_index = declaration_index + 1
            if not self.tokens[name_index].is_identifier:
                continue
            cursor = name_index + 1
            type_start = None
            type_end = None
            initializer_start = None
            initializer_end = None
            if cursor < len(self.tokens) and self.tokens[cursor].text == ":":
                type_start = cursor + 1
                cursor = type_start
                while cursor < len(self.tokens) and self.tokens[cursor].text not in {"=", ";", "{"}:
                    if self.tokens[cursor].line > self.tokens[name_index].line and self.tokens[cursor].text in {"val", "var", "fun"}:
                        break
                    cursor += 1
                type_end = cursor
            if cursor < len(self.tokens) and self.tokens[cursor].text == "=":
                initializer_start = cursor + 1
                initializer_end = self._expression_end(initializer_start)
            properties.append(
                PropertyNode(
                    name=self.tokens[name_index].text,
                    declaration_index=declaration_index,
                    name_index=name_index,
                    type_start=type_start,
                    type_end=type_end,
                    initializer_start=initializer_start,
                    initializer_end=initializer_end,
                )
            )
        return properties

    def _expression_end(self, start: int) -> int:
        if start >= len(self.tokens):
            return start
        depth = 0
        index = start
        while index < len(self.tokens):
            token = self.tokens[index].text
            if token in ("(", "[", "{"):
                depth += 1
            elif token in (")", "]", "}"):
                if depth == 0:
                    return index
                depth -= 1
            if depth == 0 and token == ";":
                return index
            if depth == 0 and index > start and self.tokens[index].line > self.tokens[index - 1].line:
                if token in {"val", "var", "fun", "class", "object", "return"}:
                    return index
            index += 1
        return index

    def _parse_imports(self) -> list[ImportNode]:
        imports: list[ImportNode] = []
        for index, token in enumerate(self.tokens):
            if token.text != "import":
                continue
            end = index + 1
            parts: list[str] = []
            while end < len(self.tokens) and self.tokens[end].line == token.line:
                if self.tokens[end].text == "as":
                    break
                if self.tokens[end].text != ".":
                    parts.append(self.tokens[end].text)
                end += 1
            imports.append(ImportNode(".".join(parts), index))
        return imports

    def _parse_package_name(self) -> str:
        for index, token in enumerate(self.tokens):
            if token.text != "package":
                continue
            end = index + 1
            parts: list[str] = []
            while end < len(self.tokens) and self.tokens[end].line == token.line:
                if self.tokens[end].text != ".":
                    parts.append(self.tokens[end].text)
                end += 1
            return ".".join(parts)
        return ""

    def _assign_enclosing_nodes(self) -> None:
        for function in self.functions:
            containing = [candidate for candidate in self.classes if candidate.body_start < function.keyword_index < candidate.body_end]
            function.parent_class = max(containing, key=lambda candidate: candidate.body_start, default=None)
        for prop in self.properties:
            containing_classes = [candidate for candidate in self.classes if candidate.body_start < prop.declaration_index < candidate.body_end]
            containing_functions = [candidate for candidate in self.functions if candidate.body_start < prop.declaration_index < candidate.body_end]
            prop.enclosing_class = max(containing_classes, key=lambda candidate: candidate.body_start, default=None)
            prop.enclosing_function = max(containing_functions, key=lambda candidate: candidate.body_start, default=None)

    def enclosing_function(self, token_index: int) -> Optional[FunctionNode]:
        candidates = [function for function in self.functions if function.body_start < token_index < function.body_end]
        return max(candidates, key=lambda candidate: candidate.body_start, default=None)

    def enclosing_class(self, token_index: int) -> Optional[ClassNode]:
        candidates = [candidate for candidate in self.classes if candidate.body_start < token_index < candidate.body_end]
        return max(candidates, key=lambda candidate: candidate.body_start, default=None)

    def tokens_between(self, start: int, end: int) -> Sequence[Token]:
        return self.tokens[max(0, start) : min(len(self.tokens), end)]


def iter_files(root: Path, suffix: str = ".kt") -> Iterator[Path]:
    if not root.is_dir():
        return
    yield from sorted(path for path in root.rglob(f"*{suffix}") if path.is_file())


def project_relative(path: Path, project_root: Path) -> str:
    try:
        return path.resolve().relative_to(project_root.resolve()).as_posix()
    except ValueError:
        return str(path)


def changed_files(project_root: Path, source_root: Path) -> list[Path]:
    try:
        commands = (
            ("git", "diff", "--name-only", "--diff-filter=d", "HEAD"),
            ("git", "diff", "--name-only", "--cached", "--diff-filter=d"),
            ("git", "ls-files", "--others", "--exclude-standard"),
        )
        names: set[str] = set()
        for command in commands:
            result = subprocess.run(command, cwd=project_root, capture_output=True, text=True, check=False)
            if result.returncode == 0:
                names.update(line.strip() for line in result.stdout.splitlines() if line.strip().endswith(".kt"))
        source_root = source_root.resolve()
        paths = []
        for name in sorted(names):
            candidate = (project_root / name).resolve()
            if candidate.is_file() and source_root in candidate.parents:
                paths.append(candidate)
        return paths
    except OSError:
        return []


def collect_files(project_root: Path, source_root: Path, scan_all: bool) -> list[Path]:
    if not scan_all and path_is_under(source_root, project_root) and (project_root / ".git").exists():
        return changed_files(project_root, source_root)
    return list(iter_files(source_root))


def parse_files(paths: Iterable[Path]) -> list[KotlinFile]:
    parsed: list[KotlinFile] = []
    for path in paths:
        try:
            parsed.append(KotlinFile(path))
        except (OSError, UnicodeError) as error:
            print(f"WARN: unable to parse {path}: {error}", file=sys.stderr)
    return parsed


def named_argument_ranges(source_file: KotlinFile, call: CallNode) -> list[tuple[str, int, int]]:
    """Return top-level named argument name and value token ranges."""

    tokens = source_file.tokens
    result: list[tuple[str, int, int]] = []
    cursor = call.open_index + 1
    segment_start = cursor
    stack: list[str] = []
    while cursor < call.close_index:
        text = tokens[cursor].text
        if text in ("(", "[", "{"):
            stack.append(text)
        elif text in (")", "]", "}"):
            if stack:
                stack.pop()
        elif text == "," and not stack:
            _append_named_argument(tokens, segment_start, cursor, result)
            segment_start = cursor + 1
        cursor += 1
    _append_named_argument(tokens, segment_start, call.close_index, result)
    return result


def _append_named_argument(tokens: Sequence[Token], start: int, end: int, result: list[tuple[str, int, int]]) -> None:
    if start >= end:
        return
    stack: list[str] = []
    for index in range(start, end):
        text = tokens[index].text
        if text in ("(", "[", "{"):
            stack.append(text)
        elif text in (")", "]", "}"):
            if stack:
                stack.pop()
        elif text == "=" and not stack and index > start and tokens[index - 1].is_identifier:
            result.append((tokens[index - 1].text, index + 1, end))
            return


def token_has_string_template(token: Token, names: Optional[set[str]] = None) -> bool:
    if not token.is_string or "$" not in token.text:
        return False
    if names is None:
        return True
    return any(re.search(rf"(?:\$|\$\{{)\s*{re.escape(name)}\b", token.text) for name in names)


def source_line(source_file: KotlinFile, token_index: int) -> int:
    return source_file.line(token_index)


class Violation:
    def __init__(self, path: Path, line: int, message: str, project_root: Path) -> None:
        self.path = project_relative(path, project_root)
        self.line = line
        self.message = message

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.message}"


class Result:
    def __init__(self, project_root: Path) -> None:
        self.project_root = project_root
        self.violations: list[Violation] = []

    def add(self, source_file: KotlinFile, token_index: int, message: str) -> None:
        self.violations.append(Violation(source_file.path, source_line(source_file, token_index), message, self.project_root))

    def add_path(self, path: Path, line: int, message: str) -> None:
        self.violations.append(Violation(path, line, message, self.project_root))

    def sorted(self) -> list[Violation]:
        return sorted(self.violations, key=lambda violation: (violation.path, violation.line, violation.message))


def print_rule(title: str, violations: Sequence[Violation]) -> None:
    print(f"  Rule: {title}")
    if not violations:
        print("    ✓ No violations")
        return
    for violation in violations:
        print(f"    ✗ {violation}")


def visit_rule(result: Result, title: str, visitor) -> None:
    before = len(result.violations)
    visitor()
    print_rule(title, result.violations[before:])


def finish(result: Result, label: str) -> int:
    print("\n======================================================")
    if result.violations:
        print(f"  ✗ {len(result.violations)} violation(s) found — see above")
        print("======================================================")
        return 1
    print(f"  ✓ All {label} rules passed — 0 violations")
    print("======================================================")
    return 0


def add_common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--project-root", type=Path, default=None)
    parser.add_argument("--source-root", type=Path, default=None)
    parser.add_argument("--all", action="store_true", dest="scan_all")


def parse_common_files(args: argparse.Namespace) -> tuple[Path, Path, list[KotlinFile]]:
    script_root = repository_root()
    project_root = (args.project_root or script_root).resolve()
    source_argument = args.source_root or args.source_root_arg
    source_root = (source_argument or project_root / "app" / "src" / "main" / "java").resolve()
    files = collect_files(project_root, source_root, args.scan_all)
    return project_root, source_root, parse_files(files)


def repository_root() -> Path:
    script_path = Path(__file__).resolve()
    for candidate in (script_path.parent, *script_path.parents):
        if (candidate / "settings.gradle.kts").is_file() and (candidate / ".git").exists():
            return candidate
    return script_path.parents[2]


def path_is_under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def derive_base_package(source_root: Path) -> Path:
    candidates = [source_root]
    if source_root.is_dir():
        candidates.extend(sorted((candidate for candidate in source_root.rglob("*") if candidate.is_dir()), key=lambda candidate: str(candidate)))
    for candidate in candidates:
        if any((candidate / layer).is_dir() for layer in ("ui", "domain", "data")):
            return candidate
    return source_root


def is_state_flow_boolean(source_file: KotlinFile, prop: PropertyNode) -> bool:
    if prop.type_start is None or prop.type_end is None:
        return False
    type_tokens = source_file.tokens[prop.type_start : prop.type_end]
    return any(
        type_tokens[index].text == "StateFlow"
        and index + 3 < len(type_tokens)
        and type_tokens[index + 1].text == "<"
        and type_tokens[index + 2].text == "Boolean"
        and type_tokens[index + 3].text == ">"
        for index in range(len(type_tokens))
    )


def class_constructor_has_context(source_file: KotlinFile, class_node: ClassNode) -> bool:
    header_end = class_node.body_open if class_node.body_open is not None else class_node.header_end
    for index in range(class_node.name_index + 1, header_end):
        if source_file.tokens[index].text != "(":
            continue
        close_index = source_file.pairs.get(index)
        if close_index is None or close_index > header_end:
            continue
        parameter_tokens = source_file.tokens[index + 1 : close_index]
        if any(token.text == "Context" for token in parameter_tokens):
            return True
        break
    if class_node.body_open is None or class_node.body_close is None:
        return False
    for index in range(class_node.body_open + 1, class_node.body_close):
        if source_file.tokens[index].text != "constructor" or index + 1 >= class_node.body_close:
            continue
        open_index = index + 1
        if source_file.tokens[open_index].text != "(":
            continue
        close_index = source_file.pairs.get(open_index)
        if close_index is not None and any(token.text == "Context" for token in source_file.tokens[open_index + 1 : close_index]):
            return True
    return False


def is_import_or_package_token(source_file: KotlinFile, token_index: int) -> bool:
    line = source_file.tokens[token_index].line
    return any(token.line == line and token.text in {"import", "package"} for token in source_file.tokens[:token_index])


def is_annotation_token(source_file: KotlinFile, token_index: int) -> bool:
    line = source_file.tokens[token_index].line
    for annotation_index, token in enumerate(source_file.tokens[:token_index]):
        if token.line != line or token.text != "@":
            continue
        declaration_tokens = {"class", "fun", "object", "typealias", "val", "var"}
        if not any(
            candidate.line == line and candidate.text in declaration_tokens
            for candidate in source_file.tokens[annotation_index + 1 : token_index]
        ):
            return True
    return False


def repository_path_is_valid(path: Path, data_root: Path) -> bool:
    if not path_is_under(path, data_root):
        return False
    relative_parts = path.resolve().relative_to(data_root.resolve()).parts
    return len(relative_parts) >= 2 and (relative_parts[0] == "repository" or "repository" in relative_parts[:-1])


def added_diff_lines(project_root: Path) -> Iterator[tuple[int, str]]:
    commands = (
        ("git", "diff", "--unified=0", "--", "app/src", "app/build.gradle.kts", "build.gradle.kts", "detekt.yml", ".editorconfig"),
        ("git", "diff", "--cached", "--unified=0", "--", "app/src", "app/build.gradle.kts", "build.gradle.kts", "detekt.yml", ".editorconfig"),
    )
    output_lines: list[str] = []
    for command in commands:
        try:
            completed = subprocess.run(command, cwd=project_root, capture_output=True, text=True, check=False)
        except OSError:
            continue
        if completed.returncode == 0:
            output_lines.extend(completed.stdout.splitlines())
    for line_number, line in enumerate(output_lines, start=1):
        if line.startswith("+") and not line.startswith("+++"):
            yield line_number, line[1:]


def calls_in_range(source_file: KotlinFile, start: int, end: int, name: Optional[str] = None) -> list[CallNode]:
    return [
        call
        for call in source_file.calls
        if start < call.open_index < end and (name is None or call.name == name)
    ]


def function_calls(source_file: KotlinFile, function: FunctionNode, name: Optional[str] = None) -> list[CallNode]:
    return calls_in_range(source_file, function.body_start, function.body_end, name)


def enclosing_calls(source_file: KotlinFile, token_index: int) -> list[CallNode]:
    return sorted(
        [call for call in source_file.calls if call.open_index < token_index < call.close_index],
        key=lambda call: call.open_index,
        reverse=True,
    )


def call_is_layer_access(call: CallNode, suffixes: tuple[str, ...]) -> bool:
    identifiers = (call.name,) + call.qualifier
    return any(identifier.lower().endswith(suffix.lower()) for identifier in identifiers for suffix in suffixes)


def argument_segments(source_file: KotlinFile, call: CallNode) -> list[tuple[int, int]]:
    """Split a call's arguments at commas belonging to that call."""

    tokens = source_file.tokens
    segments: list[tuple[int, int]] = []
    start = call.open_index + 1
    cursor = start
    stack: list[str] = []
    while cursor < call.close_index:
        text = tokens[cursor].text
        if text in ("(", "[", "{"):
            stack.append(text)
        elif text in (")", "]", "}"):
            if stack:
                stack.pop()
        elif text == "," and not stack:
            if start < cursor:
                segments.append((start, cursor))
            start = cursor + 1
        cursor += 1
    if start < call.close_index:
        segments.append((start, call.close_index))
    return segments


def direct_named_argument(source_file: KotlinFile, call: CallNode, name: str) -> Optional[tuple[int, int]]:
    for argument_name, start, end in named_argument_ranges(source_file, call):
        if argument_name == name:
            return start, end
    return None


def trailing_lambda_named_argument(source_file: KotlinFile, call: CallNode, name: str) -> Optional[tuple[int, int]]:
    opening = call.close_index + 1
    if opening >= len(source_file.tokens) or source_file.tokens[opening].text != "{":
        return None
    closing = source_file.pairs.get(opening)
    if closing is None:
        return None
    tokens = source_file.tokens
    for index in range(opening + 1, closing):
        if tokens[index].text == name and index + 1 < closing and tokens[index + 1].text == "=":
            return index + 2, min(closing, index + 3)
    return None


def call_named_or_trailing_argument(source_file: KotlinFile, call: CallNode, name: str) -> Optional[tuple[int, int]]:
    return direct_named_argument(source_file, call, name) or trailing_lambda_named_argument(source_file, call, name)


def direct_argument_has_call(source_file: KotlinFile, call: CallNode, name: str) -> bool:
    for start, end in argument_segments(source_file, call):
        if any(candidate.name == name and start <= candidate.open_index < end for candidate in source_file.calls):
            return True
    return False


def first_argument_is_string(source_file: KotlinFile, call: CallNode) -> Optional[Token]:
    segments = argument_segments(source_file, call)
    if not segments:
        return None
    start, end = segments[0]
    if start < end and source_file.tokens[start].is_identifier and source_file.tokens[start].text not in KEYWORDS:
        if start + 1 < end and source_file.tokens[start + 1].text == "=":
            start += 2
    if start < end and source_file.tokens[start].is_string:
        return source_file.tokens[start]
    return None


def is_composable_function(function: FunctionNode) -> bool:
    return "Composable" in function.annotations or "androidx.compose.runtime.Composable" in function.annotations


def is_dynamic_test_tag(source_file: KotlinFile, call: CallNode) -> bool:
    segments = argument_segments(source_file, call)
    if len(segments) != 1:
        return False
    start, end = segments[0]
    argument = source_file.tokens[start:end]
    if any(token_has_string_template(token) for token in argument):
        return True
    if any(token.text == "+" for token in argument):
        return True
    return any(token.text in {"lowercase", "replace"} for token in argument)


def load_dynamic_tag_registry(project_root: Path) -> tuple[Optional[list[dict]], Optional[str]]:
    registry = Path(os.environ.get("DOCUMENTED_DYNAMIC_TAGS_REGISTRY", project_root / "harness" / "rules-matrix" / "documented-dynamic-test-tags.json"))
    if not registry.is_file():
        return None, f"Missing documented dynamic test-tag registry: {registry}"
    try:
        payload = json.loads(registry.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return None, f"Invalid documented dynamic test-tag registry: {registry} ({error})"
    entries = payload.get("entries") if isinstance(payload, dict) else None
    if not isinstance(entries, list) or not entries:
        return None, f"Invalid documented dynamic test-tag registry: {registry}"
    required_fields = {"id", "file", "documentation", "template", "source_type", "line_pattern"}
    for entry in entries:
        if not isinstance(entry, dict) or not required_fields.issubset(entry) or entry.get("source_type") not in {"immutable-domain-id", "fixed-catalog-key"}:
            return None, f"Invalid documented dynamic test-tag registry: {registry}"
        documentation = project_root / str(entry["documentation"])
        if not documentation.is_file():
            return None, f"Registry entry {entry.get('id', '<unknown>')} references missing documentation: {entry['documentation']}"
        try:
            documentation_text = documentation.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            return None, f"Unable to read registry documentation {documentation}: {error}"
        if str(entry["template"]) not in documentation_text:
            return None, f"Registry entry {entry.get('id', '<unknown>')} is not documented by template '{entry['template']}' in {entry['documentation']}"
    return entries, None


def dynamic_tag_is_documented(source_file: KotlinFile, call: CallNode, project_root: Path, entries: Sequence[dict]) -> bool:
    relative_file = project_relative(source_file.path, project_root)
    line = source_file.source.splitlines()[source_file.line(call.open_index) - 1]
    for entry in entries:
        if entry.get("file") != relative_file:
            continue
        try:
            if re.search(str(entry["line_pattern"]), line):
                return True
        except re.error:
            return False
    return False


def compose_is_interactive(call: CallNode) -> bool:
    return call.name in {
        "Button",
        "FloatingActionButton",
        "IconButton",
        "Chip",
        "Switch",
        "Checkbox",
        "RadioButton",
        "Slider",
        "DropdownMenu",
        "ExposedDropdownMenuBox",
    }


def compose_uses_layer_access(call: CallNode) -> bool:
    return call_is_layer_access(call, ("repository", "usecase", "datasource"))


def _is_hex_color_argument(source_file: KotlinFile, call: CallNode) -> bool:
    segments = argument_segments(source_file, call)
    if not segments:
        return False
    start, end = segments[0]
    return start < end and source_file.tokens[start].kind == "number" and source_file.tokens[start].text.lower().startswith("0x")


def _is_named_color_reference(source_file: KotlinFile, index: int) -> bool:
    tokens = source_file.tokens
    return (
        index + 2 < len(tokens)
        and tokens[index].text == "Color"
        and tokens[index + 1].text == "."
        and tokens[index + 2].text in {
            "Red",
            "Green",
            "Blue",
            "Black",
            "White",
            "Gray",
            "Grey",
            "Yellow",
            "Cyan",
            "Magenta",
            "Transparent",
            "DarkGray",
            "LightGray",
            "Unspecified",
        }
    )


def run_compose(args: argparse.Namespace) -> int:
    project_root, source_root, files = parse_common_files(args)
    result = Result(project_root)
    print("\n======================================================")
    print("  Compose Rules Checker")
    print("======================================================")
    print(f"  Source root: {source_root}")
    print(f"  Files scanned: {len(files)}")

    def check_colors() -> None:
        for source_file in files:
            if source_file.path.name == "AppColors.kt":
                continue
            for call in source_file.calls:
                if call.name == "Color" and _is_hex_color_argument(source_file, call):
                    result.add(source_file, call.name_index, "Color(0x...) literal outside AppColors.kt")
            for index in range(len(source_file.tokens)):
                if _is_named_color_reference(source_file, index):
                    result.add(source_file, index, "Named Color constant outside AppColors.kt")

    visit_rule(result, "Hardcoded colors", check_colors)

    def check_interactive_tags() -> None:
        for source_file in files:
            interactive_calls = [call for call in source_file.calls if compose_is_interactive(call)]
            if interactive_calls and not any(call.name == "testTag" for call in source_file.calls):
                result.add(
                    source_file,
                    interactive_calls[0].name_index,
                    "file contains interactive Composables but no Modifier.testTag(...) call",
                )

    visit_rule(result, "Interactive elements without a testTag", check_interactive_tags)

    def check_content_view_models() -> None:
        for source_file in files:
            for function in source_file.functions:
                if not function.name.endswith("Content"):
                    continue
                for call in function_calls(source_file, function):
                    if call.name in {"hiltViewModel", "viewModel"}:
                        result.add(source_file, call.name_index, f"{call.name}() called inside a *Content composable")

    visit_rule(result, "ViewModel inside *Content composables", check_content_view_models)

    def check_composable_layer_access() -> None:
        for source_file in files:
            for function in source_file.functions:
                if not is_composable_function(function):
                    continue
                for call in function_calls(source_file, function):
                    if compose_uses_layer_access(call):
                        result.add(source_file, call.name_index, "repository/use case/data source call inside a @Composable function")

    visit_rule(result, "Repository/use-case calls inside Composables", check_composable_layer_access)

    entries, registry_error = load_dynamic_tag_registry(project_root)

    def check_dynamic_tags() -> None:
        if registry_error is not None:
            result.add_path(project_root / "harness" / "rules-matrix" / "documented-dynamic-test-tags.json", 1, registry_error)
            return
        assert entries is not None
        for source_file in files:
            for call in source_file.calls:
                if call.name != "testTag" or not is_dynamic_test_tag(source_file, call):
                    continue
                if not dynamic_tag_is_documented(source_file, call, project_root, entries):
                    result.add(source_file, call.name_index, "dynamic testTag is not an approved documented immutable identifier")

    visit_rule(result, "Dynamic testTag values", check_dynamic_tags)

    def check_eager_lists() -> None:
        for source_file in files:
            for column in (call for call in source_file.calls if call.name == "Column"):
                for for_each in calls_in_range(source_file, column.open_index, column.close_index, "forEach"):
                    if for_each.qualifier:
                        result.add(source_file, for_each.name_index, "Column with .forEach { ... } should use LazyColumn")

    visit_rule(result, "Column + forEach instead of LazyColumn", check_eager_lists)
    return finish(result, "Compose")


def run_localization(args: argparse.Namespace) -> int:
    project_root, source_root, files = parse_common_files(args)
    result = Result(project_root)
    print("\n======================================================")
    print("  Localization Rules Checker")
    print("======================================================")
    print(f"  Source root: {source_root}")
    print(f"  Files scanned: {len(files)}")

    def check_text_literals() -> None:
        for source_file in files:
            for call in source_file.calls:
                if call.name == "Text":
                    literal = first_argument_is_string(source_file, call)
                    if literal is not None:
                        result.add(source_file, call.name_index, "Text() called with a raw string literal (not stringResource)")

    visit_rule(result, "Hardcoded strings in Text()", check_text_literals)

    def check_named_ui_literals() -> None:
        names = {"label", "title", "placeholder", "hint"}
        for source_file in files:
            for call in source_file.calls:
                enclosing_function = source_file.enclosing_function(call.open_index)
                if enclosing_function is not None and not is_composable_function(enclosing_function):
                    continue
                for name, start, end in named_argument_ranges(source_file, call):
                    if name in names and start < end and source_file.tokens[start].is_string:
                        result.add(source_file, start, f"{name}= is assigned a hardcoded string")

    visit_rule(result, "Hardcoded strings in Composable parameters", check_named_ui_literals)

    def check_local_ui_literals() -> None:
        suffixes = ("Label", "Text", "Title", "Placeholder", "Description", "Action")
        for source_file in files:
            is_ui_file = ".ui." in source_file.package_name or "/ui/" in source_file.path.as_posix()
            if not is_ui_file:
                continue
            for prop in source_file.properties:
                if not prop.name.endswith(suffixes) or prop.initializer_start is None:
                    continue
                if prop.initializer_start < len(source_file.tokens) and source_file.tokens[prop.initializer_start].is_string:
                    result.add(source_file, prop.initializer_start, "local UI label variable is assigned a hardcoded string")

    visit_rule(result, "Hardcoded local UI string variables", check_local_ui_literals)

    def check_null_descriptions() -> None:
        icon_calls = {"Icon", "IconButton", "Image", "ImageButton", "FloatingActionButton", "EditorBarButton"}
        direct_interactive_icons = {"IconButton", "ImageButton", "FloatingActionButton", "EditorBarButton"}
        for source_file in files:
            for call in source_file.calls:
                if call.name not in icon_calls:
                    continue
                named = direct_named_argument(source_file, call, "contentDescription")
                if named is not None and named[0] < named[1] and source_file.tokens[named[0]].text == "null":
                    enclosing = enclosing_calls(source_file, named[0])
                    is_interactive = (
                        call.name in direct_interactive_icons
                        or any(parent.name in {"IconButton", "ImageButton"} for parent in enclosing)
                        or any(candidate.name == "clickable" for candidate in calls_in_range(source_file, call.open_index, call.close_index))
                    )
                    if is_interactive:
                        result.add(source_file, named[0], "interactive icon contentDescription must not be null")

    visit_rule(result, "Null contentDescription on interactive icons", check_null_descriptions)
    return finish(result, "localization")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="checker", required=True)
    for name in ("architecture", "compose", "localization"):
        child = subparsers.add_parser(name)
        add_common_arguments(child)
        child.add_argument("source_root_arg", nargs="?", type=Path)
    navigation = subparsers.add_parser("navigation")
    navigation.add_argument("--project-root", type=Path, default=None)
    navigation.add_argument("project_root_arg", nargs="?", type=Path)
    assertions = subparsers.add_parser("assertions")
    assertions.add_argument("--test-directory", type=Path, default=None)
    assertions.add_argument("--project-root", type=Path, default=None)
    assertions.add_argument("test_directory_arg", nargs="?", type=Path)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    if args.checker == "architecture":
        return run_architecture(args)
    if args.checker == "compose":
        return run_compose(args)
    if args.checker == "localization":
        return run_localization(args)
    if args.checker == "navigation":
        return run_navigation(args)
    if args.checker == "assertions":
        return run_assertions(args)
    raise AssertionError(f"Unknown checker: {args.checker}")


def run_architecture(args: argparse.Namespace) -> int:
    project_root, source_root, files = parse_common_files(args)
    result = Result(project_root)
    base_package = derive_base_package(source_root)
    ui_root = base_package / "ui"
    domain_root = base_package / "domain"
    data_root = base_package / "data"
    ui_files = [source_file for source_file in files if path_is_under(source_file.path, ui_root)]
    domain_files = [source_file for source_file in files if path_is_under(source_file.path, domain_root)]
    data_files = [source_file for source_file in files if path_is_under(source_file.path, data_root)]
    viewmodel_files = [source_file for source_file in files if "viewmodel" in source_file.path.parts]

    print("\n======================================================")
    print("  Architecture Rules Checker")
    print("======================================================")
    print(f"  Source root: {source_root}")
    print(f"  Files scanned: {len(files)}")
    print(f"    UI files    : {len(ui_files)}")
    print(f"    Domain files: {len(domain_files)}")
    print(f"    Data files  : {len(data_files)}")
    print("  NOTE: Import-based layer boundaries remain owned by Detekt.")

    def check_ui_dao_calls() -> None:
        for source_file in ui_files:
            for call in source_file.calls:
                if call.name.lower() in {"get", "insert", "update", "delete", "query"} and call_is_layer_access(call, ("dao",)):
                    result.add(source_file, call.name_index, "UI code calls a Room DAO directly")

    visit_rule(result, "UI Composable DAO calls", check_ui_dao_calls)

    def check_ui_layer_calls() -> None:
        for source_file in ui_files:
            for function in source_file.functions:
                if not is_composable_function(function):
                    continue
                for call in function_calls(source_file, function):
                    if compose_uses_layer_access(call):
                        result.add(source_file, call.name_index, "Composable calls a repository, use case, or data source directly")

    visit_rule(result, "UI Composable repository/use-case calls", check_ui_layer_calls)

    ui_package = f"{base_package.relative_to(source_root).as_posix().replace('/', '.')}.ui" if base_package != source_root and path_is_under(base_package, source_root) else ""

    def check_ui_imports() -> None:
        if not ui_package:
            return
        for source_file in domain_files + data_files:
            for import_node in source_file.imports:
                if import_node.path.startswith(f"{ui_package}."):
                    result.add(source_file, import_node.import_index, "domain/data layer must not import UI packages")

    visit_rule(result, "Domain/data imports from UI", check_ui_imports)

    def check_domain_platform_imports() -> None:
        for source_file in domain_files:
            for import_node in source_file.imports:
                if import_node.path.startswith(("android.", "androidx.")):
                    result.add(source_file, import_node.import_index, "domain layer must not import Android framework classes")

    visit_rule(result, "Android imports in domain layer", check_domain_platform_imports)

    def check_data_ui_state() -> None:
        for source_file in data_files:
            for index, token in enumerate(source_file.tokens):
                if token.is_identifier and token.text == "UiState":
                    result.add(source_file, index, "data layer must not reference UI state types")

    visit_rule(result, "UI state references in data layer", check_data_ui_state)

    def check_viewmodel_api_calls() -> None:
        api_methods = {"get", "post", "put", "patch", "delete", "create", "fetch", "update"}
        for source_file in viewmodel_files:
            for function in source_file.functions:
                for call in function_calls(source_file, function):
                    if call.name.lower() in api_methods and call_is_layer_access(call, ("apiservice",)):
                        result.add(source_file, call.name_index, "ViewModel calls a Retrofit API service directly")

    visit_rule(result, "ViewModel Retrofit API calls", check_viewmodel_api_calls)

    def check_boolean_state_flows() -> None:
        for source_file in viewmodel_files:
            vm_classes = [candidate for candidate in source_file.classes if candidate.name.endswith("ViewModel")]
            for vm_class in vm_classes:
                boolean_flows = [
                    prop
                    for prop in source_file.properties
                    if prop.enclosing_class is vm_class
                    and prop.enclosing_function is None
                    and prop.type_start is not None
                    and prop.type_end is not None
                    and is_state_flow_boolean(source_file, prop)
                ]
                if len(boolean_flows) >= 3:
                    result.add(source_file, vm_class.name_index, f"ViewModel has {len(boolean_flows)} StateFlow<Boolean> properties")

    visit_rule(result, "Scattered StateFlow<Boolean> properties", check_boolean_state_flows)

    def check_permanent_events() -> None:
        event_names = {"showDialog", "showToast", "showSnackbar", "navigateTo", "isNavigating", "navigationEvent"}
        for source_file in viewmodel_files:
            for prop in source_file.properties:
                if prop.name in event_names:
                    result.add(source_file, prop.name_index, "one-off event must use Channel/SharedFlow instead of permanent state")

    visit_rule(result, "Permanent one-off event state", check_permanent_events)

    def check_domain_context() -> None:
        for source_file in domain_files:
            for class_node in source_file.classes:
                if class_constructor_has_context(source_file, class_node):
                    result.add(source_file, class_node.name_index, "domain class receives Context in a constructor")

    visit_rule(result, "Context in domain constructors", check_domain_context)

    def check_repository_singletons() -> None:
        for source_file in data_files:
            for class_node in source_file.classes:
                if class_node.name.endswith("RepositoryImpl") and "Singleton" not in class_node.annotations:
                    result.add(source_file, class_node.name_index, "RepositoryImpl is missing @Singleton")

    visit_rule(result, "RepositoryImpl Hilt scoping", check_repository_singletons)

    def check_qualified_names() -> None:
        roots = {"com", "io", "retrofit2", "androidx"}
        for source_file in files:
            for index, token in enumerate(source_file.tokens):
                if token.text not in roots or is_import_or_package_token(source_file, index) or is_annotation_token(source_file, index):
                    continue
                end = index + 1
                segment_count = 1
                while end + 1 < len(source_file.tokens) and source_file.tokens[end].text == "." and source_file.tokens[end + 1].is_identifier:
                    segment_count += 1
                    end += 2
                if segment_count >= 3 and end < len(source_file.tokens) and source_file.tokens[end].text in {"(", "<", "{", "::"}:
                    result.add(source_file, index, "fully-qualified class name used inline; use an import")

    visit_rule(result, "Fully-qualified names used inline", check_qualified_names)

    def check_viewmodel_retrofit_methods() -> None:
        for source_file in files:
            for class_node in source_file.classes:
                if not class_node.name.endswith("ViewModel"):
                    continue
                for call in calls_in_range(source_file, class_node.body_start, class_node.body_end):
                    if call.name in {"enqueue", "execute", "await"}:
                        result.add(source_file, call.name_index, "ViewModel must not call Retrofit directly")

    visit_rule(result, "Direct Retrofit calls in ViewModels", check_viewmodel_retrofit_methods)

    def check_composable_business_branches() -> None:
        property_names = {"status", "state", "type", "role", "kind"}
        for source_file in files:
            for function in source_file.functions:
                if not is_composable_function(function):
                    continue
                cursor = function.body_start + 1
                while cursor < function.body_end:
                    token = source_file.tokens[cursor]
                    if token.text not in {"if", "when"}:
                        cursor += 1
                        continue
                    open_index = cursor + 1
                    if open_index >= function.body_end or source_file.tokens[open_index].text != "(":
                        cursor += 1
                        continue
                    close_index = source_file.pairs.get(open_index)
                    if close_index is not None and any(
                        source_file.tokens[index].text == "."
                        and index + 1 < close_index
                        and source_file.tokens[index + 1].text in property_names
                        for index in range(open_index + 1, close_index)
                    ):
                        result.add(source_file, cursor, "Composable branches on a domain-model property")
                    cursor = close_index + 1 if close_index is not None else cursor + 1

    visit_rule(result, "Business branches inside Composables", check_composable_business_branches)

    test_root = project_root / "app" / "src" / "test"

    def check_viewmodel_tests() -> None:
        test_names = {path.name for path in iter_files(test_root)}
        for source_file in viewmodel_files:
            vm_classes = [candidate for candidate in source_file.classes if candidate.name.endswith("ViewModel")]
            for vm_class in vm_classes:
                if f"{vm_class.name}Test.kt" not in test_names and f"{vm_class.name}IntegrationTest.kt" not in test_names:
                    result.add(source_file, vm_class.name_index, f"no matching test file found for {vm_class.name}")

    visit_rule(result, "ViewModels without tests", check_viewmodel_tests)

    def check_misplaced_classes() -> None:
        for source_file in files:
            for class_node in source_file.classes:
                if class_node.name.endswith("ViewModel") and "viewmodel" not in source_file.path.parts:
                    result.add(source_file, class_node.name_index, "ViewModel class must reside in a viewmodel/ folder")
                if class_node.name.endswith("UseCase") and "usecase" not in source_file.path.parts:
                    result.add(source_file, class_node.name_index, "UseCase class must reside in a usecase/ folder")
                if class_node.name.endswith("RepositoryImpl") and not repository_path_is_valid(source_file.path, data_root):
                    result.add(source_file, class_node.name_index, "RepositoryImpl class must reside in data/repository/")
            if source_file.path.name.endswith("Mapper.kt") and path_is_under(source_file.path, domain_root):
                result.add(source_file, 0, "mapper belongs in data/ or ui/, not domain/")

    visit_rule(result, "Misplaced layer classes and mappers", check_misplaced_classes)

    def check_new_suppressions() -> None:
        for line_number, line in added_diff_lines(project_root):
            if re.search(r"@file:Suppress|@Suppress|@SuppressLint|tools:ignore|ktlint-disable|detekt-disable|noinspection|lint:ignore|baseline(?:[._-]|$)", line):
                result.add_path(project_root, line_number, f"new suppression/ignore directive in diff: {line}")

    visit_rule(result, "New suppression directives", check_new_suppressions)
    return finish(result, "architecture")


def find_named_file(root: Path, name: str) -> Optional[Path]:
    if not root.is_dir():
        return None
    return next((path for path in sorted(root.rglob(name)) if path.is_file()), None)


def navigation_source_files(project_root: Path) -> tuple[Optional[Path], Optional[Path], Optional[Path], Optional[Path], Optional[Path]]:
    main_root = project_root / "app" / "src" / "main" / "java"
    test_root = project_root / "app" / "src" / "androidTest"
    destinations = find_named_file(main_root, "Destinations.kt")
    graph = find_named_file(main_root, "AppNavGraph.kt")
    host = find_named_file(main_root, "AppNavigationHost.kt")
    navigation_test = find_named_file(test_root, "NavigationTest.kt")
    contract_test = find_named_file(test_root, "NavigationContractTest.kt")
    return destinations, graph, host, navigation_test, contract_test


def route_literal_matches(value: str, route_names: set[str]) -> bool:
    normalized = value.strip()
    return any(normalized == name or normalized.startswith(f"{name}?") or normalized.startswith(f"{name}/") or normalized.startswith(f"{name}{{") for name in route_names)


def navigation_route_name(source_file: KotlinFile, call: CallNode) -> Optional[str]:
    route = direct_named_argument(source_file, call, "route")
    if route is None:
        segments = argument_segments(source_file, call)
        route = segments[0] if segments else None
    if route is None:
        return None
    tokens = source_file.tokens[route[0] : route[1]]
    for index in range(len(tokens) - 2):
        if tokens[index].text == "Destinations" and tokens[index + 1].text == "." and tokens[index + 2].is_identifier:
            return tokens[index + 2].text
    return None


def run_navigation(args: argparse.Namespace) -> int:
    project_root = (args.project_root or args.project_root_arg or repository_root()).resolve()
    result = Result(project_root)
    print("\n======================================================")
    print("  Navigation Rules Checker")
    print("======================================================")
    print(f"  Project root: {project_root}")

    source_root = project_root / "app" / "src"
    destinations_path, graph_path, host_path, navigation_test_path, contract_test_path = navigation_source_files(project_root)
    rules_path = project_root / ".agents" / "rules" / "navigation-rules.md"
    for required_path, label in (
        (rules_path, "navigation rules file"),
        (destinations_path, "route definition file"),
        (graph_path, "navigation graph file"),
        (host_path, "navigation host file"),
    ):
        if required_path is None or not required_path.is_file():
            result.add_path(required_path or project_root, 1, f"{label} is missing")

    route_names = {
        "onboarding",
        "notes",
        "folders",
        "settings",
        "collectionNotes",
        "moveTo",
        "folderDescription",
        "editor",
        "voiceRecorder",
        "exportNote",
        "sharedUsers",
        "shareInvite",
        "manageAccess",
    }

    destination_ast = KotlinFile(destinations_path) if destinations_path is not None and destinations_path.is_file() else None
    graph_ast = KotlinFile(graph_path) if graph_path is not None and graph_path.is_file() else None
    host_ast = KotlinFile(host_path) if host_path is not None and host_path.is_file() else None

    def check_destinations_declaration() -> None:
        if destination_ast is None or not any(
            candidate.name == "Destinations" and "sealed" in candidate.modifiers for candidate in destination_ast.classes
        ):
            result.add_path(destinations_path or project_root, 1, "route definitions must use the Destinations sealed class")

    visit_rule(result, "Destinations declaration", check_destinations_declaration)

    all_source_files = parse_files(iter_files(source_root))

    def check_raw_route_literals() -> None:
        for source_file in all_source_files:
            for call in source_file.calls:
                if call.name in {"composable", "navigate", "popUpTo"}:
                    for start, end in argument_segments(source_file, call):
                        if end - start == 1 and source_file.tokens[start].is_string:
                            result.add(source_file, start, "raw route literal; use Destinations constants or createRoute()")
                for argument_name, start, end in named_argument_ranges(source_file, call):
                    if argument_name in {"route", "startDestination"} and end - start == 1 and source_file.tokens[start].is_string:
                        result.add(source_file, start, "raw route literal; use Destinations constants or createRoute()")

    visit_rule(result, "Raw route literals", check_raw_route_literals)

    def check_raw_route_prefixes() -> None:
        for source_file in all_source_files:
            for call in source_file.calls:
                if call.name != "startsWith":
                    continue
                literal = first_argument_is_string(source_file, call)
                if literal is not None and route_literal_matches(literal.text, route_names):
                    result.add(source_file, call.name_index, "raw route prefix; compare against Destinations route metadata")

    visit_rule(result, "Raw route prefixes", check_raw_route_prefixes)

    def check_unencoded_route_arguments() -> None:
        if destination_ast is None:
            return
        names = {"noteId", "folderId", "type"}
        for index, token in enumerate(destination_ast.tokens):
            if not token.is_string or not token_has_string_template(token, names):
                continue
            for name in names:
                if re.search(rf"\$\{{\s*{re.escape(name)}\b|\${re.escape(name)}\b", token.text) and not re.search(
                    rf"\$\{{\s*Uri\.encode\s*\(\s*{re.escape(name)}\b", token.text
                ):
                    result.add(destination_ast, index, "dynamic route argument is interpolated without Uri.encode()")
                    break

    visit_rule(result, "Encoded dynamic route arguments", check_unencoded_route_arguments)

    required_arguments = {
        "MoveTo": {"itemType", "itemId"},
        "ExportNote": {"noteId"},
        "SharedUsers": {"noteId"},
        "ManageAccess": {"noteId"},
        "ShareInvite": {"noteId"},
    }
    optional_arguments = {
        "CollectionNotes": {"type", "folderId", "label"},
        "Editor": {"noteId", "folderId"},
        "VoiceRecorder": {"noteId", "source", "focusedBlockId"},
    }

    def check_route_arguments() -> None:
        if host_ast is None:
            return
        route_blocks = [call for call in host_ast.calls if call.name == "composable"]
        for destination, names in required_arguments.items():
            matching = [call for call in route_blocks if navigation_route_name(host_ast, call) == destination]
            if not matching:
                result.add_path(host_ast.path, 1, f"missing route block for Destinations.{destination}")
                continue
            for route_block in matching:
                nav_arguments = [
                    call
                    for call in calls_in_range(host_ast, route_block.open_index, route_block.close_index, "navArgument")
                    if first_argument_is_string(host_ast, call) is not None
                ]
                for nav_argument in nav_arguments:
                    literal = first_argument_is_string(host_ast, nav_argument)
                    assert literal is not None
                    if literal.text not in names:
                        continue
                    default = call_named_or_trailing_argument(host_ast, nav_argument, "defaultValue")
                    if default is not None:
                        result.add(host_ast, default[0], f"required {destination}.{literal.text} must not define defaultValue")
        for destination, names in optional_arguments.items():
            matching = [call for call in route_blocks if navigation_route_name(host_ast, call) == destination]
            if not matching:
                result.add_path(host_ast.path, 1, f"missing route block for Destinations.{destination}")
                continue
            for route_block in matching:
                nav_arguments = [
                    call
                    for call in calls_in_range(host_ast, route_block.open_index, route_block.close_index, "navArgument")
                    if first_argument_is_string(host_ast, call) is not None
                ]
                present = set()
                for nav_argument in nav_arguments:
                    literal = first_argument_is_string(host_ast, nav_argument)
                    assert literal is not None
                    if literal.text in names:
                        present.add(literal.text)
                        if call_named_or_trailing_argument(host_ast, nav_argument, "defaultValue") is None:
                            result.add(host_ast, nav_argument.name_index, f"optional {destination}.{literal.text} must define defaultValue")
                for missing in sorted(names - present):
                    result.add(host_ast, route_block.name_index, f"optional {destination}.{missing} must define defaultValue")

    visit_rule(result, "Route argument defaults", check_route_arguments)

    def check_navigation_tests() -> None:
        for path, label in ((navigation_test_path, "production navigation test"), (contract_test_path, "navigation contract test")):
            if path is None or not path.is_file():
                result.add_path(path or project_root, 1, f"{label} is missing")
                continue
            test_ast = KotlinFile(path)
            if not any(token.text == "AppNavigationHost" for token in test_ast.tokens):
                result.add_path(path, 1, f"{label} must mount AppNavigationHost")

    visit_rule(result, "Production navigation test mounting", check_navigation_tests)
    return finish(result, "navigation")


def run_assertions(args: argparse.Namespace) -> int:
    project_root = (args.project_root or repository_root()).resolve()
    test_argument = args.test_directory or args.test_directory_arg
    test_directory = (test_argument or project_root / "app" / "src" / "test").resolve()
    files = [path for path in iter_files(test_directory) if path.name.endswith("Test.kt")]
    parsed_files = parse_files(files)
    result = Result(project_root)
    print("\n======================================================")
    print("  Test Assertions Quality Checker")
    print("======================================================")
    print(f"  Test root: {test_directory}")
    print(f"  Files scanned: {len(parsed_files)}")

    envelope_prefixes = ("<svg", "</svg", "<SVG", "</SVG", "<html", "</html", "<HTML", "</HTML")
    semantic_fragments = (
        "<rect",
        "<line",
        "<polygon",
        "<circle",
        "<marker",
        "<text",
        "<path",
        "font-size",
        "fill=",
        "stroke=",
    )

    def check_rendering_assertions() -> None:
        for source_file in parsed_files:
            envelope_calls = []
            semantic_calls = []
            for call in source_file.calls:
                if call.name != "contains":
                    continue
                literal = first_argument_is_string(source_file, call)
                if literal is None:
                    continue
                if literal.text.startswith(envelope_prefixes):
                    envelope_calls.append(call)
                if any(fragment in literal.text for fragment in semantic_fragments) or re.search(r">[^<]+</text>", literal.text):
                    semantic_calls.append(call)
            if envelope_calls and not semantic_calls:
                result.add(source_file, envelope_calls[0].name_index, "envelope-only assertions without semantic content checks")

    visit_rule(result, "Semantic rendering assertions", check_rendering_assertions)
    return finish(result, "test assertion quality")


if __name__ == "__main__":
    sys.exit(main())
