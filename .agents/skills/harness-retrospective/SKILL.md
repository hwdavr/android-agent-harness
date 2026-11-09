---
name: harness-retrospective
description: Repair harness workflow, gate, fixture, or evidence failures without changing application behavior.
---

# Harness Retrospective

## Purpose

Repair the repository harness when it allows incorrect evidence, hides unavailable environments, or fails to catch a recurring workflow defect. Preserve the application and product contract while making the harness detect the problem earlier and fail clearly.

## Scope Boundary

Work only on harness-environment concerns:

- `.agents/workflows/`, `.agents/rules/`, and `.agents/gates/` instructions;
- `harness/templates/` and harness artifact schemas;
- `harness/scripts/` validators, environment probes, and contract tests;
- test fixtures that validate harness behavior;
- `docs/knowledge/pitfalls/` and `docs/changes/` audit records.

Do not fix or reinterpret:
- model capability, model quality, OEM behavior, or platform-service limitations;
- application source defects or feature implementation;
- lifecycle status transitions, slice selection, or implementation authorization.

If the root cause is outside the scope boundary, classify it, document the evidence, and stop the repair. Improve only the harness detection and handoff if that is independently useful.

## Root-Cause Classification

Classify before editing. Use exactly one primary classification:

| Classification | Meaning | Skill action |
|---|---|---|
| `HARNESS_ENVIRONMENT` | A workflow, gate, validator, fixture, environment probe, or evidence rule allowed a false pass or misleading result. | Repair and regression-test the harness. |
| `WORKFLOW_GAP` | The correct rule exists nowhere or is not attached to the required stage. | Add it to the authoritative workflow/template/gate and test enforcement. |
| `TEST_EVIDENCE_GAP` | The test runner or evidence schema cannot prove the required boundary. | Add a mechanical evidence requirement; do not implement the product behavior. |
| `SPEC_GAP` | The expected product behavior or acceptance criteria are ambiguous, conflicting, or absent. | Repair the feature block in `docs/product/requirements/` (re-approval), `UI_contract.md`/Pen references, and the plans in the feature workspace; then re-validate downstream artifacts. |
| `MODEL_OR_PLATFORM_CAPABILITY` | The runtime, model, OEM, SDK, or service cannot provide the requested capability. | Stop; route to product/architecture decision. Add only fail-loud diagnostics if needed. |
| `APPLICATION_DEFECT` | The harness correctly exposed a defect in shipped application behavior. | Stop; route to the application bug-fixing workflow. |

Never relabel a `MODEL_OR_PLATFORM_CAPABILITY` or `APPLICATION_DEFECT` as a harness issue just to keep working.

## Workflow

### 1. Orient and preserve state

1. Read `AGENTS.md` and `.agents/rules/android-architecture.md` (skip if already loaded this session). `rules/testing-strategy.md` is auto-loaded as a system rule.
2. Read the specific workflow, gate, template, or validator named by the incident. Read it completely before editing.
3. Run `bash harness/scripts/check-feature-lifecycle.sh` when the incident concerns a complex feature. Do not change the tracker or select a slice.
4. Collect the smallest raw evidence set: failing command, exit code, relevant log, artifact path, and the harness rule that should have caught it.
5. Check `git status --short` and preserve unrelated user changes.

### 2. Reproduce the harness failure

Create or identify a minimal fixture that demonstrates the incorrect behavior. Prefer a contract test over an informal manual check.

The fixture must make the failure observable, for example:

- missing capability matrix is accepted;
- `Pending`, `Unavailable`, or `Skipped` runtime evidence is accepted;
- a fake adapter is accepted as the only platform proof;
- a stale fixture fails for the wrong reason;
- a validator reports a misleading error before reaching the intended assertion.

Do not alter application code to make the fixture pass.

### 3. Define the invariant

Write the intended invariant in one sentence before patching. Examples:

- “A required runtime that was not executed cannot produce passing evidence.”
- “A platform-bound feature requires a real instrumented boundary test; fake/JVM tests are supplemental.”
- “A contract fixture must reach the condition it claims to test.”

The invariant must be enforceable by a script, test, or required artifact—not only by reviewer memory.

### 4. Patch the authoritative source

Before editing `.agents/rules/`, `.agents/workflows/`, or `.agents/skills/`:

1. Finish the read-only diagnosis and identify the exact instruction files that need changes.
2. Present the file list, reason for each change, and a concise diff or change outline to the user; request explicit approval.
3. Stop before editing. Resume only after approval covers the proposed files. If the scope changes, request approval for the added files first.

A request to review, investigate, or retro an instruction mismatch does not itself authorize editing those files. Apply this gate before the patching steps below.

Read relevant existing skills and workflows; keep new instructions minimal and link existing guidance instead of repeating it.

Make the smallest change that closes the gap at its source:

- Update the workflow, rule, gate, schema, or template that allowed the failure.
- Add or tighten the validator or environment probe that enforces the invariant.
- Add a focused regression fixture or contract test that reproduces the old false pass and proves rejection now.
- Add a knowledge pitfall only when the lesson is reusable beyond the incident.

Keep each operational rule in one authoritative document. Before editing, assign ownership:
workflows own stage order and gates, skills own reusable procedures, and schemas/scripts own
artifact shape and mechanical enforcement. Put the full issue-specific instruction only in
its owner; replace repeats in other documents with a short link. Search those documents before
and after editing to remove duplicates without deleting necessary ownership or handoff links.

Use `apply_patch` for file edits. Do not add suppressions, exclusions, warning-only paths, silent skips, or broad “best effort” fallbacks. Do not modify product code, product requirements, model behavior, or platform capabilities while acting as this skill.

### 5. Apply evidence rules

Apply [Evidence Invariants](../../rules/testing-strategy.md#evidence-invariants); for platform incidents, also apply [Platform-Bound Evidence](../../rules/testing-runtime-evidence.md#platform-bound-evidence) and the [capability matrix contract](../../../harness/templates/platform-capability-matrix-template.md).

### 6. Validate the harness change

Run the narrowest relevant checks, then the project gates affected by the change. Typical checks are:

```bash
bash -n <changed-shell-scripts>
bash harness/scripts/check-feature-lifecycle.sh
bash harness/scripts/check-stage-artifacts.sh <workflow> <stage> <feature-dir>
bash harness/scripts/check-platform-evidence.sh <feature-dir> --planning
bash harness/scripts/check-platform-evidence.sh <feature-dir> --evaluate
bash harness/scripts/tests/<relevant-contract-test>.sh
git diff --check
```

Expected negative cases must be asserted as expected failures in a contract test; do not hide them with `|| true` or suppress their output. Run Android build, unit, coverage, lint, or instrumented checks when the harness change affects app compilation or that gate’s behavior. Otherwise, state explicitly that no app source changed and why those gates were not relevant.

### 7. Record and hand off

Create `docs/changes/harness-retro-<YYYY-MM-DD>-<short-slug>/retrospective.md` with:

- Incident: trigger, observed evidence, and affected stage.
- Classification and root cause.
- The invariant added.
- Harness change: workflow/rule/gate, validator/template, and regression fixture.
- Verification commands and results.
- Routed items that are intentionally outside harness scope.
- Remaining risk.

Resolve this path from the consuming application's project root. If the harness is a nested shared submodule, the consumer's project-specific retrospective belongs in the consumer's `docs/changes/`; do not create or edit it under the submodule's `docs/`.

Quote exact artifact paths and one-line excerpts so a reviewer can verify the change. If the incident is a model-capability, platform-capability, or application defect, route it clearly and leave the harness unchanged except for an independently justified fail-loud diagnostic or handoff improvement.

## Completion Criteria

Complete when the applicable [validation](#6-validate-the-harness-change) and [handoff record](#7-record-and-hand-off) above are finished.
