#!/usr/bin/env bash
# Contract test for the feature-delivery Testing stage artifact gate.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAGE_CHECKER="$REPO_ROOT/harness/scripts/check-stage-artifacts.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/feature-delivery-testing-stage-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local fixture="$1"
  local expected="$2"
  local output
  local exit_code
  set +e
  output=$(HARNESS_PROJECT_ROOT="$fixture" bash "$STAGE_CHECKER" \
    feature-delivery testing "$fixture" 2>&1)
  exit_code=$?
  set -e
  [ "$exit_code" -ne 0 ] || fail_test "invalid fixture unexpectedly passed: $fixture"
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    fail_test "output did not contain expected text '$expected'"
  }
}

create_fixture() {
  local fixture="$1"
  local sui_decision="$2"
  local nav_decision="$3"
  mkdir -p "$fixture"
  printf '%s\n' '# Stage Summary' > "$fixture/summary_v1.md"
  cat > "$fixture/spec_v1.md" <<EOF
# Feature Spec

## Rule Applicability

| Rule ID | Rule | Default | Decision for this change | Trigger / rationale | Planned evidence |
|---|---|---|---|---|---|
| ARCH | Architecture | Always | Not applicable — fixture isolates the stage gate. | Isolated fixture. | None. |
| IMPL | Implementation | Always | Not applicable — fixture isolates the stage gate. | Isolated fixture. | None. |
| TEST | Testing | Always | Required | Stage-gate regression fixture. | This test plan. |
| SUI | UI | Conditional | $sui_decision | Isolated fixture. | UI contract when required. |
| L10N | Localization | Conditional | Not applicable — fixture isolates the stage gate. | Isolated fixture. | None. |
| NAV | Navigation | Conditional | $nav_decision | Isolated fixture. | Production journey when required. |
| API | API | Conditional | Not applicable — fixture isolates the stage gate. | Isolated fixture. | None. |
| OBS | Observability | Conditional | Not applicable — fixture isolates the stage gate. | Isolated fixture. | None. |
| ANL | Analytics | Conditional | Not applicable — fixture isolates the stage gate. | Isolated fixture. | None. |
| SEC | Security | Conditional | Not applicable — fixture isolates the stage gate. | Isolated fixture. | None. |
EOF

  cat > "$fixture/test_plan_v1.md" <<'EOF'
# Test Plan

Canonical decisions: `spec_v1.md#rule-applicability`.

## Rule Applicability Test Mapping

| Rule | Test / evidence |
|---|---|
| TEST | Focused test-stage contract fixture. |
EOF

  if [ "$sui_decision" = "Required" ]; then
    printf '%s\n' '| SUI | UI contract and rendered state tests. |' >> "$fixture/test_plan_v1.md"
  fi
  if [ "$nav_decision" = "Required" ]; then
    printf '%s\n' '| NAV | Production-entry journey boundary. |' >> "$fixture/test_plan_v1.md"
  fi
}

VALID="$FIXTURE_ROOT/valid"
create_fixture "$VALID" "Not applicable — logic-only fixture." "Not applicable — no navigation."
HARNESS_PROJECT_ROOT="$VALID" bash "$STAGE_CHECKER" feature-delivery testing "$VALID" >/dev/null ||
  fail_test "valid logic-only feature-delivery Testing artifacts did not pass"

MISSING_PLAN="$FIXTURE_ROOT/missing-test-plan"
create_fixture "$MISSING_PLAN" "Not applicable — logic-only fixture." "Not applicable — no navigation."
rm "$MISSING_PLAN/test_plan_v1.md"
expect_failure "$MISSING_PLAN" "no file matching 'test_plan_v*.md'"

MISSING_UI_CONTRACT="$FIXTURE_ROOT/missing-ui-contract"
create_fixture "$MISSING_UI_CONTRACT" "Required" "Not applicable — no navigation."
expect_failure "$MISSING_UI_CONTRACT" "no file matching 'UI_contract.md'"

MISSING_NAV_BOUNDARY="$FIXTURE_ROOT/missing-nav-boundary"
create_fixture "$MISSING_NAV_BOUNDARY" "Not applicable — logic-only fixture." "Required"
expect_failure "$MISSING_NAV_BOUNDARY" "requires a '## Production Journey Boundary' section"

echo "PASS: feature-delivery Testing requires its test plan, matching rule mappings, UI contract when UI applies, and production journey details when navigation applies."
