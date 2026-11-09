---
description: Run an independent ad-hoc review of a completed Android change before merge.
---

# Workflow: Feature Review

Use `evaluator` for test review and code review.
If required delegation or a requested model is unavailable or unsupported, block the affected stage and report it; never silently substitute. Record requested and actual models in stage evidence when available. The evaluator must be fresh and independent, having neither implemented nor tested the change; if unavailable, keep independent review pending.

Read and follow [Product documentation flow](../rules/product-documentation.md). Load affected living capability requirements before scoping or reviewing this change. Dated complex-change contracts and evidence belong under `.scratch/`.

## When to use

- Use this workflow when you are acting as the **Evaluator** agent.
- A change has been implemented by feature-delivery workflow
- Post-implementation self-review before presenting to the user

---

## Core Principle

Review independently and adversarially. Execute required static and runtime checks, score only from
observable evidence, and keep missing acceptance or boundary proof non-passing. Ad-hoc artifact
paths and user-controlled follow-up remain specific to this workflow.

---

## Stage Execution
The review must read and independently reconcile all ten Rule Applicability decisions
against the diff and evidence. A missing row, triggered Not applicable decision, or
unapproved exception is a blocking finding.
When a feature is submitted for review, execute these steps in order:

### Stage 1: Read the Baselines
Read all four baselines produced by the `/feature-delivery` workflow in the dated workspace `$FEATURE_DIR=.scratch/<YYYY-MM-DD>-<feature-id>/` before touching any source code or running any checks. These are the single source of truth the review is evaluated against.

| Document | Location | What to extract |
|---|---|---|
| `summary.md` | `$FEATURE_DIR` | Stage evidence and approvals |
| Feature block `<feature-id>` | `docs/product/requirements/<capability>.md` | Requirements · acceptance criteria · out of scope (approved SHA-256 in the plan) |
| `implementation-plan.md` | `$FEATURE_DIR` | Rule Applicability · approved design · file list |
| `test-plan.md` | `$FEATURE_DIR` | Acceptance tests · scenarios · coverage targets · UI state verification |

> [!IMPORTANT]
> If any of these files are missing, **immediately flag it as a blocking gap** in the Stage 5 rubric (`Handoff readiness` category). Do not silently skip a missing baseline — absent plans mean the review has no ground truth to compare against.

After reading, summarise the key constraints and all ten rule decisions you will verify during Stages 2–4. Independently compare the diff with the matrix: missing rows, unsupported `Not applicable` outcomes, and unapproved exceptions are blocking findings. Use these notes as your checklist anchor throughout the review.

---

### Stage 2: Test Review
The test review report must include the Rule Applicability Test Reconciliation table.
**INVOKE** the `android-test-review` skill via the Skill tool (name: `android-test-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Evaluate test coverage, assertions, and shared JSON scenario completeness. Do not stop after this stage — proceed immediately to Stage 3.

- Test review report: `$FEATURE_DIR/test_review.md`

---

### Stage 3: Code Review
The code review report must include the Rule Applicability Reconciliation table.
**INVOKE** the `android-code-review` skill via the Skill tool (name: `android-code-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Perform static analysis and identify logic/architectural flaws. Do not stop after this stage — proceed immediately to Stage 4.

- Code review report: `$FEATURE_DIR/code_review.md`

---

### Stage 4: Execute Runtime Verification
- Execute local unit and integration tests to verify correctness: `./gradlew testDebugUnitTest`.
- Run the declared instrumented Compose UI tests with `harness/scripts/run-android-instrumented-tests.sh` as documented by the `android-testing` skill. Visual approval is the conformance review recorded in `ui_verification.json`, never a screenshot golden.
- **If the feature touches the UI**, **INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`) to verify the implemented UI matches the approved mockup/design. Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Compare review captures against the approved design assets in `$FEATURE_DIR/design/` and `docs/product/design_system.md`; any Critical or unresolved Major deviation (wrong layout, spacing, typography, color, clipped text) is a review finding. Record the outcome in `$FEATURE_DIR/ui_verification.json`.

---

### Stage 5: Quality Assessment ⛔ STOP
The Evaluator's primary deliverable is the final quality assessment report.

*   **`evaluator-rubric.md`**: Generated strictly by following the structure defined in the **[`evaluator-rubric-template.md`](../../harness/templates/evaluator-rubric-template.md)**.

Fill every category, file-assessment row, verdict, and follow-up field in
`harness/templates/evaluator-rubric-template.md`. The template is the scoring authority; this
workflow retains the ad-hoc rule that the user decides whether findings are accepted or fixed.

**⛔ STOP — present all review reports and the evaluator rubric to the user.**
The user decides whether findings are acceptable or fixes are required.

---

## Human-in-the-Loop Confirmation Points

1. **After Stage 5 (Quality Assessment)** — user sees all code findings, test findings, and the final evaluator rubric *(mandatory)*
2. **Nit/Optional findings** — user decides which to accept *(optional but recommended)*
