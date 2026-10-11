#!/usr/bin/env bash
# Contract test for Pen-export-backed Roborazzi visual verification.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

SKILL="$REPO_ROOT/.agents/skills/ui-verification/SKILL.md"
RULE="$REPO_ROOT/.agents/rules/testing-runtime-evidence.md"
CONTRACT="$REPO_ROOT/harness/scripts/check-visual-evidence-contract.sh"
TEMPLATE="$REPO_ROOT/harness/templates/visual-target-template.json"
DESIGN_TEMPLATE="$REPO_ROOT/harness/templates/feature-design-template.md"
PLANNING_WORKFLOW="$REPO_ROOT/.agents/workflows/harness-planning.md"
UX_SKILL="$REPO_ROOT/.agents/skills/ux-design/SKILL.md"
STAGE_GATE="$REPO_ROOT/harness/scripts/check-stage-artifacts.sh"
REVIEW_SKILL="$REPO_ROOT/.agents/skills/android-code-review/SKILL.md"

[ ! -e "$REPO_ROOT/harness/scripts/compare-visual-evidence.sh" ] \
  || fail_test "the removed Python/Pillow comparator must not be present"
[ ! -e "$REPO_ROOT/harness/scripts/check-existing-screen-baseline-contract.sh" ] \
  || fail_test "planning must not require an implementation screenshot baseline"
[ ! -e "$REPO_ROOT/harness/scripts/tests/existing-screen-baseline-contract-test.sh" ] \
  || fail_test "the removed screenshot-baseline contract test must not be present"
grep -Fq './gradlew app:verifyRoborazziDebug' "$SKILL" \
  || fail_test "ui-verification skill must use verifyRoborazziDebug"
grep -Fq 'pen_source' "$RULE" \
  || fail_test "runtime evidence rules must declare the canonical Pen source"
grep -Fq 'approved-pen-export' "$TEMPLATE" \
  || fail_test "visual target template must declare the approved Pen export policy"
grep -Fq '"content_alignment": "different"' "$TEMPLATE" \
  || fail_test "visual target template must not assume identical design and runtime content"
grep -Fq '"pixel_parity": "not-claimed"' "$TEMPLATE" \
  || fail_test "different-content template must not claim full-screen pixel parity"
grep -Fq '../UI_design/fun_photo_editor.pen' "$TEMPLATE" \
  || fail_test "visual target template must point to the canonical sibling Pen design"
grep -Fq 'verifyRoborazziDebug' "$CONTRACT" \
  || fail_test "visual evidence contract must validate Roborazzi verification"
if grep -Fq 'compare-visual-evidence.sh' "$CONTRACT"; then
  fail_test "visual evidence contract must not invoke the removed comparator"
fi
if grep -Eqi 'similarity[[:space:]]*>=[[:space:]]*0\.95|golden baseline' "$SKILL" "$RULE" "$CONTRACT"; then
  fail_test "visual verification rules must not use the removed similarity/golden-baseline gate"
fi
if grep -Fq 'Existing Surface Baseline' "$DESIGN_TEMPLATE" "$PLANNING_WORKFLOW" "$UX_SKILL" "$STAGE_GATE"; then
  fail_test "planning sources must not require an existing-surface screenshot baseline"
fi
if grep -Fq 'applicable golden comparison' "$REVIEW_SKILL"; then
  fail_test "code review guidance must name Pen-export Roborazzi verification"
fi

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/pen-design-reference-contract.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT
printf '%s\n' \
  '# Spec' \
  '' \
  '## Screen States' \
  '' \
  '## Rule Applicability' \
  '' \
  '| Rule ID | Rule document | Decision | Evidence |' \
  '|---|---|---|---|' \
  '| ARCH | rule.md | Required | fixture |' \
  '| IMPL | rule.md | Required | fixture |' \
  '| TEST | rule.md | Required | fixture |' \
  '| SUI | rule.md | Required | fixture |' \
  '| L10N | rule.md | Not applicable — no copy | fixture |' \
  '| NAV | rule.md | Not applicable — no route | fixture |' \
  '| API | rule.md | Not applicable — no API | fixture |' \
  '| OBS | rule.md | Not applicable — no boundary | fixture |' \
  '| ANL | rule.md | Not applicable — analytics: none | fixture |' \
  '| SEC | rule.md | Not applicable — no security boundary | fixture |' \
  > "$fixture_root/spec.md"
printf '%s\n' \
  '# Design' \
  'Project design system: `docs/product/design_system.md`' \
  '' \
  '## Screens Covered' \
  '' \
  '| # | Screen / Surface | Status |' \
  '|---|---|---|' \
  '| 1 | Existing Editor | Updated |' \
  > "$fixture_root/design.md"
bash "$STAGE_GATE" harness-planning feature-specification "$fixture_root" >/dev/null

echo "PASS: Pen-export verification distinguishes matched-content pixels from different-content structural evidence."
