---
description: Plan a complex Android feature into approved vertical slices and sprint-contract artifacts.
---

# Workflow: Harness Planning

Read and follow [Product documentation flow](../rules/product-documentation.md). Load affected living capability requirements before scoping or reviewing this change. Dated complex-change contracts and evidence belong under `.scratch/`.

## When to use
- A feature is complex enough to touch multiple areas of the codebase.
- The requirement is large and needs to be scoped and broken down into smaller, independently deliverable features before implementation begins.
- You want to define the feature order, verification steps, and scope boundaries **before** implementation.
- The user has a broad product idea (new screen, enhancement, or logic change) that needs clarification before slicing.

---

## Core Principle

Do not guess at scope. Clarify and approve requirements, complete and approve UX design for UI
scope, then decompose into structured features and implement later.
Every open question must be answered and approved by the user before slice planning begins.
Each planned feature in the list must represent a clean, end-to-end user-visible behavior with specific verification steps.

## Feature Workspace

At the start of planning, create one dated feature workspace:

```text
.scratch/<YYYY-MM-DD>-<feature-short-name>/
```

Use lowercase kebab case for `<feature-short-name>` and the local planning date for the prefix. This stable directory retains the approved change contract and delivery evidence throughout planning, implementation, and completion. Product behavior is maintained in the linked living capability requirements. Do not use `docs/current/` for harness artifacts; it remains reserved for ad-hoc workflows.

Immediately add a row to the **Harness Feature Tracker** in `docs/product/product.md` using a stable lowercase-kebab-case ID, status `Planning`, and a link labelled with the exact `.scratch/` workspace. Run `bash harness/scripts/check-feature-lifecycle.sh` after creating or changing the row. The controlled lifecycle is `Planning` → `Awaiting specification approval` → `Awaiting implementation approval` → `In Progress` / `Blocked` → `Complete`.

Workspace location never represents lifecycle status. Planning must never create a second lifecycle file or infer active work by scanning directories.

---

## Stage Execution

### Stage 1 — Clarify & Specify ⛔ STOP FOR APPROVAL
**INVOKE** the `feature-specification` skill via the Skill tool (name: `feature-specification`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Objective:
Record the complete Rule Applicability matrix in the feature specification; every row
needs a supported decision, trigger or rationale, and planned evidence before slicing.
- Classify the task type (new screen, enhancement, or logic-only change).
- Ask targeted clarifying questions in chat until every material ambiguity is resolved.
- Create `FEATURE_DIR=.scratch/<YYYY-MM-DD>-<feature-short-name>` before writing artifacts.
- Write `$FEATURE_DIR/spec.md` with behavior, scope, data, navigation, acceptance criteria, and
  the required screen/state inventory. Preserve supplied visual inputs for Stage 2. Do not
  generate layouts, `design.md`, or mockups inside feature specification.

Output: `$FEATURE_DIR/spec.md` only, plus preserved user inputs when supplied.
Gate: Update the tracker status to `Awaiting specification approval`, then run
`bash harness/scripts/check-stage-artifacts.sh harness-planning feature-specification "$FEATURE_DIR"`.
The gate validates the requirements and lifecycle; it requires no visual artifacts.
**STOP — present the clarified specification for explicit user approval before UX begins.**

### Stage 2 — UX Design ⛔ STOP FOR DESIGN APPROVAL
For new screens or UI enhancements, **INVOKE** `ux-design` through the available skill mechanism.
If the Skill tool is unavailable, read its repository `SKILL.md` and record that once in evidence.
Input: the approved `$FEATURE_DIR/spec.md`, supplied visual inputs, and `docs/product/design_system.md`.
Logic-only scope records UX Design N/A and proceeds to Stage 3.

Output: `$FEATURE_DIR/design.md`, `$FEATURE_DIR/visual_evidence/visual-target.json`, the canonical
Pen reference when generated, and verified `$FEATURE_DIR/design/mockup_*.png` review exports.
The UX skill owns the state designs, design-system decisions, keyboard states, and deterministic
Roborazzi comparison scopes. It invokes `pen-design-editor` for missing visual references.
Do not create or require an implementation screenshot baseline during planning.

Gate: run `bash harness/scripts/check-stage-artifacts.sh harness-planning ux-design "$FEATURE_DIR"`.
**STOP — present the design and verified references for explicit user approval before slicing.**
Retain the existing `Awaiting specification approval` tracker status through this separate UX
review; no lifecycle status is added. After approval, apply the Pen skill's finalization contract.

During visual iteration, update only design artifacts. Keep `spec.md` stable unless behavior,
scope, data, navigation, or the required state inventory changes. Such changes return to Stage 1
for clarification and approval before UX resumes. Record stage completion, approval, or a blocker
once in the existing progress/summary record; do not rewrite it for every design edit.

### Stage 3 — Slice Planning ⛔ STOP FOR APPROVAL
**INVOKE** the `slice-planning` skill via the Skill tool (name: `slice-planning`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
Input: approved `$FEATURE_DIR/spec.md` and approved `$FEATURE_DIR/design.md` for UI scope.
Output: `$FEATURE_DIR/feature_list.json`, `$FEATURE_DIR/progress.md`, and `$FEATURE_DIR/sprint-contract.md` — plus `$FEATURE_DIR/platform-capability-matrix.md` only when the feature is platform-bound (`platform_validation.required: true`). Each feature entry must also contain a `production_journey` classification mirrored by the sprint contract's Production Journey Planning Contract. Artifact requirements — including the root `platform_validation` contract, production-journey ownership, and the platform capability matrix — are defined in the `slice-planning` skill's Output section.
Gate: Update the tracker status to `Awaiting implementation approval`, then run `bash harness/scripts/check-stage-artifacts.sh harness-planning slice-planning "$FEATURE_DIR"` and `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --planning` — both validate the artifacts and must exit 0. The slice-planning gate runs `bash harness/scripts/check-journey-planning-contract.sh "$FEATURE_DIR"`; it fails when navigation/lifecycle signals are only covered by a JVM or Content-only row, when `NAV` is required without a journey owner, or when a required journey lacks a production entry point, real actions, return boundary, or visible post-return assertion. **STOP — present `feature_list.json` and `sprint-contract.md` to user (plus `platform-capability-matrix.md` when platform-bound). Do not proceed until user explicitly approves the task breakdown, platform contract, journey ownership, and sprint contract.**

---

## Human-in-the-Loop Confirmation Points

1. **After Clarify & Specify** — User approves `spec.md`; all material product questions are answered.
2. **After UX Design** — User approves `design.md` and the references for UI scope.
3. **After Slice Planning** — User approves the sliced features list, priorities, and `sprint-contract.md` before any implementation work begins.
