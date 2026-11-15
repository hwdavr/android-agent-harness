#!/usr/bin/env bash
# Edge-to-edge inset rule entry point: screens must account for the status and navigation bar insets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/check-edge-to-edge-insets.py" "$@"
