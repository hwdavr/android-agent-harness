#!/usr/bin/env bash
# harness/scripts/claude-harness-generator.sh
#
# Picks the next available harness task and launches Claude Code (claude)
# to handle it. Task selection, mode (generate / evaluate / fix) and prompt
# building live in harness-generator-common.sh, shared with the codex and agy
# wrappers. Claude Code delegates to the subagents in .claude/agents/.
#
# Usage:
#   bash harness/scripts/claude-harness-generator.sh            # auto-pick + launch claude (interactive TUI)
#   bash harness/scripts/claude-harness-generator.sh --check    # dry-run: print selected task + prompt, no mutations
#   bash harness/scripts/claude-harness-generator.sh --headless # use claude -p (non-interactive) instead of the TUI
#
# Exit codes:
#   0 — task found; claude launched (or --check printed the task)
#   1 — configuration error (claude missing, lifecycle invalid, JSON parse error, etc.)
#   2 — no pending task found (safe for background scheduling; claude not launched)
#
# Notes:
# - Requires python3 for JSON parsing.
# - Requires claude (Claude Code) on PATH unless --check is used.
#   Docs: https://code.claude.com/docs
# - Uses --dangerously-skip-permissions to auto-approve all commands. Run it only
#   in a checkout you trust. Models and effort come from .claude/agents/*.md.

set -euo pipefail

# --- agent configuration (read by harness-generator-common.sh) ----------------
AGENT_NAME="claude"
AGENT_BIN="claude"
AGENT_INSTALL_CMD="curl -fsSL https://claude.ai/install.sh | bash"
AGENT_INSTALL_URL="https://code.claude.com/docs"
# claude "<prompt>" = interactive TUI seeded with the prompt; claude -p = non-interactive.
AGENT_INTERACTIVE_CMD="claude --dangerously-skip-permissions"
AGENT_HEADLESS_CMD="claude --dangerously-skip-permissions -p"
AGENT_BG_CMD="claude --dangerously-skip-permissions"

source "$(dirname "$0")/harness-generator-common.sh"
