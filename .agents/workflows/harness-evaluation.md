---
description: You are a senior Android developer running an independent code and test review of an existing change — harness-evaluation workflow.
---

# Workflow: Harness Evaluation

## When to use
- Use this workflow when you are acting as the **Evaluator** agent.
- A change has been implemented and tested and is ready for review by the Generator agent.
- You want a **second-agent review** — a different model/agent reviews code it did not write
- Post-implementation self-review before presenting findings to the user

---
## 1. Core Operating Principles
1. **Be Adversarial & Skeptical**: Assume the Generator agent wrote incomplete, buggy, or "happy-path-only" code. Your job is to find the cracks.
2. **Demand Observability & Evidence**: Do not just check the source code. You must run build commands, run lint checks, run the application, and use browser testing tools (e.g., Playwright MCP) to interact with the UI like a real user.
3. **No Subjective Approvals**: All evaluations must be scored strictly using the categories in `evaluator-rubric.md` and the binary items in `sprint-contract.md`. 
4. **Reject Over-forgiving Tendencies**: If a feature is 95% complete but missing a boundary check or styling detail, you **MUST** mark it as "Fail" / "Revise" and output explicit negative feedback. Do not rationalize or make excuses for the generator.

---

## 2. Evaluation Step-by-Step Workflow
When a feature is submitted for review, execute these steps in order:

### Stage 1: Read the Baselines
- Run `bash harness/scripts/check-feature-lifecycle.sh`; stop if lifecycle state is invalid.
- Select the active non-complete `FEATURE_DIR` from the Harness Feature Tracker in `docs/product/product.md`. Do not infer lifecycle state by scanning product directories.
- Read `$FEATURE_DIR/sprint-contract.md` to see the agreed **Acceptance Criteria**, **Scope**, and **Exclusions**.
- Read `$FEATURE_DIR/feature_list.json` to verify the target feature definition and its current status.
- Read `$FEATURE_DIR/platform-capability-matrix.md` and validate it with `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate`. A missing matrix, missing required API row, pending/unavailable/skipped environment, or non-zero real-boundary test is a review failure; do not convert it into a pass because the environment is inconvenient.
- When `feature_list.json` declares a visual-verification owner, validate visual traceability with `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"`; a visual method without a sprint-contract row, successful connected evidence, non-empty screenshot, or reference-anchor proof is a review failure.
- If the change affects UI, read `docs/product/design_system.md`, `$FEATURE_DIR/design.md`, and its visual assets. Treat unexplained deviations from the global design system as review findings.

---

### Stage 2: Test Review
**INVOKE** the `android-test-review` skill via the Skill tool (name: `android-test-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Evaluate test coverage, assertions, and shared JSON scenario completeness. Do not stop after this stage — proceed immediately to Stage 3.

**Output**:
- Test review report: `$FEATURE_DIR/test_review_{feature_id}.md`

---

### Stage 3: Code Review
**INVOKE** the `android-code-review` skill via the Skill tool (name: `android-code-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Perform static analysis and identify logic/architectural flaws. Do not stop after this stage — proceed immediately to Stage 4.

**Output**:
- Code review report: `$FEATURE_DIR/code_review_{feature_id}.md`

---

### Stage 4: Execute Runtime Verification
- Execute local unit and integration tests to verify correctness: `./gradlew testDebugUnitTest`.
- Run instrumented Compose UI tests to check interactivity and transitions: target an emulator first (e.g. `ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest`), using a connected physical device only if no emulator is present.
- Execute the declared real platform boundary tests from `platform_validation.real_boundary_test_ids`. The test must exercise the shipped Android API/resource boundary and produce successful `connectedDebugAndroidTest` evidence. Fake recognizers, fake callbacks, JVM-only intent tests, and tests that merely instantiate a seam are supplemental and cannot close the finding.
- If the required runtime, device, model, locale, permission, or service is missing, record the command as failed/blocked and keep the verdict `Revise` or `Block`. Never record a skip, warning, or absent result as evidence of support.

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
> 3. **Harness File Assessment**: Verify that every required repository harness file is present and assess its quality details:
>    *   `feature_list.json`
>    *   `progress.md`
>    *   `session-handoff.md`
>    *   `clean-state-checklist.md`
>    *   `evaluator-rubric.md` (This file itself)
> 4. **Issue Verdict & Follow-Up**: Document the final verdict (`Accept` | `Revise` | `Block`) and explicitly itemize any missing evidence, required fixes, or review triggers in the **Required Follow-Up** block.
> 5. **Platform Hard Gate**: If the platform capability matrix is missing or invalid, or if only fake/JVM recognizer tests exist for a platform-bound behavior, the overall score MUST be below `5.0 / 5` and the verdict MUST be `Revise` or `Block`. The feature must transition to `To be fixed` through the score-based rule.

**⛔ STOP — present all review reports and the evaluator rubric to the user.**
The findings are presented for transparency, but the status transition is **driven automatically by the overall score** (see the rule below), not by a manual accept/fix decision.

After presenting the evaluation results, update the Harness Feature Tracker in `docs/product/product.md` with a **score-based transition**:
*   **If the overall score is `5.0 / 5` (perfect)** → transition the feature status from `To be reviewed` → `To be human reviewed`.
*   **If the overall score is less than `5.0 / 5` (not perfect)** → transition the feature status from `To be reviewed` → `To be fixed`. This routes the feature to the **harness-fix workflow** (`.agents/workflows/harness-fix.md`): the Generator resolves every finding in `$FEATURE_DIR/code_review_{feature_id}.md` and `$FEATURE_DIR/test_review_{feature_id}.md`, updates the per-finding status inside those reports, and then transitions to `To be human reviewed`.
*   Update the date to today and add the evaluation verdict (`Accept` / `Revise` / `Block`) and overall score to the notes column.
*   Run `bash harness/scripts/check-feature-lifecycle.sh` after the tracker update. Do not claim completion if it fails.

---

## Human-in-the-Loop Confirmation Points

1. **After Stage 5 (Quality Assessment)** — user sees all code findings, test findings, and the final evaluator rubric *(mandatory)*. The evaluator then applies the score-based transition automatically: `5.0 / 5` → `To be human reviewed`; `< 5.0 / 5` → `To be fixed` (the Generator then runs the **harness-fix workflow** — `.agents/workflows/harness-fix.md` — and transitions to `To be human reviewed`).
2. **Nit/Optional findings** — user decides which to accept *(optional but recommended)*
