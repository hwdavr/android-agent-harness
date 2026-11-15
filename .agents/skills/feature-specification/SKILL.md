---
name: feature-specification
description: Specify and clarify a feature or enhancement by writing intent.md, design.md, and specs/ requirement deltas in its dated change workspace.
---

# Skill — Feature Specification (Specify + Clarify)

Follow `.agents/rules/product-documentation.md`. The dated change workspace **is** the
specification of a change: `intent.md` (what and why), `design.md` (lane, stories, flow, screen
states), and one `specs/<capability>.md` requirement delta per affected capability. Living
capability files in `docs/product/requirements/` state delivered behavior only and are not edited
here; `archive-change.py` merges the deltas into them after delivery.

## Purpose

Turn a request into an approved, unambiguous change, and decide the delivery lane:

- **single lane** — one deliverable change; `design.md` has no user stories.
- **sliced lane** — two or more independently deliverable, independently testable stories.

Describe WHAT and WHY only. Do not choose libraries, classes, or files; do not write code; do not
plan slices or tasks; do not invent product decisions; do not create visual designs (UX Design
owns `UI_contract.md` and the Pen design).

## Load

- L1 rules (skip if already loaded this session).
- `harness/templates/intent-template.md`, `design-template.md`, and `spec-delta-template.md`.
- `docs/product/requirements/README.md`, then every affected capability file **in full**.
- `harness/templates/capability-spec-template.md` when a capability file must be converted.
- For a bug that restores already-specified behavior, stop: use the `bug-fixing` workflow instead.

## Execute

### 1. Capture the request

Record the user's words verbatim for the **Input** line of `intent.md`. Preserve concrete anchors:
named screens, entry points, roles, copy, non-goals. Save supplied screenshots or mockups unchanged
under `<workspace>/design/` for UX Design.

### 2. Set up the workspace

- Choose a lowercase kebab-case `<feature-id>`. Create `.scratch/<YYYY-MM-DD>-<feature-id>/`
  (local date) with `summary.md` from `harness/templates/summary-template.md` and the
  `harness-planning` stage profile.
- Add the Harness Feature Tracker row in `docs/product/product.md` (status `Planning`, link label
  = the workspace path) and run `bash harness/scripts/check-feature-lifecycle.sh`.

### 3. Capture intent — `intent.md`

Fill the template: Problem, Proposed Outcome with `SC-###` success criteria, Affected Users and
Systems with the capability table, Constraints (out of scope, assumptions), Open Questions.

### 4. Specify — `specs/<capability>.md`

Write one delta file per affected capability, named after the capability file.

- `## ADDED Requirements` continue the file's `FR-###` and `AC-###` sequences; never reuse an ID.
  `## MODIFIED Requirements` restate the whole requirement under its existing `FR-###`.
  `## REMOVED Requirements` give a `**Reason**:`.
- One `#### Scenario: AC-###` per outcome the requirement promises: happy path plus each
  fallback, error, boundary, and compatibility outcome.
- MODIFIED or REMOVED against a capability file that still uses a status table: first convert
  that file to `capability-spec-template.md` format without changing behavior, and say so.
- A new capability starts its delta with `# <Title>` and `**User goal**:`; do not create the
  living file.

### 5. Design — `design.md`

- **Lane**: write `## User Scenarios` only when the change splits into two or more independently
  deliverable stories (sliced lane), each listing its `<capability>.md#FR-###`. Otherwise omit
  the section (single lane). Never split or merge stories to steer the lane.
- UI scope: **Screen States** (every visually distinct screen/state, including empty, loading,
  error, selected, disabled, overlay, and keyboard-open variants) and **User Flow and Navigation**
  when routes or the back stack change.
- Record each product choice and its rejected alternatives under **Product Decisions**.

### 6. Clarify — resolve the open questions

Mark every unresolved product decision as `[NEEDS CLARIFICATION: <question>]`. Make an informed
guess only for low-impact defaults, and list it under Assumptions. Ask at most five questions per
round, the highest-impact first (scope, security/privacy, user experience, then technical
defaults). For each question offer a recommended answer and two to four concrete options. After
each answer:

- record it in `intent.md` under `## Clarifications` → `### Session <YYYY-MM-DD>` as `- Q: … → A: …`;
- update the affected requirement, scenario, or design text immediately and remove the marker.

Repeat until no `[NEEDS CLARIFICATION` remains and every Review Checklist item holds. Set the
`intent.md` **Status** to `Clarified`.

### 7. Gate

```bash
bash harness/scripts/check-stage-artifacts.sh harness-planning specify .scratch/<YYYY-MM-DD>-<feature-id>
```

Record the stage in `summary.md` with the delta file paths and a one-line excerpt.

## Approval

- **Sliced lane**: present `intent.md`, `design.md`, and `specs/` now. On explicit approval set
  the `intent.md` **Status** to `Approved — <user>, <YYYY-MM-DD>` and the tracker to
  `Awaiting specification approval` → UX Design (UI) or Implementation Plan.
- **Single lane**: do not stop here. The change is approved together with the visual design and
  both plans in one review at the end of the Implementation Plan stage.

After approval the three artifacts are frozen: `implementation-plan.md` records each SHA-256, and
any later edit returns to this skill for re-approval.

## Done When

- [ ] `intent.md`, `design.md`, and one `specs/<capability>.md` per affected capability exist.
- [ ] No `[NEEDS CLARIFICATION]` remains; the Clarifications log records every answer.
- [ ] IDs continue each capability's sequence; every outcome has its own scenario.
- [ ] UI scope has Screen States (and navigation when routes change) in `design.md`.
- [ ] The lane is declared in `design.md`: no user stories (single) or two or more (sliced).
- [ ] Workspace, `summary.md`, and tracker row exist; the `specify` gate exits 0.
