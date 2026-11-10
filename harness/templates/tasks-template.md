# Tasks — <Feature Name>

**Feature ID**: `<feature-id>`
**Input**: [`implementation-plan.md`](implementation-plan.md), the approved feature block(s) in `docs/product/requirements/`
**Slices**: [`feature_list.json`](feature_list.json) — one entry per slice below, each listing its tasks

Use this template in the **Implementation Plan** stage, after `implementation-plan.md`.
Sliced lane only (the single lane has no `tasks.md`). One user story = one slice: each slice is
implemented, tested, and accepted independently. Every task belongs to exactly one slice, so
nothing is left outside the slice that must finish it.

`feature_list.json` is the machine-readable slice contract (status, evidence, journey, and each
slice's `tasks`); this file is the human-readable breakdown; `test-plan.md` defines each slice's
acceptance tests. The analyze gate checks that all three agree.

## Format

`- [ ] T### [P?] [US-n] <Description> in <exact/file/path.kt>`

- `T###` — sequential task ID in execution order; never renumber after approval.
- `[P]` — may run in parallel: different files and no dependency on an unfinished task.
- `[US-n]` — the owning slice. **Every task carries one**, including prerequisites and final checks.
- Every task names the exact file(s) it touches.
- Implementation precedes tests within a slice (harness delivery is implementation-first;
  bug-fixing adds its RED reproduction task under Prerequisites).
- The same task appears in the slice's `tasks` array in `feature_list.json` as
  `{"id": "T001", "title": "...", "file": "...", "done": false}`. Mark it `done: true` there and
  tick the checkbox here when the task is finished; the two must agree.

## Slices

| Slice | Delivers (what the user can do) | Requirements | Tasks | Depends on | Acceptance tests |
|---|---|---|---|---|---|
| US-1 | <observable delta through an existing entry point> | `<capability>.md#FR-###`, `AC-###` | T001–T008 | none | `TC-US-1-01`, `TC-US-1-02` |
| US-2 | <…> | `<capability>.md#FR-###`, `AC-###` | T009–T012 | US-1 | `TC-US-2-01` |
| US-3 | <…> | `<capability>.md#FR-###`, `AC-###` | T013–T016 | US-2 | `TC-US-3-01` |

The Tasks column lists **every** task of the slice (ranges or comma lists). The first slice
includes the shared prerequisites; the last slice includes the final checks.

---

## US-1: <Brief title> (Priority: P1) 🎯 MVP

**Slice**: `US-1` in `feature_list.json`
**Requirements**: `<capability>.md#FR-###`, `AC-###`, `AC-###`
**Independent Test**: <how this slice alone is verified>
**Acceptance tests**: `TC-US-1-01`, `TC-US-1-02` (defined in `test-plan.md` → `### US-1`)

### Prerequisites *(first slice only — shared setup every later slice relies on)*

- [ ] T001 [US-1] <shared configuration, dependency, or resource> in `<path>`
- [ ] T002 [US-1] <entity, migration, DI binding, contract update> in `<path>`
- [ ] T003 [P] [US-1] <independent prerequisite> in `<path>`

### Implementation

- [ ] T004 [P] [US-1] <domain use case> in `app/src/main/java/.../<UseCase>.kt`
- [ ] T005 [US-1] <ViewModel state and events> in `app/src/main/java/.../<Feature>ViewModel.kt`
- [ ] T006 [US-1] <Composable, strings, testTags> in `app/src/main/java/.../<Feature>Screen.kt`

### Tests

- [ ] T007 [P] [US-1] <ViewModel unit test> in `app/src/test/java/.../<Feature>ViewModelTest.kt`
- [ ] T008 [US-1] <integration or instrumented boundary test> in `app/src/.../<Feature>IntegrationTest.kt`

**Checkpoint**: the app builds (`./gradlew assembleDebug`), all US-1 tasks are done, and the US-1
acceptance tests pass with non-zero executed counts; the slice is independently demonstrable.

---

## US-2: <Brief title> (Priority: P2)

**Slice**: `US-2` in `feature_list.json`
**Requirements**: `<capability>.md#FR-###`, `AC-###`
**Independent Test**: <…>
**Acceptance tests**: `TC-US-2-01` (defined in `test-plan.md` → `### US-2`)

### Implementation

- [ ] T009 [US-2] <…> in `<path>`

### Tests

- [ ] T010 [US-2] <…> in `<path>`

**Checkpoint**: all US-2 tasks are done and US-1 and US-2 both pass independently.

---

[Add a section per further user story, in priority order. The last one ends with Final checks.]

## US-3: <Brief title> (Priority: P3)

**Slice**: `US-3` in `feature_list.json`
**Requirements**: `<capability>.md#FR-###`, `AC-###`
**Independent Test**: <…>
**Acceptance tests**: `TC-US-3-01` (defined in `test-plan.md` → `### US-3`)

### Implementation

- [ ] T013 [US-3] <…> in `<path>`

### Tests

- [ ] T014 [US-3] <…> in `<path>`

### Final checks *(last slice only)*

- [ ] T015 [US-3] Code quality: `ktlintCheck`, `detekt`, `lintDebug`, custom checks exit 0
- [ ] T016 [US-3] Product Document Update: reconcile the feature block into `## Requirements` in place; record `## Product Requirement Reconciliation` in `summary.md`
- [ ] T017 [US-3] Install the debug build when required (`./gradlew installDebug`)

**Checkpoint**: all US-3 tasks are done and every slice passes independently.

## Dependencies & Execution Order

- Slices run in priority order; the **Depends on** column above records any other order.
- <slice-to-slice dependencies, or "Slices are independent after US-1">
- Within a slice: Prerequisites → domain/data → presentation → UI → tests → Final checks.

## Parallel Opportunities

- <task IDs that may run together, e.g. "T003 with T002; T004 and T007 within US-1">
