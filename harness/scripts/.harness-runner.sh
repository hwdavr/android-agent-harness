#!/usr/bin/env bash
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT_FILE="$ROOT_DIR/scripts/.harness-prompt.tmp"
PRIMARY_CMD="codex --yolo"
FALLBACK_CMD="agy --dangerously-skip-permissions -i"
PRIMARY_NAME="codex"
FALLBACK_NAME="agy"
QUOTA_PATTERN="Individual.quota|quota.reached|rate.limit|429|RESOURCE_EXHAUSTED|token.*(exhaust|exceed|run.out|depleted)|insufficient.*(quota|credit|balance)|usage.*limit|daily.*limit|hit.*limit|Upgrade to Pro|purchase.*credits|out of credits|exceeded.*quota"
CAN_FALLBACK="1"

cd "$ROOT_DIR" || exit 1
PROMPT="$(cat "$PROMPT_FILE")"
rm -f "$PROMPT_FILE"

if [ "$CAN_FALLBACK" -eq 1 ] && [ "$PRIMARY_NAME" = "codex" ]; then
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
except Exception:
    sys.exit(1)
" 2>&1 || true)
  if echo "$probe_out" | grep -qiE "$QUOTA_PATTERN"; then
    echo ""
    echo ">>> ${PRIMARY_NAME} quota exhausted. Switching to ${FALLBACK_NAME}..."
    echo "    Error: $(echo "$probe_out" | grep -iE "$QUOTA_PATTERN" | head -1)"
    echo ""
    exec $FALLBACK_CMD "$PROMPT"
  fi
fi

echo ">>> Running ${PRIMARY_NAME}..."
output_file=$(mktemp -t harness-agent-output.XXXXXX)
exit_code=0
if command -v script >/dev/null 2>&1; then
  script -q "$output_file" bash -c "$PRIMARY_CMD \"\$1\"" -- "$PROMPT" || exit_code=$?
else
  $PRIMARY_CMD "$PROMPT" >"$output_file" 2>&1 || exit_code=$?
  cat "$output_file" >&2
fi

if [ "$exit_code" -ne 0 ] && [ "$CAN_FALLBACK" -eq 1 ]; then
  err_text=$(cat "$output_file" 2>/dev/null || true)
  if echo "$err_text" | grep -qiE "$QUOTA_PATTERN"; then
    echo ""
    echo ">>> ${PRIMARY_NAME} quota exhausted. Switching to ${FALLBACK_NAME}..."
    echo "    Error: $(echo "$err_text" | grep -iE "$QUOTA_PATTERN" | head -3)"
    echo ""
    rm -f "$output_file"
    exec $FALLBACK_CMD "$PROMPT"
  fi
fi
rm -f "$output_file"
exit "$exit_code"

