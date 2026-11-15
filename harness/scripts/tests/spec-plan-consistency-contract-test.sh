#!/usr/bin/env bash
# Contract test for the analyze gate (check-spec-plan-consistency.sh), single and sliced lanes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../check-spec-plan-consistency.sh"
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/spec-plan-consistency-test.XXXXXX")
FEATURE_ID="share-expiry"
FEATURE_DIR="$FIXTURE_ROOT/.scratch/2026-11-09-$FEATURE_ID"
CAPABILITY="$FIXTURE_ROOT/docs/product/requirements/note-sharing.md"
INTENT="$FEATURE_DIR/intent.md"
DESIGN="$FEATURE_DIR/design.md"
DELTA="$FEATURE_DIR/specs/note-sharing.md"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() { echo "FAIL: $1" >&2; exit 1; }
run_validator() { bash "$VALIDATOR" "$FEATURE_DIR" --project-root "$FIXTURE_ROOT"; }

expect_success() {
  local output
  output=$(run_validator 2>&1) || { echo "$output" >&2; fail_test "$1"; }
}

expect_failure() {
  local expected="$1" output
  if output=$(run_validator 2>&1); then
    fail_test "validator accepted a fixture that should report: $expected"
  fi
  printf '%s\n' "$output" | grep -Fq -- "$expected" || { echo "$output" >&2; fail_test "missing report: $expected"; }
}

replace() { python3 - "$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:]
text = open(path, encoding="utf-8").read()
assert old in text, f"fixture text not found: {old}"
open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
}

artifact_hash() {  # $1 = path; intent.md ignores its **Status** line
  python3 - "$SCRIPT_DIR/.." "$1" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import spec_change
print(spec_change.artifact_hash(Path(sys.argv[2])))
PY
}

rule_rows() {
  cat <<'MD'
## Rule Applicability

| Rule ID | Rule document | Decision | Feature-specific trigger or reason | Planned work and evidence |
|---|---|---|---|---|
| ARCH | `android-architecture.md` | Required | layers | review |
| IMPL | `implementation-rules.md` | Required | behavior | tests |
| TEST | `testing-strategy.md` | Required | tests | acceptance tests |
| SUI | `compose-rules.md` | Required | picker | review capture |
| L10N | `localization-rules.md` | Required | copy | strings |
| NAV | `navigation-rules.md` | Not applicable — no route change | | |
| API | `api-contract-rules.md` | Required | expiry field | contract |
| OBS | `observability.md` | Not applicable — no new async boundary | | |
| ANL | `analytics-rules.md` | Not applicable — analytics: none | | |
| SEC | `android-security.md` | Not applicable — no auth or storage change | | |
MD
}

write_plan() {  # $1 = lane
  cat > "$FEATURE_DIR/implementation-plan.md" <<MD
# Implementation Plan — Expiring share invitations

**Feature ID**: \`$FEATURE_ID\`
**Workflow**: harness-planning
**Lane**: $1

## Product Requirements

| Artifact | Capability file | Requirement IDs | Approved SHA-256 | Approved by / date |
|---|---|---|---|---|
| \`intent.md\` | — | SC-001 | \`$(artifact_hash "$INTENT")\` | user, 2026-11-09 |
| \`design.md\` | — | — | \`$(artifact_hash "$DESIGN")\` | user, 2026-11-09 |
| \`specs/note-sharing.md\` | \`docs/product/requirements/note-sharing.md\` | ADDED FR-002, FR-003 | \`$(artifact_hash "$DELTA")\` | user, 2026-11-09 |

$(rule_rows)
MD
}

write_capability() {  # $1 = user-scenarios markdown (empty = single lane)
  rm -rf "$FIXTURE_ROOT/docs" "$FIXTURE_ROOT/.scratch"
  mkdir -p "$FEATURE_DIR/specs" "$(dirname "$CAPABILITY")"
  local lane=single
  [ -n "$1" ] && lane=sliced
  cat > "$CAPABILITY" <<'MD'
# Note Sharing & Access Control

**Capability ID**: `note-sharing`

## Requirements

### Requirement: FR-001 Open sharing for an editable note
The app SHALL open the Shared Users screen when Share is selected.

#### Scenario: AC-001 Share an editable note
- **GIVEN** an editable note
- **WHEN** Share is selected
- **THEN** Shared Users opens
MD
  cat > "$INTENT" <<'MD'
# share-expiry — Expiring share invitations

**Author**: owner
**Status**: Approved — user, 2026-11-09
**Input**: "Let invitations expire"

## Problem

Invitations never expire.

## Proposed Outcome

- Owners choose an invitation expiry.

**Success criteria**
- **SC-001**: An owner sets an expiry in under 10 seconds.
MD
  cat > "$DESIGN" <<MD
# share-expiry — Design

**Lane**: $lane
$1
## Product Decisions

| Decision | Chosen | Alternatives considered | Reason |
|---|---|---|---|
| Expiry choices | 1, 7, 30 days | free date | fewer taps |
MD
  cat > "$DELTA" <<'MD'
# Note Sharing — delta

## ADDED Requirements

### Requirement: FR-002 Invitation expiry
The app SHALL let users choose an invitation expiry of 1, 7, or 30 days.

#### Scenario: AC-002 Choose an expiry
- **GIVEN** the invite screen
- **WHEN** the owner picks 7 days and sends
- **THEN** the pending row shows the expiry

### Requirement: FR-003 Expired invitation state
The app SHALL show an expired invitation as Expired.

#### Scenario: AC-003 Expired row
- **GIVEN** an invitation past its expiry
- **WHEN** Shared Users loads
- **THEN** the row shows Expired
MD
}

acceptance_header='| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|'

write_single() {
  write_capability ""
  write_plan single
  cat > "$FEATURE_DIR/test-plan.md" <<MD
# Test Plan — Expiring share invitations

## Acceptance Test Cases

$acceptance_header
| TC-01 | AC-002 | JVM integration | \`ShareInviteIntegrationTest.kt#expiry\` | N/A — no API | Given invite | Row shows expiry | \`./gradlew testDebugUnitTest\` |
| TC-02 | AC-003 | JVM integration | \`SharedUsersIntegrationTest.kt#expired\` | N/A — no API | Given expired | Row shows Expired | \`./gradlew testDebugUnitTest\` |

## Rule Applicability Test Mapping

| Required Rule ID | Planned verification |
|---|---|
| ARCH | review |
| IMPL | TC-01 |
| TEST | acceptance tests |
| SUI | review capture |
| L10N | strings check |
| API | contract test |

## Layer Selection

JVM only.
MD
}

write_sliced() {
  write_capability "
## User Scenarios

### US-1 — Owner sets an expiry (Priority: P1)

**Independent Test**: Invite with a 7-day expiry.
**Requirements**: note-sharing.md#FR-002

### US-2 — Owner sees expired invitations (Priority: P2)

**Independent Test**: Load an expired invitation.
**Requirements**: note-sharing.md#FR-003
"
  write_plan sliced
  cat > "$FEATURE_DIR/test-plan.md" <<MD
# Test Plan — Expiring share invitations

## Rule Applicability Test Mapping

| Required Rule ID | Planned verification |
|---|---|
| ARCH | review |
| IMPL | TC-01 |
| TEST | acceptance tests |
| SUI | review capture |
| L10N | strings check |
| API | contract test |

## Acceptance Test Cases

### US-1 — Owner sets an expiry

$acceptance_header
| TC-US-1-01 | AC-002 | JVM integration | \`ShareInviteIntegrationTest.kt#expiry\` | N/A — no API | Given invite | Row shows expiry | \`./gradlew testDebugUnitTest\` |

### US-2 — Owner sees expired invitations

$acceptance_header
| TC-US-2-01 | AC-003 | JVM integration | \`SharedUsersIntegrationTest.kt#expired\` | N/A — no API | Given expired | Row shows Expired | \`./gradlew testDebugUnitTest\` |

## Spec Coverage Matrix *(sliced lane only)*

| Source requirement | Capability file | Requirement summary | User story | Primary acceptance test | Handling |
|---|---|---|---|---|---|
| FR-002 | \`note-sharing.md\` | Expiry choice | US-1 | TC-US-1-01 | In scope |
| AC-002 | \`note-sharing.md\` | Row shows expiry | US-1 | TC-US-1-01 | In scope |
| FR-003 | \`note-sharing.md\` | Expired state | US-2 | TC-US-2-01 | In scope |
| AC-003 | \`note-sharing.md\` | Row shows Expired | US-2 | TC-US-2-01 | In scope |
| SC-001 | \`intent.md\` | Under 10 seconds | US-1 | TC-US-1-01 | In scope |

## Production Journey Planning Contract *(sliced lane only)*

| User story | Journey required | Journey reason | Journey acceptance test ID | Production entry point | Planned test file and method | User actions | Return boundary | Post-return assertion |
|---|---|---|---|---|---|---|---|---|
| US-1 | No | Same screen | N/A | N/A | N/A | N/A | N/A | N/A |
| US-2 | No | Same screen | N/A | N/A | N/A | N/A | N/A | N/A |
MD
  cat > "$FEATURE_DIR/tasks.md" <<'MD'
# Tasks — Expiring share invitations

## Slices

| Slice | Delivers | Requirements | Tasks | Depends on | Acceptance tests |
|---|---|---|---|---|---|
| US-1 | Owner sets an expiry | `note-sharing.md#FR-002` | T001–T003 | none | `TC-US-1-01` |
| US-2 | Owner sees expired invitations | `note-sharing.md#FR-003` | T004, T005 | US-1 | `TC-US-2-01` |

## US-1: Owner sets an expiry (Priority: P1)

**Slice**: `US-1` in `feature_list.json`

### Prerequisites

- [ ] T001 [US-1] [L10N] Add expiry strings in `app/src/main/res/values/strings.xml`

### Implementation

- [ ] T002 [US-1] [API] Add expiry to invite state in `ShareInviteViewModel.kt`

### Tests

- [ ] T003 [P] [US-1] Test expiry state in `ShareInviteViewModelTest.kt`

## US-2: Owner sees expired invitations (Priority: P2)

**Slice**: `US-2` in `feature_list.json`

### Implementation

- [ ] T004 [US-2] [SUI] Map expired status in `ShareUiModels.kt`

### Final checks

- [ ] T005 [US-2] Run ktlintCheck and detekt
MD
  cat > "$FEATURE_DIR/feature_list.json" <<'JSON'
{
  "features": [
    {"id": "US-1", "acceptance_test_ids": ["TC-US-1-01"], "production_journey": {"required": false},
     "tasks": [
       {"id": "T001", "title": "Expiry strings", "file": "app/src/main/res/values/strings.xml", "done": false},
       {"id": "T002", "title": "Invite state", "file": "ShareInviteViewModel.kt", "done": false},
       {"id": "T003", "title": "State test", "file": "ShareInviteViewModelTest.kt", "done": false}]},
    {"id": "US-2", "acceptance_test_ids": ["TC-US-2-01"], "production_journey": {"required": false},
     "tasks": [
       {"id": "T004", "title": "Expired status", "file": "ShareUiModels.kt", "done": false},
       {"id": "T005", "title": "Quality checks", "file": "app/build.gradle.kts", "done": false}]}
  ]
}
JSON
}

# ---------------------------------------------------------------- single lane
write_single
expect_success "validator rejected a consistent single-lane workspace"

write_single
replace "$DELTA" "1, 7, or 30 days" "1, 7, 30, or 90 days"
expect_failure "specs/note-sharing.md changed after approval"

write_single
replace "$INTENT" "Invitations never expire." "Invitations never expire, ever."
expect_failure "intent.md changed after approval"

# Approval and archiving flip intent.md **Status** without changing its recorded hash.
write_single
replace "$INTENT" "**Status**: Approved — user, 2026-11-09" "**Status**: Archived — 2026-11-10"
expect_success "an archived intent must keep its approved hash"
python3 "$SCRIPT_DIR/../archive-change.py" "$FEATURE_DIR" --project-root "$FIXTURE_ROOT" >/dev/null 2>&1 && fail_test "archive must refuse an already archived intent"
replace "$INTENT" "**Status**: Archived — 2026-11-10" "**Status**: Approved — user, 2026-11-09"
python3 "$SCRIPT_DIR/../archive-change.py" "$FEATURE_DIR" --project-root "$FIXTURE_ROOT" >/dev/null || fail_test "archive rejected an approved change"
expect_success "the analyze gate must still pass after the deltas are archived"

write_single
replace "$DELTA" "1, 7, or 30 days." "1, 7, or 30 days [NEEDS CLARIFICATION: custom?]."
write_plan single
expect_failure "still contains [NEEDS CLARIFICATION] markers"

write_single
replace "$INTENT" "**Status**: Approved — user, 2026-11-09" "**Status**: Clarified"
write_plan single
expect_failure "**Status** is not Approved"

# --pre-approval: a clarified block with no recorded hash can be analyzed before approval.
write_single
replace "$INTENT" "**Status**: Approved — user, 2026-11-09" "**Status**: Clarified"
python3 - "$FEATURE_DIR/implementation-plan.md" <<'PY2'
import re, sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(re.sub(r"`[0-9a-f]{64}`", "`<64 hex characters>`", text))
PY2
bash "$VALIDATOR" "$FEATURE_DIR" --project-root "$FIXTURE_ROOT" --pre-approval >/dev/null ||
  fail_test "pre-approval analysis rejected a clarified, unhashed change"
expect_failure "approved SHA-256 is not recorded"
replace "$FEATURE_DIR/test-plan.md" "| TC-02 | AC-003 |" "| TC-02 | AC-002 |"
if bash "$VALIDATOR" "$FEATURE_DIR" --project-root "$FIXTURE_ROOT" --pre-approval >/dev/null 2>&1; then
  fail_test "pre-approval analysis must still enforce acceptance coverage"
fi

write_single
replace "$DELTA" "### Requirement: FR-002 Invitation expiry" "### Requirement: FR-001 Invitation expiry"
write_plan single
expect_failure "ADDED FR-001 already exists in docs/product/requirements/note-sharing.md"

write_single
replace "$DELTA" "#### Scenario: AC-002 Choose an expiry" "#### Scenario: AC-001 Choose an expiry"
write_plan single
expect_failure "ADDED scenario AC-001 already exists"

write_single
replace "$DELTA" "## ADDED Requirements" "## MODIFIED Requirements"
write_plan single
expect_failure "FR-002 is not a '### Requirement:' in docs/product/requirements/note-sharing.md"

write_single
replace "$DELTA" "The app SHALL show an expired" "The app shows an expired"
write_plan single
expect_failure "ADDED FR-003 must state its behavior with SHALL"

write_single
rm "$DESIGN"
expect_failure "missing design.md"

write_single
replace "$FEATURE_DIR/implementation-plan.md" "| \`specs/note-sharing.md\` |" "| \`specs/other.md\` |"
expect_failure "needs a \`specs/note-sharing.md\` row"

write_single
replace "$DESIGN" "**Lane**: single" "**Lane**: sliced"
write_plan single
expect_failure "design.md **Lane** is sliced, but implementation-plan.md declares single"

write_single
replace "$FEATURE_DIR/test-plan.md" "| TC-02 | AC-003 |" "| TC-02 | AC-002 |"
expect_failure "test-plan.md has no acceptance test covering note-sharing.md#AC-003"

write_single
replace "$FEATURE_DIR/test-plan.md" "| TC-02 | AC-003 |" "| TC-02 | AC-003, AC-099 |"
expect_failure "TC-02 cites AC-099, which no listed capability file or delta defines"

write_single
replace "$FEATURE_DIR/test-plan.md" "| TC-02 | AC-003 |" "| TC-02 | none |"
expect_failure "TC-02 does not name the AC-### it covers"

write_single
replace "$FEATURE_DIR/implementation-plan.md" "| NAV | \`navigation-rules.md\` | Not applicable — no route change |" "| NAV | \`navigation-rules.md\` | N/A |"
expect_failure "NAV has an unsupported decision"

write_single
echo '{"features": []}' > "$FEATURE_DIR/feature_list.json"
expect_failure "single lane does not use feature_list.json"

write_single
replace "$FEATURE_DIR/test-plan.md" "## Acceptance Test Cases" "## Acceptance Test Cases

### US-1 — Grouped"
expect_failure "single lane keeps one flat '## Acceptance Test Cases' table"

write_single
rm "$FEATURE_DIR/test-plan.md"
expect_failure "2026-11-09-share-expiry/test-plan.md"

write_sliced
write_plan single
expect_failure "single lane must not define user stories"

# ---------------------------------------------------------------- sliced lane
write_sliced
expect_success "validator rejected a consistent sliced-lane workspace"

write_sliced
replace "$FEATURE_DIR/test-plan.md" "| AC-003 | \`note-sharing.md\` | Row shows Expired | US-2 | TC-US-2-01 | In scope |" ""
expect_failure "test-plan.md Spec Coverage Matrix is missing note-sharing.md#AC-003"

write_sliced
replace "$FEATURE_DIR/test-plan.md" "| SC-001 | \`intent.md\` | Under 10 seconds | US-1 | TC-US-1-01 |" "| SC-001 | \`intent.md\` | Under 10 seconds | US-1 | TC-US-2-01 |"
expect_failure "test TC-US-2-01 belongs to US-2, not US-1"

write_sliced
replace "$FEATURE_DIR/test-plan.md" "### US-2 — Owner sees expired invitations" "### Other"
expect_failure "has no '### US-2' subsection"

write_sliced
replace "$FEATURE_DIR/feature_list.json" '"acceptance_test_ids": ["TC-US-2-01"]' '"acceptance_test_ids": []'
expect_failure "US-2 is missing acceptance test TC-US-2-01"

write_sliced
replace "$FEATURE_DIR/feature_list.json" '"acceptance_test_ids": ["TC-US-1-01"], "production_journey": {"required": false}' '"acceptance_test_ids": ["TC-US-1-01"], "production_journey": {"required": true}'
expect_failure "production_journey.required disagrees with test-plan.md"

write_sliced
replace "$FEATURE_DIR/tasks.md" "- [ ] T003 [P] [US-1]" "- [ ] T003 [P] [US-3]"
expect_failure "T003 is in the US-1 section but labelled US-3"

write_sliced
replace "$FEATURE_DIR/tasks.md" "- [ ] T003 [P]" "- [ ] T002 [P]"
expect_failure "tasks.md reuses task ID T002"

write_sliced
replace "$FEATURE_DIR/tasks.md" '**Slice**: `US-2` in `feature_list.json`' ''
expect_failure "must declare '**Slice**: \`US-2\`'"

# Required rules become planned work, a planned verification, and (sliced) a tagged task.
write_single
replace "$FEATURE_DIR/implementation-plan.md" "| SUI | \`compose-rules.md\` | Required | picker | review capture |" "| SUI | \`compose-rules.md\` | Required | picker | |"
expect_failure "SUI is Required but has no planned work and evidence"

write_single
replace "$FEATURE_DIR/test-plan.md" "| L10N | strings check |" ""
expect_failure "no planned verification for Required rule L10N"

write_single
replace "$FEATURE_DIR/test-plan.md" "| API | contract test |" "| API | <test IDs, planned command, review check, or verification gap> |"
expect_failure "no planned verification for Required rule API"

write_sliced
replace "$FEATURE_DIR/tasks.md" "[US-1] [L10N] Add expiry strings" "[US-1] Add expiry strings"
expect_failure "tasks.md has no task tagged [L10N] for Required rule L10N"

write_sliced
replace "$FEATURE_DIR/tasks.md" "[US-2] [SUI] Map" "[US-2] [NAV] Map"
expect_failure "T004 is tagged [NAV], but Rule Applicability does not mark NAV Required"

# Tasks belong to exactly one slice; Prerequisites / Final checks sit in one slice each.
write_sliced
replace "$FEATURE_DIR/tasks.md" "- [ ] T004 [US-2] [SUI] Map" "- [ ] T004 [SUI] Map"
expect_failure "T004 has no [US-n] label"

write_sliced
replace "$FEATURE_DIR/tasks.md" "### Implementation

- [ ] T004" "### Prerequisites

- [ ] T004"
expect_failure "section US-2 has '### Prerequisites'; only the first slice (US-1) may"

write_sliced
replace "$FEATURE_DIR/tasks.md" "### Tests

- [ ] T003" "### Final checks

- [ ] T003"
expect_failure "section US-1 has '### Final checks'; only the last slice (US-2) may"

write_sliced
replace "$FEATURE_DIR/tasks.md" "| T001–T003 |" "| T001–T002 |"
expect_failure "Slices table tasks for US-1 (T001, T002) do not match its section (T001, T002, T003)"

write_sliced
replace "$FEATURE_DIR/tasks.md" "## US-1: Owner sets an expiry (Priority: P1)" "- [ ] T009 [US-1] Stray task in \`Stray.kt\`

## US-1: Owner sets an expiry (Priority: P1)"
expect_failure "T009 is outside every slice section"

write_sliced
python3 - "$FEATURE_DIR/feature_list.json" <<'PY4'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["features"][0]["tasks"] = [t for t in d["features"][0]["tasks"] if t["id"] != "T003"]
json.dump(d, open(p, "w"))
PY4
expect_failure "feature_list.json US-1 is missing task T003 from tasks.md"

write_sliced
replace "$FEATURE_DIR/feature_list.json" '"id": "T004", "title": "Expired status", "file": "ShareUiModels.kt", "done": false' '"id": "T004", "title": "Expired status", "file": "ShareUiModels.kt", "done": true'
expect_failure "T004 is done in feature_list.json but unchecked in tasks.md"

write_sliced
replace "$FEATURE_DIR/tasks.md" "- [ ] T004 [US-2]" "- [x] T004 [US-2]"
expect_failure "T004 is not done in feature_list.json but checked in tasks.md"

write_sliced
python3 - "$FEATURE_DIR/feature_list.json" <<'PY3'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d["features"][1]["tasks"]
json.dump(d, open(p, "w"))
PY3
expect_failure "feature_list.json US-2 needs a non-empty 'tasks' array"

write_sliced
rm "$FEATURE_DIR/tasks.md"
expect_failure "required in the sliced lane"

write_sliced
replace "$DESIGN" "**Requirements**: note-sharing.md#FR-003" "**Requirements**: note-sharing.md#FR-002"
write_plan sliced
expect_failure "FR-003 is not owned by any user story"

write_sliced
replace "$DESIGN" "**Requirements**: note-sharing.md#FR-003" "**Requirements**: note-sharing.md#FR-009"
write_plan sliced
expect_failure "US-2 lists note-sharing.md#FR-009, which no ADDED/MODIFIED delta defines"

write_single
write_plan sliced
expect_failure "sliced lane needs two or more user stories"

echo "PASS: spec-plan consistency contract (single and sliced lanes)"
