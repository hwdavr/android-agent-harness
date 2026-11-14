#!/usr/bin/env bash
# Contract: prune-harness-artifacts.py keeps the written record and open-workspace
# evidence, prunes only raw output of Complete workspaces and stale unreferenced QA runs,
# is a dry run without --apply, and rotates the scheduler log in place.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRUNE="$SCRIPT_DIR/../prune-harness-artifacts.py"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

fail_test() { echo "FAIL: $1" >&2; exit 1; }

mkdir -p "$W/docs/product" "$W/.scratch/2026-01-01-done/evidence" "$W/.scratch/2026-01-02-open" \
  "$W/.qa-artifacts/old-referenced" "$W/.qa-artifacts/old-unreferenced" "$W/.qa-artifacts/recent"
cat > "$W/docs/product/product.md" <<'EOF'
<!-- HARNESS_TRACKER_START -->
| ID | Feature | Workspace | Status | Updated | Notes |
|---|---|---|---|---|---|
| done | Done | [.scratch/2026-01-01-done/](../../.scratch/2026-01-01-done/) | Complete | 2026-01-01 | n |
| open | Open | [.scratch/2026-01-02-open/](../../.scratch/2026-01-02-open/) | To be human reviewed | 2026-01-02 | n |
<!-- HARNESS_TRACKER_END -->
EOF
echo summary > "$W/.scratch/2026-01-01-done/summary.md"
echo raw > "$W/.scratch/2026-01-01-done/gradle.log"
echo apk > "$W/.scratch/2026-01-01-done/evidence/app.apk"
echo raw > "$W/.scratch/2026-01-02-open/gradle.log"
echo 'Evidence: `.qa-artifacts/old-referenced/report.json`' > "$W/.scratch/2026-01-02-open/summary.md"
for d in old-referenced old-unreferenced recent; do echo r > "$W/.qa-artifacts/$d/run.log"; done
head -c 2000000 /dev/zero > "$W/gen.log"

python3 - "$W" <<'EOF'
import os, sys, time
root = sys.argv[1]; old = time.time() - 60 * 86400
for dirpath, _, files in os.walk(root):
    if dirpath.endswith("recent") or dirpath == root:
        continue
    for f in files:
        os.utime(os.path.join(dirpath, f), (old, old))
EOF

dry=$(python3 "$PRUNE" --root "$W" --keep-runs 1)
[ -f "$W/.scratch/2026-01-01-done/gradle.log" ] || fail_test "dry run deleted a file"
printf '%s\n' "$dry" | grep -Fq 'WOULD DELETE .scratch/2026-01-01-done/gradle.log' || fail_test "dry run omitted a Complete workspace log"

python3 "$PRUNE" --root "$W" --keep-runs 1 --apply --rotate-log "$W/gen.log" --log-max-mb 1 >/dev/null

[ ! -e "$W/.scratch/2026-01-01-done/gradle.log" ] || fail_test "Complete workspace log was kept"
[ ! -e "$W/.scratch/2026-01-01-done/evidence/app.apk" ] || fail_test "Complete workspace APK was kept"
[ -f "$W/.scratch/2026-01-01-done/summary.md" ] || fail_test "Complete workspace summary was pruned"
[ -f "$W/.scratch/2026-01-02-open/gradle.log" ] || fail_test "open workspace log was pruned"
[ -d "$W/.qa-artifacts/old-referenced" ] || fail_test "QA run referenced by an open workspace was pruned"
[ -d "$W/.qa-artifacts/recent" ] || fail_test "recent QA run was pruned"
[ ! -e "$W/.qa-artifacts/old-unreferenced" ] || fail_test "stale unreferenced QA run was kept"
[ ! -s "$W/gen.log" ] && [ -s "$W/gen.log.1" ] || fail_test "scheduler log was not rotated in place"

echo "PASS: artifact retention keeps records and open evidence, prunes Complete raw output and stale QA runs, and rotates the scheduler log."
