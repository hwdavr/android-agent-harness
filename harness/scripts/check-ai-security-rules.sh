#!/usr/bin/env bash
# AI and WebView security policy entry point.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/check-ai-security-rules.py" "$@"
