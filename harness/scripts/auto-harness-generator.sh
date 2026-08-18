#!/usr/bin/env bash
# harness/scripts/auto-harness-generator.sh
#
# Picks the next available harness task and launches an AI agent to handle it.
# The mode is auto-selected from the feature's tracker status in product.md:
#   - "In Progress" / "Awaiting implementation approval" -> implement a slice
#     via the harness-generator workflow (Stages 1..9).
#   - "To be reviewed" -> evaluate via the harness-evaluation workflow
#     (Stages 1..5). The Evaluator then applies a score-based transition:
#       overall 5.0/5  -> "To be human reviewed"
#       overall < 5.0  -> "To be fixed"
#   - "To be fixed" -> run the Generator's Fix Mode Pipeline to resolve every
#     code_review / test_review finding, then transition to "To be human reviewed".
#
# Tries codex first; if codex's token/quota is exhausted (or codex is not
# installed), falls back to agy. Mode selection, status parsing, and prompt
# building live in harness-generator-common.sh (sourced below).
#
# Usage:
#   bash harness/scripts/auto-harness-generator.sh            # auto-pick + launch (interactive TUI in a TTY or Terminal.app)
#   bash harness/scripts/auto-harness-generator.sh --check    # dry-run: print selected task + prompt
#   bash harness/scripts/auto-harness-generator.sh --headless # non-interactive drain mode
#
# Exit codes:
#   0 — task/session completed, or --check printed the task
#   1 — configuration error (neither agy nor codex installed, lifecycle invalid, etc.)
#   2 — no pending task found (safe for background scheduling)
#
# Notes:
# - Requires python3 (ships with macOS Sonoma+) for JSON parsing.
# - Requires at least one of: codex (OpenAI Codex CLI) or agy (Antigravity CLI).
#   codex install: npm install -g @openai/codex
#   agy install:   curl -fsSL https://antigravity.google/cli/install.sh | bash
# - Both agents run in YOLO mode (auto-approve all commands).

set -euo pipefail

# Ensure standard binary locations are on PATH for background/launchd jobs
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- run separator -----------------------------------------------------------

echo ""
echo "================================================================================"
echo "  Run: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================================================"
echo ""

# --- agent configurations ----------------------------------------------------

AGY_NAME="agy"
AGY_BIN="agy"
AGY_INSTALL_CMD="curl -fsSL https://antigravity.google/cli/install.sh | bash"
AGY_INSTALL_URL="https://codelabs.developers.google.com/antigravity-cli-hands-on"
AGY_INTERACTIVE_CMD="agy --dangerously-skip-permissions -i"
AGY_HEADLESS_CMD="agy --dangerously-skip-permissions -p"
AGY_BG_CMD="agy --dangerously-skip-permissions"

CODEX_NAME="codex"
CODEX_BIN="codex"
CODEX_INSTALL_CMD="npm install -g @openai/codex"
CODEX_INSTALL_URL="https://developers.openai.com/codex"
CODEX_INTERACTIVE_CMD="codex --yolo"
CODEX_HEADLESS_CMD="codex exec --yolo"
CODEX_BG_CMD="codex --yolo"

# Patterns that indicate token/quota exhaustion (checked against agent stdout/stderr).
QUOTA_ERROR_PATTERN='Individual.quota|quota.reached|rate.limit|429|RESOURCE_EXHAUSTED|token.*(exhaust|exceed|run.out|depleted)|insufficient.*(quota|credit|balance)|usage.*limit|daily.*limit|hit.*limit|Upgrade to Pro|purchase.*credits|out of credits|exceeded.*quota'


# --- helpers -----------------------------------------------------------------

info() {
  printf '%s\n' "$1"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# A fixed /tmp path keeps the lock visible to launchd and manually launched
# processes while allowing separate worktrees to run independently.
LOCK_KEY="$(printf '%s' "$ROOT_DIR" | cksum | awk '{print $1}')"
LOCK_DIR="/tmp/android-harness-${LOCK_KEY}.lock"
LOCK_ACQUIRED=0
LOCK_PID_FILE="$LOCK_DIR/pid"
LOCK_TASK_FILE="$LOCK_DIR/task"
LOCK_PROMPT_FILE="$LOCK_DIR/prompt"
LOCK_LAUNCH_SCRIPT="$LOCK_DIR/launch-interactive.sh"
LOCK_AGENT_READY_FILE="$LOCK_DIR/agent-ready"

release_lock() {
  if [ "$LOCK_ACQUIRED" -eq 1 ]; then
    local lock_pid=""
    if [ -f "$LOCK_PID_FILE" ]; then
      lock_pid=$(sed -n '1p' "$LOCK_PID_FILE" 2>/dev/null || true)
    fi
    if [ "$lock_pid" = "$$" ]; then
      rm -rf "$LOCK_DIR"
    else
      info "OK  Harness lock was handed off; leaving the new owner lock intact."
    fi
    LOCK_ACQUIRED=0
  fi
}

lock_owned_by_current_process() {
  local lock_pid=""
  [ -f "$LOCK_PID_FILE" ] || return 1
  lock_pid=$(sed -n '1p' "$LOCK_PID_FILE" 2>/dev/null || true)
  [ "$lock_pid" = "$$" ]
}

write_lock_task() {
  lock_owned_by_current_process || return 0

  local task_file_tmp="$LOCK_DIR/task.$$"
  local prompt_file_tmp="$LOCK_DIR/prompt.$$"
  local launch_script_tmp="$LOCK_DIR/launch-interactive.sh.$$"
  {
    printf 'feature_id=%s\n' "$FEATURE_ID"
    printf 'feature_status=%s\n' "$FEATURE_STATUS"
    printf 'feature_list=%s\n' "$FEATURE_LIST"
    printf 'eval_mode=%s\n' "$EVAL_MODE"
    printf 'fix_mode=%s\n' "$FIX_MODE"
    printf 'slice_id=%s\n' "${SLICE_ID:-}"
  } > "$task_file_tmp"
  mv "$task_file_tmp" "$LOCK_TASK_FILE"
  printf '%s' "$PROMPT" > "$prompt_file_tmp"
  mv "$prompt_file_tmp" "$LOCK_PROMPT_FILE"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -euo pipefail'
    printf '[ -d %q ] || exit 1\n' "$LOCK_DIR"
    printf 'echo "$$" > %q\n' "$LOCK_PID_FILE"
    printf ': > %q\n' "$LOCK_AGENT_READY_FILE"
    printf 'cd %q\n' "$ROOT_DIR"
    printf 'exec %s "$(cat %q)"\n' "$AGENT_INTERACTIVE_CMD" "$LOCK_PROMPT_FILE"
  } > "$launch_script_tmp"
  chmod 700 "$launch_script_tmp"
  mv "$launch_script_tmp" "$LOCK_LAUNCH_SCRIPT"
}

lock_value() {
  local key="$1"
  [ -f "$LOCK_TASK_FILE" ] || return 0
  sed -n "s/^${key}=//p" "$LOCK_TASK_FILE" | sed -n '1p'
}

owner_task_is_complete() {
  local owner_feature_id
  local owner_feature_status
  local owner_feature_list
  local owner_eval_mode
  local owner_fix_mode
  local owner_slice_id
  owner_feature_id=$(lock_value feature_id)
  owner_feature_status=$(lock_value feature_status)
  owner_feature_list=$(lock_value feature_list)
  owner_eval_mode=$(lock_value eval_mode)
  owner_fix_mode=$(lock_value fix_mode)
  owner_slice_id=$(lock_value slice_id)

  # A lock without task metadata belongs to a session started before task-aware
  # handoff support. Keep treating it as active rather than guessing whether it
  # is safe to overlap that process.
  [ -n "$owner_feature_id" ] || return 1

  if [ "$owner_eval_mode" -eq 1 ] || [ "$owner_fix_mode" -eq 1 ]; then
    local current_status
    current_status=$(awk -F'|' -v id="$owner_feature_id" '
      function trim(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return value
      }
      trim($2) == id { print trim($5); exit }
    ' "$ROOT_DIR/docs/product/product.md")
    [ -n "$current_status" ] && [ "$current_status" != "$owner_feature_status" ]
    return
  fi

  [ -f "$owner_feature_list" ] || return 1
  [ -n "$owner_slice_id" ] || return 1
  python3 - "$owner_feature_list" "$owner_slice_id" <<'PY'
import json
import sys

path, slice_id = sys.argv[1:]
try:
    with open(path) as handle:
        data = json.load(handle)
    completed = any(
        feature.get("id") == slice_id and feature.get("status") == "passing"
        for feature in data.get("features", [])
    )
except (OSError, json.JSONDecodeError):
    sys.exit(1)
sys.exit(0 if completed else 1)
PY
}

acquire_lock() {
  local attempts=0
  while true; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      chmod 700 "$LOCK_DIR"
      LOCK_ACQUIRED=1
      trap release_lock EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM
      printf '%s\n' "$$" > "$LOCK_PID_FILE"
      info "OK  Harness lock acquired (pid $$)."
      return 0
    fi

    local owner_pid=""
    if [ -f "$LOCK_PID_FILE" ]; then
      owner_pid=$(sed -n '1p' "$LOCK_PID_FILE" 2>/dev/null || true)
    fi

    if [ -n "$owner_pid" ] && [[ "$owner_pid" =~ ^[0-9]+$ ]]; then
      if kill -0 "$owner_pid" 2>/dev/null; then
        if owner_task_is_complete; then
          info "OK  Previous harness process (pid $owner_pid) completed its task; handing off the lock."
          rm -rf "$LOCK_DIR"
          continue
        fi
        info "SKIP Harness session already running (pid $owner_pid)."
        exit 0
      fi
      info "OK  Reclaiming stale harness lock (pid $owner_pid no longer exists)."
      rm -rf "$LOCK_DIR"
      continue
    fi

    attempts=$((attempts + 1))
    if [ "$attempts" -le 2 ]; then
      sleep 0.2
      continue
    fi

    info "OK  Reclaiming orphaned harness lock directory (no active pid)."
    rm -rf "$LOCK_DIR"
    continue
  done
}

# --- step 1: check which agents are available --------------------------------
# This MUST happen before sourcing common — common checks AGENT_BIN and exits
# if the binary is missing. We need to set AGENT_BIN to whatever is available.

AGY_AVAILABLE=0
CODEX_AVAILABLE=0
command -v "$AGY_BIN" >/dev/null 2>&1 && AGY_AVAILABLE=1
command -v "$CODEX_BIN" >/dev/null 2>&1 && CODEX_AVAILABLE=1

# Detect --check mode (common skips the binary check in --check mode, so we
# only need to fail if neither agent is installed AND we're not in --check).
IS_CHECK=0
for _arg in "$@"; do
  [ "$_arg" = "--check" ] && IS_CHECK=1
done

if [ "$AGY_AVAILABLE" -eq 0 ] && [ "$CODEX_AVAILABLE" -eq 0 ] && [ "$IS_CHECK" -eq 0 ]; then
  fail "Neither agy nor codex is installed or on PATH.
  Install codex: $CODEX_INSTALL_CMD
  Install agy:   $AGY_INSTALL_CMD"
fi

if [ "$AGY_AVAILABLE" -eq 0 ] && [ "$CODEX_AVAILABLE" -eq 0 ] && [ "$IS_CHECK" -eq 1 ]; then
  info "Neither agy nor codex installed — continuing in --check mode."
fi

if [ "$IS_CHECK" -eq 0 ]; then
  acquire_lock
fi

check_agent_quota() {
  local agent="$1"
  if [ "$agent" != "codex" ]; then
    return 0
  fi
  local probe_out
  probe_out=$(python3 -c "
import subprocess, sys
try:
    p = subprocess.run(
        ['codex', 'exec', '--yolo', 'ping'],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=8
    )
    print(p.stdout)
    sys.exit(p.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
except Exception:
    sys.exit(1)
" 2>&1 || true)

  if echo "$probe_out" | grep -qiE "$QUOTA_ERROR_PATTERN"; then
    QUOTA_PROBE_ERROR=$(echo "$probe_out" | grep -iE "$QUOTA_ERROR_PATTERN" | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    return 1 # quota exhausted
  fi
  return 0
}

# --- step 2: set config and prepare task -------------------------------------
# Prefer codex for the common file config; fall back to agy if codex is not
# installed or its quota/token limit is exhausted.

QUOTA_PROBE_ERROR=""
if [ "$CODEX_AVAILABLE" -eq 1 ] && [ "$AGY_AVAILABLE" -eq 1 ]; then
  info "--> Checking codex quota..."
  if ! check_agent_quota "codex"; then
    info ">>> codex token/quota exhausted. Falling back to agy..."
    if [ -n "$QUOTA_PROBE_ERROR" ]; then
      info "    Reason: $QUOTA_PROBE_ERROR"
    fi
    CODEX_AVAILABLE=0
  else
    info "OK  codex quota available."
  fi
fi

if [ "$CODEX_AVAILABLE" -eq 1 ]; then
  AGENT_NAME="$CODEX_NAME"
  AGENT_BIN="$CODEX_BIN"
  AGENT_INSTALL_CMD="$CODEX_INSTALL_CMD"
  AGENT_INSTALL_URL="$CODEX_INSTALL_URL"
  AGENT_INTERACTIVE_CMD="$CODEX_INTERACTIVE_CMD"
  AGENT_HEADLESS_CMD="$CODEX_HEADLESS_CMD"
  AGENT_BG_CMD="$CODEX_BG_CMD"
else
  # codex not installed or quota exhausted — use agy.
  AGENT_NAME="$AGY_NAME"
  AGENT_BIN="$AGY_BIN"
  AGENT_INSTALL_CMD="$AGY_INSTALL_CMD"
  AGENT_INSTALL_URL="$AGY_INSTALL_URL"
  AGENT_INTERACTIVE_CMD="$AGY_INTERACTIVE_CMD"
  AGENT_HEADLESS_CMD="$AGY_HEADLESS_CMD"
  AGENT_BG_CMD="$AGY_BG_CMD"
fi

SKIP_LAUNCH=1


# --- step 3: launch with fallback --------------------------------------------

# --- launch function with fallback -------------------------------------------

launch_agent() {
  local interactive_cmd="$1"
  local headless_cmd="$2"
  local agent_name="$3"
  local fallback_name="$4"
  local fallback_interactive="$5"
  local fallback_headless="$6"
  local can_fallback="$7"

  if [ "$HEADLESS" -eq 1 ]; then
    info "--> Launching ${agent_name} in headless mode. Output streams to this terminal."
    local output_file
    output_file=$(mktemp -t harness-agent-output.XXXXXX)
    local exit_code=0
    $headless_cmd "$PROMPT" >"$output_file" 2>&1 || exit_code=$?
    cat "$output_file"

    if [ "$exit_code" -ne 0 ] && [ "$can_fallback" -eq 1 ]; then
      local err_text
      err_text=$(cat "$output_file" 2>/dev/null || true)
      rm -f "$output_file"
      if echo "$err_text" | grep -qiE "$QUOTA_ERROR_PATTERN"; then
        info ""
        info ">>> ${agent_name} token/quota exhausted. Switching to ${fallback_name}..."
        info "    Error: $(echo "$err_text" | grep -iE "$QUOTA_ERROR_PATTERN" | head -1)"
        local fallback_exit_code=0
        $fallback_headless "$PROMPT" || fallback_exit_code=$?
        return "$fallback_exit_code"
      else
        fail "${agent_name} failed (exit $exit_code): $err_text"
      fi
    fi
    rm -f "$output_file"
    return "$exit_code"
  fi

  # launchd has no TTY. Open a visible Terminal.app session with the selected
  # prompt. The launched CLI replaces the scheduler as lock owner, so the lock
  # remains valid after this wrapper exits.
  if [ ! -t 1 ]; then
    info "--> No TTY detected; opening Terminal.app with ${agent_name} interactive CLI."
    osascript -e "tell application \"Terminal\" to do script \"/bin/bash $LOCK_LAUNCH_SCRIPT\"" \
              -e "activate application \"Terminal\"" >/dev/null 2>&1 || \
      fail "osascript failed to open Terminal.app. Run this script from an interactive terminal."
    local wait_attempts=0
    while [ ! -f "$LOCK_AGENT_READY_FILE" ]; do
      wait_attempts=$((wait_attempts + 1))
      if [ "$wait_attempts" -ge 50 ]; then
        fail "Terminal.app did not start the ${agent_name} session within 10 seconds."
      fi
      sleep 0.2
    done
    info "OK  Terminal window launched with the harness prompt."
    return 0
  fi

  # Interactive TUI mode.
  if [ -t 1 ]; then
    info "--> Launching ${agent_name} interactive TUI. Press Ctrl+C to exit."
    local output_file2
    output_file2=$(mktemp -t harness-agent-output.XXXXXX)
    local exit_code2=0
    if command -v script >/dev/null 2>&1; then
      script -q "$output_file2" bash -c "$interactive_cmd \"\$1\"" -- "$PROMPT" || exit_code2=$?
    else
      $interactive_cmd "$PROMPT" >"$output_file2" 2>&1 || exit_code2=$?
      cat "$output_file2" >&2
    fi

    if [ "$exit_code2" -ne 0 ] && [ "$can_fallback" -eq 1 ]; then
      local err_text2
      err_text2=$(cat "$output_file2" 2>/dev/null || true)
      rm -f "$output_file2"
      if echo "$err_text2" | grep -qiE "$QUOTA_ERROR_PATTERN"; then
        info ""
        info ">>> ${agent_name} token/quota exhausted. Switching to ${fallback_name}..."
        info "    Error: $(echo "$err_text2" | grep -iE "$QUOTA_ERROR_PATTERN" | head -1)"
        info "--> Launching ${fallback_name} interactive TUI."
        local fallback_exit_code2=0
        $fallback_interactive "$PROMPT" || fallback_exit_code2=$?
        return "$fallback_exit_code2"
      else
        fail "${agent_name} failed (exit $exit_code2): $err_text2"
      fi
    fi
    rm -f "$output_file2"
    return "$exit_code2"
  fi
  return 0
}

# --- run agent sessions (headless mode drains advanced tasks) -----------------

PREVIOUS_TASK_KEY=""
while true; do
  if [ "$IS_CHECK" -eq 0 ] && ! lock_owned_by_current_process; then
    info "OK  Harness lock was handed off to a newer session; stopping this process."
    exit 0
  fi

  # shellcheck source=harness-generator-common.sh
  source "$SCRIPT_DIR/harness-generator-common.sh"

  if [ "$IS_CHECK" -eq 0 ] && ! lock_owned_by_current_process; then
    info "OK  Harness lock was handed off to a newer session; stopping this process."
    exit 0
  fi

  TASK_KEY="${FEATURE_ID}|${FEATURE_STATUS}|${EVAL_MODE}|${FIX_MODE}|${SLICE_ID:-}"
  write_lock_task

  if ! lock_owned_by_current_process; then
    info "OK  Harness lock was handed off to a newer session; stopping this process."
    exit 0
  fi

  if [ -n "$PREVIOUS_TASK_KEY" ] && [ "$TASK_KEY" = "$PREVIOUS_TASK_KEY" ]; then
    info "OK  Session exited successfully but the tracker still selects '$TASK_KEY'; stopping to avoid a no-progress loop."
    exit 0
  fi
  PREVIOUS_TASK_KEY="$TASK_KEY"

  # --- determine which agent to try first ------------------------------------

  session_exit_code=0
  if [ "$CODEX_AVAILABLE" -eq 1 ]; then
    # Try codex first, fall back to agy if available.
    CAN_FALLBACK=$AGY_AVAILABLE
    launch_agent \
      "$CODEX_INTERACTIVE_CMD" "$CODEX_HEADLESS_CMD" \
      "$CODEX_NAME" \
      "$AGY_NAME" \
      "$AGY_INTERACTIVE_CMD" "$AGY_HEADLESS_CMD" \
      "$CAN_FALLBACK" || session_exit_code=$?
  else
    # Only agy is available — no fallback.
    launch_agent \
      "$AGY_INTERACTIVE_CMD" "$AGY_HEADLESS_CMD" \
      "$AGY_NAME" \
      "$CODEX_NAME" \
      "$CODEX_INTERACTIVE_CMD" "$CODEX_HEADLESS_CMD" \
      0 || session_exit_code=$?
  fi

  if [ "$session_exit_code" -ne 0 ]; then
    exit "$session_exit_code"
  fi

  # A human-launched TTY invocation remains one-shot. Headless runs continue
  # only after a successful session. A Terminal.app session has already taken
  # ownership of the lock, so this wrapper exits on the next loop iteration.
  if [ "$HEADLESS" -eq 0 ] && [ -t 1 ]; then
    exit 0
  fi
  info "OK  Session completed; checking for the next harness task."
done
