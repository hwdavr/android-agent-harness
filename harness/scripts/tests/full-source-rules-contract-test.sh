#!/usr/bin/env bash
# Contract test for the repository-wide source-rule bundle.
# It proves the bundle forces --all scans and still runs every checker after a
# violation, instead of reproducing the old changed-file false pass.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUNDLE="$REPO_ROOT/harness/scripts/check-full-source-rules.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/full-source-rules-test.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -x "$BUNDLE" ] || fail "bundle is missing or not executable"
[ -f "${BUNDLE%.sh}.ps1" ] || fail "native PowerShell bundle is missing"
[ -f "${BUNDLE%.sh}.cmd" ] || fail "native Command Prompt bundle is missing"
grep -Fq 'check-full-source-rules.ps1' "${BUNDLE%.sh}.cmd" \
  || fail "Command Prompt launcher does not invoke the PowerShell bundle"
grep -Fq '$ErrorActionPreference = "Continue"' "${BUNDLE%.sh}.ps1" \
  || fail "PowerShell bundle would stop before aggregating checker failures"

for required_file in \
  "$REPO_ROOT/AGENTS.md" \
  "$REPO_ROOT/.agents/workflows/harness-generator.md" \
  "$REPO_ROOT/.agents/workflows/harness-evaluation.md" \
  "$REPO_ROOT/.agents/workflows/harness-fix.md" \
  "$REPO_ROOT/.agents/skills/code-quality-fix/SKILL.md" \
  "$REPO_ROOT/.agents/skills/android-code-quality-checks/SKILL.md" \
  "$REPO_ROOT/.agents/skills/android-code-review/SKILL.md" \
  "$REPO_ROOT/.agents/gates/ci-checks.md" \
  "$REPO_ROOT/.agents/gates/review-checklist.md" \
  "$REPO_ROOT/.agents/prompts/harness-generator.md" \
  "$REPO_ROOT/.agents/prompts/harness-evaluation.md" \
  "$REPO_ROOT/.agents/prompts/harness-fix.md" \
  "$REPO_ROOT/harness/templates/code-review-template.md" \
  "$REPO_ROOT/harness/templates/summary-template.md" \
  "$REPO_ROOT/harness/templates/clean-state-checklist-template.md" \
  "$REPO_ROOT/harness/templates/evaluator-rubric-template.md" \
  "$REPO_ROOT/.harness/README.md" \
  "$REPO_ROOT/.github/workflows/android.yml"; do
  [ -f "$required_file" ] || fail "missing source-rule integration file: $required_file"
  grep -Fq 'check-full-source-rules.sh' "$required_file" \
    || fail "source-rule bundle is not wired into: $required_file"
done

for checker in \
  check-architecture-rules.sh \
  check-compose-rules.sh \
  check-localization-rules.sh; do
  grep -Fq "$checker" "$BUNDLE" || fail "bundle does not invoke $checker"
done
grep -Fq -- '--all' "$BUNDLE" || fail "bundle does not force full-source scans"
grep -Fq 'failed=0' "$BUNDLE" || fail "bundle does not aggregate checker failures"

mkdir -p \
  "$fixture_root/app/src/main/java/com/example/notesapp/ui" \
  "$fixture_root/app/src/test" \
  "$fixture_root/app/src/androidTest"

cat > "$fixture_root/app/src/main/java/com/example/notesapp/ui/ExistingViolation.kt" <<'KOTLIN'
package com.example.notesapp.ui

@Composable
fun ExistingViolation() {
    Button(onClick = {}) { Text("Visible text") }
}
KOTLIN

# Commit the violating source so a changed-file scan would see zero files. The
# bundle must still find it because it explicitly requests a full baseline scan.
git -C "$fixture_root" init -q
git -C "$fixture_root" config user.email harness-contract@example.invalid
git -C "$fixture_root" config user.name harness-contract
git -C "$fixture_root" add app
git -C "$fixture_root" commit -qm baseline

if output=$(bash "$BUNDLE" --project-root "$fixture_root" 2>&1); then
  echo "$output" >&2
  fail "bundle accepted a full-source violation"
fi

for expected in \
  "Architecture rules (full source)" \
  "Compose rules (full source)" \
  "Localization rules (full source)" \
  "Navigation rules (full source)" \
  "Test assertion rules (full test source)"; do
  printf '%s\n' "$output" | grep -Fq ">> $expected" \
    || { echo "$output" >&2; fail "bundle did not run $expected"; }
done

printf '%s\n' "$output" | grep -Fq 'Files scanned: 1' \
  || { echo "$output" >&2; fail "bundle did not force a full source scan"; }
printf '%s\n' "$output" | grep -Fq 'full-source rules bundle (one or more checkers failed)' \
  || { echo "$output" >&2; fail "bundle did not report an aggregate failure"; }

echo "PASS: full-source rules bundle scans untouched source and aggregates all checker failures."
