---
description: Plan any new feature or enhancement — specify, design, plan, and approve; then hand off to exactly one generator workflow for the selected lane.
---

# Workflow: Harness Planning

Use `planner` for Specify, UX Design, and Implementation Plan.
If required delegation or a requested model is unavailable or unsupported, block the affected stage and report it; never silently substitute. Record requested and actual models in stage evidence when available.

Read and follow [Product documentation flow](../rules/product-documentation.md). The living
requirement file is the specification; plans and evidence live in the dated workspace.

## When to use

Every new feature, enhancement, or backend/API integration. Bugs use `bug-fixing`; an
appearance-only tweak defined by an existing approved design uses the `android-ui-layer` direct lane.

This workflow writes no application code. It ends at approval and hands off to one generator.

## Core principle

No code before an approved plan. Every stage skill is invoked through the available skill
mechanism; if the Skill tool is unavailable, read the complete `SKILL.md`, follow it, and record
that once in stage evidence. Approval evidence lives on disk, never in memory.

**Workspace**: `FEATURE_DIR=.scratch/<YYYY-MM-DD>-<feature-id>/` — one per feature, never versioned.

```text
Specify & Clarify → [UX Design] → Implementation Plan & Analyze → ⛔ Approval
   single lane → single-lane-generator
   sliced lane → sliced-lane-generator (one slice per user story)
```

| | Single lane (no user stories) | Sliced lane (two or more stories) |
|---|---|---|
| Approvals | One: block + design + both plans | Block; design (UI); plans + slices |
| Artifacts | `implementation-plan.md`, `test-plan.md`, `summary.md` (+ `UI_contract.md`) | adds `tasks.md`, `feature_list.json`, `summary_<slice>.md` |
| Execution | [`single-lane-generator`](single-lane-generator.md) | [`sliced-lane-generator`](sliced-lane-generator.md) / `harness-evaluation` / `harness-fix` |

`summary.md` uses the [`harness-planning` stage profile](../../harness/templates/summary-profiles/harness-planning.md)
for Stages 1–3 in both lanes. Execution stages are added only by the selected generator.

---

### Stage 1 — Specify & Clarify

**INVOKE** `feature-specification`. It writes the feature block under `## Planned changes` of the
affected capability file(s), resolves every `[NEEDS CLARIFICATION]`, decides the lane, and creates
the workspace, `summary.md`, and the tracker row.

Gate: `bash harness/scripts/check-stage-artifacts.sh harness-planning specify "$FEATURE_DIR"`.
Sliced lane: ⛔ STOP for block approval. Single lane: continue; approval comes at Stage 3.

### Stage 2 — UX Design *(UI scope; otherwise record N/A)*

**INVOKE** `ux-design`. Input: the block's Screen States and Navigation, supplied visual inputs, and
`docs/product/design_system.md` with its Component Registry.

1. Write `$FEATURE_DIR/UI_contract.md` (every state, viewport = design frame size, controls, fixtures,
   IME behavior; design references and reused components may be `Pending`). Gate:
   `check-stage-artifacts.sh harness-planning ui-contract "$FEATURE_DIR"`.
2. **INVOKE** `ui-design-tool` with that contract; it drives the tool set in `UX/design-tool.json`
   (pen.dev or OpenPencil). Design from registered components; record each state's design node,
   export, and reused components. Gate:
   `check-stage-artifacts.sh harness-planning ux-design "$FEATURE_DIR"`.

Sliced lane: ⛔ STOP for design approval. Single lane: continue; the design is approved with the
plans. Visual feedback updates only design artifacts; a behavior or state-inventory change returns
to Stage 1.

### Stage 3 — Implementation Plan & Analyze ⛔ STOP FOR APPROVAL

**INVOKE** `implementation-plan`. It writes `implementation-plan.md` and `test-plan.md` (plus
`tasks.md` and `feature_list.json` in the sliced lane), runs the `analyze` gate, presents the
package, and on approval records the block SHA-256, sets Status, moves the tracker, and runs:

```bash
bash harness/scripts/check-stage-artifacts.sh harness-planning implementation-plan "$FEATURE_DIR"
```

Mark the `Approval` row complete in `summary.md` only after this command exits 0.

---

## Hand-off

Planning is complete only when the Stage 3 gate exits 0. Then continue in exactly one workflow:

| Lane | Next workflow |
|---|---|
| Single lane | [`single-lane-generator`](single-lane-generator.md) |
| Sliced lane | [`sliced-lane-generator`](sliced-lane-generator.md); the tracker stays at `Awaiting implementation approval` and the generator executes the slices |

## Rollback routes

| Failure | Return to |
|---|---|
| Behavior, scope, data, navigation, or state-inventory change | Stage 1 (re-approval; the block hash changes) |
| Visual design feedback | Stage 2 |
| Plan-only feedback or analyze inconsistency | Stage 3 |

## Human-in-the-loop confirmation points

1. **Single lane**: one approval after Stage 3 (block + design + plans).
2. **Sliced lane**: block after Stage 1, design after Stage 2, plans and slices after Stage 3.
