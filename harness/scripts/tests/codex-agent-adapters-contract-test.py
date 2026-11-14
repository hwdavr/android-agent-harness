#!/usr/bin/env python3
"""Exercise the Codex and Claude Code adapter validator against valid and invalid fixtures (models are not checked)."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Logical path (symlinks kept): the root the test was invoked through, like the shell contract tests.
PROJECT_ROOT = Path(os.path.abspath(__file__)).parents[3]
VALIDATOR = PROJECT_ROOT / "harness/scripts/check-codex-agent-adapters.py"
ROLES = ("planner", "implementer", "tester", "evaluator")


def run_validator(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(VALIDATOR), str(root)],
        check=False,
        capture_output=True,
        text=True,
    )


def require(condition: bool, message: str, result: subprocess.CompletedProcess[str] | None = None) -> None:
    if not condition:
        detail = "" if result is None else f"\nstdout: {result.stdout}\nstderr: {result.stderr}"
        raise AssertionError(message + detail)


def copy_fixture(root: Path) -> None:
    for rel in (".codex/agents", ".claude/agents", ".agents/agents"):
        (root / rel).mkdir(parents=True)
    for role in ROLES:
        shutil.copy2(PROJECT_ROOT / ".codex/agents" / f"{role}.toml", root / ".codex/agents" / f"{role}.toml")
        shutil.copy2(PROJECT_ROOT / ".claude/agents" / f"{role}.md", root / ".claude/agents" / f"{role}.md")
    for profile in ("planner.md", "generator.md", "tester.md", "evaluator.md"):
        shutil.copy2(PROJECT_ROOT / ".agents/agents" / profile, root / ".agents/agents" / profile)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="codex-agent-adapter-contract-") as temp:
        root = Path(temp) / "valid"
        copy_fixture(root)

        result = run_validator(root)
        require(result.returncode == 0, "valid isolated fixture was rejected", result)

        missing = Path(temp) / "missing"
        shutil.copytree(root, missing)
        (missing / ".codex/agents/tester.toml").unlink()
        result = run_validator(missing)
        require(result.returncode != 0, "fixture with missing tester adapter was accepted", result)
        require("missing adapter: .codex/agents/tester.toml" in result.stderr, "missing adapter failed for the wrong reason", result)

        missing_description = Path(temp) / "missing-description"
        shutil.copytree(root, missing_description)
        adapter = missing_description / ".codex/agents/planner.toml"
        adapter.write_text(adapter.read_text(encoding="utf-8").replace(
            'description = "Plan requirements, architecture, and verifiable slices."\n', ""), encoding="utf-8")
        result = run_validator(missing_description)
        require(result.returncode != 0, "fixture with missing description was accepted", result)
        require("planner: description must be non-empty text" in result.stderr, "missing description failed for the wrong reason", result)

        other_model = Path(temp) / "other-model"
        shutil.copytree(root, other_model)
        adapter = other_model / ".codex/agents/implementer.toml"
        adapter.write_text(adapter.read_text(encoding="utf-8").replace("gpt-6.1-terra", "any-model-the-user-likes"), encoding="utf-8")
        claude_adapter = other_model / ".claude/agents/planner.md"
        claude_adapter.write_text(claude_adapter.read_text(encoding="utf-8").replace("model: opus", "model: sonnet"), encoding="utf-8")
        result = run_validator(other_model)
        require(result.returncode == 0, "a user-configured model must be accepted", result)

        no_model = Path(temp) / "no-model"
        shutil.copytree(root, no_model)
        claude_adapter = no_model / ".claude/agents/tester.md"
        claude_adapter.write_text(claude_adapter.read_text(encoding="utf-8").replace("model: haiku\n", ""), encoding="utf-8")
        result = run_validator(no_model)
        require(result.returncode == 0, "an adapter without a model (inherit) must be accepted", result)

        missing_claude = Path(temp) / "missing-claude"
        shutil.copytree(root, missing_claude)
        (missing_claude / ".claude/agents/evaluator.md").unlink()
        result = run_validator(missing_claude)
        require(result.returncode != 0, "fixture with missing Claude adapter was accepted", result)
        require("missing adapter: .claude/agents/evaluator.md" in result.stderr, "missing Claude adapter failed for the wrong reason", result)

        claude_no_profile = Path(temp) / "claude-no-profile"
        shutil.copytree(root, claude_no_profile)
        claude_adapter = claude_no_profile / ".claude/agents/implementer.md"
        claude_adapter.write_text(claude_adapter.read_text(encoding="utf-8").replace(".agents/agents/generator.md", "the role profile"), encoding="utf-8")
        result = run_validator(claude_no_profile)
        require(result.returncode != 0, "Claude adapter without profile reference was accepted", result)
        require("claude implementer: instructions must reference .agents/agents/generator.md" in result.stderr,
                "Claude missing profile reference failed for the wrong reason", result)

        claude_bad_name = Path(temp) / "claude-bad-name"
        shutil.copytree(root, claude_bad_name)
        claude_adapter = claude_bad_name / ".claude/agents/tester.md"
        claude_adapter.write_text(claude_adapter.read_text(encoding="utf-8").replace("name: tester", "name: qa"), encoding="utf-8")
        result = run_validator(claude_bad_name)
        require(result.returncode != 0, "Claude adapter with wrong name was accepted", result)
        require("claude tester: name must be 'tester'" in result.stderr, "Claude wrong name failed for the wrong reason", result)

        invalid_toml = Path(temp) / "invalid-toml"
        shutil.copytree(root, invalid_toml)
        (invalid_toml / ".codex/agents/planner.toml").write_text("name = [broken\n", encoding="utf-8")
        result = run_validator(invalid_toml)
        require(result.returncode != 0, "fixture with invalid TOML was accepted", result)
        require("invalid TOML in .codex/agents/planner.toml" in result.stderr, "invalid TOML failed for the wrong reason", result)

        missing_profile = Path(temp) / "missing-profile"
        shutil.copytree(root, missing_profile)
        (missing_profile / ".agents/agents/tester.md").unlink()
        result = run_validator(missing_profile)
        require(result.returncode != 0, "fixture with missing role profile was accepted", result)
        require("tester: referenced profile does not exist: .agents/agents/tester.md" in result.stderr,
                "missing profile failed for the wrong reason", result)

    result = run_validator(PROJECT_ROOT)
    require(result.returncode == 0, "repository root adapter validation failed", result)
    print("PASS: positive fixture, any configured model, missing adapter/description/profile, invalid TOML, Claude adapter cases, and repository root validation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
