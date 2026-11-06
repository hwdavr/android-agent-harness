#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
PROJECT_ROOT="$(cd "$HARNESS_ROOT/.." && pwd -P)"
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"
NESTED_AGENTS_FILE="$HARNESS_ROOT/AGENTS.md"
SKILL_FILE="$HARNESS_ROOT/.agents/skills/harness-retrospective/SKILL.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_text() {
  local file="$1"
  local expected="$2"
  grep -Fq "$expected" "$file" || fail "$file must contain: $expected"
}

require_text "$AGENTS_FILE" \
  '**Instruction-file changes require approval** — before editing `.agents/rules/`, `.agents/workflows/`, or `.agents/skills/`, present the exact file list and proposed changes and get explicit user approval.'
require_text "$AGENTS_FILE" \
  'Approval applies only to listed files; ask again if scope changes.'
require_text "$NESTED_AGENTS_FILE" \
  '**Instruction-file changes require approval** — before editing `.agents/rules/`, `.agents/workflows/`, or `.agents/skills/`, present the exact file list and proposed changes and get explicit user approval.'
require_text "$NESTED_AGENTS_FILE" \
  'Approval applies only to listed files; ask again if scope changes.'
require_text "$SKILL_FILE" \
  'Finish the read-only diagnosis and identify the exact instruction files that need changes.'
require_text "$SKILL_FILE" \
  'Present the file list, reason for each change, and a concise diff or change outline to the user; request explicit approval.'
require_text "$SKILL_FILE" \
  'Stop before editing. Resume only after approval covers the proposed files.'
require_text "$SKILL_FILE" \
  'A request to review, investigate, or retro an instruction mismatch does not itself authorize editing those files.'

approval_line="$(grep -nF 'Before editing `.agents/rules/`, `.agents/workflows/`, or `.agents/skills/`:' "$SKILL_FILE" | cut -d: -f1)"
patch_steps_line="$(grep -nF 'Read relevant existing skills and workflows;' "$SKILL_FILE" | cut -d: -f1)"
[ -n "$approval_line" ] && [ -n "$patch_steps_line" ] && [ "$approval_line" -lt "$patch_steps_line" ] ||
  fail "instruction-file approval gate must appear before the authoritative patch instructions"

echo "PASS: instruction changes require explicit, file-scoped user approval before editing."
