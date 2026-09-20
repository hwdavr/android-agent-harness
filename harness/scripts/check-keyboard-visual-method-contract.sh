#!/usr/bin/env bash
# Require keyboard-state visual tests to prove software-IME visibility before capture.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/kotlin_ast_checker.py" keyboard-visual "$@"
