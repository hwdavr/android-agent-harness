#!/usr/bin/env bash
# Contract tests for prepare-visual-runtime.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HELPER="$REPO_ROOT/harness/scripts/prepare-visual-runtime.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/visual-runtime-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "$output" >&2
    fail_test "command unexpectedly succeeded: $*"
  fi
  printf '%s\n' "$output" | grep -Fq -- "$expected" || {
    echo "$output" >&2
    fail_test "output did not contain '$expected': $*"
  }
}

mkdir -p "$FIXTURE_ROOT/bin"
cat > "$FIXTURE_ROOT/bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ge 1 ] && [ "$1" = "devices" ]; then
  printf 'List of devices attached\nemulator-5554\tdevice\n\n'
  exit 0
fi
if [ "$#" -ge 2 ] && [ "$1" = "-s" ]; then
  printf '%s\n' "$*" >> "${VISUAL_RUNTIME_CALL_LOG:?}"
  exit 0
fi
echo "unexpected adb invocation: $*" >&2
exit 1
EOF
chmod +x "$FIXTURE_ROOT/bin/adb"

export VISUAL_RUNTIME_CALL_LOG="$FIXTURE_ROOT/calls.log"
printf '%s\n' \
  '{' \
  '  "version": 1,' \
  '  "target_id": "runtime-test",' \
  '  "appearance": "light",' \
  '  "device": "Pixel 8",' \
  '  "logical_size_dp": { "width": 412, "height": 915 },' \
  '  "locale": "en-US",' \
  '  "states": { "runtime-state": {} }' \
  '}' > "$FIXTURE_ROOT/visual-target.json"
PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/visual-target.json"
PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/visual-target.json" --device emulator-5554
grep -Fq "cmd uimode night no" "$VISUAL_RUNTIME_CALL_LOG" \
  || fail_test "the helper did not configure the requested light appearance"

printf '%s\n' \
  '{' \
  '  "version": 1,' \
  '  "target_id": "runtime-test-invalid-locale",' \
  '  "appearance": "light",' \
  '  "device": "Pixel 8",' \
  '  "logical_size_dp": { "width": 412, "height": 915 },' \
  '  "locale": "en",' \
  '  "states": { "runtime-state": {} }' \
  '}' > "$FIXTURE_ROOT/invalid-locale-target.json"
expect_failure "visual target locale must be a concrete BCP-47" env PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/invalid-locale-target.json"

printf '%s\n' \
  '{' \
  '  "version": 1,' \
  '  "target_id": "runtime-test-wrong-device",' \
  '  "appearance": "light",' \
  '  "device": "Pixel 9",' \
  '  "logical_size_dp": { "width": 412, "height": 915 },' \
  '  "locale": "en-US",' \
  '  "states": { "runtime-state": {} }' \
  '}' > "$FIXTURE_ROOT/wrong-device-target.json"
expect_failure "conflicts with visual target device" env PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/wrong-device-target.json" --device-name "Pixel 8"

cat > "$FIXTURE_ROOT/bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ge 1 ] && [ "$1" = "devices" ]; then
  printf 'List of devices attached\n\n'
  exit 0
fi
exit 1
EOF
chmod +x "$FIXTURE_ROOT/bin/adb"
expect_failure "no connected Android device or emulator found" env PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/visual-target.json"

echo "PASS: visual runtime preflight configures the shared target on the requested booted emulator/device and rejects invalid locale, device, and availability cases."
