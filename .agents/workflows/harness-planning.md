---
description: You are a senior Android developer clarifying requirements and planning a complex feature by breaking it into deliverable vertical slices — harness-planning workflow.
---

# Workflow: Harness Planning

## When to use
- A feature is complex enough to touch multiple areas of the codebase.
- The requirement is large and needs to be scoped and broken down into smaller, independently deliverable features before implementation begins.
- You want to define the feature order, verification steps, and scope boundaries **before** implementation.
- The user has a broad product idea (new screen, enhancement, or logic change) that needs clarification before slicing.

---

## Core Principle

Do not guess at scope. Clarify requirements first, decompose into structured features second, and implement later.
Every open question must be answered and approved by the user before slice planning begins.
Each planned feature in the list must represent a clean, end-to-end user-visible behavior with specific verification steps.

## Feature Workspace

At the start of planning, create one dated feature workspace:

```text
docs/product/<YYYY-MM-DD>-<feature-short-name>/
```

Use lowercase kebab case for `<feature-short-name>` and the local planning date for the prefix. This stable directory is the source of truth for every complex-feature artifact throughout planning, implementation, and completion. Do not use `docs/current/` for harness artifacts; it remains reserved for ad-hoc workflows.

Immediately add a row to the **Harness Feature Tracker** in `docs/product/product.md` using a stable lowercase-kebab-case ID, status `Planning`, and a link labelled with the exact `docs/product/` workspace. Run `bash harness/scripts/check-feature-lifecycle.sh` after creating or changing the row. The controlled lifecycle is `Planning` → `Awaiting specification approval` → `Awaiting implementation approval` → `In Progress` / `Blocked` → `Complete`.

Workspace location never represents lifecycle status. Planning must never create a second lifecycle file or infer active work by scanning directories.

---

## Stage Execution

### Stage 1 — Clarify & Specify ⛔ STOP FOR APPROVAL
**INVOKE** the `feature-specification` skill via the Skill tool (name: `feature-specification`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Objective:
- Classify the task type (new screen, enhancement, or logic-only change).
- Ask targeted clarifying questions in chat until every material ambiguity is resolved.
- Create `FEATURE_DIR=docs/product/<YYYY-MM-DD>-<feature-short-name>` before writing artifacts.
- Write `$FEATURE_DIR/spec.md` (always) and `$FEATURE_DIR/design.md` (for new screens or UI enhancements/flows).
- For UI work, read `docs/product/design_system.md` before design decisions, link it from `$FEATURE_DIR/design.md`, and record every explicit user-approved exception. Generated mockups must use its exact applicable tokens and component patterns.

Output: `$FEATURE_DIR/spec.md` + `$FEATURE_DIR/design.md` + `$FEATURE_DIR/design/mockup_*.png` visual mockup images (user-provided or AI-generated, if the change includes UI modifications). If a bottom sheet contains a textbox, text field, search field, or other text input, `design.md` must also define the keyboard-visible state and reference a distinct keyboard-visible mockup asset alongside the base mockup.
Gate: Update the tracker status to `Awaiting specification approval`, then run `bash harness/scripts/check-stage-artifacts.sh harness-planning feature-specification "$FEATURE_DIR"` — it validates stage artifacts, lifecycle state, and the keyboard-visible mockup contract and must exit 0. For UI work, also verify `design.md` cites `docs/product/design_system.md`. **STOP — present specification, design document, and visual mockup images to user for review. Do not proceed until user explicitly approves.**

### Stage 2 — Slice Planning ⛔ STOP FOR APPROVAL
**INVOKE** the `slice-planning` skill via the Skill tool (name: `slice-planning`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
Input: `$FEATURE_DIR/spec.md` (+ `$FEATURE_DIR/design.md` if present)
Output: `$FEATURE_DIR/feature_list.json`, `$FEATURE_DIR/progress.md`, `$FEATURE_DIR/sprint-contract.md`, and `$FEATURE_DIR/platform-capability-matrix.md`.
The feature list MUST include a root `platform_validation` object. For platform-bound work set `required: true`, `unsupported_environment_policy: "fail_loudly"`, and declare at least one real instrumented boundary test. For work with no Android/device/platform boundary, set `required: false`, provide a reason, and still create the matrix artifact with an explicit N/A statement.
Gate: Update the tracker status to `Awaiting implementation approval`, then run `bash harness/scripts/check-stage-artifacts.sh harness-planning slice-planning "$FEATURE_DIR"` and `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --planning` — both validate the artifacts and must exit 0. **STOP — present `feature_list.json`, `sprint-contract.md`, and `platform-capability-matrix.md` to user. Do not proceed until user explicitly approves the task breakdown, platform contract, and sprint contract.**

---

## Human-in-the-Loop Confirmation Points

1. **After Clarify & Specify** — User approves `spec.md` (and `design.md` if produced). All questions are answered, no open assumptions remain.
2. **After Slice Planning** — User approves the sliced features list, priorities, and `sprint-contract.md` before any implementation work begins.
