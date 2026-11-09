#!/usr/bin/env bash
# Contract test for the UI conformance-review policy: no screenshot goldens, captures at the Pen frame
# size, structural checks, registered-component reuse, and user approval — consistent across the
# rules, skills, workflows, templates, and gates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fail_test() { echo "FAIL: $1" >&2; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail_test "$1 must contain: $2"; }
lacks() { if grep -Eq -- "$2" "$1"; then fail_test "$1 must not contain: $2"; fi; }

RULE="$REPO_ROOT/.agents/rules/testing-runtime-evidence.md"
UIV="$REPO_ROOT/.agents/skills/ui-verification/SKILL.md"
UX="$REPO_ROOT/.agents/skills/ux-design/SKILL.md"
UIL="$REPO_ROOT/.agents/skills/android-ui-layer/SKILL.md"
FD="$REPO_ROOT/.agents/workflows/feature-delivery.md"
CONTRACT_T="$REPO_ROOT/harness/templates/UI_contract-template.md"
REPORT_T="$REPO_ROOT/harness/templates/ui-verification-template.json"
TEST_PLAN_T="$REPO_ROOT/harness/templates/test-plan-template.md"
TASKS_T="$REPO_ROOT/harness/templates/tasks-template.md"

# Removed pixel-golden machinery stays removed.
for retired in harness/scripts/compare-visual-evidence.sh harness/scripts/check-existing-screen-baseline-contract.sh \
  harness/templates/visual-reference-anchor-verification-template.md .agents/workflows/create-ui-and-verify.md \
  .agents/workflows/harness-planning.md; do
  [ ! -e "$REPO_ROOT/$retired" ] || fail_test "$retired must not exist"
done

# Policy text.
has "$RULE" "## UI Conformance Evidence"
has "$RULE" "never by a screenshot golden"
has "$RULE" "Never resize a capture or"
has "$UIV" "Review capture"
has "$UIV" "Structural check"
has "$UIV" "Never record, commit, or compare a screenshot golden"
has "$UIV" "check-visual-evidence-contract.sh \"\$FEATURE_DIR\" --evaluate"
has "$UX" "Build every state from Pen component instances that"
has "$UX" "Do not create, version, or edit the requirement block or summary during visual iteration"
has "$UIL" "## Direct lane — entry check"
has "$UIL" "run the \`ui-verification\` skill"
has "$FD" "### Stage 6 — UI Verification"
has "$FD" "No screenshot golden is recorded or compared"
has "$FD" "### Stage 1 — Specify & Clarify"
has "$FD" "### Stage 3 — Implementation Plan & Analyze"

# Templates carry the new contract and none of the pixel contract.
has "$CONTRACT_T" "| Reused components |"
lacks "$CONTRACT_T" "\\| Comparison \\|"
has "$REPORT_T" "No screenshot golden is recorded or compared"
lacks "$REPORT_T" "pixel_parity|runtime_evidence|verifyRoborazziDebug"
has "$TEST_PLAN_T" "## UI State Verification"
lacks "$TEST_PLAN_T" "TC-US-1-VIS|captureRoboImage"
lacks "$TASKS_T" "TC-US-1-VIS|captureRoboImage"

# Skills and workflows never plan a pixel gate as acceptance evidence.
for file in "$REPO_ROOT"/.agents/workflows/*.md "$REPO_ROOT"/.agents/skills/*/SKILL.md; do
  if grep -Eq "captureRoboImage\\(\\)|reference-anchor-verification|visual_evidence/visual-target.json" "$file"; then
    fail_test "$file still requires the retired pixel-golden contract"
  fi
done

echo "PASS: UI appearance is approved by a conformance review, consistently across the harness."
