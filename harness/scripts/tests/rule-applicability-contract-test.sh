#!/usr/bin/env bash
# Rule Applicability contract: implementation-plan.md owns the ten-row matrix, test-plan.md links
# and maps its Required rows, and the stage gates reject incomplete or unmapped matrices.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
if [[ ! -f "$PROJECT_ROOT/settings.gradle.kts" && -f "$PROJECT_ROOT/../settings.gradle.kts" ]]; then
  PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
fi
HARNESS_AGENTS="$PROJECT_ROOT/AGENTS.md"
for candidate in "$PROJECT_ROOT/.harness/AGENTS.md" "$PROJECT_ROOT/android-agent-harness/AGENTS.md"; do
  [ -f "$candidate" ] && HARNESS_AGENTS="$candidate" && break
done
STAGE_CHECKER="$PROJECT_ROOT/harness/scripts/check-stage-artifacts.sh"
T="$PROJECT_ROOT/harness/templates"

fail() { echo "FAIL: $1" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "expected $1 to contain: $2"; }

for rule_id in ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC; do
  assert_contains "$T/rule-applicability-template.md" "| $rule_id |"
  assert_contains "$T/implementation-plan-template.md" "| $rule_id |"
done
assert_contains "$T/rule-applicability-template.md" "Not applicable — <feature-specific reason>"
assert_contains "$T/rule-applicability-template.md" "Exception — approved by <user/date>"
assert_contains "$T/rule-applicability-template.md" "analytics: none"
assert_contains "$T/implementation-plan-template.md" "## Rule Applicability"
assert_contains "$T/implementation-plan-template.md" "rules gate"
assert_contains "$T/test-plan-template.md" "implementation-plan.md#rule-applicability"
assert_contains "$T/summary-template.md" "Context Provenance"
assert_contains "$T/summary-template.md" "## Product Requirement Reconciliation"
assert_contains "$T/summary-profiles/single-lane-generator.md" "Product Document Update"
assert_contains "$T/summary-profiles/bug-fixing.md" "Ad-hoc Bug Fix"
assert_contains "$T/code-review-template.md" "Rule Applicability Reconciliation"
assert_contains "$T/test-review-template.md" "Rule Applicability Test Reconciliation"
assert_contains "$STAGE_CHECKER" "require_rule_applicability"
assert_contains "$STAGE_CHECKER" "require_required_rule_mappings"

S="$PROJECT_ROOT/.agents/skills"
assert_contains "$S/implementation-plan/SKILL.md" "**Rule Applicability** is the rules gate"
assert_contains "$S/android-testing/SKILL.md" 'Every `Required` Rule Applicability row'
assert_contains "$S/feature-orient/SKILL.md" "print-context-index.sh"
assert_contains "$S/android-code-review/SKILL.md" "Rule Applicability Reconciliation"
assert_contains "$S/android-test-review/SKILL.md" "Rule Applicability Test Reconciliation"
assert_contains "$S/code-review-and-quality/SKILL.md" "Reconcile the Approved Rule Contract"
assert_contains "$S/android-implementation/SKILL.md" "only triggered context"
assert_contains "$PROJECT_ROOT/.agents/rules/product-documentation.md" "edit existing requirement rows and paragraphs in place"
assert_contains "$PROJECT_ROOT/.agents/rules/product-documentation.md" "instead of appending a new dated/versioned subsection"
assert_contains "$PROJECT_ROOT/.agents/workflows/single-lane-generator.md" "Existing claim reviewed"
assert_contains "$PROJECT_ROOT/.agents/workflows/sliced-lane-generator.md" "approved Rule Applicability decisions"
assert_contains "$PROJECT_ROOT/.agents/workflows/harness-fix.md" "Reconcile all Rule Applicability rows again"
assert_contains "$PROJECT_ROOT/.agents/gates/ci-checks.md" "Rule Applicability Harness Contract"
assert_contains "$HARNESS_AGENTS" "rule-applicability-template.md"
assert_contains "$HARNESS_AGENTS" "The approved \`implementation-plan.md\` is canonical"
assert_contains "$HARNESS_AGENTS" "print-context-index.sh"
assert_contains "$HARNESS_AGENTS" "available skill mechanism"

# ---------------------------------------------------------------- stage gate behavior
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rule-applicability-contract.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
W="$ROOT/.scratch/2026-11-09-rules"
mkdir -p "$W" "$ROOT/docs/product/requirements"
cat > "$ROOT/docs/product/requirements/rules.md" <<'MD'
# Rules

## Planned changes

<!-- feature: rules -->
### rules — Fixture

**Status**: Clarified

#### Requirements

##### FR-001 — Behavior (New)

**Acceptance criteria**

- **AC-001**: Given the fixture, when the gate runs, then it validates.
<!-- /feature: rules -->
MD
cat > "$ROOT/docs/product/product.md" <<'MD'
<!-- HARNESS_TRACKER_START -->
| ID | Feature | Workspace | Status | Updated | Notes |
|---|---|---|---|---|---|
| rules | Rules fixture | [.scratch/2026-11-09-rules/](../../.scratch/2026-11-09-rules/) | Planning | 2026-11-09 | fixture |
<!-- HARNESS_TRACKER_END -->
MD

write_plan() {  # $1 = rule to omit
  {
    printf '%s\n' '# Implementation Plan' '' '**Feature ID**: `rules`' '**Lane**: single' '' '## Product Requirements' '' \
      '| Capability file | Feature block | Requirement IDs | Approved block SHA-256 | Approved by / date |' '|---|---|---|---|---|' \
      '| `docs/product/requirements/rules.md` | `rules` | FR-001 | `<64 hex characters>` | pending |' '' '## Rule Applicability' '' \
      '| Rule ID | Rule document | Decision | Feature-specific trigger or reason | Planned work and evidence |' '|---|---|---|---|---|'
    for rule_id in ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC; do
      [ "$rule_id" = "${1:-}" ] && continue
      case "$rule_id" in
        SUI|L10N|NAV|OBS|ANL|SEC) printf '| %s | rule.md | Not applicable — fixture scope | | |\n' "$rule_id" ;;
        *) printf '| %s | rule.md | Required | fixture | evidence |\n' "$rule_id" ;;
      esac
    done
  } > "$W/implementation-plan.md"
}
write_test_plan() {  # $1 = canonical reference, $2 = rule to omit from mapping
  {
    printf '%s\n' '# Test Plan' '' '## Rule Applicability Test Mapping' '' "Canonical decisions: [$1]($1)." '' \
      '| Required Rule ID | Planned verification |' '|---|---|'
    for rule_id in ARCH IMPL TEST API; do
      [ "$rule_id" = "${2:-}" ] || printf '| %s | evidence |\n' "$rule_id"
    done
    printf '%s\n' '' '## Acceptance Test Cases' '' \
      '| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |' \
      '|---|---|---|---|---|---|---|---|' \
      '| TC-01 | AC-001 | JVM unit | `FixtureTest.kt#runs` | N/A — no API | Given fixture | Validates | `./gradlew testDebugUnitTest` |'
  } > "$W/test-plan.md"
}
gate() { HARNESS_PROJECT_ROOT="$ROOT" bash "$STAGE_CHECKER" harness-planning analyze "$W"; }
expect_fail() {
  local out
  if out=$(gate 2>&1); then fail "analyze gate accepted: $1"; fi
  printf '%s\n' "$out" | grep -Fq -- "$1" || { echo "$out" >&2; fail "missing diagnostic: $1"; }
}

write_plan; write_test_plan "implementation-plan.md#rule-applicability"
gate >/dev/null || fail "complete matrix and mapping did not pass the analyze gate"
write_plan SEC
expect_fail "missing the SEC rule-applicability row"
write_plan; write_test_plan "other-plan.md#rule-applicability"
expect_fail "missing the canonical Rule Applicability reference"
write_test_plan "implementation-plan.md#rule-applicability" API
expect_fail "missing the required API evidence mapping"

echo "PASS: Rule Applicability lives in implementation-plan.md, test-plan.md maps it, and the gates reject gaps."
