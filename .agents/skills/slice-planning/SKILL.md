---
name: slice-planning
description: Decomposes requirements into vertical slices and schedules a Sprint Contract.
---

# Skill — Slice Planning

## Purpose

Decompose a complex requirement into independently deliverable vertical slices before any code is written.
Each slice must be end-to-end (Data → Domain → UI → Tests) and leave the codebase in a working, shippable state.

This stage only applies when the feature touches **more than one logical area** or **more than ~3 files**.
For trivially small changes, skip this stage and go directly to the Implementation Plan stage.

---

## Load

- `skills/incremental-implementation/SKILL.md`
- `harness/templates/feature_list_template.json`
- `harness/templates/progress-template.md`
- `harness/templates/sprint-contract-template.md`
- **Requirement input** — read the path from the active workflow's `Input:` line:
  - harness-planning workflow → `$FEATURE_DIR/spec.md` (+ `$FEATURE_DIR/design.md` if present)
  - Other workflows → `docs/current/spec_v<N>.md`

---

## Execute

### 1. Assess Complexity

Read the complete requirement input document (path defined by the calling workflow), including every Functional Requirement, Acceptance Criterion, edge case, scope boundary, data/persistence requirement, verification expectation, and applicable design requirement. Do not rely on a summary, a previous plan, or only the user stories.

Create a **Spec Coverage Matrix** before defining slices. Every `FR-*` and `AC-*` in the spec must map to exactly one primary user story and acceptance-test ID; explicitly map edge cases, non-functional constraints, and design requirements to a user story or mark them `out_of_scope` with the approved reason. Do not omit a requirement because it appears foundational, duplicated, or non-user-visible.

Then answer:
- How many distinct areas of the codebase are touched?
- Is there a natural dependency order (e.g. DB schema must exist before the ViewModel can query it)?
- Which part carries the highest technical risk or most uncertainty?

### 2. Compile Sprint Contract

Decompose the high-level requirement into a detailed scope, acceptance criteria, and verification plan. Strictly follow the structure in `harness/templates/sprint-contract-template.md` to generate `sprint-contract.md`. Fill in the Sprint Overview (Sprint ID, Feature Name, Duration), Scope (In Scope, Out of Scope), the **Spec Coverage Matrix**, and User Scenarios & Testing (user stories with acceptance criteria and acceptance test cases).

The Spec Coverage Matrix is mandatory. It must include the source requirement ID, concise requirement text, primary user-story ID, acceptance-test ID, and handling. A requirement may map to multiple secondary tests, but it must have exactly one primary owner. Preserve the source requirement ID verbatim so the planning gate can verify coverage.

For every acceptance criterion, define a uniquely identified acceptance test case in the contract. Each row must name the test layer, proposed test file and method, fixture/action, observable assertions, and exact Gradle command. The test must invoke the production entry point for the user story; an isolated helper/use-case test cannot be the sole proof of an end-to-end or user-visible criterion.

**Each user story MUST have a unique ID** (e.g. `US-1`, `US-2`, `US-3`). This ID is the cross-reference key used in `feature_list.json` to enforce a 1:1 mapping between user stories and feature slices.

### 3. Choose a Slicing Strategy

**Strongly Prefer Vertical Slices**: Always default to the **Vertical Slices** strategy to ensure that each slice delivers an end-to-end, testable user value and leaves the codebase in a clean, shippable state. 

**Calibrate Granularity**: Each feature item should be scoped to "completable in one session." Too broad and it won't finish; too narrow and the management overhead grows.
- *Good granularity*: "User can add items to cart"
- *Too broad*: "Implement the shopping cart"
- *Too narrow*: "Create the name field on the Cart model"

### 4. Define Features inside `feature_list.json`

For each slice, you must populate the `features` list in the `feature_list.json` schema. Define each task completely, ensuring that each field is explained and adheres to the following definitions:

- **`id`**: The user story ID from the sprint contract (e.g. `US-1`, `US-2`). This directly links the feature to its sprint contract user story, enforcing a strict 1:1 mapping. **Each feature `id` MUST match exactly one user story heading in `sprint-contract.md`, and every user story MUST have a corresponding feature.**
- **`priority`**: Integer priority indicating delivery order (lower number = higher priority).
- **`area`**: The codebase component or feature area (e.g., `comments`, `folders`, `editor`).
- **`title`**: A short, readable title summarizing the slice.
- **`description`**: A comprehensive detailed instruction mapping the precise code-level logic, domain model changes, and database structures required. **This field specifically tells the generator agent exactly what to do** at a technical execution level.
- **`ui_design`**: A file path to a layout asset/mockup or a reference name from an external design tool (e.g. Figma or Pencil.dev) depicting the UI specifications for the feature.
- **`user_visible_behavior`**: A clear explanation of what observable UI elements, texts, behavior, or default flows are affected by this task.
- **`affects_ui`**: Boolean. `true` if the slice adds, removes, or modifies any Composable, screen layout, or visible UI state. It always triggers UI-focused automated acceptance testing and `android-code-review` SKILL.md §4 during harness-evaluation. It does not, by itself, require a screenshot gate. When `false`, the slice is treated as a non-UI change.
- **`requires_visual_verification`**: Boolean. Set this to `true` only for the final user story that makes the completed visual flow reachable and reviewable. Set it to `false` for intermediate UI slices, including a slice that changes Composables but has no standalone production entry point. A `true` owner MUST include the required `TC-US-*-VIS` rows and state-verifying screenshot commands; `false` slices require automated UI/integration proof for their acceptance criteria but no screenshot gate.
- **`status`**: The progress status (`not_started`, `in_progress`, `blocked`, or `passing`).
- **`verification`**: An array of specific, step-by-step proof required for that feature. A high-quality verification is defined as a set of instrumented tests or integration tests that can be executed directly in the shell to provide PASS or FAIL results. The visual-verification owner MUST also include every state-verifying screenshot command referenced by its `TC-US-*-VIS` Test IDs. A bare `adb exec-out screencap` command is not sufficient evidence because it can capture an unrelated screen.
- **`evidence`**: Terminal output, test reports, or screenshots verifying task completion.
- **`notes`**: Additional technical context or design considerations.

Each task must change **one logical thing** and do it completely, ensuring the codebase is never left in a broken or non-compiling state.

### 5. Validate 1:1 Cross-Reference

Before finalizing, verify the bidirectional mapping is complete:

1. **No orphan user stories**: Every `US-*` heading in `sprint-contract.md` must have a matching feature `id` in `feature_list.json`.
2. **No orphan features**: Every feature `id` in `feature_list.json` must match a `US-*` heading in `sprint-contract.md`.
3. **No duplicates**: Feature IDs are unique by definition — no two features may share the same `id`.
4. **No dropped spec requirements**: Every `FR-*` and `AC-*` in the source spec appears in the Spec Coverage Matrix and maps to a user story and primary acceptance-test ID, unless it is explicitly approved as out of scope with its reason.
5. **No invented scope**: Every planned capability, acceptance criterion, and verification requirement traces back to the source spec or an explicitly recorded user decision.
6. **`requires_visual_verification` ↔ `TC-US-*-VIS` consistency**: For every feature with `"requires_visual_verification": true`, the matching `US-*` user story in `sprint-contract.md` MUST contain the visual-state rows needed to assess the completed flow, and each row's state-verifying `Exact command` MUST appear verbatim in the feature's `verification` array. A feature with `"requires_visual_verification": false` MUST contain no `TC-US-*-VIS` row. `affects_ui` alone does not require a screenshot gate.
7. **One visual-verification owner**: If the planned feature contains UI changes, select exactly one final, user-reachable slice as the visual-verification owner. Its acceptance tests must navigate through the completed production flow before capturing. Do not attach screenshot rows to intermediate slices merely because they change a Composable.

If a user story is too large to fit into a single feature slice, **split the user story** in the sprint contract first, then create the corresponding feature. If a feature slice doesn't map to any user story, either the sprint contract is missing a story or the slice should be merged into another feature.

### 6. Order Tasks

Place the riskiest or most foundational slice first.
Express the dependency order explicitly (linear or branching).

---

## Output

Write the **feature list** following `harness/templates/feature_list_template.json`.
Write the **progress file** following `harness/templates/progress-template.md`.
Write the **sprint contract** following `harness/templates/sprint-contract-template.md`.

Output paths are defined by the calling workflow:
- **harness-planning workflow** → `$FEATURE_DIR/feature_list.json`, `$FEATURE_DIR/progress.md`, and `$FEATURE_DIR/sprint-contract.md`
- **Other workflows** → `docs/current/feature_list.json`, `docs/current/progress.md`, and `docs/current/sprint-contract.md`

Pre-populate the task list with all slices.
Set Feature 1 to `in_progress`, all others to `not_started`.

---

## Done When — ⛔ MANDATORY STOP

**Present the feature list to the user.**

The user must confirm:
- [ ] The slice boundaries make sense
- [ ] The dependency order is correct
- [ ] No feature is too large (completable in a single session)
- [ ] Feature descriptions are clear, instructing exactly what to do
- [ ] Verification steps are concrete, machine-executable shell commands (returning binary PASS/FAIL)
- [ ] The sprint-contract is compiled with explicit acceptance criteria and a corresponding verification plan
- [ ] Every AC has exactly one primary acceptance test case with an ID, test layer, test target, setup/action, observable assertions, and exact command
- [ ] Every cross-layer or user-visible AC has an integration or instrumented acceptance test that exercises the production entry point
- [ ] Every sprint contract user story maps to exactly one feature list item (1:1, no orphans on either side)
- [ ] Every source `FR-*` and `AC-*` appears in the Spec Coverage Matrix with a primary slice and acceptance-test owner
- [ ] All edge cases, non-functional constraints, verification expectations, and changed design requirements are either mapped to a slice or explicitly approved as out of scope

**APPROVED by user →** Return to the active workflow file and proceed to the next stage.
