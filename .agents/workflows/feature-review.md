---
description: You are a senior Android developer running an independent review of an existing change and fixing all findings before merge.
---

# Workflow: Feature Review

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
Read all four baseline documents produced by the `/feature-delivery` workflow before touching any source code or running any checks. These are the single source of truth the review is evaluated against.

| Document | Location | What to extract |
|---|---|---|
| summary_v<N>.md | docs/current/ | Stage evidence and approved-artifact versions |
| `spec_v<N>.md` | `docs/current/` | Acceptance Criteria · Scope · Exclusions |
| `implementation_plan_v<N>.md` | `docs/current/` | Approved architecture · layer breakdown · file list |
| `test_plan_v<N>.md` | `docs/current/` | Approved test strategy · scenarios · coverage targets |

> [!IMPORTANT]
> If any of these files are missing, **immediately flag it as a blocking gap** in the Stage 5 rubric (`Handoff readiness` category). Do not silently skip a missing baseline — absent plans mean the review has no ground truth to compare against.

After reading, summarise the key constraints and open decisions you will verify during Stages 2–4. Use these notes as your checklist anchor throughout the review.

---

### Stage 2: Test Review
The test review report must include the Rule Applicability Test Reconciliation table.
**INVOKE** the `android-test-review` skill via the Skill tool (name: `android-test-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Evaluate test coverage, assertions, and shared JSON scenario completeness. Do not stop after this stage — proceed immediately to Stage 3.

- Test review report: `docs/current/test_review_v<N>.md`

---

### Stage 3: Code Review
The code review report must include the Rule Applicability Reconciliation table.
**INVOKE** the `android-code-review` skill via the Skill tool (name: `android-code-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Perform static analysis and identify logic/architectural flaws. Do not stop after this stage — proceed immediately to Stage 4.

- Code review report: `docs/current/code_review_v<N>.md`

---

### Stage 4: Execute Runtime Verification
- Execute local unit and integration tests to verify correctness: `./gradlew testDebugUnitTest`.
- Run instrumented Compose UI tests to check interactivity and transitions: target an emulator first (e.g. `ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest`), using a connected physical device only if no emulator is present.
- **If the feature touches the UI**, **INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`) to verify the implemented UI matches the approved mockup/design. Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Compare runtime screenshots against the design assets in `docs/current/design/` and `docs/product/design_system.md`; any Critical or unresolved Major deviation (wrong layout, spacing, typography, color, clipped text) is a review finding. Record the outcome in `docs/current/ui_verification.json`.

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
