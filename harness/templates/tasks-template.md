# Tasks — <Feature Name>

**Feature ID**: `<feature-id>`
**Input**: [`implementation-plan.md`](implementation-plan.md), the approved feature block(s) in `docs/product/requirements/`
**Slices**: [`feature_list.json`](feature_list.json) — one entry per user-story phase below

Use this template in the **Implementation Plan** stage, after `implementation-plan.md`.
Sliced lane only (the single lane has no `tasks.md`). Group tasks by user story so each story is implemented, tested, and accepted as
an independent slice. `feature_list.json`
remains the machine-readable slice contract (status, `passes`, `platform_validation`,
`production_journey`, evidence); this file is the human-readable work breakdown, and
`test-plan.md` defines each story's acceptance tests. The analyze gate checks that they agree.

## Format

`- [ ] T### [P?] [US-n?] <Description> in <exact/file/path.kt>`

- `T###` — sequential task ID in execution order; never renumber after approval.
- `[P]` — may run in parallel: different files and no dependency on an unfinished task.
- `[US-n]` — the owning user story; Setup, Foundational, and Polish tasks carry none.
- Every task names the exact file(s) it touches.
- Implementation precedes tests within a story (harness feature delivery is
  implementation-first; bug-fixing adds its RED reproduction task in Foundational).

---

## Phase 1 — Setup

- [ ] T001 <shared configuration, dependency, or resource> in `<path>`

## Phase 2 — Foundational *(blocking prerequisites for every story)*

- [ ] T002 <entity, migration, DI binding, contract update> in `<path>`
- [ ] T003 [P] <independent prerequisite> in `<path>`

**Checkpoint**: foundation compiles (`./gradlew assembleDebug`); story work can begin.

---

## Phase 3 — US-1: <Brief title> (Priority: P1) 🎯 MVP

**Slice**: `US-1` in `feature_list.json`
**Requirements**: `<capability>.md#FR-###`, `AC-###`, `AC-###`
**Independent Test**: <how this story alone is verified>
**Acceptance tests**: `TC-US-1-01`, `TC-US-1-02` (defined in `test-plan.md` → `### US-1`)

### Implementation

- [ ] T004 [P] [US-1] <domain use case> in `app/src/main/java/.../<UseCase>.kt`
- [ ] T005 [US-1] <ViewModel state and events> in `app/src/main/java/.../<Feature>ViewModel.kt`
- [ ] T006 [US-1] <Composable, strings, testTags> in `app/src/main/java/.../<Feature>Screen.kt`

### Tests

- [ ] T007 [P] [US-1] <ViewModel unit test> in `app/src/test/java/.../<Feature>ViewModelTest.kt`
- [ ] T008 [US-1] <integration or instrumented boundary test> in `app/src/.../<Feature>IntegrationTest.kt`

**Checkpoint**: US-1 acceptance tests pass with non-zero executed counts; the slice is
independently demonstrable.

---

## Phase 4 — US-2: <Brief title> (Priority: P2)

**Slice**: `US-2` in `feature_list.json`
**Requirements**: `<capability>.md#FR-###`, `AC-###`
**Independent Test**: <…>
**Acceptance tests**: `TC-US-2-01` (defined in `test-plan.md` → `### US-2`)

### Implementation

- [ ] T009 [US-2] <…> in `<path>`

### Tests

- [ ] T010 [US-2] <…> in `<path>`

**Checkpoint**: US-1 and US-2 both pass independently.

---

[Add a phase per further user story, in priority order.]

## Phase N — Polish & Cross-Cutting

- [ ] T0## Code quality: `ktlintCheck`, `detekt`, `lintDebug`, custom checks exit 0
- [ ] T0## Product Document Update: reconcile the feature block into `## Requirements` in place; record `## Product Requirement Reconciliation` in `summary.md`
- [ ] T0## Install the debug build when required (`./gradlew installDebug`)

## Dependencies & Execution Order

- Setup → Foundational → user stories in priority order → Polish.
- <story-to-story dependencies, or "Stories are independent after Foundational">
- Within a story: domain/data → presentation → UI → tests.

## Parallel Opportunities

- <task IDs that may run together, e.g. "T003 with T002; T004 and T007 within US-1">
