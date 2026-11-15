#!/usr/bin/env python3
"""Fail when a screen composable ignores the system-bar insets of the edge-to-edge app.

MainActivity draws edge to edge, so the app Scaffold in AppNavGraph reports the status and navigation bar
insets only through its inner padding. A public `*Screen` composable under a `screen/` directory that
neither takes that padding (`parentPadding`/`innerPadding`) nor applies an inset modifier of its own draws
its first controls under the status bar on a real device. Unit tests, structural checks, and journeys run
without system bars and cannot see it.
"""
import argparse
import re
import sys
from pathlib import Path

SCREEN_FILE = re.compile(r"/screen/[A-Za-z0-9_]*Screen\.kt$")
PUBLIC_SCREEN = re.compile(r"^(?:internal\s+)?fun\s+([A-Z][A-Za-z0-9_]*Screen)\s*\(", re.M)
INSET_TOKEN = re.compile(
    r"\b(parentPadding|innerPadding|statusBarsPadding|systemBarsPadding|safeDrawingPadding|"
    r"safeContentPadding|windowInsetsPadding)\b"
)


def violations(project_root: Path):
    found = []
    for path in sorted((project_root / "app/src/main/java").rglob("*Screen.kt")):
        if not SCREEN_FILE.search(path.as_posix()):
            continue
        text = path.read_text(encoding="utf-8")
        screens = PUBLIC_SCREEN.findall(text)
        if screens and not INSET_TOKEN.search(text):
            line = text[: PUBLIC_SCREEN.search(text).start()].count("\n") + 1
            found.append((path.relative_to(project_root).as_posix(), line, screens[0]))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    found = violations(args.project_root.resolve())
    for path, line, name in found:
        print(
            f"{path}:{line}: {name} ignores system-bar insets; take `parentPadding` from the app Scaffold "
            "or apply statusBarsPadding()/systemBarsPadding() (rules/compose-rules.md, Edge-to-edge insets)",
            file=sys.stderr,
        )
    if found:
        return 1
    print("PASS: every screen composable accounts for system-bar insets")
    return 0


if __name__ == "__main__":
    sys.exit(main())
