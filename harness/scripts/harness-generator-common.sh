#!/usr/bin/env bash
# harness/scripts/harness-generator-common.sh
#
# Shared logic for agy-harness-generator.sh and codex-harness-generator.sh.
# Must be SOURCED by a wrapper script — not executed directly.
#
# The wrapper sets these variables BEFORE sourcing this file:
#   AGENT_NAME           — human-readable name ("agy" or "codex")
#   AGENT_BIN            — binary on PATH ("agy" or "codex")
#   AGENT_INSTALL_CMD    — install command string
#   AGENT_INSTALL_URL    — setup docs URL
#   AGENT_INTERACTIVE_CMD — full command prefix for interactive TUI with prompt
#                           (e.g., "agy --dangerously-skip-permissions -i")
#   AGENT_HEADLESS_CMD   — full command prefix for headless mode with prompt
#                           (e.g., "agy --dangerously-skip-permissions -p")
#   AGENT_BG_CMD         — command for background Terminal.app (no prompt arg)
#                           (e.g., "agy --dangerously-skip-permissions")
#
# Usage (from wrapper):
#   source "$(dirname "$0")/harness-generator-common.sh"

# Guard: must be sourced, not executed.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "ERROR: source this file from a wrapper script; do not execute it directly." >&2
  exit 1
fi

# Guard: wrapper must set AGENT_NAME.
[ -n "${AGENT_NAME:-}" ] || { echo "ERROR: AGENT_NAME not set before sourcing common." >&2; exit 1; }
[ -n "${AGENT_BIN:-}" ] || { echo "ERROR: AGENT_BIN not set before sourcing common." >&2; exit 1; }
[ -n "${AGENT_INTERACTIVE_CMD:-}" ] || { echo "ERROR: AGENT_INTERACTIVE_CMD not set." >&2; exit 1; }
[ -n "${AGENT_HEADLESS_CMD:-}" ] || { echo "ERROR: AGENT_HEADLESS_CMD not set." >&2; exit 1; }
[ -n "${AGENT_BG_CMD:-}" ] || { echo "ERROR: AGENT_BG_CMD not set." >&2; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRODUCT_FILE="$ROOT_DIR/docs/product/product.md"
LIFECYCLE_SCRIPT="$ROOT_DIR/harness/scripts/check-feature-lifecycle.sh"
START_MARKER="<!-- HARNESS_TRACKER_START -->"
END_MARKER="<!-- HARNESS_TRACKER_END -->"
TODAY="$(date +%Y-%m-%d)"

# --- helpers -----------------------------------------------------------------

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

info() {
  printf '%s\n' "$1"
}

# --- args --------------------------------------------------------------------

CHECK_ONLY=0
HEADLESS=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --headless) HEADLESS=1 ;;
    *) fail "Unknown argument: $arg" ;;
  esac
done

# --- 1. agent binary check (skip in --check mode) ----------------------------

if [ "$CHECK_ONLY" -eq 0 ]; then
  if ! command -v "$AGENT_BIN" >/dev/null 2>&1; then
    cat >&2 <<EOF
FAIL: ${AGENT_BIN} (${AGENT_NAME}) is not installed or not on PATH.

Install it (macOS / Linux):
  ${AGENT_INSTALL_CMD}

Then restart your terminal and verify:
  ${AGENT_BIN} --version

See ${AGENT_INSTALL_URL} for setup.
EOF
    exit 1
  fi
fi

# --- 2. lifecycle validation -------------------------------------------------

cd "$ROOT_DIR"
bash "$LIFECYCLE_SCRIPT" >/dev/null
info "OK  Feature lifecycle tracker valid."

# --- 3. parse tracker for eligible features ----------------------------------

# Output TSV: feature_id \t workspace_path \t status
# Columns: | ID | Feature | Workspace | Status | Updated | Notes |
# Split by "|" gives: a[2]=id, a[3]=feature, a[4]=workspace, a[5]=status, a[6]=updated
eligible_rows=$(awk -v start="$START_MARKER" -v end="$END_MARKER" '
  $0 == start { in_tracker = 1; next }
  $0 == end { exit }
  in_tracker && /^\|/ && $0 !~ /^\| ID \|/ && $0 !~ /^\|---/ {
    n = split($0, a, "|")
    if (n < 7) next
    id = a[2]; ws_cell = a[4]; status = a[5]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", ws_cell)
    workspace = ws_cell
    sub(/^\[/, "", workspace)
    sub(/\].*/, "", workspace)
    if (status == "In Progress" || status == "Awaiting implementation approval" || status == "To be reviewed" || status == "To be fixed") {
      print id "\t" workspace "\t" status
    }
  }
' "$PRODUCT_FILE")

if [ -z "$eligible_rows" ]; then
  info "No pending harness tasks (no In Progress, Awaiting implementation approval, To be reviewed, or To be fixed features in tracker)."
  exit 2
fi

# "In Progress" takes priority; otherwise the first eligible row.
in_progress_row=$(printf '%s\n' "$eligible_rows" | awk -F'\t' '$3 == "In Progress" { print; exit }')
if [ -n "$in_progress_row" ]; then
  selected_row="$in_progress_row"
else
  selected_row=$(printf '%s\n' "$eligible_rows" | head -n 1)
fi

FEATURE_ID=$(printf '%s' "$selected_row" | cut -f1)
FEATURE_DIR=$(printf '%s' "$selected_row" | cut -f2)
FEATURE_STATUS=$(printf '%s' "$selected_row" | cut -f3)
FEATURE_DIR="${FEATURE_DIR%/}"  # strip trailing slash from tracker link label

FEATURE_LIST="$ROOT_DIR/$FEATURE_DIR/feature_list.json"
[ -f "$FEATURE_LIST" ] || fail "$FEATURE_LIST does not exist for feature '$FEATURE_ID'."

# --- 4. find next pending slice or detect evaluation/fix mode ----------------

EVAL_MODE=0
FIX_MODE=0

if [ "$FEATURE_STATUS" = "To be reviewed" ]; then
  # All slices are passing and the feature is awaiting evaluation.
  EVAL_MODE=1
  info "OK  Feature '$FEATURE_ID' is 'To be reviewed' — switching to evaluation mode."
elif [ "$FEATURE_STATUS" = "To be fixed" ]; then
  # Evaluation scored below 5.0/5; the Generator must resolve code_review /
  # test_review findings before the feature returns to human review.
  FIX_MODE=1
  info "OK  Feature '$FEATURE_ID' is 'To be fixed' — switching to fix mode."
else
  # Prefer resuming an in_progress slice; otherwise pick the highest-priority
  # not_started slice.
  set +e
  SLICE_INFO=$(python3 - "$FEATURE_LIST" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
features = data.get("features", [])
in_progress = [s for s in features if s.get("status") == "in_progress"]
not_started = [s for s in features if s.get("status") == "not_started"]
candidates = in_progress if in_progress else not_started
if not candidates:
    sys.exit(42)
candidates.sort(key=lambda s: s.get("priority", 9999))
s = candidates[0]
print(f"{s['id']}\t{s.get('title', '')}\t{s.get('status', '')}")
PY
  )
  py_exit=$?
  set -e

  if [ "$py_exit" -eq 42 ]; then
    info "Feature '$FEATURE_ID' has no pending slices (no in_progress or not_started slices)."
    exit 2
  elif [ "$py_exit" -ne 0 ]; then
    fail "Failed to parse $FEATURE_LIST (python3 exit $py_exit)."
  fi
fi

if [ "$EVAL_MODE" -eq 1 ]; then
  info "OK  Evaluation target:"
  info "      Feature:    $FEATURE_ID ($FEATURE_STATUS)"
  info "      Workspace:  $FEATURE_DIR"
  info "      Mode:       Evaluation (all slices passing)"
elif [ "$FIX_MODE" -eq 1 ]; then
  info "OK  Fix target:"
  info "      Feature:    $FEATURE_ID ($FEATURE_STATUS)"
  info "      Workspace:  $FEATURE_DIR"
  info "      Mode:       Fix (resolve code_review / test_review findings)"
else
  SLICE_ID=$(printf '%s' "$SLICE_INFO" | cut -f1)
  SLICE_TITLE=$(printf '%s' "$SLICE_INFO" | cut -f2)

  info "OK  Selected task:"
  info "      Feature:    $FEATURE_ID ($FEATURE_STATUS)"
  info "      Workspace:  $FEATURE_DIR"
  info "      Slice:      $SLICE_ID - $SLICE_TITLE"
fi

# --- 5. transition tracker (skipped in --check mode) -------------------------

if [ "$CHECK_ONLY" -eq 0 ] && [ "$EVAL_MODE" -eq 0 ] && [ "$FIX_MODE" -eq 0 ]; then
  if [ "$FEATURE_STATUS" = "Awaiting implementation approval" ]; then
    info "--> Transitioning tracker: 'Awaiting implementation approval' -> 'In Progress'"
    python3 - "$PRODUCT_FILE" "$FEATURE_ID" "$TODAY" <<'PY'
import sys, re
path, feature_id, today = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    content = f.read()
pattern = re.compile(
    r'(\| ' + re.escape(feature_id) + r' \| [^|]+ \| [^|]+ \| )[^|]+( \| )[^|]+( \|)'
)
# Use \g<N> (not \N) so the backreference is not ambiguous when today starts
# with a digit.
new_content, n = pattern.subn(r'\g<1>In Progress\g<2>' + today + r'\g<3>', content, count=1)
if n == 0:
    sys.exit("Could not find tracker row for " + feature_id)
with open(path, "w") as f:
    f.write(new_content)
PY
    bash "$LIFECYCLE_SCRIPT" >/dev/null
    info "OK  Tracker transitioned and re-validated."
  fi

  # Mark the slice in_progress (idempotent) and bump last_updated.
  python3 - "$FEATURE_LIST" "$SLICE_ID" "$TODAY" <<'PY'
import json, sys
path, slice_id, today = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
changed = False
if data.get("last_updated") != today:
    data["last_updated"] = today
    changed = True
for s in data.get("features", []):
    if s.get("id") == slice_id and s.get("status") != "in_progress":
        s["status"] = "in_progress"
        changed = True
        break
if changed:
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
PY
else
  info "(--check mode: no tracker or feature_list.json mutations performed)"
fi

if [ "$EVAL_MODE" -eq 1 ]; then
  # --- 6a. build evaluation prompt -------------------------------------------
  PROMPT_TEMPLATE="$(cat "$ROOT_DIR/.agents/prompts/harness-evaluation.md")"

  PROMPT="$PROMPT_TEMPLATE"
  PROMPT="${PROMPT//__AGENT_NAME__/$AGENT_NAME}"
  PROMPT="${PROMPT//__FEATURE_ID__/$FEATURE_ID}"
  PROMPT="${PROMPT//__FEATURE_DIR__/$FEATURE_DIR}"
elif [ "$FIX_MODE" -eq 1 ]; then
  # --- 6c. build fix-mode prompt ---------------------------------------------
  # The feature was evaluated but did NOT score 5.0/5, so its tracker status is
  # "To be fixed". The Generator must resolve every code_review / test_review
  # finding, re-verify against the sprint-contract gates, and transition to
  # "To be human reviewed".
  PROMPT_TEMPLATE="$(cat "$ROOT_DIR/.agents/prompts/harness-fix.md")"

  PROMPT="$PROMPT_TEMPLATE"
  PROMPT="${PROMPT//__AGENT_NAME__/$AGENT_NAME}"
  PROMPT="${PROMPT//__FEATURE_ID__/$FEATURE_ID}"
  PROMPT="${PROMPT//__FEATURE_DIR__/$FEATURE_DIR}"
else
  # --- 6b. build generator prompt ---------------------------------------------
  PROMPT_TEMPLATE="$(cat "$ROOT_DIR/.agents/prompts/harness-generator.md")"

  PROMPT="$PROMPT_TEMPLATE"
  PROMPT="${PROMPT//__AGENT_NAME__/$AGENT_NAME}"
  PROMPT="${PROMPT//__FEATURE_ID__/$FEATURE_ID}"
  PROMPT="${PROMPT//__FEATURE_DIR__/$FEATURE_DIR}"
  PROMPT="${PROMPT//__SLICE_ID__/$SLICE_ID}"
  PROMPT="${PROMPT//__SLICE_TITLE__/$SLICE_TITLE}"
fi

# --- 7. --check mode: print and exit -----------------------------------------

if [ "$CHECK_ONLY" -eq 1 ]; then
  info ""
  if [ "$EVAL_MODE" -eq 1 ]; then
    label="Evaluation prompt"
  elif [ "$FIX_MODE" -eq 1 ]; then
    label="Fix-mode prompt"
  else
    label="Starter prompt"
  fi
  info "----- ${label} for ${AGENT_NAME} (dry-run, no mutations performed) -----"
  printf '%s\n' "$PROMPT"
  info "----- end prompt -----"
  exit 0
fi

# --- 8. print prompt + copy to clipboard (safety net for manual paste) -------

info ""
if [ "$EVAL_MODE" -eq 1 ]; then
  info "Evaluation prompt for ${AGENT_NAME} (also copied to clipboard if pbcopy is available):"
elif [ "$FIX_MODE" -eq 1 ]; then
  info "Fix-mode prompt for ${AGENT_NAME} (also copied to clipboard if pbcopy is available):"
else
  info "Starter prompt (also copied to clipboard if pbcopy is available):"
fi
info ""
printf '%s\n' "$PROMPT"
info ""

if command -v pbcopy >/dev/null 2>&1; then
  if printf '%s' "$PROMPT" | pbcopy; then
    info "OK  Prompt copied to clipboard."
  else
    info "WARN Prompt could not be copied to the clipboard; continuing."
  fi
fi

# --- 9. launch agent ---------------------------------------------------------
# If the wrapper set SKIP_LAUNCH=1, return without launching. The wrapper
# then uses PROMPT / CHECK_ONLY / HEADLESS / ROOT_DIR to do its own launch.
if [ "${SKIP_LAUNCH:-0}" = "1" ]; then
  return 0 2>/dev/null || true
fi

if [ "$HEADLESS" -eq 1 ]; then
  info "--> Launching ${AGENT_NAME} in headless mode. Output streams to this terminal."
  $AGENT_HEADLESS_CMD "$PROMPT"
  exit $?
fi

# Interactive TUI mode. With a TTY, exec the agent directly. Without one
# (launchd / background), open a new Terminal.app window.
if [ -t 1 ]; then
  info "--> Launching ${AGENT_NAME} interactive TUI. Press Ctrl+C to exit."
  exec $AGENT_INTERACTIVE_CMD "$PROMPT"
else
  info "--> No TTY detected. Opening a new Terminal.app window with ${AGENT_NAME}."
  info "    Paste the prompt with Cmd+V (already in clipboard)."
  osascript -e "tell application \"Terminal\" to do script \"cd '$ROOT_DIR' && $AGENT_BG_CMD\"" \
            -e "activate application \"Terminal\"" >/dev/null 2>&1 || \
    fail "osascript failed to open Terminal.app. Run this script from an interactive terminal."
  info "OK  Terminal window launched."
fi
