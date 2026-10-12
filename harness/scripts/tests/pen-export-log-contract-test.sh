#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checker="$script_dir/../check-pen-export-log.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

clean_log="$tmp_dir/clean.log"
printf '%s\n' '[INFO] Exported screen.png' > "$clean_log"
bash "$checker" "$clean_log" >/dev/null

bad_log="$tmp_dir/missing-font.log"
printf '%s\n' '[ERROR] Failed to load font family lucide-0 AssetFetchError' > "$bad_log"
if bash "$checker" "$bad_log" >/dev/null 2>&1; then
    echo "FAIL: missing-font export log was accepted" >&2
    exit 1
fi

placeholder_log="$tmp_dir/placeholder.log"
printf '%s\n' '[WARN] question-mark glyph placeholder rendered' > "$placeholder_log"
if bash "$checker" "$placeholder_log" >/dev/null 2>&1; then
    echo "FAIL: placeholder-glyph export log was accepted" >&2
    exit 1
fi

echo "PASS: Pen export log contract rejects missing-font and placeholder-glyph diagnostics."
