#!/usr/bin/env bash
# Contract test for the analyze gate (check-spec-plan-consistency.sh), single and sliced lanes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../check-spec-plan-consistency.sh"
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/spec-plan-consistency-test.XXXXXX")
FEATURE_ID="share-expiry"
FEATURE_DIR="$FIXTURE_ROOT/.scratch/2026-11-09-$FEATURE_ID"
CAPABILITY="$FIXTURE_ROOT/docs/product/requirements/note-sharing.md"
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

block_hash() {
  python3 - "$CAPABILITY" "$FEATURE_ID" <<'PY'
import hashlib, sys
text = open(sys.argv[1], encoding="utf-8").read()
start, end = f"<!-- feature: {sys.argv[2]} -->", f"<!-- /feature: {sys.argv[2]} -->"
print(hashlib.sha256(text[text.index(start) + len(start):text.index(end)].encode()).hexdigest())
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
**Workflow**: feature-delivery
**Lane**: $1

## Product Requirements

| Capability file | Feature block | Requirement IDs | Approved block SHA-256 | Approved by / date |
|---|---|---|---|---|
| \`docs/product/requirements/note-sharing.md\` | \`$FEATURE_ID\` | FR-002, FR-003 | \`$(block_hash)\` | user, 2026-11-09 |

$(rule_rows)
MD
}

write_capability() {  # $1 = user-scenarios markdown (may be empty)
  rm -rf "$FIXTURE_ROOT/docs" "$FIXTURE_ROOT/.scratch"
  mkdir -p "$FEATURE_DIR" "$(dirname "$CAPABILITY")"
  cat > "$CAPABILITY" <<MD
# Note Sharing & Access Control

## Requirements

### FR-001 — Open sharing for an editable note

Selecting Share opens the Shared Users screen.

**Acceptance criteria**

- **AC-001**: Given an editable note, when Share is selected, then Shared Users opens.

## Planned changes

<!-- feature: share-expiry -->
### share-expiry — Expiring share invitations

**Status**: Approved — user, 2026-11-09
$1
#### Requirements *(mandatory)*

##### FR-002 — Invitation expiry (New)

Users MUST be able to choose an invitation expiry of 1, 7, or 30 days.

**Acceptance criteria**

- **AC-002**: Given the invite screen, when the owner picks 7 days and sends, then the pending row shows the expiry.

##### FR-003 — Expired invitation state (New)

The system MUST show an expired invitation as Expired.

**Acceptance criteria**

- **AC-003**: Given an invitation past its expiry, when Shared Users loads, then the row shows Expired.

#### Success Criteria *(mandatory)*

- **SC-001**: An owner sets an expiry in under 10 seconds.
<!-- /feature: share-expiry -->
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

## Layer Selection

JVM only.
MD
}

write_sliced() {
  write_capability "
#### User Scenarios

##### US-1 — Owner sets an expiry (Priority: P1)

**Independent Test**: Invite with a 7-day expiry.
**Requirements**: FR-002

##### US-2 — Owner sees expired invitations (Priority: P2)

**Independent Test**: Load an expired invitation.
**Requirements**: FR-003
"
  write_plan sliced
  cat > "$FEATURE_DIR/test-plan.md" <<MD
# Test Plan — Expiring share invitations

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
| SC-001 | \`note-sharing.md\` | Under 10 seconds | US-1 | TC-US-1-01 | In scope |

## Production Journey Planning Contract *(sliced lane only)*

| User story | Journey required | Journey reason | Journey acceptance test ID | Production entry point | Planned test file and method | User actions | Return boundary | Post-return assertion |
|---|---|---|---|---|---|---|---|---|
| US-1 | No | Same screen | N/A | N/A | N/A | N/A | N/A | N/A |
| US-2 | No | Same screen | N/A | N/A | N/A | N/A | N/A | N/A |
MD
  cat > "$FEATURE_DIR/tasks.md" <<'MD'
# Tasks — Expiring share invitations

## Phase 1 — Setup

- [ ] T001 Add expiry strings in `app/src/main/res/values/strings.xml`

## Phase 2 — US-1: Owner sets an expiry (Priority: P1)

**Slice**: `US-1` in `feature_list.json`

- [ ] T002 [US-1] Add expiry to invite state in `ShareInviteViewModel.kt`
- [ ] T003 [P] [US-1] Test expiry state in `ShareInviteViewModelTest.kt`

## Phase 3 — US-2: Owner sees expired invitations (Priority: P2)

**Slice**: `US-2` in `feature_list.json`

- [ ] T004 [US-2] Map expired status in `ShareUiModels.kt`
MD
  cat > "$FEATURE_DIR/feature_list.json" <<'JSON'
{
  "features": [
    {"id": "US-1", "acceptance_test_ids": ["TC-US-1-01"], "production_journey": {"required": false}},
    {"id": "US-2", "acceptance_test_ids": ["TC-US-2-01"], "production_journey": {"required": false}}
  ]
}
JSON
}

# ---------------------------------------------------------------- single lane
write_single
expect_success "validator rejected a consistent single-lane workspace"

write_single
replace "$CAPABILITY" "1, 7, or 30 days" "1, 7, 30, or 90 days"
expect_failure "feature block changed after approval"

write_single
replace "$CAPABILITY" "1, 7, or 30 days." "1, 7, or 30 days [NEEDS CLARIFICATION: custom?]."
write_plan single
expect_failure "still contains [NEEDS CLARIFICATION] markers"

write_single
replace "$CAPABILITY" "**Status**: Approved — user, 2026-11-09" "**Status**: Clarified"
write_plan single
expect_failure "**Status** is not Approved"

# --pre-approval: a clarified block with no recorded hash can be analyzed before approval.
write_single
replace "$CAPABILITY" "**Status**: Approved — user, 2026-11-09" "**Status**: Clarified"
python3 - "$FEATURE_DIR/implementation-plan.md" <<'PY2'
import re, sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(re.sub(r"`[0-9a-f]{64}`", "`<64 hex characters>`", text))
PY2
bash "$VALIDATOR" "$FEATURE_DIR" --project-root "$FIXTURE_ROOT" --pre-approval >/dev/null ||
  fail_test "pre-approval analysis rejected a clarified, unhashed block"
expect_failure "approved block SHA-256 is not recorded"
replace "$FEATURE_DIR/test-plan.md" "| TC-02 | AC-003 |" "| TC-02 | AC-002 |"
if bash "$VALIDATOR" "$FEATURE_DIR" --project-root "$FIXTURE_ROOT" --pre-approval >/dev/null 2>&1; then
  fail_test "pre-approval analysis must still enforce acceptance coverage"
fi

write_single
replace "$CAPABILITY" "##### FR-002 — Invitation expiry (New)" "##### FR-001 — Invitation expiry (New)"
write_plan single
expect_failure "FR-001 is defined more than once"

write_single
replace "$FEATURE_DIR/test-plan.md" "| TC-02 | AC-003 |" "| TC-02 | AC-002 |"
expect_failure "test-plan.md has no acceptance test covering note-sharing.md#AC-003"

write_single
replace "$FEATURE_DIR/test-plan.md" "| TC-02 | AC-003 |" "| TC-02 | AC-003, AC-099 |"
expect_failure "TC-02 cites AC-099, which no listed capability file defines"

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
replace "$FEATURE_DIR/test-plan.md" "| SC-001 | \`note-sharing.md\` | Under 10 seconds | US-1 | TC-US-1-01 |" "| SC-001 | \`note-sharing.md\` | Under 10 seconds | US-1 | TC-US-2-01 |"
expect_failure "test TC-US-2-01 belongs to US-2, not US-1"

write_sliced
replace "$FEATURE_DIR/test-plan.md" "### US-2 — Owner sees expired invitations" "### Other"
expect_failure "has no '### US-2' subsection"

write_sliced
replace "$FEATURE_DIR/feature_list.json" '"acceptance_test_ids": ["TC-US-2-01"]' '"acceptance_test_ids": []'
expect_failure "US-2 is missing acceptance test TC-US-2-01"

write_sliced
replace "$FEATURE_DIR/feature_list.json" '"production_journey": {"required": false}}' '"production_journey": {"required": true}}'
expect_failure "production_journey.required disagrees with test-plan.md"

write_sliced
replace "$FEATURE_DIR/tasks.md" "- [ ] T003 [P] [US-1]" "- [ ] T003 [P] [US-3]"
expect_failure "T003 is labelled US-3, which is not a user story"

write_sliced
replace "$FEATURE_DIR/tasks.md" "- [ ] T003 [P]" "- [ ] T002 [P]"
expect_failure "tasks.md reuses task ID T002"

write_sliced
replace "$FEATURE_DIR/tasks.md" '**Slice**: `US-2` in `feature_list.json`' ''
expect_failure "must declare '**Slice**: \`US-2\`'"

write_sliced
rm "$FEATURE_DIR/tasks.md"
expect_failure "required in the sliced lane"

write_sliced
replace "$CAPABILITY" "**Requirements**: FR-003" "**Requirements**: FR-002"
write_plan sliced
expect_failure "FR-003 is not owned by any user story"

write_single
write_plan sliced
expect_failure "sliced lane needs two or more user stories"

echo "PASS: spec-plan consistency contract (single and sliced lanes)"
