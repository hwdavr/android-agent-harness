#!/usr/bin/env bash
# Analyze gate (Spec Kit /analyze): requirement blocks ↔ implementation-plan.md ↔ tasks.md ↔ feature_list.json.
# Usage: bash harness/scripts/check-spec-plan-consistency.sh <feature-dir> [--project-root <dir>]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/check-spec-plan-consistency.py" "$@"
