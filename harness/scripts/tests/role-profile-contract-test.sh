#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AGENT_DIR="$PROJECT_ROOT/.agents/agents"

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

require_link() {
  local profile="$1"
  local target="$2"
  grep -Fq "]($target)" "$AGENT_DIR/$profile" \
    || fail_test "$profile must link to $target"
  [ -f "$AGENT_DIR/$target" ] \
    || fail_test "$profile links to missing file: $target"
}

forbid_text() {
  local file="$1"
  local forbidden="$2"
  if grep -Fq "$forbidden" "$AGENT_DIR/$file"; then
    fail_test "$file contains stale instruction: $forbidden"
  fi
}

# Profiles point to the stage contracts instead of copying their details.
require_link planner.md "../workflows/feature-delivery.md"
require_link generator.md "../workflows/harness-generator.md"
require_link generator.md "../workflows/harness-fix.md"
require_link generator.md "tester.md"
require_link tester.md "../workflows/bug-fixing.md"
require_link evaluator.md "../workflows/harness-evaluation.md"
require_link evaluator.md "../workflows/feature-review.md"
require_link evaluator.md "../workflows/harness-fix.md"

# Retain the historical stale-reference regression checks.
forbid_text planner.md "docs/current/"
forbid_text planner.md "task-list.md"
forbid_text planner.md "docs/templates/"
forbid_text planner.md "only relies on stateless Composable logic"
forbid_text generator.md ".docs/current/"
forbid_text generator.md "Select One Task"
forbid_text generator.md "HSL palettes"
forbid_text evaluator.md "android-ui-verification"
forbid_text evaluator.md "docs/templates/"

echo "PASS: role profiles link to installed canonical workflows and avoid stale references."
