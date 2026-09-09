#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

sum_bytes() {
  local total=0
  local file size
  for file in "$@"; do
    [ -f "$PROJECT_ROOT/$file" ] || fail "missing budgeted instruction file: $file"
    size=$(wc -c < "$PROJECT_ROOT/$file" | tr -d ' ')
    total=$((total + size))
  done
  printf '%s\n' "$total"
}

L1_BYTES=$(sum_bytes \
  AGENTS.md \
  .agents/rules/android-architecture.md \
  .agents/rules/testing-strategy.md)
[ "$L1_BYTES" -le 23000 ] || fail "L1 instruction budget exceeded: $L1_BYTES bytes (limit 23000)"

if rg -q '\*\*L1 — Always\*\*.*implementation-rules\.md' "$PROJECT_ROOT/AGENTS.md"; then
  fail "implementation rules must not be always-loaded L1 context"
fi
CONTEXT_SKILL="$PROJECT_ROOT/.agents/skills/context-management/SKILL.md"
rg -Fq 'Implementation-only:' "$CONTEXT_SKILL" \
  || fail "context management must defer implementation rules until Implementation"
if rg -Fq 'android-security.md' "$CONTEXT_SKILL"; then
  fail "context management must not preload Android security guidance"
fi

UI_REVIEW_BYTES=$(sum_bytes \
  AGENTS.md \
  .agents/rules/android-architecture.md \
  .agents/rules/testing-strategy.md \
  harness/templates/rule-applicability-template.md \
  .agents/rules/compose-rules.md \
  .agents/rules/localization-rules.md \
  .agents/rules/testing-runtime-evidence.md \
  .agents/workflows/harness-evaluation.md \
  .agents/skills/android-test-review/SKILL.md \
  .agents/skills/android-code-review/SKILL.md \
  .agents/skills/ui-verification/SKILL.md \
  docs/product/design_system.md \
  harness/templates/ui-verification-template.json \
  harness/templates/test-review-template.md \
  harness/templates/code-review-template.md \
  harness/templates/evaluator-rubric-template.md)
[ "$UI_REVIEW_BYTES" -le 128000 ] \
  || fail "complex UI review instruction budget exceeded: $UI_REVIEW_BYTES bytes (limit 128000)"

UI_SKILL="$PROJECT_ROOT/.agents/skills/ui-verification/SKILL.md"
rg -Fq 'harness/templates/ui-verification-template.json' "$UI_SKILL" \
  || fail "UI verification skill must reference the canonical JSON template"
if rg -Fq '"runtime_evidence_schema"' "$UI_SKILL"; then
  fail "UI verification skill embeds the canonical report schema"
fi

DESCRIPTION_HASH=$(
  for file in $(find "$PROJECT_ROOT/.agents/workflows" "$PROJECT_ROOT/.agents/skills" \
      -type f -name '*.md' | sort); do
    relative=${file#"$PROJECT_ROOT/"}
    awk -v file="$relative" '/^description:/{print file "\t" $0}' "$file"
  done | shasum -a 256 | awk '{print $1}'
)
[ "$DESCRIPTION_HASH" = "ed4496ebf0349dcc4c4457e8f426a07398db69932c48bba26a9f5a48a2fa1afa" ] \
  || fail "workflow or skill descriptions changed outside the approved phase"

echo "PASS: instruction profiles stay within budget and descriptions/schema ownership are preserved."
