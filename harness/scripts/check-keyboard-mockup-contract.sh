#!/usr/bin/env bash
# Compatibility entry point: keyboard coverage now belongs to UI_contract.md.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_DIR="${1:-}"
if [ -z "$FEATURE_DIR" ]; then
  echo "Usage: bash harness/scripts/check-keyboard-mockup-contract.sh <feature-directory> [--inventory]" >&2
  exit 2
fi
shift
exec python3 "$SCRIPT_DIR/check-ui-contract.py" "$FEATURE_DIR/UI_contract.md" "$@"
