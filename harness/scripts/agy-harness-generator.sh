#!/usr/bin/env bash
# harness/scripts/agy-harness-generator.sh
#
# Picks the next available harness task and launches Antigravity CLI (agy)
# to implement it via the harness-generator workflow.
#
# Usage:
#   bash harness/scripts/agy-harness-generator.sh            # auto-pick + launch agy (interactive TUI, YOLO mode)
#   bash harness/scripts/agy-harness-generator.sh --check    # dry-run: print selected task + prompt, no mutations
#   bash harness/scripts/agy-harness-generator.sh --headless # use agy -p (non-interactive) instead of agy -i
#
# Exit codes:
#   0 — task found; agy launched (or --check printed the task)
#   1 — configuration error (agy missing, lifecycle invalid, JSON parse error, etc.)
#   2 — no pending task found (safe for background scheduling; agy not launched)
#
# Background scheduling (every 2 hours via launchd):
#   sed "s|__PROJECT_ROOT__|$(pwd)|g" \
#     harness/scripts/com.android.harness-generator.plist.template \
#     > ~/Library/LaunchAgents/com.android.harness-generator.plist
#   launchctl load ~/Library/LaunchAgents/com.android.harness-generator.plist
#
# Notes:
# - Requires python3 (ships with macOS Sonoma+) for JSON parsing.
# - Requires agy (Antigravity CLI) on PATH unless --check is used.
#   Install: curl -fsSL https://antigravity.google/cli/install.sh | bash
# - Uses --dangerously-skip-permissions (YOLO mode) to auto-approve all commands.

set -euo pipefail

# --- agent configuration (read by harness-generator-common.sh) ----------------
AGENT_NAME="agy"
AGENT_BIN="agy"
AGENT_INSTALL_CMD="curl -fsSL https://antigravity.google/cli/install.sh | bash"
AGENT_INSTALL_URL="https://codelabs.developers.google.com/antigravity-cli-hands-on"
# agy -i = initial prompt + interactive TUI; agy -p = non-interactive (headless)
AGENT_INTERACTIVE_CMD="agy --dangerously-skip-permissions -i"
AGENT_HEADLESS_CMD="agy --dangerously-skip-permissions -p"
AGENT_BG_CMD="agy --dangerously-skip-permissions"

source "$(dirname "$0")/harness-generator-common.sh"
