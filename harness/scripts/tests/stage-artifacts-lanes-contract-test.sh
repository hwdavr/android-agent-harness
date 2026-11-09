#!/usr/bin/env bash
# End-to-end contract test for check-stage-artifacts.sh on dated workspaces:
# single-lane non-UI feature, single-lane UI feature (registered components), and bug fix.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../check-stage-artifacts.sh"
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/stage-lanes-test.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT
export HARNESS_PROJECT_ROOT="$ROOT"

fail_test() { echo "FAIL: $1" >&2; exit 1; }
gate() { (cd "$ROOT" && bash "$GATE" "$@"); }
expect_pass() {
  local out
  out=$(gate "$@" 2>&1) || { echo "$out" >&2; fail_test "gate rejected: $*"; }
}
expect_fail() {
  local expected="$1" out
  shift
  if out=$(gate "$@" 2>&1); then fail_test "gate accepted: $* (expected: $expected)"; fi
  printf '%s\n' "$out" | grep -Fq -- "$expected" || { echo "$out" >&2; fail_test "missing report: $expected"; }
}

png() {  # path width height
  python3 - "$@" <<'PY'
import struct, sys, zlib
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
raw = b"".join(b"\x00" + b"\xff\xff\xff" * w for _ in range(h))
open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                       + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
PY
}

block_hash() {  # capability feature-id
  python3 - "$1" "$2" <<'PY'
import hashlib, sys
t = open(sys.argv[1], encoding="utf-8").read()
s, e = f"<!-- feature: {sys.argv[2]} -->", f"<!-- /feature: {sys.argv[2]} -->"
print(hashlib.sha256(t[t.index(s) + len(s):t.index(e)].encode()).hexdigest())
PY
}

rules() {  # SUI decision
  cat <<MD
## Rule Applicability

| Rule ID | Rule document | Decision | Feature-specific trigger or reason | Planned work and evidence |
|---|---|---|---|---|
| ARCH | \`android-architecture.md\` | Required | layers | review |
| IMPL | \`implementation-rules.md\` | Required | behavior | tests |
| TEST | \`testing-strategy.md\` | Required | tests | acceptance tests |
| SUI | \`compose-rules.md\` | $1 | | |
| L10N | \`localization-rules.md\` | Not applicable — no copy change | | |
| NAV | \`navigation-rules.md\` | Not applicable — no route change | | |
| API | \`api-contract-rules.md\` | Not applicable — no API change | | |
| OBS | \`observability.md\` | Not applicable — no async boundary | | |
| ANL | \`analytics-rules.md\` | Not applicable — analytics: none | | |
| SEC | \`android-security.md\` | Not applicable — no security boundary | | |
MD
}

rule_mapping() {
  cat <<'MD'
## Rule Applicability Test Mapping

Canonical decisions: [`implementation-plan.md#rule-applicability`](implementation-plan.md#rule-applicability).

| Required Rule ID | Planned verification |
|---|---|
| ARCH | review |
| IMPL | TC-01 |
| TEST | TC-01 |
| SUI | UI-01 review capture |
MD
}

setup_project() {
  rm -rf "$ROOT"/{docs,.scratch,app,UX}
  mkdir -p "$ROOT/docs/product/requirements" "$ROOT/.scratch" "$ROOT/app/src/test/java/example/review"
  cat > "$ROOT/docs/product/design_system.md" <<'MD'
# Design System

## Component Contracts

### Component Registry

| Component | Pen component | Composable | Required testTag | Wraps Material |
|---|---|---|---|---|
| TopActionBar | comp/top-bar | ui/components/TopActionBar.kt | top_action_bar | TopAppBar, CenterAlignedTopAppBar |
| NoteCard | comp/note-card | ui/components/NoteCard.kt | note_card | Card, ElevatedCard |
MD
  cat > "$ROOT/docs/product/requirements/note-sharing.md" <<'MD'
# Note Sharing

## Requirements

### FR-001 — Open sharing

**Acceptance criteria**

- **AC-001**: Given an editable note, when Share is selected, then Shared Users opens.

## Planned changes

<!-- feature: share-expiry -->
### share-expiry — Expiring invitations

**Status**: Approved — user, 2026-11-09

#### Requirements *(mandatory)*

##### FR-002 — Invitation expiry (New)

Users MUST be able to choose an invitation expiry.

**Acceptance criteria**

- **AC-002**: Given the invite screen, when the owner picks 7 days, then the row shows the expiry.

#### Screen States *(include when the change has UI; remove otherwise)*

| Screen | State ID | Requirement | Acceptance Criteria |
|---|---|---|---|
| Share Invite | invite-expiry-selected | FR-002 | AC-002 |
<!-- /feature: share-expiry -->
MD
  cat > "$ROOT/docs/product/product.md" <<'MD'
# Product

<!-- HARNESS_TRACKER_START -->
| ID | Feature | Workspace | Status | Updated | Notes |
|---|---|---|---|---|---|
| share-expiry | Expiring invitations | [.scratch/2026-11-09-share-expiry/](../../.scratch/2026-11-09-share-expiry/) | Planning | 2026-11-09 | single lane |
| fix-share-crash | Share crash | [.scratch/2026-11-09-fix-share-crash/](../../.scratch/2026-11-09-fix-share-crash/) | Planning | 2026-11-09 | bug |
<!-- HARNESS_TRACKER_END -->
MD
  W="$ROOT/.scratch/2026-11-09-share-expiry"
  B="$ROOT/.scratch/2026-11-09-fix-share-crash"
  mkdir -p "$W/design" "$W/evidence" "$B"
  echo "# Summary" > "$W/summary.md"
}

write_feature_plans() {
  cat > "$W/implementation-plan.md" <<MD
# Implementation Plan — Expiring invitations

**Feature ID**: \`share-expiry\`
**Lane**: single

## Product Requirements

| Capability file | Feature block | Requirement IDs | Approved block SHA-256 | Approved by / date |
|---|---|---|---|---|
| \`docs/product/requirements/note-sharing.md\` | \`share-expiry\` | FR-002 | \`$(block_hash "$ROOT/docs/product/requirements/note-sharing.md" share-expiry)\` | user, 2026-11-09 |

$(rules Required)

## Phase 1 — Design

### Project Structure

| Layer | Files affected | Change type |
|---|---|---|
| UI | \`app/src/main/java/example/ShareInviteScreen.kt\` | modify |

### UI State Stages *(UI scope; remove otherwise)*

| Stage ID | Reused registered components | Implementation |
|---|---|---|
| UI-01 | \`TopActionBar\`, \`NoteCard\` | Expiry chip row on Share Invite |

## Delivery

Single lane.
MD
  cat > "$W/test-plan.md" <<MD
# Test Plan — Expiring invitations

$(rule_mapping)

## Acceptance Test Cases

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-01 | AC-002 | JVM integration | \`app/src/test/java/example/ShareInviteTest.kt#expiry\` | N/A — no API | Given invite | Row shows expiry | \`./gradlew testDebugUnitTest\` |

## UI State Verification *(UI scope; remove otherwise)*

| Stage ID | Review capture (test#method) | Structural check (test#method) | Command |
|---|---|---|---|
| UI-01 | \`app/src/test/java/example/review/ShareInviteReviewCaptureTest.kt#expirySelected\` | \`app/src/test/java/example/ShareInviteStructureTest.kt#expirySelected\` | \`./gradlew testDebugUnitTest --tests "example.ShareInviteStructureTest" --tests "example.review.ShareInviteReviewCaptureTest"\` |
MD
}

write_ui_contract() {  # $1 = reused components cell, $2 = design fields (Pending or complete)
  local design
  if [ "$2" = "Pending" ]; then
    design="Pending | Pending | Pending | Pending"
  else
    design="design/share-invite.png | external | external-screen | design/share-invite.png"
    png "$W/design/share-invite.png" 780 1688
  fi
  cat > "$W/UI_contract.md" <<MD
# UI Contract — share-expiry

**Project design system**: \`docs/product/design_system.md\`

## Screen States

| Screen | State ID | Design source | Design node ID | Design node role | Design image | Viewport | Required regions | State controls | Reused components | Runtime fixture | Plan stage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Share Invite | invite-expiry-selected | $design | 390x844 | primary-content; state-controls; persistent-controls | Expiry chips with 7 days selected; Send enabled | $1 | invite-expiry-7d | UI-01 |
MD
}

# ------------------------------------------------------------ feature lane
setup_project
expect_pass feature-delivery specify .scratch/2026-11-09-share-expiry

mkdir -p "$ROOT/.scratch/2026-11-09-untracked"
expect_fail "has no row linking .scratch/2026-11-09-untracked" feature-delivery specify .scratch/2026-11-09-untracked

mkdir -p "$ROOT/docs/current"
expect_fail "is not a dated feature workspace under .scratch/" feature-delivery specify docs/current

write_ui_contract '`TopActionBar`, `NoteCard`' Pending
expect_pass feature-delivery ui-contract .scratch/2026-11-09-share-expiry
expect_fail "has pending design references" feature-delivery ux-design .scratch/2026-11-09-share-expiry

write_ui_contract '`TopActionBar`, `NoteCard`' complete
expect_pass feature-delivery ux-design .scratch/2026-11-09-share-expiry

write_ui_contract '`TopActionBar`, `FancyChip`' complete
expect_fail "reuses unregistered components ['FancyChip']" feature-delivery ux-design .scratch/2026-11-09-share-expiry

write_ui_contract '`TopActionBar`, `NoteCard`' complete
write_feature_plans
expect_pass feature-delivery implementation-plan .scratch/2026-11-09-share-expiry

python3 - "$W/implementation-plan.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("| UI-01 | `TopActionBar`, `NoteCard` |", "| UI-01 | `TopActionBar` |"))
PY
expect_fail "UI plan stage UI-01 reused components differ from UI_contract.md" feature-delivery implementation-plan .scratch/2026-11-09-share-expiry

write_feature_plans
python3 - "$W/test-plan.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("example/review/ShareInviteReviewCaptureTest.kt", "example/ShareInviteCaptureTest.kt"))
PY
expect_fail "review capture must be app/src/test/java/<package>/review/" feature-delivery implementation-plan .scratch/2026-11-09-share-expiry

write_feature_plans
expect_pass feature-delivery testing .scratch/2026-11-09-share-expiry

# ------------------------------------------------------------ UI conformance review
mkdir -p "$ROOT/app/src/main/java/example" "$ROOT/app/src/test/java/example/review" "$W/evidence/ui"
printf 'package example\n\n@Composable\nfun ShareInviteScreen() {\n    TopActionBar(title = "Share")\n    NoteCard(note)\n}\n' \
  > "$ROOT/app/src/main/java/example/ShareInviteScreen.kt"
printf 'package example.review\n\nclass ShareInviteReviewCaptureTest\n' > "$ROOT/app/src/test/java/example/review/ShareInviteReviewCaptureTest.kt"
printf 'package example\n\nclass ShareInviteStructureTest\n' > "$ROOT/app/src/test/java/example/ShareInviteStructureTest.kt"
png "$W/evidence/ui/invite-expiry-selected.png" 780 1688
write_report() {  # $1 decision
  cat > "$W/ui_verification.json" <<JSON
{
  "version": 1,
  "capture": {"renderer": "robolectric", "density": "xhdpi", "theme": "light", "locale": "en-US", "font_scale": 1.0},
  "build_and_static_checks": {"assembleDebug": "PASS", "compose_rules": "PASS"},
  "state_results": [{
    "screen": "Share Invite", "state_id": "invite-expiry-selected",
    "design_image": "design/share-invite.png",
    "review_capture": "evidence/ui/invite-expiry-selected.png",
    "review_capture_test": "app/src/test/java/example/review/ShareInviteReviewCaptureTest.kt#expirySelected",
    "structural_check": "app/src/test/java/example/ShareInviteStructureTest.kt#expirySelected",
    "structural_result": "PASS", "reused_components": ["TopActionBar", "NoteCard"],
    "review_decision": "$1", "approved_by": "user", "approved_on": "2026-11-09",
    "review_notes": "Font rasterization differs; accepted.", "result": "PASS"
  }]
}
JSON
}
write_report approved
expect_pass feature-delivery ui-verification .scratch/2026-11-09-share-expiry

write_report changes-requested
expect_fail "cannot PASS without an approved review" feature-delivery ui-verification .scratch/2026-11-09-share-expiry

write_report approved
png "$W/evidence/ui/invite-expiry-selected.png" 1080 1080
expect_fail "was not rendered at the contract viewport 390x844" feature-delivery ui-verification .scratch/2026-11-09-share-expiry
png "$W/evidence/ui/invite-expiry-selected.png" 780 1688

printf 'package example\n\n@Composable\nfun ShareInviteScreen() {\n    TopActionBar(title = "Share")\n}\n' \
  > "$ROOT/app/src/main/java/example/ShareInviteScreen.kt"
expect_fail "lists NoteCard, but no UI file in the plan's Project Structure calls it" feature-delivery ui-verification .scratch/2026-11-09-share-expiry

# ------------------------------------------------------------ bug lane
cat > "$B/implementation-plan.md" <<MD
# Implementation Plan — Share crash

**Feature ID**: \`fix-share-crash\`
**Lane**: single

## Product Requirements

| Capability file | Feature block | Requirement IDs | Approved block SHA-256 | Approved by / date |
|---|---|---|---|---|
| \`docs/product/requirements/note-sharing.md\` | none — restores FR-001 | FR-001 | N/A | N/A |

## Root Cause & Reproduction

- **Violated requirement**: \`note-sharing.md#FR-001\` / \`AC-001\`
- **Root cause**: ShareViewModel dereferences a null note.

$(rules "Not applicable — no UI change")
MD
expect_fail "no 'summary.md'" bug-fixing bug-context .scratch/2026-11-09-fix-share-crash
printf '# Summary\n\n| Stage | Status |\n|---|---|\n| Bug Reproduction | RED |\n' > "$B/summary.md"
expect_pass bug-fixing bug-context .scratch/2026-11-09-fix-share-crash

mkdir -p "$ROOT/app/src/test/java/example"
printf 'package example\n\nclass ShareCrashTest {\n    @org.junit.Test\n    fun opensShareForNullNote() {}\n}\n' > "$ROOT/app/src/test/java/example/ShareCrashTest.kt"
cat > "$B/test-plan.md" <<'MD'
# Test Plan — Share crash

## Rule Applicability Test Mapping

Canonical decisions: [`implementation-plan.md#rule-applicability`](implementation-plan.md#rule-applicability).

| Required Rule ID | Planned verification |
|---|---|
| ARCH | review |
| IMPL | TC-01 |
| TEST | TC-01 |

## Reproduction Test *(bug-fixing lane only; written in the bug-reproduction stage)*

- File: `app/src/test/java/example/ShareCrashTest.kt`
- Test name: `opensShareForNullNote`
- Run result: FAILED — NullPointerException in ShareViewModel

## Acceptance Test Cases

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-01 | AC-001 | JVM unit | `app/src/test/java/example/ShareCrashTest.kt#opensShareForNullNote` | N/A — no API | Given null note | Shared Users opens | `./gradlew testDebugUnitTest` |
MD
expect_pass bug-fixing bug-reproduction .scratch/2026-11-09-fix-share-crash
expect_pass bug-fixing implementation-plan .scratch/2026-11-09-fix-share-crash

python3 - "$B/test-plan.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("Run result: FAILED", "Run result: PASSED"))
PY
expect_fail "reproduction result must record FAILED or RED evidence" bug-fixing bug-reproduction .scratch/2026-11-09-fix-share-crash

echo "PASS: stage artifacts contract (single feature, UI feature, bug fix)"
