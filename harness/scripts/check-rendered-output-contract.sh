#!/usr/bin/env bash
# Verifies that a rich-text appearance claim is backed by a Roborazzi JVM
# comparison, rather than a model/state assertion or device screenshot.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/kotlin_ast_checker.py" rendered-output "$@"
