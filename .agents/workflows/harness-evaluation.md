---
description: Evaluate complex-feature code and test evidence in a post-implementation review.
---

# Workflow: Harness Evaluation

Use `evaluator` for code review, test review, and evaluation evidence.
If required delegation or a requested model is unavailable or unsupported, block the affected stage and report it; never silently substitute. Record requested and actual models in stage evidence when available. The evaluator must be fresh and independent, having neither implemented nor tested the change; if unavailable, keep independent review pending.

Read and follow [Product documentation flow](../rules/product-documentation.md). Load affected living capability requirements before scoping or reviewing this change. Dated complex-change contracts and evidence belong under `.scratch/`.

## When to use
- Use this workflow when you are acting as the **Evaluator** agent.
- A change has been implemented and tested and is ready for review by the Generator agent.
- You want a **second-agent review** — a different model/agent reviews code it did not write
- Post-implementation self-review before presenting findings to the user

---
## 1. Core Operating Principles
Review independently and adversarially. Execute required static and runtime checks, score only from
observable evidence, and keep any missing boundary or acceptance proof non-passing. The canonical
review criteria live in the invoked review skills, the plans, and evaluator rubric template.

---

## 2. Evaluation Step-by-Step Workflow
When a feature is submitted for review, execute these steps in order:

### Stage 1: Read the Baselines

Run the acceptance-test traceability validator in evaluation mode before review work.
It must prove every acceptance Test ID maps to a real Kotlin method, a suite-scoped
command, any declared shared scenario, and successful evidence:

    bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --evaluate

Read the active feature specification and independently reconcile its complete Rule
Applicability matrix against the submitted diff. Missing rows, triggered Not applicable
decisions, and unapproved exceptions are review failures.
- Run `bash harness/scripts/check-feature-lifecycle.sh`; stop if lifecycle state is invalid.
- Select the active non-complete `FEATURE_DIR` from the Harness Feature Tracker in `docs/product/product.md`. Do not infer lifecycle state by scanning product directories.
- Read the approved feature block(s) in `docs/product/requirements/` (requirements, acceptance criteria, out of scope), `$FEATURE_DIR/implementation-plan.md` (Rule Applicability, design, file list), the slice's `### US-n` section and journey row in `$FEATURE_DIR/test-plan.md`, and its `tasks.md` phase.
- Read `$FEATURE_DIR/feature_list.json` to verify the target feature definition and its current status.
- Validate the platform contract with `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate`. The platform capability matrix exists only for platform-bound features (`platform_validation.required: true`); for those, a missing matrix, missing required API row, pending/unavailable/skipped environment, or non-zero real-boundary test is a review failure. Non-platform features must declare `required: false` with an explicit `reason` in `feature_list.json`. Do not convert any failure into a pass because the environment is inconvenient.
- When `feature_list.json` declares the conformance-review owner (`requires_visual_verification: true`), run `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate`: every `UI_contract.md` state needs a review capture at its Viewport, a passing structural check, its registered components called from the changed UI files, and the user's approval. Rich-text appearance rows must pass the rendered-output (span-style) contract. A screenshot golden recorded from the implementation is a review finding, not evidence.
- If the change affects UI, read `docs/product/design_system.md`, `$FEATURE_DIR/UI_contract.md`, its canonical Pen source, and mapped exports. Treat unexplained deviations from the global design system as review findings.

---

### Stage 2: Test Review
The test review report must include the Rule Applicability Test Reconciliation table.
**INVOKE** the `android-test-review` skill via the Skill tool (name: `android-test-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Evaluate test coverage, assertions, and shared JSON scenario completeness. Do not stop after this stage — proceed immediately to Stage 3.

**Output**:
- Test review report: `$FEATURE_DIR/test_review_{feature_id}.md`

---

### Stage 3: Code Review
The code review report must include the Rule Applicability Reconciliation table.
**INVOKE** the `android-code-review` skill via the Skill tool (name: `android-code-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Perform static analysis and identify logic/architectural flaws. Do not stop after this stage — proceed immediately to Stage 4.

The skill MUST run the repository-wide source-rule bundle:

    bash harness/scripts/check-full-source-rules.sh

This command forces `--all` scans for architecture, Compose, and localization,
checks all test sources for assertion quality, and runs navigation checks. It runs
every checker and aggregates failures; record its complete output and treat any
non-zero result as a review failure, including pre-existing findings.

**Output**:
- Code review report: `$FEATURE_DIR/code_review_{feature_id}.md`

---

### Stage 4: Execute Runtime Verification
- Execute local unit and integration tests to verify correctness: `./gradlew testDebugUnitTest`.
- Run instrumented Compose UI tests to check interactivity and transitions with `harness/scripts/run-android-instrumented-tests.sh` as documented by the `android-testing` skill. This runtime command does not satisfy the visual-comparison gate.
- **If the feature touches the UI**, **INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`) to review the implemented UI against the approved design as a conformance review (side-by-side captures, structural checks, registered-component reuse). Reading the SKILL.md manually is not a substitute when the Skill tool is available.
- Execute the declared real platform boundary tests from `platform_validation.real_boundary_test_ids`. The test must exercise the shipped Android API/resource boundary and produce successful direct-runner evidence from `harness/scripts/run-android-instrumented-tests.sh`. Fake recognizers, fake callbacks, JVM-only intent tests, and tests that merely instantiate a seam are supplemental and cannot close the finding.
- If the required runtime, device, model, locale, permission, or service is missing, record the command as failed/blocked and keep the verdict `Revise` or `Block`. Never record a skip, warning, or absent result as evidence of support.

---

### Stage 5: Quality Assessment ⛔ STOP

After recording the score-based tracker transition, run the evaluation/fix lifecycle
contract as a hard gate:

    bash harness/scripts/check-evaluation-fix-contract.sh "$FEATURE_DIR" --evaluation

Do not claim an evaluation pass if this command rejects the arithmetic score,
contradictory evidence, acceptance traceability, hard-gate routing, or required
review artifacts.

The Evaluator's primary deliverable is the final quality assessment report.

*   **`evaluator-rubric.md`**: Generated strictly by following the structure defined in the **[`evaluator-rubric-template.md`](../../harness/templates/evaluator-rubric-template.md)**.

Fill every category, hard-gate answer, file-assessment row, verdict, and follow-up field defined by
the template. Its arithmetic and hard-gate routing are binding and are enforced by
`check-evaluation-fix-contract.sh`; do not maintain a second scoring policy in this workflow.

**⛔ STOP — present all review reports and the evaluator rubric to the user.**
The findings are presented for transparency, but the status transition is **driven automatically by the overall score** (see the rule below), not by a manual accept/fix decision.

After presenting the evaluation results, update the Harness Feature Tracker in `docs/product/product.md` with a **score-based transition**:
*   **If the overall score is `5.0 / 5` (perfect)** → transition the feature status from `To be reviewed` → `To be human reviewed`.
*   **If the overall score is less than `5.0 / 5` (not perfect)** → transition the feature status from `To be reviewed` → `To be fixed`. This routes the feature to the **harness-fix workflow** (`.agents/workflows/harness-fix.md`): the Generator resolves every finding in `$FEATURE_DIR/code_review_{feature_id}.md` and `$FEATURE_DIR/test_review_{feature_id}.md`, updates the per-finding status inside those reports, and then transitions to `To be human reviewed`.
*   Update the date to today and add the evaluation verdict (`Accept` / `Revise` / `Block`) and overall score to the notes column.
*   Run `bash harness/scripts/check-feature-lifecycle.sh` after the tracker update. Do not claim completion if it fails.
*   Then apply [artifact retention](../rules/artifact-retention.md): run `python3 harness/scripts/prune-harness-artifacts.py --apply`. It prunes only raw output of `Complete` workspaces and stale QA runs no open workspace cites, never the workspace under review. Report what it deleted; a prune failure is reported, not blocking.

---

## Human-in-the-Loop Confirmation Points

1. **After Stage 5 (Quality Assessment)** — user sees all code findings, test findings, and the final evaluator rubric *(mandatory)*. The evaluator then applies the score-based transition automatically: `5.0 / 5` → `To be human reviewed`; `< 5.0 / 5` → `To be fixed` (the Generator then runs the **harness-fix workflow** — `.agents/workflows/harness-fix.md` — and transitions to `To be human reviewed`).
2. **Nit/Optional findings** — user decides which to accept *(optional but recommended)*
