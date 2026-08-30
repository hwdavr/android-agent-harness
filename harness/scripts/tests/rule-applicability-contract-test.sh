#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMPLATE="$PROJECT_ROOT/harness/templates/rule-applicability-template.md"
STAGE_CHECKER="$PROJECT_ROOT/harness/scripts/check-stage-artifacts.sh"
HARNESS_AGENTS="$PROJECT_ROOT/.harness/AGENTS.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  rg -Fq "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_exists() {
  local file="$1"
  [ -f "$file" ] || fail "expected file: $file"
}

for required_file in \
  "$TEMPLATE" \
  "$PROJECT_ROOT/harness/templates/requirement-summary-template.md" \
  "$STAGE_CHECKER" \
  "$PROJECT_ROOT/AGENTS.md" \
  "$HARNESS_AGENTS" \
  "$PROJECT_ROOT/.agents/skills/requirement-analysis/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/feature-specification/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/requirement-capture/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/implementation-plan/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/android-testing/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/feature-orient/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/code-quality-fix/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/android-code-quality-checks/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/android-code-review/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/android-test-review/SKILL.md" \
  "$PROJECT_ROOT/.agents/skills/code-review-and-quality/SKILL.md" \
  "$PROJECT_ROOT/.agents/workflows/create-ui-and-verify.md" \
  "$PROJECT_ROOT/.agents/workflows/harness-generator.md" \
  "$PROJECT_ROOT/.agents/workflows/harness-fix.md" \
  "$PROJECT_ROOT/.agents/gates/ci-checks.md" \
  "$PROJECT_ROOT/harness/templates/code-review-template.md" \
  "$PROJECT_ROOT/harness/templates/test-review-template.md"; do
  assert_exists "$required_file"
done

for rule_id in ARCH IMPL TEST SUI L10N NAV API OBS ANL; do
  assert_contains "$TEMPLATE" "| $rule_id |"
done

assert_contains "$TEMPLATE" "Not applicable — <feature-specific reason>"
assert_contains "$TEMPLATE" "Exception — approved by <user/date>"
assert_contains "$TEMPLATE" "analytics: none"
assert_contains "$STAGE_CHECKER" "require_rule_applicability"
assert_contains "$PROJECT_ROOT/.agents/skills/requirement-analysis/SKILL.md" "Rule Applicability"
assert_contains "$PROJECT_ROOT/.agents/skills/feature-specification/SKILL.md" "Rule Applicability"
assert_contains "$PROJECT_ROOT/.agents/skills/requirement-capture/SKILL.md" "Rule Applicability"
assert_contains "$PROJECT_ROOT/.agents/skills/implementation-plan/SKILL.md" "Rule Applicability Implementation"
assert_contains "$PROJECT_ROOT/.agents/skills/android-testing/SKILL.md" "Every required Rule Applicability row"
assert_contains "$PROJECT_ROOT/.agents/skills/feature-orient/SKILL.md" "complete Rule Applicability matrix"
assert_contains "$PROJECT_ROOT/.agents/skills/code-quality-fix/SKILL.md" "Rule Applicability matrix"
assert_contains "$PROJECT_ROOT/.agents/skills/android-code-quality-checks/SKILL.md" "Rule Applicability Harness Contract"
assert_contains "$PROJECT_ROOT/.agents/skills/android-code-review/SKILL.md" "Rule Applicability Reconciliation"
assert_contains "$PROJECT_ROOT/.agents/skills/android-test-review/SKILL.md" "Rule Applicability Test Reconciliation"
assert_contains "$PROJECT_ROOT/.agents/skills/code-review-and-quality/SKILL.md" "Reconcile the Approved Rule Contract"
assert_contains "$PROJECT_ROOT/.agents/workflows/create-ui-and-verify.md" "approved Rule Applicability matrix"
assert_contains "$PROJECT_ROOT/.agents/workflows/harness-generator.md" "approved Rule Applicability decisions"
assert_contains "$PROJECT_ROOT/.agents/workflows/harness-fix.md" "Reconcile all Rule Applicability rows again"
assert_contains "$PROJECT_ROOT/.agents/gates/ci-checks.md" "Rule Applicability Harness Contract"
assert_contains "$PROJECT_ROOT/harness/templates/code-review-template.md" "Rule Applicability Reconciliation"
assert_contains "$PROJECT_ROOT/harness/templates/test-review-template.md" "Rule Applicability Test Reconciliation"
assert_contains "$PROJECT_ROOT/AGENTS.md" "rule-applicability-template.md"
assert_contains "$PROJECT_ROOT/AGENTS.md" "feature-specific evidence"

cmp -s "$PROJECT_ROOT/AGENTS.md" "$HARNESS_AGENTS" || \
  fail "harness AGENTS.md does not match the repository AGENTS.md"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rule-applicability-contract.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

create_spec() {
  local output="$1"
  local omit_rule_id="${2:-}"
  local rule_id

  printf '%s\n' '# Spec' '' '## Rule Applicability' '' \
    '| Rule ID | Rule document | Default | Decision for this change | Trigger / rationale | Planned evidence |' \
    '|---|---|---|---|---|---|' > "$output"
  for rule_id in ARCH IMPL TEST SUI L10N NAV API OBS ANL; do
    if [ "$rule_id" != "$omit_rule_id" ]; then
      printf '| %s | rule.md | Always | Required | contract test | shell evidence |\n' "$rule_id" >> "$output"
    fi
  done
}

VALID_DOCS="$TEMP_ROOT/valid"
INVALID_DOCS="$TEMP_ROOT/invalid"
mkdir -p "$VALID_DOCS" "$INVALID_DOCS"
touch "$VALID_DOCS/summary_v1.md" "$INVALID_DOCS/summary_v1.md"
create_spec "$VALID_DOCS/spec_v1.md"
create_spec "$INVALID_DOCS/spec_v1.md" ANL

bash "$STAGE_CHECKER" feature-delivery requirement-analysis "$VALID_DOCS" >/dev/null \
  || fail "complete rule-applicability matrix did not pass the requirement gate"

set +e
invalid_output="$(bash "$STAGE_CHECKER" feature-delivery requirement-analysis "$INVALID_DOCS" 2>&1)"
invalid_status=$?
set -e

[ "$invalid_status" -ne 0 ] || fail "incomplete rule-applicability matrix unexpectedly passed"
printf '%s\n' "$invalid_output" | rg -Fq "missing the ANL rule-applicability row" \
  || fail "incomplete matrix did not report the missing rule row"

echo "PASS: rule-applicability contract accepts complete and rejects incomplete requirement artifacts."
