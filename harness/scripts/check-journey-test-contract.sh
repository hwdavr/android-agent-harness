#!/usr/bin/env bash
# Verifies that a declared navigation/lifecycle regression is a real
# production-entry journey rather than a stateless screen or ViewModel test.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/kotlin_ast_checker.py" journey "$@"
