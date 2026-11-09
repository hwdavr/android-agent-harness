---
name: feature-specification
description: Specify and clarify a feature or enhancement (Spec Kit /specify + /clarify) by writing an approved feature block into the living requirement file, and set up its dated workspace.
---

# Skill — Feature Specification (Specify + Clarify)

Follow `.agents/rules/product-documentation.md`. The living capability file in
`docs/product/requirements/` **is** the specification: this skill writes the change as a feature
block under its `## Planned changes`. The dated workspace holds plans and evidence, never a spec.

## Purpose

Turn a request into an approved, unambiguous feature block, and decide the delivery lane:

- **single lane** — one deliverable change; the block has no user stories.
- **sliced lane** — two or more independently deliverable, independently testable stories.

Describe WHAT and WHY only. Do not choose libraries, classes, or files; do not write code; do not
plan slices or tasks; do not invent product decisions; do not create visual designs (UX Design
owns `UI_contract.md` and the Pen design).

## Load

- L1 rules (skip if already loaded this session).
- `harness/templates/requirement-delta-template.md` — the block format and writing guidelines.
- `docs/product/requirements/README.md`, then every affected capability file **in full**.
- `harness/templates/product-requirements-template.md` only when no capability file fits.
- For a bug that restores already-specified behavior, stop: use the `bug-fixing` workflow instead.

## Execute

### 1. Capture the request

Record the user's words verbatim for the block's **Input** line. Preserve concrete anchors: named
screens, entry points, roles, copy, non-goals. Save supplied screenshots or mockups unchanged under
`<workspace>/design/` for UX Design.

### 2. Locate the capability and set up the workspace

- Pick the affected capability file(s). A new capability gets a new file from
  `product-requirements-template.md` and an entry in `requirements/README.md`.
- Choose a lowercase kebab-case `<feature-id>`. Create `.scratch/<YYYY-MM-DD>-<feature-id>/`
  (local date) with `summary.md` from `harness/templates/summary-template.md` and the
  `feature-delivery` stage profile.
- Add the Harness Feature Tracker row in `docs/product/product.md` (status `Planning`, link label
  = the workspace path) and run `bash harness/scripts/check-feature-lifecycle.sh`.

### 3. Specify — draft the block

Copy the block from `requirement-delta-template.md` under `## Planned changes` of each affected
file, between the exact `<!-- feature: <feature-id> -->` markers.

- Continue the file's `FR-###`, `AC-###`, `SC-###` sequences; never reuse an ID. Mark each
  requirement `New`, `Changes FR-###`, or `Retires FR-###`. Leave delivered requirements under
  `## Requirements` untouched until Product Document Update.
- One `AC-###` per outcome the requirement promises: happy path plus each fallback, error,
  boundary, and compatibility outcome.
- UI scope: add **Screen States** (every visually distinct screen/state, including empty,
  loading, error, selected, disabled, overlay, and keyboard-open variants) and **Navigation**
  when routes or the back stack change.
- **Lane**: write `#### User Scenarios` only when the change splits into two or more
  independently deliverable stories (sliced lane), each listing its `FR-###`. Otherwise omit the
  section (single lane). Never split or merge stories to steer the lane.
- Mark every unresolved product decision inline as `[NEEDS CLARIFICATION: <question>]`. Make an
  informed guess only for low-impact defaults, and list it under Assumptions.

### 4. Clarify — resolve the markers

Ask at most five questions per round, the highest-impact first (scope, security/privacy, user
experience, then technical defaults). For each question offer a recommended answer and two to four
concrete options. After each answer:

- record it under `#### Clarifications` → `##### Session <YYYY-MM-DD>` as `- Q: … → A: …`;
- update the affected `FR-###`/`AC-###` text immediately and remove the marker.

Repeat until no `[NEEDS CLARIFICATION` remains and every Review & Acceptance Checklist item holds.
Set **Status** to `Clarified`.

### 5. Gate

```bash
bash harness/scripts/check-stage-artifacts.sh feature-delivery specify .scratch/<YYYY-MM-DD>-<feature-id>
```

Record the stage in `summary.md` with the block location and a one-line excerpt.

## Approval

- **Sliced lane**: present the block now. On explicit approval set **Status** to
  `Approved — <user>, <YYYY-MM-DD>` and the tracker to `Awaiting specification approval` → UX
  Design (UI) or Implementation Plan.
- **Single lane**: do not stop here. The block is approved together with the design and both
  plans in one review at the end of the Implementation Plan stage.

After approval the block is frozen: `implementation-plan.md` records its SHA-256, and any later edit
returns to this skill for re-approval.

## Done When

- [ ] The block sits between exact markers under `## Planned changes` in every affected file.
- [ ] No `[NEEDS CLARIFICATION]` remains; the Clarifications log records every answer.
- [ ] IDs continue each file's sequence; every outcome has its own `AC-###`.
- [ ] UI scope has Screen States (and Navigation when routes change).
- [ ] The lane is decided: no user stories (single) or two or more (sliced).
- [ ] Workspace, `summary.md`, and tracker row exist; the `specify` gate exits 0.
