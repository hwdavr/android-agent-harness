#!/usr/bin/env bash
# Architecture rule entry point.  Kotlin source analysis lives in the shared
# dependency-free AST checker; import boundaries remain owned by Detekt.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/kotlin_ast_checker.py" architecture "$@"
