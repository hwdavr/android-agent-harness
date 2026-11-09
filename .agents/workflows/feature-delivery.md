---
description: Deliver any new feature or enhancement — specify, design, plan, and (single lane) implement and verify; sliced work hands off to the harness generator.
---

# Workflow: Feature Delivery

Use `planner` for Specify, UX Design, and Implementation Plan; `implementer` for implementation;
`tester` for test authoring and execution; `evaluator` for review.
If required delegation or a requested model is unavailable or unsupported, block the affected stage and report it; never silently substitute. Record requested and actual models in stage evidence when available. The evaluator must be fresh and independent, having neither implemented nor tested the change; if unavailable, keep independent review pending.

Read and follow [Product documentation flow](../rules/product-documentation.md). The living
requirement file is the specification; plans and evidence live in the dated workspace.

## When to use

Every new feature, enhancement, or backend/API integration. Bugs use `bug-fixing`; an
appearance-only tweak defined by an existing approved design uses the `android-ui-layer` direct lane.

## Core principle

No code before an approved plan. Every stage skill is invoked through the available skill
mechanism; if the Skill tool is unavailable, read the complete `SKILL.md`, follow it, and record
that once in stage evidence. Approval evidence lives on disk, never in memory.

**Workspace**: `FEATURE_DIR=.scratch/<YYYY-MM-DD>-<feature-id>/` — one per feature, never versioned.

```text
Specify & Clarify → [UX Design] → Implementation Plan & Analyze → ⛔ Approval
   single lane → Implementation → Testing → [UI Verification ↩] → Code Quality → Product Docs → Install
   sliced lane → harness-generator (one slice per user story)
```

| | Single lane (no user stories) | Sliced lane (two or more stories) |
|---|---|---|
| Approvals | One: block + design + both plans | Block; design (UI); plans + slices |
| Artifacts | `implementation-plan.md`, `test-plan.md`, `summary.md` (+ `UI_contract.md`) | adds `tasks.md`, `feature_list.json`, `summary_<slice>.md` |
| Execution | This workflow, one pass | `harness-generator` / `harness-evaluation` / `harness-fix` |

---

### Stage 1 — Specify & Clarify

**INVOKE** `feature-specification`. It writes the feature block under `## Planned changes` of the
affected capability file(s), resolves every `[NEEDS CLARIFICATION]`, decides the lane, and creates
the workspace, `summary.md`, and the tracker row.

Gate: `bash harness/scripts/check-stage-artifacts.sh feature-delivery specify "$FEATURE_DIR"`.
Sliced lane: ⛔ STOP for block approval. Single lane: continue; approval comes at Stage 3.

### Stage 2 — UX Design *(UI scope; otherwise record N/A)*

**INVOKE** `ux-design`. Input: the block's Screen States and Navigation, supplied visual inputs, and
`docs/product/design_system.md` with its Component Registry.

1. Write `$FEATURE_DIR/UI_contract.md` (every state, viewport = design frame size, controls, fixtures,
   IME behavior; design references and reused components may be `Pending`). Gate:
   `check-stage-artifacts.sh feature-delivery ui-contract "$FEATURE_DIR"`.
2. **INVOKE** `ui-design-tool` with that contract; it drives the tool set in `UX/design-tool.json`
   (pen.dev or OpenPencil). Design from registered components; record each state's design node,
   export, and reused components. Gate:
   `check-stage-artifacts.sh feature-delivery ux-design "$FEATURE_DIR"`.

Sliced lane: ⛔ STOP for design approval. Single lane: continue; the design is approved with the
plans. Visual feedback updates only design artifacts; a behavior or state-inventory change returns
to Stage 1.

### Stage 3 — Implementation Plan & Analyze ⛔ STOP FOR APPROVAL

**INVOKE** `implementation-plan`. It writes `implementation-plan.md` and `test-plan.md` (plus
`tasks.md` and `feature_list.json` in the sliced lane), runs the `analyze` gate, presents the
package, and on approval records the block SHA-256, sets Status, moves the tracker, and runs:

```bash
bash harness/scripts/check-stage-artifacts.sh feature-delivery implementation-plan "$FEATURE_DIR"
```

**Sliced lane ends here**: the tracker stays at `Awaiting implementation approval` and `harness-generator` executes the slices.

---

### Stage 4 — Implementation *(single lane)*

**INVOKE** `android-implementation`. Implement the approved plan before testing; reuse the
registered components named in UI State Stages.
Gate: `./gradlew assembleDebug` passes and all layer rules hold.

### Stage 5 — Testing

Select maintained regression tests for the approved change; a temporary WireMock journey runs
separately through `exploratory-qa` / `agent-device`. **INVOKE** `android-testing`; complete the
planned tests and verify them GREEN (no separate RED stage).

Gate: every selected test passes with a non-zero executed count; required instrumented boundaries
pass on the declared runtime. Record commands and counts in `summary.md`, then run
`check-stage-artifacts.sh feature-delivery testing "$FEATURE_DIR"`,
`bash harness/scripts/check-journey-registry.sh --validate`, and `--run-one <journey-id>` for each
affected registered journey. Rich-text appearance claims run
`bash harness/scripts/check-rendered-output-contract.sh` for the named span-style test.

### Stage 6 — UI Verification ↩ *(UI scope; otherwise record N/A)*

**INVOKE** `ui-verification`. For each `UI_contract.md` state: render the review capture at its
Viewport, run the structural check, present the capture beside the approved design, and record the
user's decision in `$FEATURE_DIR/ui_verification.json`. Changes requested → fix and repeat; after 3
loops stop and surface the differences. No screenshot golden is recorded or compared.
Gate: `check-stage-artifacts.sh feature-delivery ui-verification "$FEATURE_DIR"`.

### Stage 7 — Code Quality Fix

**INVOKE** `code-quality-fix`. Gate: `ktlintCheck`, `detekt`, `lintDebug`, and all custom check
scripts (including the compose "Registered design-system components" rule) exit 0.

### Stage 8 — Product Document Update

Reconcile the feature block into the living file: move each delivered `FR-###`/`AC-###` from
`## Planned changes` into `## Requirements` in place — replace changed requirements, retire IDs a
`Retires` relation names, and remove the block markers. Keep genuinely undelivered scope under
`## Planned changes`, explicitly qualified. Update the product index only where its summary is stale.

In `summary.md` add `## Product Requirement Reconciliation` with columns `Capability file`,
`Existing claim reviewed`, `Disposition` (`Replace`, `Retire`, `Retain`, `Confirm unchanged`),
`Current requirement location or retired status`, and `Evidence / qualification`.

```bash
python3 harness/scripts/check-product-docs.py --change-dir "$FEATURE_DIR" --summary "$FEATURE_DIR/summary.md"
bash harness/scripts/check-feature-lifecycle.sh
bash harness/scripts/check-harness-metrics.sh --validate "$FEATURE_DIR/summary.md"
```

Set the tracker row to `Complete` only after these pass.

### Stage 9 — Install App To Device

When the feature affects UI, needs instrumented/platform verification, or the user asks:
`./gradlew installDebug` on every connected device; record command, device IDs, and exit status in
`summary.md`. Otherwise record a feature-specific N/A. Failure or no connected device is Blocked.

---

## Rollback routes

| Failure | Return to |
|---|---|
| Behavior, scope, data, navigation, or state-inventory change | Stage 1 (re-approval; the block hash changes) |
| Visual design feedback | Stage 2 |
| Plan-only feedback or analyze inconsistency | Stage 3 |
| Compilation error | Stage 4 |
| Conformance review changes requested or structural check fails | Stage 6 (fix in Stage 4) |
| Selected test, CI suite, or coverage failure | Stage 5 (fix the implementation if needed) |
| Quality check violation | Stage 7 (root cause; no suppressions) |
| Install failure or no device | Stage 9 |

## Human-in-the-loop confirmation points

1. **Single lane**: one approval after Stage 3 (block + design + plans), and the per-state
   conformance review in Stage 6.
2. **Sliced lane**: block after Stage 1, design after Stage 2, plans and slices after Stage 3.
