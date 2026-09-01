#!/usr/bin/env bash
# Rendering assertion quality entry point.  Kotlin test assertions are
# inspected through the shared AST checker rather than regular expressions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/kotlin_ast_checker.py" assertions "$@"
