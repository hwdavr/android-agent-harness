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

1. **Be Adversarial & Skeptical**: Assume the Generator agent wrote incomplete, buggy, or "happy-path-only" code. Your job is to find the cracks.
2. **Demand Observability & Evidence**: Do not just check the source code. You must run build commands, run lint checks, run the application, and use browser testing tools (e.g., Playwright MCP) to interact with the UI like a real user.
3. **No Subjective Approvals**: All evaluations must be scored strictly using the categories in `evaluator-rubric.md` and the binary items in `sprint-contract.md`. 
4. **Reject Over-forgiving Tendencies**: If a feature is 95% complete but missing a boundary check or styling detail, you **MUST** mark it as "Fail" / "Revise" and output explicit negative feedback. Do not rationalize or make excuses for the generator.

---

## Stage Execution
When a feature is submitted for review, execute these steps in order:

### Stage 1: Read the Baselines
Read all four baseline documents produced by the `/feature-delivery` workflow before touching any source code or running any checks. These are the single source of truth the review is evaluated against.

| Document | Location | What to extract |
|---|---|---|
| `spec_v<N>.md` | `docs/current/` | Acceptance Criteria · Scope · Exclusions |
| `implementation_plan_v<N>.md` | `docs/current/` | Approved architecture · layer breakdown · file list |
| `test_plan_v<N>.md` | `docs/current/` | Approved test strategy · scenarios · coverage targets |

> [!IMPORTANT]
> If any of these files are missing, **immediately flag it as a blocking gap** in the Stage 5 rubric (`Handoff readiness` category). Do not silently skip a missing baseline — absent plans mean the review has no ground truth to compare against.

After reading, summarise the key constraints and open decisions you will verify during Stages 2–4. Use these notes as your checklist anchor throughout the review.

---

### Stage 2: Test Review
**INVOKE** the `android-test-review` skill via the Skill tool (name: `android-test-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Evaluate test coverage, assertions, and shared JSON scenario completeness. Do not stop after this stage — proceed immediately to Stage 3.

- Test review report: `docs/current/test_review_v<N>.md`

---

### Stage 3: Code Review
**INVOKE** the `android-code-review` skill via the Skill tool (name: `android-code-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Perform static analysis and identify logic/architectural flaws. Do not stop after this stage — proceed immediately to Stage 4.

- Code review report: `docs/current/code_review_v<N>.md`

---

### Stage 4: Execute Runtime Verification
- Execute local unit and integration tests to verify correctness: `./gradlew testDebugUnitTest`.
- Run instrumented Compose UI tests to check interactivity and transitions: target an emulator first (e.g. `ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest`), using a connected physical device only if no emulator is present.

---

### Stage 5: Quality Assessment ⛔ STOP
The Evaluator's primary deliverable is the final quality assessment report.

*   **`evaluator-rubric.md`**: Generated strictly by following the structure defined in the **[`evaluator-rubric-template.md`](../../harness/templates/evaluator-rubric-template.md)**.

> [!IMPORTANT]
> The Evaluator **MUST** execute the following grading policy inside `evaluator-rubric.md`:
> 1. **Category Scoring**: Evaluate and assign a quantitative score **(0-5)** to each core category based on objective mechanical evidence. Core categories are:
>    *   **Correctness**: Does the behavior match the request?
>    *   **Verification**: Did checks run, with evidence?
>    *   **Scope discipline**: Did it stay inside scope?
>    *   **Reliability**: Does it survive rerun?
>    *   **Maintainability**: Is code/docs clear?
>    *   **Handoff readiness**: Can work continue?
>    *   **Code & Test Review**: Rate the outcome of static analysis (ktlint, detekt, lint), code structure, and test coverage/robustness from Stages 3 & 4.
> 2. **Calculate Overall Score**: Formulate a comprehensive overall score summarizing quality.
> 3. **File Assessment**: Verify that every required repository file is present and assess its quality details:
>    *   `summary_v<N>.md`
>    *   `spec_v<N>.md`
>    *   `implementation_plan_v<N>.md`
>    *   `test_plan_v<N>.mdd`
>    *   `evaluator-rubric.md` (This file itself)
> 4. **Issue Verdict & Follow-Up**: Document the final verdict (`Accept` | `Revise` | `Block`) and explicitly itemize any missing evidence, required fixes, or review triggers in the **Required Follow-Up** block.

**⛔ STOP — present all review reports and the evaluator rubric to the user.**
The user decides whether findings are acceptable or fixes are required.

---

## Human-in-the-Loop Confirmation Points

1. **After Stage 5 (Quality Assessment)** — user sees all code findings, test findings, and the final evaluator rubric *(mandatory)*
2. **Nit/Optional findings** — user decides which to accept *(optional but recommended)*

