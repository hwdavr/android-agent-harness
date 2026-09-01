#!/usr/bin/env bash
# Compose rule entry point.  Kotlin source analysis lives in the shared
# dependency-free AST checker so the Unix and Windows launchers use one rule
# implementation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/kotlin_ast_checker.py" compose "$@"
