#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MAX_DESCRIPTION_CHARS=120
MAX_TOTAL_CHARS=3600
EXPECTED_DESCRIPTION_COUNT=42

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

description_of() {
  sed -n 's/^description:[[:space:]]*//p' "$PROJECT_ROOT/$1"
}

assert_contains() {
  local file="$1"
  local expected="$2"
  local description
  description="$(description_of "$file")"
  printf '%s' "$description" | rg -qi -- "$expected" \
    || fail "$file description must contain routing term: $expected"
}

DESCRIPTION_FILES="$(rg -l '^description:' "$PROJECT_ROOT/.agents" | sort)"
DESCRIPTION_COUNT="$(printf '%s\n' "$DESCRIPTION_FILES" | sed '/^$/d' | wc -l | tr -d ' ')"
[ "$DESCRIPTION_COUNT" -eq "$EXPECTED_DESCRIPTION_COUNT" ] \
  || fail "expected $EXPECTED_DESCRIPTION_COUNT descriptions, found $DESCRIPTION_COUNT"

TOTAL_CHARS=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  relative="${file#"$PROJECT_ROOT/"}"
  description="$(description_of "$relative")"
  [ -n "$description" ] || fail "$relative has an empty description"
  line_count="$(rg -N '^description:' "$file" | wc -l | tr -d ' ')"
  [ "$line_count" -eq 1 ] || fail "$relative must have exactly one single-line description"
  description_chars="$(printf '%s' "$description" | wc -c | tr -d ' ')"
  [ "$description_chars" -le "$MAX_DESCRIPTION_CHARS" ] \
    || fail "$relative description is $description_chars characters (limit $MAX_DESCRIPTION_CHARS)"
  TOTAL_CHARS=$((TOTAL_CHARS + description_chars))
done <<EOF
$DESCRIPTION_FILES
EOF

[ "$TOTAL_CHARS" -le "$MAX_TOTAL_CHARS" ] \
  || fail "description total is $TOTAL_CHARS characters (limit $MAX_TOTAL_CHARS)"

assert_contains .agents/workflows/feature-delivery.md 'feature.*end-to-end'
assert_contains .agents/workflows/bug-fixing.md 'bug'
assert_contains .agents/workflows/create-ui-and-verify.md 'UI'
assert_contains .agents/workflows/feature-review.md 'ad-hoc.*review'
assert_contains .agents/workflows/harness-planning.md 'complex.*slice'
assert_contains .agents/workflows/harness-generator.md 'complex.*slice'
assert_contains .agents/workflows/harness-evaluation.md 'complex.*code.*test.*review'
assert_contains .agents/workflows/harness-fix.md 'evaluator.*finding'
assert_contains .agents/skills/context-management/SKILL.md 'session.*context'
assert_contains .agents/skills/ui-verification/SKILL.md 'UI.*visual'
assert_contains .agents/skills/security-and-hardening/SKILL.md 'Android.*security'
assert_contains .agents/skills/api-contract-update/SKILL.md 'API.*contract'
assert_contains .agents/skills/android-test-review/SKILL.md 'test.*review'
assert_contains .agents/skills/bug-reproduction/SKILL.md 'bug.*failing test'

echo "PASS: $DESCRIPTION_COUNT descriptions are compact and retain routing distinctions ($TOTAL_CHARS characters)."
