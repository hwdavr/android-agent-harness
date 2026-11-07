#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORKFLOW_DIR="$PROJECT_ROOT/.agents/workflows"

fail_test() {
  echo "FAIL: $1" >&2
  return 1
}

check_routing_contract() {
  local root="$1"
  local workflow_dir="$root/.agents/workflows"
  local workflow role
  local -a workflows=(
    bug-fixing.md
    create-ui-and-verify.md
    feature-acceptance.md
    feature-delivery.md
    feature-review.md
    harness-evaluation.md
    harness-fix.md
    harness-generator.md
    harness-planning.md
  )
  local required_roles
  local stage_contract='If required delegation or a requested model is unavailable or unsupported, block the affected stage and report it; never silently substitute. Record requested and actual models in stage evidence when available.'
  local evaluator_contract='The evaluator must be fresh and independent, having neither implemented nor tested the change; if unavailable, keep independent review pending.'

  [ -f "$root/AGENTS.md" ] || { fail_test "missing root AGENTS.md"; return 1; }
  [ ! -e "$workflow_dir/agent-routing.md" ] \
    || { fail_test "obsolete .agents/workflows/agent-routing.md must not exist"; return 1; }

  for workflow in "${workflows[@]}"; do
    [ -f "$workflow_dir/$workflow" ] || { fail_test "missing workflow: $workflow"; return 1; }
    case "$workflow" in
      bug-fixing.md|create-ui-and-verify.md|feature-delivery.md)
        required_roles='planner implementer tester evaluator' ;;
      feature-acceptance.md)
        required_roles='planner tester' ;;
      feature-review.md|harness-evaluation.md)
        required_roles='evaluator' ;;
      harness-fix.md|harness-generator.md)
        required_roles='implementer tester evaluator' ;;
      harness-planning.md)
        required_roles='planner' ;;
    esac
    for role in $required_roles; do
      rg -Fq "\`$role\`" "$workflow_dir/$workflow" \
        || { fail_test "$workflow is missing its direct \`$role\` agent reference"; return 1; }
    done
    rg -Fq 'agent-routing.md' "$workflow_dir/$workflow" \
      && { fail_test "$workflow still depends on agent-routing.md"; return 1; }
    rg -Fq "$stage_contract" "$workflow_dir/$workflow" \
      || { fail_test "$workflow is missing the per-stage fail-closed and model-evidence contract"; return 1; }
    case "$required_roles" in
      *evaluator*)
        rg -Fq "$evaluator_contract" "$workflow_dir/$workflow" \
          || { fail_test "$workflow is missing its fresh independent evaluator requirement"; return 1; }
        ;;
    esac
  done

  rg -Fq 'Codex uses role profiles in `.codex/agents/`; other clients use equivalent roles.' "$root/AGENTS.md" \
    || { fail_test "AGENTS.md is missing the portable agent-profile pointer"; return 1; }
}

check_routing_contract "$PROJECT_ROOT"

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/.agents/workflows"
cp "$PROJECT_ROOT/AGENTS.md" "$fixture_dir/AGENTS.md"
for workflow in bug-fixing.md create-ui-and-verify.md feature-acceptance.md \
  feature-delivery.md feature-review.md harness-evaluation.md harness-fix.md \
  harness-generator.md harness-planning.md; do
  cp "$WORKFLOW_DIR/$workflow" "$fixture_dir/.agents/workflows/"
done

# Negative fixture: a missing directly named role must fail.
python3 - "$fixture_dir/.agents/workflows/feature-review.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text().replace('`evaluator`', 'evaluator', 1)
path.write_text(text)
PY
if check_routing_contract "$fixture_dir" >"$fixture_dir/missing-role.log" 2>&1; then
  fail_test "negative fixture accepted a workflow with its named role removed"
fi
rg -Fq 'feature-review.md is missing its direct `evaluator` agent reference' "$fixture_dir/missing-role.log" \
  || { cat "$fixture_dir/missing-role.log" >&2; fail_test "missing-role fixture failed for an unintended reason"; }

# Negative fixture: a workflow without blocked-on-unavailable behavior must fail.
cp "$WORKFLOW_DIR/feature-review.md" "$fixture_dir/.agents/workflows/feature-review.md"
python3 - "$fixture_dir/.agents/workflows/feature-review.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text().replace(
    'block the affected stage and report it; never silently substitute.',
    'continue without reporting or substitution guidance.', 1,
)
path.write_text(text)
PY
if check_routing_contract "$fixture_dir" >"$fixture_dir/fail-closed.log" 2>&1; then
  fail_test "negative fixture accepted a workflow without fail-closed delegation"
fi
rg -Fq 'feature-review.md is missing the per-stage fail-closed and model-evidence contract' "$fixture_dir/fail-closed.log" \
  || { cat "$fixture_dir/fail-closed.log" >&2; fail_test "fail-closed fixture failed for an unintended reason"; }

# Negative fixture: evaluator workflows must require a fresh independent evaluator.
cp "$WORKFLOW_DIR/feature-review.md" "$fixture_dir/.agents/workflows/feature-review.md"
python3 - "$fixture_dir/.agents/workflows/feature-review.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text().replace(
    'The evaluator must be fresh and independent, having neither implemented nor tested the change; if unavailable, keep independent review pending.',
    'The evaluator reviews the change.', 1,
)
path.write_text(text)
PY
if check_routing_contract "$fixture_dir" >"$fixture_dir/independence.log" 2>&1; then
  fail_test "negative fixture accepted evaluator workflow without independent evaluation"
fi
rg -Fq 'feature-review.md is missing its fresh independent evaluator requirement' "$fixture_dir/independence.log" \
  || { cat "$fixture_dir/independence.log" >&2; fail_test "independence fixture failed for an unintended reason"; }

echo "PASS: nine workflows directly name required roles and enforce fail-closed, model-evidence, and independent-evaluation contracts."
