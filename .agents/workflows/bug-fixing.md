---
description: Diagnose and fix an Android bug with RED reproduction, approved planning, and GREEN verification.
---

# Workflow: Bug Fixing

Use `planner` for the fix plan, `tester` for reproduction and verification, `implementer` for the fix, and `evaluator` for review.
If required delegation or a requested model is unavailable or unsupported, block the affected stage and report it; never silently substitute. Record requested and actual models in stage evidence when available. The evaluator must be fresh and independent, having neither implemented nor tested the change; if unavailable, keep independent review pending.

Use for a defect, crash, ANR, regression, test failure, or unexpected behavior. Follow
[Product documentation flow](../rules/product-documentation.md) and, for runtime, UI, navigation,
IME, or rich-text bugs, [testing-runtime-evidence](../rules/testing-runtime-evidence.md), which owns
those boundary requirements. Apply each stage skill through the Skill tool, or read its `SKILL.md`
and record the missing interface, as `AGENTS.md` requires.

```text
Root Cause → Reproduction (RED) → Fix Plan ⛔ → Implementation → Testing → Code Quality → Install → Review ⛔
```

**Workspace**: `FEATURE_DIR=.scratch/<YYYY-MM-DD>-fix-<short-name>/` with `summary.md` (bug-fixing
stage profile) and a Harness Feature Tracker row (`Planning`). A bug that restores specified
behavior adds no `intent.md` or `specs/`; `implementation-plan.md` cites the violated
`<capability>.md#FR-###`. A wrong or missing requirement is a behavior change: route that part
through `harness-planning`.

---

### Stage 1 — Bug Context & Root Cause

Read the affected capability file(s). Write `implementation-plan.md` from its template with the
Product Requirements row (`none — restores <capability>.md#FR-###`), `## Root Cause & Reproduction`
(expected vs. actual, fault localization UI → VM → UC → Repo → API, root cause "triggered when
<cond>, causing <behavior>"), `## Screen States` for UI bugs, and all ten Rule Applicability rows
for the fix scope. The rest of the plan is completed in Stage 3.

Runtime evidence: when coming from Exploratory QA, read the finding once with
`python3 harness/scripts/read-qa-bug-context.py --report .qa-artifacts/<run-id>/report.json --finding <finding-id>`
and record `## Exploratory QA Handoff` (Report, Finding) in `test-plan.md`; do not rerun QA, and
collect only evidence the finding lacks. Otherwise, for runtime-dependent bugs, reproduce with
`agent-device` (open, follow the path, inspect UI and logs, close) and record device, build, steps,
and results.

Gate: `bash harness/scripts/check-stage-artifacts.sh bug-fixing bug-context "$FEATURE_DIR"` exits 0.

### Stage 2 — Bug Reproduction

Apply `bug-reproduction`. Record `## Reproduction Test` (File, Test name, Run result) in
`test-plan.md` and the `Bug Reproduction` row in `summary.md`.

Gate: the test fails RED for the stated root cause with no application code changed;
`bash harness/scripts/check-stage-artifacts.sh bug-fixing bug-reproduction "$FEATURE_DIR"` exits 0.
⛔ If no test can reproduce the root cause, surface it to the user.

### Stage 3 — Fix Plan ⛔

Apply `implementation-plan` (single lane): minimal fix citing the reproduction test, the `@Ignore`
to remove, and Rule Applicability re-checked against the fix, with every `Required` row mapped in
`test-plan.md`. UI fixes add `## UI State Verification`; boundary sections follow
testing-runtime-evidence.

Gate: `check-stage-artifacts.sh bug-fixing analyze "$FEATURE_DIR"` exits 0. ⛔ Present the Fix Plan
and test plan; wait for explicit approval. Then set the plan Status, move the tracker to
`In Progress`, and run `check-stage-artifacts.sh bug-fixing implementation-plan "$FEATURE_DIR"`.

### Stage 4 — Implementation

Apply `android-implementation` to the affected layers only. Gate: `./gradlew assembleDebug` passes.
UI bugs then apply `ui-verification` to the touched states and run
`check-stage-artifacts.sh bug-fixing ui-verification "$FEATURE_DIR"`.

### Stage 5 — Testing

Apply `android-testing`. Gate: the reproduction test and selected related tests pass GREEN with
non-zero executed counts; required instrumented boundaries pass on the declared runtime. When `NAV`
is `Required` or the fix touches UI/IME, run `check-stage-artifacts.sh bug-fixing testing "$FEATURE_DIR"`;
rich-text fixes also run `bash harness/scripts/check-rendered-output-contract.sh`.

### Stage 6 — Code Quality Fix

Apply `code-quality-fix`. Gate: its conditions pass, the `@Ignore` is removed, and no unrelated
changes slipped in.

### Stage 7 — Install App To Device

When the fix affects UI, needs platform verification, or the user asks: `./gradlew installDebug`
on every connected device, record command, device IDs, and exit status, and replay any Stage 1
`agent-device` journey. Otherwise record a non-runtime N/A. No connected device when required
is blocked.

### Stage 8 — Independent Review ⛔

Present the fix and results and ask whether to start independent review; record the decision in
`summary.md`. After approval, follow the applicable review workflow.

### Close

Reconcile affected capability claims in place and record them in the summary's
`## Product Requirement Reconciliation` table (use `Confirm unchanged` with a reason for an
already-correct contract), as the product documentation flow defines. Run
`python3 harness/scripts/check-product-docs.py --change-dir "$FEATURE_DIR" --summary "$FEATURE_DIR/summary.md"`
and the lifecycle validator, then set the tracker row to `Complete`.
