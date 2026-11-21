#!/usr/bin/env bash
# Contract test for check-quick-change.sh: valid quick changes of every kind pass; each out-of-lane case fails.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/check-quick-change.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# write_intent <dir> <status> <kind> <scenario> <entry-box> [tests-body]
write_intent() {
  mkdir -p "$1"
  local tests="${6:-- \`EditorViewModelTest.rule\` — preserved behavior
  - GREEN: testDebugUnitTest → 12 passed}"
  cat > "$1/intent.md" <<MD
# qc-1 — tweak

**Lane**: quick-change
**Kind**: $3
**Status**: $2
**Input**: "tweak"

## Intent

Change the rule.

## Entry Check

- $5 Logic only
- [x] No new screen
- [x] Scenario rule
- [x] Bug reproduction
- [x] At most 5 files

## Scenario Affected

$4

## Files

- \`app/src/main/java/a/ui/EditorViewModel.kt\` — rule

## Tests

$tests

## Result

testDebugUnitTest exit 0, 12 tests
MD
}
RED_GREEN='- `EditorViewModelTest.rule` — AC-004
  - RED: testDebugUnitTest → 1 failed
  - GREEN: testDebugUnitTest → 12 passed'
OK="Approved — user, 2026-11-15"

new_repo() { # <name> -> repo path with one base commit on main, working branch checked out
  local r="$TMP/$1"
  mkdir -p "$r/app/src/main/java/a/ui" "$r/app/src/main/java/a/data" "$r/app/src/test/java/a" "$r/docs/product/requirements"
  git -C "$r" init -q -b main
  git -C "$r" config user.email t@t; git -C "$r" config user.name t
  echo "class EditorViewModel" > "$r/app/src/main/java/a/ui/EditorViewModel.kt"
  printf '# Drawing\n\n## Requirements\n\n### Requirement: FR-002 Brush\nThe app SHALL x.\n\n#### Scenario: AC-004 size\n- **WHEN** a\n- **THEN** b\n' \
    > "$r/docs/product/requirements/drawing.md"
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
delta() { # <file> <extra-scenarios...>
  { printf '# Drawing — delta\n\n## MODIFIED Requirements\n\n### Requirement: FR-002 Brush\nThe app SHALL x.\n\n#### Scenario: AC-004 size\n- **WHEN** a\n- **THEN** b\n'
    for ac in "${@:2}"; do printf '\n#### Scenario: %s extra\n- **WHEN** c\n- **THEN** d\n' "$ac"; done; } > "$1"
}

# 1. valid refactor passes scope, then completes with Archived + PASS review
R="$(new_repo ok)"; C="$R/.scratch/2026-11-15-qc-1"
echo "class EditorViewModel { val x = 1 }" > "$R/app/src/main/java/a/ui/EditorViewModel.kt"
echo "class EditorViewModelTest" > "$R/app/src/test/java/a/EditorViewModelTest.kt"
write_intent "$C" "$OK" refactor "None — refactor" "[x]"
expect_pass "$C" --base main
expect_fail "Archived" "$C" --base main --complete
sed -i.bak 's/^\*\*Status\*\*:.*/**Status**: Archived — 2026-11-15/' "$C/intent.md"
expect_fail "review.md" "$C" --base main --complete
printf '**Verdict**: PASS\n**Reviewer**: evaluator (fresh)\n' > "$C/review.md"
expect_pass "$C" --base main --complete

# 2. record shape: draft, unchecked entry, missing lane marker, unknown kind
R="$(new_repo record)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "Draft" refactor "None — refactor" "[x]"
expect_fail "Approved or Archived" "$C" --base main
write_intent "$C" "$OK" refactor "None — refactor" "[ ]"
expect_fail "unchecked" "$C" --base main
write_intent "$C" "$OK" hotfix "None — refactor" "[x]"
expect_fail "Kind" "$C" --base main
write_intent "$C" "$OK" refactor "None — refactor" "[x]"
sed -i.bak '/^\*\*Lane\*\*/d' "$C/intent.md"
expect_fail "Lane" "$C" --base main

# 3. scope: resources, Composables, file cap
R="$(new_repo scope)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "$OK" refactor "None — refactor" "[x]"
mkdir -p "$R/app/src/main/res/values"; echo "<resources/>" > "$R/app/src/main/res/values/strings.xml"
expect_fail "outside quick-change scope" "$C" --base main
rm -r "$R/app/src/main/res"
printf '@Composable\nfun Screen() {}\n' > "$R/app/src/main/java/a/ui/Screen.kt"
expect_fail "@Composable" "$C" --base main
rm "$R/app/src/main/java/a/ui/Screen.kt"
for i in 1 2 3 4 5 6; do echo "class U$i" > "$R/app/src/main/java/a/ui/U$i.kt"; done
expect_fail "limit 5" "$C" --base main

# 4. data-layer logic passes; DAO, entity, migration, Retrofit, and DTO changes fail
R="$(new_repo data)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "$OK" refactor "None — refactor" "[x]"
echo "class PhotoRepository { fun sorted() = 1 }" > "$R/app/src/main/java/a/data/PhotoRepository.kt"
expect_pass "$C" --base main
for code in '@Dao interface PhotoDao' '@Entity data class Photo(val id: Int)' 'val M = Migration(1, 2) {}' 'import retrofit2.http.GET'; do
  printf '%s\n' "$code" > "$R/app/src/main/java/a/data/Contract.kt"
  expect_fail "outside quick-change scope" "$C" --base main
done
rm "$R/app/src/main/java/a/data/Contract.kt"
echo "data class PhotoDto(val id: Int)" > "$R/app/src/main/java/a/data/PhotoDto.kt"
expect_fail "DTO/API contract" "$C" --base main

# 5. behavior: one MODIFIED delta, at most one new scenario, RED/GREEN recorded
R="$(new_repo behavior)"; C="$R/.scratch/2026-11-15-qc-1"
write_intent "$C" "$OK" behavior "drawing.md#AC-004" "[x]" "$RED_GREEN"
expect_fail "exactly one specs" "$C" --base main
mkdir -p "$C/specs"
printf '# Drawing — delta\n\n## ADDED Requirements\n\n### Requirement: FR-020 New\n' > "$C/specs/drawing.md"
expect_fail "may only MODIFY" "$C" --base main
delta "$C/specs/drawing.md" AC-010
expect_pass "$C" --base main
delta "$C/specs/drawing.md" AC-010 AC-011
expect_fail "limit 1" "$C" --base main
delta "$C/specs/drawing.md"
write_intent "$C" "$OK" behavior "drawing.md#AC-004" "[x]"
expect_fail "RED:" "$C" --base main
write_intent "$C" "$OK" refactor "None — refactor" "[x]"
expect_fail "must not have specs" "$C" --base main

# 6. bug-fix: cites the violated scenario, RED/GREEN recorded, no specs
R="$(new_repo bugfix)"; C="$R/.scratch/2026-11-15-qc-1"
echo "class EditorViewModel { val fixed = true }" > "$R/app/src/main/java/a/ui/EditorViewModel.kt"
write_intent "$C" "$OK" bug-fix "drawing.md#AC-004" "[x]" "$RED_GREEN"
expect_pass "$C" --base main
write_intent "$C" "$OK" bug-fix "drawing.md#AC-004" "[x]"
expect_fail "RED:" "$C" --base main
write_intent "$C" "$OK" bug-fix "None — refactor" "[x]" "$RED_GREEN"
expect_fail "AC-###" "$C" --base main
write_intent "$C" "$OK" bug-fix "drawing.md#AC-004" "[x]" "$RED_GREEN"
mkdir -p "$C/specs"; delta "$C/specs/drawing.md"
expect_fail "must not have specs" "$C" --base main

# 7. test-only: tests pass; any production change fails
R="$(new_repo testonly)"; C="$R/.scratch/2026-11-15-qc-1"
echo "class EditorViewModelTest" > "$R/app/src/test/java/a/EditorViewModelTest.kt"
write_intent "$C" "$OK" test-only "None — test-only" "[x]"
expect_pass "$C" --base main
echo "class EditorViewModel { val x = 2 }" > "$R/app/src/main/java/a/ui/EditorViewModel.kt"
expect_fail "test-only change must not modify production" "$C" --base main

echo "PASS: quick-change contract (refactor, behavior, bug-fix, test-only, and data-logic changes accepted; record, scope, contract-code, file-cap, delta, scenario-count, RED/GREEN, and test-only violations rejected)."
