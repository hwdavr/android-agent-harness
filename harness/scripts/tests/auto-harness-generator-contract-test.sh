#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/auto-harness-contract.XXXXXX")
ACTIVE_FIXTURE=""

cleanup() {
  if [ -n "$ACTIVE_FIXTURE" ]; then
    local lock_dir
    lock_dir=$(lock_path "$ACTIVE_FIXTURE")
    rm -f "$lock_dir/pid"
    rmdir "$lock_dir" 2>/dev/null || true
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail_test() {
  echo "FAIL: $1" >&2
  if [ -n "$ACTIVE_FIXTURE" ] && [ -f "$ACTIVE_FIXTURE/run.log" ]; then
    echo "--- fixture run.log ---" >&2
    sed -n '1,240p' "$ACTIVE_FIXTURE/run.log" >&2
    echo "--- end fixture run.log ---" >&2
  fi
  exit 1
}

lock_path() {
  local root
  root=$(cd "$1" && pwd)
  local key
  key=$(printf '%s' "$root" | cksum | awk '{print $1}')
  printf '/tmp/android-harness-%s.lock' "$key"
}

write_fake_codex() {
  local home_dir="$1"
  mkdir -p "$home_dir/.local/bin"
  cat > "$home_dir/.local/bin/codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
set -euo pipefail

if [ "${3:-}" = "ping" ]; then
  if [ "${FAKE_MODE:-advance}" = "quota" ]; then
    printf 'quota.reached\n' >&2
    exit 9
  fi
  exit 0
fi

count=0
if [ -f "$FAKE_COUNT_FILE" ]; then
  count=$(wc -l < "$FAKE_COUNT_FILE" | tr -d ' ')
fi
printf '%s\n' "session-$((count + 1))" >> "$FAKE_COUNT_FILE"
printf '%s %s\n' "${1:-}" "${2:-}" >> "$FAKE_ARGS_FILE"

if [ "${FAKE_MODE:-advance}" = "quota" ]; then
  printf '%s\n' 'quota.reached' >&2
  exit 9
fi

if [ "${FAKE_MODE:-advance}" = "fail" ]; then
  exit 9
fi

if [ "${FAKE_MODE:-advance}" = "no-progress" ]; then
  exit 0
fi

python3 - "$FAKE_FEATURE_LIST" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path) as handle:
    data = json.load(handle)

for feature in data.get("features", []):
    if feature.get("status") == "in_progress":
        feature["status"] = "passing"
        break

with open(path, "w") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
FAKE_CODEX
  chmod +x "$home_dir/.local/bin/codex"
}

write_fake_agy() {
  local home_dir="$1"
  mkdir -p "$home_dir/.local/bin"
  cat > "$home_dir/.local/bin/agy" <<'FAKE_AGY'
#!/usr/bin/env bash
set -euo pipefail

count=0
if [ -f "$FAKE_FALLBACK_COUNT_FILE" ]; then
  count=$(wc -l < "$FAKE_FALLBACK_COUNT_FILE" | tr -d ' ')
fi
printf '%s\n' "fallback-$((count + 1))" >> "$FAKE_FALLBACK_COUNT_FILE"
printf '%s %s %s\n' "${1:-}" "${2:-}" "${3:-}" >> "$FAKE_FALLBACK_ARGS_FILE"

python3 - "$FAKE_FEATURE_LIST" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path) as handle:
    data = json.load(handle)

for feature in data.get("features", []):
    if feature.get("status") == "in_progress":
        feature["status"] = "passing"
        break

with open(path, "w") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
FAKE_AGY
  chmod +x "$home_dir/.local/bin/agy"
}

create_fixture() {
  local name="$1"
  ACTIVE_FIXTURE="$TEST_ROOT/$name"
  mkdir -p "$ACTIVE_FIXTURE/harness/scripts" \
    "$ACTIVE_FIXTURE/docs/product/test-feature" \
    "$ACTIVE_FIXTURE/home/.local/bin" \
    "$ACTIVE_FIXTURE/.agents"

  cp -r "$PROJECT_ROOT/.agents/prompts" "$ACTIVE_FIXTURE/.agents/"
  cp "$PROJECT_ROOT/harness/scripts/auto-harness-generator.sh" "$ACTIVE_FIXTURE/harness/scripts/"
  cp "$PROJECT_ROOT/harness/scripts/harness-generator-common.sh" "$ACTIVE_FIXTURE/harness/scripts/"
  cp "$PROJECT_ROOT/harness/scripts/check-feature-lifecycle.sh" "$ACTIVE_FIXTURE/harness/scripts/"
  chmod +x "$ACTIVE_FIXTURE/harness/scripts/"*.sh

  printf '%s\n' \
    '# Fixture' \
    '<!-- HARNESS_TRACKER_START -->' \
    '| ID | Feature | Workspace | Status | Updated | Notes |' \
    '|---|---|---|---|---|---|' \
    '| test-feature | Test Feature | [docs/product/test-feature/](test-feature/) | In Progress | 2026-08-09 | Contract fixture |' \
    '<!-- HARNESS_TRACKER_END -->' \
    > "$ACTIVE_FIXTURE/docs/product/product.md"

  cat > "$ACTIVE_FIXTURE/docs/product/test-feature/feature_list.json" <<'JSON'
{
  "last_updated": "2026-08-09",
  "features": [
    {
      "id": "US-1",
      "title": "First fixture task",
      "priority": 1,
      "status": "not_started"
    },
    {
      "id": "US-2",
      "title": "Second fixture task",
      "priority": 2,
      "status": "not_started"
    }
  ]
}
JSON

  write_fake_codex "$ACTIVE_FIXTURE/home"
  write_fake_agy "$ACTIVE_FIXTURE/home"
  cat > "$ACTIVE_FIXTURE/home/.local/bin/pbcopy" <<'FAKE_PBCOPY'
#!/usr/bin/env bash
cat >/dev/null
FAKE_PBCOPY
  chmod +x "$ACTIVE_FIXTURE/home/.local/bin/pbcopy"
  cat > "$ACTIVE_FIXTURE/home/.local/bin/osascript" <<'FAKE_OSASCRIPT'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$FAKE_OSASCRIPT_ARGS_FILE"
launcher=$(printf '%s\n' "$@" | sed -n 's#.*do script "/bin/bash \([^"]*\)".*#\1#p')
[ -n "$launcher" ] && [ -f "$launcher" ] || exit 1
cat "$launcher" >> "$FAKE_OSASCRIPT_ARGS_FILE"
launcher_dir=$(dirname "$launcher")
cat "$launcher_dir/prompt" >> "$FAKE_OSASCRIPT_ARGS_FILE"
printf '%s\n' "$$" > "$launcher_dir/pid"
: > "$launcher_dir/agent-ready"
FAKE_OSASCRIPT
  chmod +x "$ACTIVE_FIXTURE/home/.local/bin/osascript"
  export FAKE_FEATURE_LIST="$ACTIVE_FIXTURE/docs/product/test-feature/feature_list.json"
  export FAKE_COUNT_FILE="$ACTIVE_FIXTURE/codex.count"
  export FAKE_ARGS_FILE="$ACTIVE_FIXTURE/codex.args"
  export FAKE_FALLBACK_COUNT_FILE="$ACTIVE_FIXTURE/agy.count"
  export FAKE_FALLBACK_ARGS_FILE="$ACTIVE_FIXTURE/agy.args"
  export FAKE_OSASCRIPT_ARGS_FILE="$ACTIVE_FIXTURE/osascript.args"
}

run_generator() {
  local mode="$1"
  local generator="$ACTIVE_FIXTURE/harness/scripts/auto-harness-generator.sh"
  set +e
  HOME="$ACTIVE_FIXTURE/home" \
    FAKE_MODE="$mode" \
    bash "$generator" --headless > "$ACTIVE_FIXTURE/run.log" 2>&1
  LAST_STATUS=$?
  set -e
}

run_generator_without_flag() {
  local mode="$1"
  local generator="$ACTIVE_FIXTURE/harness/scripts/auto-harness-generator.sh"
  set +e
  HOME="$ACTIVE_FIXTURE/home" \
    FAKE_MODE="$mode" \
    bash "$generator" > "$ACTIVE_FIXTURE/run.log" 2>&1
  LAST_STATUS=$?
  set -e
}

assert_file_line_count() {
  local file="$1"
  local expected="$2"
  local actual=0
  if [ -f "$file" ]; then
    actual=$(wc -l < "$file" | tr -d ' ')
  fi
  [ "$actual" -eq "$expected" ] ||
    fail_test "$file expected $expected lines but contained $actual"
}

test_headless_drain() {
  create_fixture "drain"
  run_generator "advance"

  [ "$LAST_STATUS" -eq 2 ] || fail_test "drain should finish with exit 2 when no tasks remain"
  assert_file_line_count "$ACTIVE_FIXTURE/codex.count" 2
  assert_file_line_count "$ACTIVE_FIXTURE/codex.args" 2
  grep -Fqx 'exec --yolo' "$ACTIVE_FIXTURE/codex.args" ||
    fail_test "headless Codex was not invoked as 'codex exec --yolo'"
  [ ! -d "$(lock_path "$ACTIVE_FIXTURE")" ] || fail_test "lock remained after a drained run"
}

test_no_progress_stops() {
  create_fixture "no-progress"
  run_generator "no-progress"

  [ "$LAST_STATUS" -eq 0 ] || fail_test "no-progress run should stop cleanly"
  assert_file_line_count "$ACTIVE_FIXTURE/codex.count" 1
  [ ! -d "$(lock_path "$ACTIVE_FIXTURE")" ] || fail_test "lock remained after no-progress stop"
}

test_no_tty_opens_interactive_terminal() {
  create_fixture "no-tty"
  run_generator_without_flag "advance"

  [ "$LAST_STATUS" -eq 0 ] || fail_test "no-TTY interactive scheduler run should hand off successfully"
  assert_file_line_count "$ACTIVE_FIXTURE/codex.count" 0
  grep -Fq 'Terminal' "$ACTIVE_FIXTURE/osascript.args" ||
    fail_test "no-TTY invocation did not ask Terminal.app to launch"
  grep -Fq 'exec codex --yolo "$(cat ' "$ACTIVE_FIXTURE/osascript.args" ||
    fail_test "no-TTY launcher did not pass the harness prompt to interactive Codex"
  grep -Fq 'You are the Generator' "$ACTIVE_FIXTURE/osascript.args" ||
    fail_test "no-TTY launcher did not create the selected harness prompt"
  rm -rf "$(lock_path "$ACTIVE_FIXTURE")"
}

test_lock_contention() {
  create_fixture "lock-contention"
  local lock_dir
  lock_dir=$(lock_path "$ACTIVE_FIXTURE")
  mkdir "$lock_dir"
  printf '%s\n' "$$" > "$lock_dir/pid"

  run_generator "advance"

  [ "$LAST_STATUS" -eq 0 ] || fail_test "lock contention should exit 0"
  assert_file_line_count "$ACTIVE_FIXTURE/codex.count" 0
  grep -Fq 'already running' "$ACTIVE_FIXTURE/run.log" ||
    fail_test "lock contention was not reported"

  rm -f "$lock_dir/pid"
  rmdir "$lock_dir"
}

test_completed_task_lock_handoff() {
  create_fixture "completed-task-handoff"
  python3 - "$ACTIVE_FIXTURE/docs/product/test-feature/feature_list.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path) as handle:
    data = json.load(handle)
data["features"][0]["status"] = "passing"
with open(path, "w") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

  local lock_dir
  lock_dir=$(lock_path "$ACTIVE_FIXTURE")
  mkdir "$lock_dir"
  printf '%s\n' "$$" > "$lock_dir/pid"
  cat > "$lock_dir/task" <<EOF
feature_id=test-feature
feature_status=In Progress
feature_list=$ACTIVE_FIXTURE/docs/product/test-feature/feature_list.json
eval_mode=0
fix_mode=0
slice_id=US-1
EOF

  run_generator "advance"

  [ "$LAST_STATUS" -eq 2 ] || fail_test "completed-task handoff should drain and finish with exit 2"
  assert_file_line_count "$ACTIVE_FIXTURE/codex.count" 1
  grep -Fq 'completed its task; handing off' "$ACTIVE_FIXTURE/run.log" ||
    fail_test "completed task lock was not handed off"
  [ ! -d "$lock_dir" ] || fail_test "lock remained after completed-task handoff"
}

test_stale_lock_reclaimed() {
  create_fixture "stale-lock"
  local lock_dir
  lock_dir=$(lock_path "$ACTIVE_FIXTURE")
  mkdir "$lock_dir"
  printf '%s\n' 99999999 > "$lock_dir/pid"

  run_generator "advance"

  [ "$LAST_STATUS" -eq 2 ] || fail_test "stale-lock run should drain and finish with exit 2"
  assert_file_line_count "$ACTIVE_FIXTURE/codex.count" 2
  [ ! -d "$lock_dir" ] || fail_test "stale lock was not removed"
}

test_failure_cleans_lock() {
  create_fixture "failure"
  run_generator "fail"

  [ "$LAST_STATUS" -eq 1 ] || fail_test "agent failure should return exit 1"
  assert_file_line_count "$ACTIVE_FIXTURE/codex.count" 1
  [ ! -d "$(lock_path "$ACTIVE_FIXTURE")" ] || fail_test "lock remained after agent failure"
}

test_quota_fallback() {
  create_fixture "quota-fallback"
  run_generator "quota"

  [ "$LAST_STATUS" -eq 2 ] || fail_test "quota fallback should drain and finish with exit 2"
  assert_file_line_count "$ACTIVE_FIXTURE/codex.count" 0
  assert_file_line_count "$ACTIVE_FIXTURE/agy.count" 2
  grep -Fq -- '--dangerously-skip-permissions -p' "$ACTIVE_FIXTURE/agy.args" ||
    fail_test "agy fallback was not invoked in print mode"
}

test_headless_drain
test_no_progress_stops
test_no_tty_opens_interactive_terminal
test_lock_contention
test_completed_task_lock_handoff
test_stale_lock_reclaimed
test_failure_cleans_lock
test_quota_fallback

echo "PASS: auto harness generator lock, headless drain, fallback, and cleanup contracts."
