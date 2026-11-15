#!/usr/bin/env bash
# Contract test for check-quick-change.sh: a valid quick change passes; each out-of-lane case fails.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/check-quick-change.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

write_intent() { # <dir> <status> <scenario> <entry-box>
  mkdir -p "$1"
  cat > "$1/intent.md" <<MD
# qc-1 — tweak

**Lane**: quick-change
**Status**: $2
**Input**: "tweak"

## Intent

Change the rule.

## Entry Check

- $4 Logic only
- [x] No new screen
- [x] One scenario
- [x] Not a defect
- [x] At most 5 files

## Scenario Affected

$3

## Files

- \`app/src/main/java/a/ui/EditorViewModel.kt\` — rule

## Tests

- \`EditorViewModelTest.rule\` — RED then GREEN

## Result

testDebugUnitTest exit 0, 12 tests
MD
}

new_repo() { # <name> -> prints repo path with one base commit on main
  local r="$TMP/$1"
  mkdir -p "$r/app/src/main/java/a/ui" "$r/app/src/main/java/a/data" "$r/app/src/test/java/a"
  git -C "$r" init -q -b main
  git -C "$r" config user.email t@t; git -C "$r" config user.name t
  echo "class EditorViewModel" > "$r/app/src/main/java/a/ui/EditorViewModel.kt"
  git -C "$r" add -A; git -C "$r" commit -qm base
  git -C "$r" checkout -qb work
  echo "$r"
}

expect_pass() { "$SCRIPT" "$@" >/dev/null 2>&1 || { "$SCRIPT" "$@" || true; fail "expected PASS: $*"; }; }
expect_fail() { # <pattern> <args...>
  local pat="$1"; shift
  local out
  if out="$("$SCRIPT" "$@" 2>&1)"; then fail "expected FAIL ($pat): $*"; fi
  printf '%s' "$out" | grep -q -- "$pat" || fail "wrong failure for $pat: $out"
}

# 1. valid refactor passes (scope) and completes with an Archived record + PASS review
R="$(new_repo ok)"; C="$R/.scratch/2026-11-15-qc-1"
echo "class EditorViewModel { val x = 1 }" > "$R/app/src/main/java/a/ui/EditorViewModel.kt"
echo "class EditorViewModelTest" > "$R/app/src/test/java/a/EditorViewModelTest.kt"
write_intent "$C" "Approved — user, 2026-11-15" "None — refactor" "[x]"
expect_pass "$C" --base main
expect_fail "Archived" "$C" --base main --complete
sed -i.bak 's/^\*\*Status\*\*:.*/**Status**: Archived — 2026-11-15/' "$C/intent.md"
expect_fail "review.md" "$C" --base main --complete
printf '**Verdict**: PASS\n**Reviewer**: evaluator (fresh)\n' > "$C/review.md"
expect_pass "$C" --base main --complete

# 2. Draft record fails
R="$(new_repo draft)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "Draft" "None — refactor" "[x]"
expect_fail "Approved or Archived" "$C" --base main

# 3. unchecked entry item fails
R="$(new_repo box)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "Approved — user, 2026-11-15" "None — refactor" "[ ]"
expect_fail "unchecked" "$C" --base main

# 4. data-layer, resource, and Composable changes fail
R="$(new_repo scope)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "Approved — user, 2026-11-15" "None — refactor" "[x]"
echo "class Repo" > "$R/app/src/main/java/a/data/Repo.kt"
expect_fail "data-layer" "$C" --base main
rm "$R/app/src/main/java/a/data/Repo.kt"
mkdir -p "$R/app/src/main/res/values"; echo "<resources/>" > "$R/app/src/main/res/values/strings.xml"
expect_fail "outside quick-change scope" "$C" --base main
rm -r "$R/app/src/main/res"
printf '@Composable\nfun Screen() {}\n' > "$R/app/src/main/java/a/ui/Screen.kt"
expect_fail "@Composable" "$C" --base main
rm "$R/app/src/main/java/a/ui/Screen.kt"
expect_pass "$C" --base main

# 5. more than five production Kotlin files fail
R="$(new_repo many)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "Approved — user, 2026-11-15" "None — refactor" "[x]"
for i in 1 2 3 4 5 6; do echo "class U$i" > "$R/app/src/main/java/a/ui/U$i.kt"; done
expect_fail "limit 5" "$C" --base main

# 6. behavior change needs exactly one MODIFIED-only delta; refactor must have none
R="$(new_repo delta)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "Approved — user, 2026-11-15" "drawing.md#AC-004" "[x]"
expect_fail "exactly one specs" "$C" --base main
mkdir -p "$C/specs"
printf '# Drawing — delta\n\n## ADDED Requirements\n\n### Requirement: FR-020 New\n' > "$C/specs/drawing.md"
expect_fail "may only MODIFY" "$C" --base main
printf '# Drawing — delta\n\n## MODIFIED Requirements\n\n### Requirement: FR-002 Brush\nThe app SHALL x.\n' > "$C/specs/drawing.md"
expect_pass "$C" --base main
write_intent "$C" "Approved — user, 2026-11-15" "None — refactor" "[x]"
expect_fail "must not have specs" "$C" --base main

# 7. record without the lane marker fails
R="$(new_repo lane)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "Approved — user, 2026-11-15" "None — refactor" "[x]"
sed -i.bak '/^\*\*Lane\*\*/d' "$C/intent.md"
expect_fail "Lane" "$C" --base main

echo "PASS: quick-change contract (valid refactor/behavior change accepted; draft, unchecked entry, data/res/Composable scope, file cap, delta shape, lane marker rejected)."
