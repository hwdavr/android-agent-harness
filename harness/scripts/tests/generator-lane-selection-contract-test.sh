#!/usr/bin/env bash
# The generator only takes sliced-lane workspaces (with feature_list.json).
# Single-lane features are delivered by single-lane-generator and must be skipped,
# even when they are In Progress (which otherwise takes priority).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/harness" "$fixture/docs/product" \
  "$fixture/.scratch/2026-11-09-single" "$fixture/.scratch/2026-11-09-sliced"
cp -RL "$SCRIPT_DIR" "$fixture/harness/scripts"

write_tracker() {
  cat > "$fixture/docs/product/product.md" <<'MD_END'
# Product

<!-- HARNESS_TRACKER_START -->
| ID | Feature | Workspace | Status | Updated | Notes |
|---|---|---|---|---|---|
| single | Single | [.scratch/2026-11-09-single/](../../.scratch/2026-11-09-single/) | In Progress | 2026-11-09 | single lane |
| sliced | Sliced | [.scratch/2026-11-09-sliced/](../../.scratch/2026-11-09-sliced/) | Awaiting implementation approval | 2026-11-09 | sliced lane |
<!-- HARNESS_TRACKER_END -->
MD_END
}

fail_test() { echo "FAIL: $1" >&2; exit 1; }

write_tracker
echo '{"features":[{"id":"US-1","title":"First","status":"not_started","priority":1}]}' \
  > "$fixture/.scratch/2026-11-09-sliced/feature_list.json"

output="$(bash "$fixture/harness/scripts/auto-harness-generator.sh" --check 2>&1 || true)"
printf '%s' "$output" | grep -Fq "SKIP 'single'" || fail_test "single-lane row was not skipped"
printf '%s' "$output" | grep -Fq "Feature:    sliced" || fail_test "sliced row was not selected"
printf '%s' "$output" | grep -Fq "Slice:      US-1" || fail_test "first slice was not selected"

rm "$fixture/.scratch/2026-11-09-sliced/feature_list.json"
set +e
output="$(bash "$fixture/harness/scripts/auto-harness-generator.sh" --check 2>&1)"
status=$?
set -e
[ "$status" -eq 2 ] || fail_test "expected exit 2 (no generator work) when only single-lane rows exist, got $status"

echo "PASS: generator skips single-lane workspaces and picks up approved sliced-lane rows."
