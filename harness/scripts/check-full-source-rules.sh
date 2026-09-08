#!/usr/bin/env bash
# Run every repository-wide source-rule checker and aggregate failures.
# The individual AST entry points default to changed-file scans; this bundle
# deliberately passes --all so baseline, review, fix, and CI flows cannot miss
# violations in untouched files. All checks run even when an earlier check fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_project_root() {
  local candidate="$SCRIPT_DIR"
  while [ "$candidate" != "/" ]; do
    if [ -f "$candidate/settings.gradle.kts" ]; then
      cd "$candidate" && pwd -P
      return 0
    fi
    candidate="$(dirname "$candidate")"
  done
  echo "ERROR: unable to find project root (settings.gradle.kts) above $SCRIPT_DIR" >&2
  return 1
}

DEFAULT_PROJECT_ROOT="$(find_project_root)" || exit 2
PROJECT_ROOT="$DEFAULT_PROJECT_ROOT"

usage() {
  cat >&2 <<'USAGE'
Usage: check-full-source-rules.sh [--project-root <path>]

Runs architecture, Compose, localization, navigation, and test-assertion
checkers against the complete source tree, followed by the AI/WebView security
evaluator and its contract test. Every checker runs; the command returns
non-zero when one or more checkers report violations.
USAGE
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || usage
      if [ -d "$2" ]; then
        PROJECT_ROOT="$(cd "$2" && pwd -P)"
      else
        echo "ERROR: project root does not exist: $2" >&2
        exit 2
      fi
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      ;;
  esac
done

failed=0

run_check() {
  local label="$1"
  shift
  echo
  echo ">> $label"
  "$@"
  local status=$?
  if [ "$status" -eq 0 ]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $status)" >&2
    failed=1
  fi
}

run_check "Architecture rules (full source)" \
  bash "$SCRIPT_DIR/check-architecture-rules.sh" \
  --project-root "$PROJECT_ROOT" --all
run_check "Compose rules (full source)" \
  bash "$SCRIPT_DIR/check-compose-rules.sh" \
  --project-root "$PROJECT_ROOT" --all
run_check "Localization rules (full source)" \
  bash "$SCRIPT_DIR/check-localization-rules.sh" \
  --project-root "$PROJECT_ROOT" --all
run_check "Navigation rules (full source)" \
  bash "$SCRIPT_DIR/check-navigation-rules.sh" \
  --project-root "$PROJECT_ROOT"
run_check "Test assertion rules (full test source)" \
  bash "$SCRIPT_DIR/check-test-assertions-quality.sh" \
  --project-root "$PROJECT_ROOT"
run_check "AI security rules" \
  bash "$SCRIPT_DIR/check-ai-security-rules.sh" \
  --root "$PROJECT_ROOT"
run_check "AI security rule contract" \
  bash "$SCRIPT_DIR/tests/ai-security-rules-contract-test.sh"

echo
if [ "$failed" -eq 0 ]; then
  echo "PASS: full-source rules bundle (all checkers passed)"
  exit 0
fi

echo "FAIL: full-source rules bundle (one or more checkers failed)" >&2
exit 1
