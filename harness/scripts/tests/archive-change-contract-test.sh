#!/usr/bin/env bash
# Contract test for archive-change.py: merges specs/ deltas into living capability files atomically.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$SCRIPT_DIR/../archive-change.py"
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/archive-change-test.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT
W="$ROOT/.scratch/2026-11-20-brush-presets"
REQ="$ROOT/docs/product/requirements"
fail_test() { echo "FAIL: $1" >&2; exit 1; }
run() { python3 "$ARCHIVE" "$W" --project-root "$ROOT" --date 2026-11-21 "$@"; }
expect_failure() {
  local expected="$1" output; shift
  if output=$(run "$@" 2>&1); then fail_test "archive accepted a fixture that should report: $expected"; fi
  printf '%s\n' "$output" | grep -Fq -- "$expected" || { echo "$output" >&2; fail_test "missing report: $expected"; }
}
setup() {
  rm -rf "$ROOT/docs" "$ROOT/.scratch"; mkdir -p "$W/specs" "$REQ"
  cat > "$REQ/drawing.md" <<'MD'
# Drawing

**Capability ID**: `drawing`
**Updated**: 2026-11-15

## User goal

Draw strokes.

## Requirements

### Requirement: FR-001 Draw tool entry
The app SHALL open the Draw tool.

#### Scenario: AC-001 Open
- **WHEN** the user taps Draw
- **THEN** Draw mode starts

### Requirement: FR-002 Brush types
The app SHALL offer four brushes.

#### Scenario: AC-002 Pen
- **WHEN** the user draws
- **THEN** a stroke appears

### Requirement: FR-003 Legacy toolbar
The app SHALL show the legacy toolbar.

#### Scenario: AC-003 Legacy
- **WHEN** Draw mode starts
- **THEN** the legacy toolbar shows

## References

- [Product index](../product.md)
MD
  printf '%s\n' '# brush-presets — Brush presets' '' '**Status**: Approved — user, 2026-11-20' > "$W/intent.md"
  cat > "$W/specs/drawing.md" <<'MD'
## ADDED Requirements

### Requirement: FR-004 Brush presets
The app SHALL let the user save up to five brush presets.

#### Scenario: AC-004 Save preset
- **WHEN** the user saves the current brush
- **THEN** it appears in the preset row

## MODIFIED Requirements

### Requirement: FR-002 Brush types
The app SHALL offer five brushes.

#### Scenario: AC-002 Pen
- **WHEN** the user draws
- **THEN** a stroke appears

## REMOVED Requirements

### Requirement: FR-003 Legacy toolbar
**Reason**: Replaced by presets.
MD
  cat > "$W/specs/brush-presets.md" <<'MD'
# Brush Presets

**User goal**: Reuse favourite brush settings.

## ADDED Requirements

### Requirement: FR-001 Preset storage
The app SHALL keep presets across restarts.

#### Scenario: AC-001 Restart
- **WHEN** the app restarts
- **THEN** saved presets are still listed
MD
}

# Dry run writes nothing.
setup; before=$(cat "$REQ/drawing.md")
run --dry-run >/dev/null || fail_test "dry run failed"
[ "$(cat "$REQ/drawing.md")" = "$before" ] && [ ! -f "$REQ/brush-presets.md" ] || fail_test "dry run wrote files"

# Merge: ADDED appended, MODIFIED replaced in place, REMOVED deleted, new capability created, intent archived.
run >/dev/null || fail_test "archive rejected a valid change"
grep -Fq "The app SHALL offer five brushes." "$REQ/drawing.md" || fail_test "MODIFIED not applied"
grep -Fq "four brushes" "$REQ/drawing.md" && fail_test "MODIFIED left the old text"
grep -Fq "FR-003" "$REQ/drawing.md" && fail_test "REMOVED not applied"
grep -Fq "### Requirement: FR-004 Brush presets" "$REQ/drawing.md" || fail_test "ADDED not applied"
grep -Eq "^## (ADDED|MODIFIED|REMOVED) Requirements" "$REQ/drawing.md" && fail_test "delta heading left behind"
grep -Fq '**Updated**: 2026-11-21' "$REQ/drawing.md" || fail_test "Updated date not set"
grep -Fq ".scratch/2026-11-20-brush-presets/" "$REQ/drawing.md" || fail_test "workspace not linked in References"
grep -Fq '**Capability ID**: `brush-presets`' "$REQ/brush-presets.md" || fail_test "new capability not created"
grep -Fq '**Status**: Archived — 2026-11-21' "$W/intent.md" || fail_test "intent not archived"
[ "$(grep -n '^### Requirement:' "$REQ/drawing.md" | sed 's/.*: //' | cut -d' ' -f1 | tr '\n' ' ')" = "FR-001 FR-002 FR-004 " ] ||
  fail_test "requirement order changed"
expect_failure "is already archived"

# One failing delta writes nothing, including the other capability.
setup; sed -i.bak 's/FR-002 Brush types/FR-009 Ghost/' "$W/specs/drawing.md"; before=$(cat "$REQ/drawing.md")
expect_failure "MODIFIED FR-009 is not in drawing.md"
[ "$(cat "$REQ/drawing.md")" = "$before" ] && [ ! -f "$REQ/brush-presets.md" ] || fail_test "failed archive wrote files"

setup; sed -i.bak 's/FR-004 Brush presets/FR-001 Brush presets/' "$W/specs/drawing.md"
expect_failure "ADDED FR-001 already exists in drawing.md"

setup; sed -i.bak 's/Approved — user, 2026-11-20/Clarified/' "$W/intent.md"
expect_failure "must be Approved before archiving"

setup; sed -i.bak '/Reason/d' "$W/specs/drawing.md"
expect_failure "REMOVED FR-003 needs a '**Reason**:' line"

setup; sed -i.bak '/User goal/d' "$W/specs/brush-presets.md"
expect_failure "a new capability needs"

# Legacy table capability: ADDED works, MODIFIED/REMOVED require conversion.
setup
printf '%s\n' '# Drawing' '' '**Capability ID**: `drawing`' '**Updated**: x' '' '## User goal' '' 'g' '' '## Requirements' '' \
  '| Feature | Status |' '|---|---|' '| Pen | Done |' '' '## References' '' '- [p](../product.md)' > "$REQ/drawing.md"
expect_failure "convert it first"
printf '%s\n' '## ADDED Requirements' '' '### Requirement: FR-001 Presets' 'The app SHALL save presets.' '' \
  '#### Scenario: AC-001 Save' '- **WHEN** saved' '- **THEN** listed' > "$W/specs/drawing.md"
run >/dev/null || fail_test "ADDED into a legacy table capability failed"
grep -Fq "| Pen | Done |" "$REQ/drawing.md" || fail_test "legacy table was dropped"

echo "PASS: archive-change merges ADDED/MODIFIED/REMOVED atomically and archives the intent."
