---
name: implementation-plan
description: Plan an approved or clarified change (Spec Kit /plan + /tasks + /analyze): implementation-plan.md and test-plan.md, plus tasks.md and feature_list.json in the sliced lane; stop for approval.
---

# Skill — Implementation Plan (Plan + Tasks + Analyze)

## Purpose

Produce a reviewable plan before any code is written, in the dated workspace
`.scratch/<YYYY-MM-DD>-<feature-id>/`:

| Artifact | Single lane | Sliced lane |
|---|---|---|
| `implementation-plan.md` — HOW the code changes; canonical Rule Applicability | ✓ | ✓ |
| `test-plan.md` — every test concern | ✓ (flat acceptance table) | ✓ (per-story tables, coverage matrix, journey contract) |
| `tasks.md` — ordered work per story | — | ✓ |
| `feature_list.json` — slice contract for the generator | — | ✓ |

The lane is fixed by the feature block: no user stories → single; two or more → sliced.

## Load

- `harness/templates/implementation-plan-template.md`, `harness/templates/test-plan-template.md`,
  and — sliced lane only — `harness/templates/tasks-template.md`,
  `harness/templates/feature_list_template.json`.
- `harness/templates/rule-applicability-template.md` (decision vocabulary and triggers).
- The feature block(s) in `docs/product/requirements/`, or for a bug the plan's Root Cause and the
  test plan's Reproduction Test. For UI scope, the approved `UI_contract.md`, its Pen references,
  and the design-system Component Registry.
- `rules/testing-practices.md`. Load a conditional rule only when its row is `Required`, excepted,
  or newly triggered; `rules/testing-runtime-evidence.md` only for platform, instrumented,
  journey, or UI claims; `rules/android-security.md` when SEC is Required or excepted.

## Execute

### 1. Implementation plan — `implementation-plan.md`

Follow the template exactly. In particular:

- **Product Requirements**: one row per capability file with the block ID; leave the SHA-256
  column `<64 hex characters>` until approval. A bug restoring existing behavior writes
  `none — restores <capability>.md#FR-###`.
- **Rule Applicability** is the rules gate: decide all ten rows before Phase 0 and re-check them
  after Phase 1. A deviation is an `Exception — approved by <user/date>` row stating its boundary.
  Do not add analytics events or logs only because a row exists.
- **Phase 0** resolves every `NEEDS RESEARCH` unknown (decision, rationale, alternatives).
- **Phase 1**: Project Structure (every file created, modified, deleted — the UI row lists the
  screen files), data model and migrations, API contract changes against
  `sharedContracts/openapi.yaml`, UiState, and for UI scope **UI State Stages**: one row per
  `UI_contract.md` Plan stage ID naming the registered components it reuses. A needed component
  that is not registered is added to the design-system Component Registry with approval first.
- No test material in this file.

### 2. Test plan — `test-plan.md`

Follow the template exactly. Classify each verification item as maintained regression or
ephemeral exploration first; temporary WireMock/device exploration belongs to `exploratory-qa`
with `agent-device`, never to an `androidTest` class or CI dependency. The plan holds planned
procedures only — results go to the summary.

- **Rule Applicability Test Mapping** links `implementation-plan.md#rule-applicability` and maps
  every `Required` row to tests, checks, or review evidence.
- **Acceptance Test Cases**: exactly one primary automated test per `AC-###`; a fallback, error,
  boundary, or compatibility outcome gets its own AC and test. Single lane: one flat table
  (`TC-01`…). Sliced lane: a `### US-n` subsection per story (`TC-US-n-01`…). Every row names the
  layer, the real test file and method, shared scenario (`sharedContracts/test-scenarios/…` or
  `N/A — no API`), assertions, and an exact scoped command.
- Each affected API endpoint has at least one integration test using a shared JSON scenario.
- **NAV Required**: declare the real instrumented journey in `## Production Journey Boundary`.
- **UI scope**: `## UI State Verification` — one review-capture method (rendered at the state's
  Viewport, i.e. the Pen frame size and density) and one structural-check method per UI state.
  No screenshot golden, `TC-*-VIS` row, or Roborazzi verify/record command.
- **Sliced lane only**: the Spec Coverage Matrix (every `FR-###`, `AC-###`, `SC-###` → story →
  primary test, or `Out of scope — <reason>`), and the Production Journey Planning Contract with
  one row per story (Yes when any AC crosses a destination, back stack, saved state, recreation,
  or post-return persistence boundary; `NAV: Required` needs at least one Yes).

### 3. Sliced lane only — `tasks.md` and `feature_list.json`

- **Vertical slices**: each story must pass the test "After this slice ships alone, a user can
  observe <delta> through the existing entry point <screen or action already in the app>."
  Merge any horizontal slice into the story that first makes it user-visible. Order by priority;
  put the riskiest foundation first only when it is itself vertical.
- `tasks.md`: a `## Slices` overview table (what each slice delivers, requirements, task IDs, depends
  on, acceptance tests), then one `## US-n:` section per slice (`**Slice**: \`US-n\``, its
  acceptance test IDs) with `### Implementation` and `### Tests`. Every task is
  `T### [P] [US-n] description in exact/path.kt` and belongs to exactly one slice. Shared setup goes
  under `### Prerequisites` in the **first** slice only; the closing quality, product-doc, and
  install tasks go under `### Final checks` in the **last** slice only. There are no separate phases.
- `feature_list.json`: one entry per story with `id` = `US-n`, `priority`, `area`, `title`,
  `description` (execution directions, not the story text), `ui_design`, `user_visible_behavior`,
  `affects_ui`, `requires_visual_verification` (true only for the final UI slice, which owns the
  conformance review), `production_journey` (mirrors the journey contract), `status`
  `not_started`, `acceptance_test_ids` (exactly that story's TC IDs), `verification`,
  `evidence: []`, `notes`, and `tasks` (`{id, title, file, done}` for every task of that slice —
  the same T### set as its `tasks.md` section; use `done`, never `status`). The root declares `platform_validation`
  (`required`, `unsupported_environment_policy: "fail_loudly"`, and a reason or capability
  matrix). Platform-bound work adds `platform-capability-matrix.md`.

### 4. Analyze

```bash
bash harness/scripts/check-stage-artifacts.sh harness-planning analyze .scratch/<YYYY-MM-DD>-<feature-id>
```

(`bug-fixing analyze` for bugs.) Fix every inconsistency at its source: a requirement gap returns to
`feature-specification`; a design gap returns to UX Design; plan and test gaps are fixed here.
Record the stage in `summary.md`.

## Approval — ⛔ MANDATORY STOP

Present the package and wait for explicit approval. Do not create or edit source files before it.

- **Single lane**: one review covers the feature block, the design (UI scope), and both plans.
- **Sliced lane**: the block was approved earlier; this review covers both plans, `tasks.md`,
  `feature_list.json`, journey ownership, and the platform contract.

Feedback routing: visual feedback → UX Design (design artifacts only); behavior, scope, data,
navigation, or state-inventory changes → `feature-specification`; plan-only feedback stays here.

On approval:

1. Set the block **Status** to `Approved — <user>, <YYYY-MM-DD>` (single lane) and record each
   block's SHA-256 (text between the markers) in Product Requirements; set the plan **Status**.
2. Move the tracker and run `bash harness/scripts/check-feature-lifecycle.sh`:
   - **Single lane**: `In Progress` — this session continues to Implementation.
   - **Sliced lane**: `Awaiting implementation approval`, then stop. The generator picks up the
     row, moves it to `In Progress`, and starts the first `not_started` slice. Do not set
     `In Progress` yourself.
3. Run the post-approval gate:
   `bash harness/scripts/check-stage-artifacts.sh <workflow> implementation-plan .scratch/<YYYY-MM-DD>-<feature-id>`.

**APPROVED →** single lane continues to Implementation. Sliced lane ends the session: tell the user
to start the generator (`bash harness/scripts/<agent>-harness-generator.sh`, the scheduled
launcher, or "Read `.agents/workflows/sliced-lane-generator.md`").
