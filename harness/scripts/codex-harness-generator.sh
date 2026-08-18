#!/usr/bin/env bash
# harness/scripts/codex-harness-generator.sh
#
# Picks the next available harness task and launches OpenAI Codex CLI (codex)
# to implement it via the harness-generator workflow.
#
# Usage:
#   bash harness/scripts/codex-harness-generator.sh            # auto-pick + launch codex (interactive TUI, YOLO mode)
#   bash harness/scripts/codex-harness-generator.sh --check    # dry-run: print selected task + prompt, no mutations
#   bash harness/scripts/codex-harness-generator.sh --headless # use codex exec (non-interactive) instead of TUI
#
# Exit codes:
#   0 — task found; codex launched (or --check printed the task)
#   1 — configuration error (codex missing, lifecycle invalid, JSON parse error, etc.)
#   2 — no pending task found (safe for background scheduling; codex not launched)
#
# Background scheduling (every 2 hours via launchd):
#   sed "s|__PROJECT_ROOT__|$(pwd)|g" \
#     harness/scripts/com.android.harness-generator.plist.template \
#     > ~/Library/LaunchAgents/com.android.harness-generator.plist
#   launchctl load ~/Library/LaunchAgents/com.android.harness-generator.plist
#   # Edit the plist to point at codex-harness-generator.sh instead of agy-.
#
# Notes:
# - Requires python3 (ships with macOS Sonoma+) for JSON parsing.
# - Requires codex (OpenAI Codex CLI) on PATH unless --check is used.
#   Install: npm install -g @openai/codex
#   Docs:    https://developers.openai.com/codex
# - Uses --yolo (alias for --dangerously-bypass-approvals-and-sandbox) to
#   auto-approve all commands and skip sandbox restrictions.

set -euo pipefail

# --- agent configuration (read by harness-generator-common.sh) ----------------
AGENT_NAME="codex"
AGENT_BIN="codex"
AGENT_INSTALL_CMD="npm install -g @openai/codex"
AGENT_INSTALL_URL="https://developers.openai.com/codex"
# codex takes the prompt as a positional arg; codex exec = non-interactive.
# --yolo = --dangerously-bypass-approvals-and-sandbox (auto-approve + no sandbox)
AGENT_INTERACTIVE_CMD="codex --yolo"
AGENT_HEADLESS_CMD="codex exec --yolo"
AGENT_BG_CMD="codex --yolo"

source "$(dirname "$0")/harness-generator-common.sh"
