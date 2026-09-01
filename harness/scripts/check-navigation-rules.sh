#!/usr/bin/env bash
# Navigation rule entry point. Kotlin navigation source is analyzed by the
# shared structural AST checker rather than line-oriented regular expressions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/kotlin_ast_checker.py" navigation "$@"
