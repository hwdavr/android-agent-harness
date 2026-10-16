#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <pen-export-log>" >&2
    exit 2
fi

log_file="$1"
if [[ ! -f "$log_file" ]]; then
    echo "FAIL: Pen export log does not exist: $log_file" >&2
    exit 1
fi

failure_pattern='Failed to load font family|AssetFetchError|Failed to load .*font|placeholder glyph|question.?mark'
if matches=$(rg -n -i "$failure_pattern" "$log_file"); then
    echo "FAIL: Pen export contains missing-asset or placeholder-glyph diagnostics:" >&2
    echo "$matches" >&2
    echo "Do not approve or use the PNG; restore the asset/font dependency and re-export." >&2
    exit 1
fi

echo "PASS: Pen export log contains no missing-font, asset-fetch, or placeholder-glyph diagnostics."
