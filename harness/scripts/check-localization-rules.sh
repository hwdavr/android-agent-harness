#!/usr/bin/env bash
# Localization rule entry point.  Kotlin source analysis lives in the shared
# dependency-free AST checker so comments and literals cannot become code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/kotlin_ast_checker.py" localization "$@"
