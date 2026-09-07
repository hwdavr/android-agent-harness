#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AGENT_DIR="$PROJECT_ROOT/.agents/agents"

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

require_text() {
  local file="$1"
  local expected="$2"
  grep -Fq "$expected" "$AGENT_DIR/$file" \
    || fail_test "$file must contain: $expected"
}

forbid_text() {
  local file="$1"
  local forbidden="$2"
  if grep -Fq "$forbidden" "$AGENT_DIR/$file"; then
    fail_test "$file contains stale instruction: $forbidden"
  fi
}

# Complex-feature planning is rooted in one dated docs/product workspace and
# hands off the approved feature list and sprint contract, never docs/current.
forbid_text planner.md "docs/current/"
forbid_text planner.md "task-list.md"
forbid_text planner.md "docs/templates/"
forbid_text planner.md "only relies on stateless Composable logic"
require_text planner.md "docs/product/<YYYY-MM-DD>-<feature-short-name>/"
require_text planner.md '`feature-specification`'
require_text planner.md '`slice-planning`'
require_text planner.md "Awaiting specification approval"
require_text planner.md "Awaiting implementation approval"
require_text planner.md "stateful screen wrappers"

# The Generator selects only an approved tracker-backed slice and routes
# evaluator findings through harness-fix rather than a made-up pipeline stage.
forbid_text generator.md ".docs/current/"
forbid_text generator.md "Select One Task"
forbid_text generator.md "HSL palettes"
require_text generator.md '`feature-orient`'
require_text generator.md "Harness Feature Tracker"
require_text generator.md '`harness-fix`'
require_text generator.md "Install App To Device"
require_text generator.md "stateful screen wrappers"
require_text generator.md "LocalAppColors"

# Evaluator skills and template links must match the installed harness names.
forbid_text evaluator.md "android-ui-verification"
forbid_text evaluator.md "docs/templates/"
require_text evaluator.md '`android-test-review`'
require_text evaluator.md '`android-code-review`'
require_text evaluator.md '`ui-verification`'
require_text evaluator.md '`harness-fix`'
require_text evaluator.md "harness/templates/evaluator-rubric-template.md"

echo "PASS: role profiles align with the canonical complex-feature workflows and installed skills."
