#!/usr/bin/env python3
"""Dependency-free source policy evaluator for AI and WebView boundaries."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


HIGH = "high"


def finding(rule_id: str, path: Path, line: int, message: str) -> dict[str, object]:
    return {
        "id": rule_id,
        "severity": HIGH,
        "path": path.as_posix(),
        "line": line,
        "message": message,
    }


def scan_file(path: Path, patterns: list[tuple[str, str, str]]) -> list[dict[str, object]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return []

    findings: list[dict[str, object]] = []
    for rule_id, regex, message in patterns:
        compiled = re.compile(regex, re.IGNORECASE)
        for line_number, line in enumerate(lines, start=1):
            if compiled.search(line):
                findings.append(finding(rule_id, path, line_number, message))
    return findings


def collect_findings(root: Path) -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []
    manifest = root / "app/src/main/AndroidManifest.xml"
    if manifest.exists():
        findings.extend(
            scan_file(
                manifest,
                [
                    (
                        "AISEC-CLEARTEXT",
                        r"usesCleartextTraffic\s*=\s*['\"]true['\"]",
                        "App-wide cleartext traffic must be disabled.",
                    )
                ],
            )
        )

    main_root = root / "app/src/main"
    kotlin_patterns = [
        (
            "AISEC-WEBVIEW-JAVASCRIPT",
            r"javaScriptEnabled\s*=\s*true",
            "The inline renderer must not enable JavaScript.",
        ),
        (
            "AISEC-WEBVIEW-FILE-ACCESS",
            r"allowFileAccess\s*=\s*true",
            "The inline renderer must not allow file access.",
        ),
        (
            "AISEC-WEBVIEW-DOM-STORAGE",
            r"domStorageEnabled\s*=\s*true",
            "The inline renderer must not enable DOM storage.",
        ),
        (
            "AISEC-WEBVIEW-CONTENT-ACCESS",
            r"allowContentAccess\s*=\s*true",
            "The inline renderer must not allow content-provider access.",
        ),
        (
            "AISEC-WEBVIEW-NETWORK-LOADS",
            r"blockNetworkLoads\s*=\s*false",
            "The inline renderer must keep network loads blocked.",
        ),
        (
            "AISEC-WEBVIEW-FILE-BASE-URL",
            r"file:///android_asset/",
            "Inline HTML must not use a file base URL.",
        ),
        (
            "AISEC-AI-INPUT-LOGGING",
            r"Log\.[a-z]+\([^\n]*(prompt|noteText|accessToken|refreshToken|idToken)\b",
            "AI inputs and credentials must not be written to logs.",
        ),
        (
            "AISEC-OUTPUT-HTML-SINK",
            r"innerHTML\s*=\s*[^;]*(prompt|modelResult|output|summary|noteText|content)\b",
            "Untrusted model output must not flow directly into an HTML sink.",
        ),
    ]
    if main_root.exists():
        for path in sorted(main_root.rglob("*.kt")):
            findings.extend(scan_file(path, kotlin_patterns))

    asset_patterns = [
        (
            "AISEC-MERMAID-SECURITY-LEVEL",
            r"securityLevel\s*:\s*['\"]loose['\"]",
            "Mermaid must use strict security mode for untrusted diagram text.",
        )
    ]
    assets_root = root / "app/src/main/assets"
    if assets_root.exists():
        for path in sorted(assets_root.rglob("*")):
            if path.is_file():
                findings.extend(scan_file(path, asset_patterns))

    return sorted(findings, key=lambda item: (str(item["path"]), int(item["line"]), str(item["id"])))


def render_markdown(root: Path, findings: list[dict[str, object]]) -> str:
    status = "FAIL" if findings else "PASS"
    lines = [
        "# AI Security Rules Report",
        "",
        f"- Status: **{status}**",
        f"- Root: `{root}`",
        f"- High-severity findings: **{len(findings)}**",
        "",
        "The report intentionally contains only rule IDs, paths, line numbers, and redacted remediation text.",
        "",
    ]
    if not findings:
        lines.append("No high-severity AI/WebView boundary findings detected.")
        return "\n".join(lines) + "\n"
    lines.extend(["| ID | Severity | Location | Remediation |", "|---|---|---|---|"])
    for item in findings:
        location = f"`{item['path']}:{item['line']}`"
        lines.append(f"| `{item['id']}` | {item['severity']} | {location} | {item['message']} |")
    return "\n".join(lines) + "\n"


def render_json(root: Path, findings: list[dict[str, object]]) -> str:
    payload = {
        "schema_version": 1,
        "status": "FAIL" if findings else "PASS",
        "root": root.as_posix(),
        "finding_count": len(findings),
        "findings": findings,
    }
    return json.dumps(payload, indent=2) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=None, help="Repository root to scan")
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--output", type=Path, default=None, help="Existing-parent report path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = (args.root or Path(__file__).resolve().parents[3]).resolve()
    if not root.is_dir():
        print(f"FAIL: repository root does not exist: {root}", file=sys.stderr)
        return 2
    if args.output is not None and not args.output.parent.is_dir():
        print(f"FAIL: report parent directory does not exist: {args.output.parent}", file=sys.stderr)
        return 2

    findings = collect_findings(root)
    report = render_markdown(root, findings) if args.format == "markdown" else render_json(root, findings)
    if args.output is None:
        print(report, end="")
    else:
        try:
            args.output.write_text(report, encoding="utf-8")
        except OSError as error:
            print(f"FAIL: could not write report: {error}", file=sys.stderr)
            return 2
        print(f"AI security report written to {args.output}")
    if findings:
        for item in findings:
            print(
                f"FAIL {item['id']} {item['path']}:{item['line']} — {item['message']}",
                file=sys.stderr,
            )
        return 1
    print("PASS: AI security rules")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
