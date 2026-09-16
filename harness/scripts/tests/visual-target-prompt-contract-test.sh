#!/usr/bin/env bash
# Contract tests for the shared visual-target mockup prompt source.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROMPT_TOOL="$REPO_ROOT/harness/scripts/visual-target-prompt.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/visual-target-prompt-contract.XXXXXX")"
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
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    fail_test "output did not contain '$expected': $*"
  }
}

mkdir -p "$FIXTURE_ROOT/design"
printf '%s\n' \
  '{' \
  '  "version": 1,' \
  '  "target_id": "prompt-target",' \
  '  "appearance": "dark",' \
  '  "device": "Pixel 8",' \
  '  "logical_size_dp": { "width": 412, "height": 915 },' \
  '  "locale": "fr-FR",' \
  '  "states": {' \
  '    "editor-empty": {' \
  '      "content_state_id": "editor-empty",' \
  '      "reference": "design/mockup_editor_empty.png",' \
  '      "content_state": "Empty editor fixture with no note content.",' \
  '      "mask": [],' \
  '      "dynamic_regions": [' \
  '        { "kind": "time", "handling": "cropped-system-insets", "rationale": "Insets are cropped." },' \
  '        { "kind": "user-content", "handling": "fixture", "rationale": "Fixture content is fixed." },' \
  '        { "kind": "identifier", "handling": "fixture", "rationale": "Fixture IDs are fixed." },' \
  '        { "kind": "keyboard", "handling": "not-present", "rationale": "The state is not editing." }' \
  '      ]' \
  '    }' \
  '  }' \
  '}' > "$FIXTURE_ROOT/visual-target.json"

output=$(bash "$PROMPT_TOOL" --target "$FIXTURE_ROOT/visual-target.json" --state editor-empty)
printf '%s\n' "$output" | grep -Fq 'Appearance: dark' || fail_test "prompt omitted appearance"
printf '%s\n' "$output" | grep -Fq 'Device: Pixel 8' || fail_test "prompt omitted device"
printf '%s\n' "$output" | grep -Fq 'Logical size: 412x915 dp' || fail_test "prompt omitted logical size"
printf '%s\n' "$output" | grep -Fq 'Locale: fr-FR' || fail_test "prompt omitted locale"
printf '%s\n' "$output" | grep -Fq 'Content state ID: editor-empty' || fail_test "prompt omitted stable state ID"
printf '%s\n' "$output" | grep -Fq 'keyboard=not-present' || fail_test "prompt omitted approved dynamic handling"

expect_failure "has no content state 'missing-state'" bash "$PROMPT_TOOL" --target "$FIXTURE_ROOT/visual-target.json" --state missing-state
expect_failure "visual target manifest not found" bash "$PROMPT_TOOL" --target "$FIXTURE_ROOT/missing.json" --state editor-empty

echo "PASS: mockup prompt generation reads appearance, device, logical size, locale, and state from the shared visual-target manifest."
