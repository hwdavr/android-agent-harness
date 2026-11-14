#!/usr/bin/env bash
# Verifies that a rich-text appearance claim is backed by a test asserting the
# rendered AnnotatedString span styles, not only model or toolbar state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/kotlin_ast_checker.py" rendered-output "$@"
