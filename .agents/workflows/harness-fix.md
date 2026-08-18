---
description: You are a senior Android developer resolving evaluator findings after a feature scored below 5.0/5 — harness-fix workflow.
---

# Workflow: Harness Fix

## When to use
- Use this workflow when you are acting as the **Generator** (Implementer) agent in **Fix Mode**.
- The active feature's tracker status is `To be fixed`. This status is set by the Evaluator ([`harness-evaluation.md`](harness-evaluation.md)) when the overall score is below `5.0 / 5`.
- The Evaluator wrote `$FEATURE_DIR/code_review_{feature_id}.md` and `$FEATURE_DIR/test_review_{feature_id}.md`. Your job is to resolve **every** finding in those reports, re-verify against the sprint-contract acceptance gates, and transition the feature to `To be human reviewed`.

> Do **NOT** run the `harness-generator.md` Stages 1–9 here — there is no new slice to implement and every slice is already `passing`. Do **NOT** flip any slice to `in_progress`, do **NOT** re-run lifecycle transition logic, and do **NOT** regenerate an implementation plan.

---

## 📌 Report Status Update Policy (mandatory)

While fixing, you **MUST** record the resolution of each finding **inside the review reports themselves**, not only in the summary. The reports are the durable evidence the human reviewer and the next Evaluator read; a finding left at `REVISION REQUIRED` with no in-report update looks unresolved even after a fix pass.

### Per-finding status convention
Every review finding carries one of three fix statuses, set by you during this workflow:

| Fix Status | Meaning |
|---|---|
| `Fixed ✅` | Root-cause fix applied, re-verification passed. Append the commit hash and the verification command that proves it. |
| `Unresolved ⚠️` | Could not be fixed within the 3-attempt Gate Failure Resolution Policy. Append the last error and the reason it remains open. |
| `Won't fix — see note` | Only when the finding is a documented false positive **and** the user explicitly approves waiving it. Never use this to skip a real issue. |

### Where to write the status
- **`$FEATURE_DIR/code_review_{feature_id}.md`** — under **each** numbered item in `## Required Findings`, append a blockquote line:
  ```
  > **Fix Status:** Fixed ✅ — <one-line fix> (commit `<sha>`; verified: `<command>` exit 0; YYYY-MM-DD)
  ```
  Then update the `## Verdict` block with an overall fix outcome line: `> **Fix Pass:** <N>/<M> findings fixed; <K> unresolved (YYYY-MM-DD).`
- **`$FEATURE_DIR/test_review_{feature_id}.md`** — in the Requirement-to-Test Traceability table, set a `Fix Status` column value (`Fixed ✅` / `Unresolved ⚠️` / `PASS (unchanged)`) on every row that was `REVISION REQUIRED` or `Missing`. Add a `## Fix Pass Summary` section listing counts and any unresolved rows with their last error.

A finding is not considered resolved until its in-report status line exists and matches the summary.

---

## 🔁 Gate Failure Resolution Policy

When **any** gate check fails during this pipeline (verification commands, checklist items, lifecycle checks, install commands, etc.), **do not stop the pipeline**. Apply the following loop **for each failing gate item independently**:

1. **Diagnose**: Read the full error output. Identify the root cause.
2. **Fix**: Apply a targeted, minimal fix for that specific failure. Follow all project rules (no suppressions, no workarounds).
3. **Re-run**: Re-execute **only** the failing gate command to confirm the fix.
4. **Retry limit**: Up to **3 fix attempts per gate item**. If still failing, mark it `Unresolved ⚠️` (both in the summary and in the relevant review report) and continue to the next item.
5. **After all gate items are processed**: If any item remains `Unresolved ⚠️`, mark the stage `⚠️ partial` (not ✅) and document the gap. Do **not** block the whole pipeline.

> [!WARNING]
> Never introduce `@Suppress`, `@SuppressLint`, `tools:ignore`, ktlint/detekt disable comments, baselines, or rule exclusions to force a gate to pass. Only genuine code fixes are acceptable.

---

## 🔄 Fix Mode Pipeline

### Fix-Stage 1 — Orient
*   **Action**:
    1. Run `bash harness/scripts/check-feature-lifecycle.sh`; confirm the active feature row is `To be fixed`. Stop if validation fails.
    2. Read, in order:
        1. `$FEATURE_DIR/sprint-contract.md` — Acceptance Test Cases and verification commands (the gates that must stay green).
        2. `$FEATURE_DIR/platform-capability-matrix.md` — API/runtime contract and unsupported-environment policy.
        3. `$FEATURE_DIR/evaluator-rubric.md` — overall score, category scores, verdict, and Required Follow-Up.
        4. `$FEATURE_DIR/code_review_{feature_id}.md` — every `REVISION REQUIRED` / `FAIL` item.
        5. `$FEATURE_DIR/test_review_{feature_id}.md` — every coverage gap, missing assertion, or failing scenario.
        6. `$FEATURE_DIR/session-handoff.md` and `$FEATURE_DIR/progress.md` — prior context.
    3. Build a consolidated, deduplicated fix list. Each item must trace to a specific report section (and line). Initialize (or append to) `$FEATURE_DIR/summary_{feature_id}.md` a **Fix Pass** section listing every fix item with status `pending`.
*   **Objective**: A single source of truth for every review finding that must be resolved.

### Fix-Stage 2 — Setup
*   **Action**: Run `adb devices` to confirm runtime readiness. Use an emulator for instrumented UI re-verification (e.g. `ANDROID_SERIAL=emulator-5554`), and use a connected physical device only if no emulator is present. Record the output in the summary.
*   **Objective**: Confirm runtime readiness; mark Fix-Stage 2 ✅ with timestamp.

### Fix-Stage 3 — Verify Baseline
*   **Action**:
    1. Run `./gradlew assembleDebug` and `./gradlew testDebugUnitTest`.
    2. If red, stop and fix the regression first (Gate Failure Resolution Policy applies). Do not begin fixing review findings on a broken baseline.
    3. Mark Fix-Stage 3 ✅ in the summary.
*   **Objective**: Confirm the repository is green before any review fix lands.

### Fix-Stage 4 — Fix Findings & Update Report Status
*   **Action**:
    1. **INVOKE** the `android-implementation` skill via the Skill tool (name: `android-implementation`) for code changes, and the `android-testing` skill via the Skill tool (name: `android-testing`) for test changes. Reading the SKILL.md manually is not a substitute.
    2. For each item in the fix list, apply a targeted, minimal fix that addresses the root cause. Do **NOT** introduce new scope — fix only what the reports flagged.
    3. **Update the status inside the review reports** (per the Report Status Update Policy): as each finding is fixed, append its `> **Fix Status:** Fixed ✅ — …` line in `code_review_{feature_id}.md`, and set its `Fix Status` column / row in `test_review_{feature_id}.md`. If a finding cannot be fixed within 3 attempts, mark it `Unresolved ⚠️` in **both** the report and the summary.
    4. Mark each item `fixed` (or `unresolved`) in the summary with the file/commit reference.
*   **Objective**: Every `code_review` and `test_review` finding has a root-cause fix **and** an in-report status line; no suppressions.

### Fix-Stage 5 — Re-verify
*   **Action**:
    1. Re-run, **one by one**, every verification command listed in `$FEATURE_DIR/sprint-contract.md` Acceptance Test Cases. Apply the Gate Failure Resolution Policy on any failure (up to 3 attempts per command).
    2. Re-run the global quality gates: `./gradlew ktlintCheck`, `./gradlew detekt`, `./gradlew lint`, and `./gradlew koverLog` (coverage ≥ 80% overall; ≥ 90% for ViewModel & Use Case).
    3. Attach objective evidence (command + exit status + fix attempts) to each Test ID's `evidence` field in `$FEATURE_DIR/feature_list.json`. All slices must remain `passing`.
    4. Run `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate`. Missing matrices, unavailable/pending/skipped environments, and fake-only platform tests remain hard failures; record them as `Unresolved ⚠️` rather than passing them through.
    5. Run `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"` when visual verification is required. Every final visual method must be declared in the sprint contract, have successful connected evidence and a non-empty screenshot, and have reference-anchor proof in `visual_evidence/reference-anchor-verification.md` for the approved design.
    6. Reconcile the in-report statuses with re-verification: any finding whose verification command still fails must read `Unresolved ⚠️` in the report (not `Fixed ✅`).
*   **Objective**: All acceptance-test commands and quality gates pass with evidence attached; report statuses are consistent with re-verification results.

### Fix-Stage 6 — Update State
*   **Action**:
    1. Finalize the in-report status updates in `$FEATURE_DIR/code_review_{feature_id}.md` (per-finding lines + the `## Verdict` `Fix Pass` line) and `$FEATURE_DIR/test_review_{feature_id}.md` (`Fix Status` column + `## Fix Pass Summary`).
    2. Update `$FEATURE_DIR/progress.md` and `$FEATURE_DIR/feature_list.json` evidence.
    3. Update `docs/product/product.md`:
        *   Transition the feature status `To be fixed` → `To be human reviewed`.
        *   Update the date to today and append to the notes column: "Fix pass applied; re-verification evidence attached; <N>/<M> findings fixed."
        *   Update the `*Document last updated*` date.
        *   Run `bash harness/scripts/check-feature-lifecycle.sh` after the tracker update. Do not claim completion if it fails.
    4. Commit the source, test, report-status, and documentation changes:
        ```bash
        git commit -m "fix(<area>): resolve evaluator findings from code_review and test_review"
        ```
    5. Mark Fix-Stage 6 ✅ in the summary, logging the commit hash.
*   **Objective**: Tracker transitioned to `To be human reviewed`, backed by mechanical evidence and updated review reports.

### Fix-Stage 7 — Clean Exit
*   **Action**:
    1. Run every item in [`harness/templates/clean-state-checklist-template.md`](../../harness/templates/clean-state-checklist-template.md) (Gate Failure Resolution Policy applies per item).
    2. Update `$FEATURE_DIR/session-handoff.md` per [`harness/templates/session-handoff-template.md`](../../harness/templates/session-handoff-template.md), documenting what was fixed, the re-verification evidence, any `Unresolved ⚠️` findings, residual risks, and that the feature is now `To be human reviewed`.
    3. Mark Fix-Stage 7 ✅ in the summary.
*   **Objective**: Repository left green, stable, and self-documenting for human review.

### Fix-Stage 8 — Install App To Device
*   **Action**:
    1. Install the debug build to every connected device and emulator:
        ```bash
        ./gradlew installDebug
        ```
    2. Mark Fix-Stage 8 ✅ in the summary, logging device IDs, command, timestamp, and exit status.
*   **Objective**: The fixed build is installed on every connected runtime device for immediate manual review.
*   **Gate**: The install command exits with code `0`. If the install fails, apply the Gate Failure Resolution Policy. If no device is connected, mark this stage blocked with the `adb devices` output.

---

## Human-in-the-Loop Confirmation Points

1. **After Fix-Stage 6 (Update State)** — user sees the updated review reports (per-finding fix statuses), re-verification evidence, and the tracker transition to `To be human reviewed` *(mandatory)*.
2. **Unresolved findings** — any `Unresolved ⚠️` finding must be surfaced to the user; the user decides whether to accept the residual risk or require another fix pass *(mandatory if any exist)*.
