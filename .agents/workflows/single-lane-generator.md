---
description: Implement and verify an approved single-lane feature — implementation, testing, UI verification, code quality, product docs, and install.
---

# Workflow: Single-Lane Generator

Use `implementer` for implementation, `tester` for test authoring and execution, and `evaluator`
for review.
If required delegation or a requested model is unavailable or unsupported, block the affected stage and report it; never silently substitute. Record requested and actual models in stage evidence when available. The evaluator must be fresh and independent, having neither implemented nor tested the change; if unavailable, keep independent review pending.

Read and follow [Product documentation flow](../rules/product-documentation.md).

## When to use

A single-lane feature (no user stories) whose plan package passed
[`harness-planning`](harness-planning.md) Stage 3:
`check-stage-artifacts.sh harness-planning implementation-plan "$FEATURE_DIR"` exits 0. Sliced-lane
features use [`sliced-lane-generator`](sliced-lane-generator.md) instead.

Stages continue the numbering of `harness-planning` (Stages 1–3). `summary.md` adds the
[`single-lane-generator` stage profile](../../harness/templates/summary-profiles/single-lane-generator.md)
rows below the planning rows.

```text
Implementation → Testing → [UI Verification ↩] → Code Quality → Product Docs → Install
```

---

### Stage 4 — Implementation

**INVOKE** `android-implementation`. Implement the approved plan before testing; reuse the
registered components named in UI State Stages.
Gate: `./gradlew assembleDebug` passes and all layer rules hold.

### Stage 5 — Testing

Select maintained regression tests for the approved change; a temporary WireMock journey runs
separately through `exploratory-qa` / `agent-device`. **INVOKE** `android-testing`; complete the
planned tests and verify them GREEN (no separate RED stage).

Gate: every selected test passes with a non-zero executed count; required instrumented boundaries
pass on the declared runtime. Record commands and counts in `summary.md`, then run
`check-stage-artifacts.sh single-lane-generator testing "$FEATURE_DIR"`,
`bash harness/scripts/check-journey-registry.sh --validate`, and `--run-one <journey-id>` for each
affected registered journey. Rich-text appearance claims run
`bash harness/scripts/check-rendered-output-contract.sh` for the named span-style test.

### Stage 6 — UI Verification ↩ *(UI scope; otherwise record N/A)*

**INVOKE** `ui-verification`. For each `UI_contract.md` state: render the review capture at its
Viewport, run the structural check, present the capture beside the approved design, and record the
user's decision in `$FEATURE_DIR/ui_verification.json`. Changes requested → fix and repeat; after 3
loops stop and surface the differences. No screenshot golden is recorded or compared.
Gate: `check-stage-artifacts.sh single-lane-generator ui-verification "$FEATURE_DIR"`.

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

Set the tracker row to `Complete` only after these pass. Then apply [artifact retention](../rules/artifact-retention.md) with
`python3 harness/scripts/prune-harness-artifacts.py --apply`; record the results its logs backed in `summary.md` before that.
A prune failure is reported, not blocking.

### Stage 9 — Install App To Device

When the feature affects UI, needs instrumented/platform verification, or the user asks:
`./gradlew installDebug` on every connected device; record command, device IDs, and exit status in
`summary.md`. Otherwise record a feature-specific N/A. Failure or no connected device is Blocked.

---

## Rollback routes

| Failure | Return to |
|---|---|
| Behavior, scope, data, navigation, or state-inventory change | `harness-planning` Stage 1 (re-approval; the block hash changes) |
| Visual design feedback | `harness-planning` Stage 2 |
| Plan-only feedback or analyze inconsistency | `harness-planning` Stage 3 |
| Compilation error | Stage 4 |
| Conformance review changes requested or structural check fails | Stage 6 (fix in Stage 4) |
| Selected test, CI suite, or coverage failure | Stage 5 (fix the implementation if needed) |
| Quality check violation | Stage 7 (root cause; no suppressions) |
| Install failure or no device | Stage 9 |

## Human-in-the-loop confirmation points

1. The per-state conformance review in Stage 6.
