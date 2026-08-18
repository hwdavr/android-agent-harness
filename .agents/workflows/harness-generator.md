---
description: You are a senior Android developer implementing features step-by-step using the harness-generator pipeline.
---

# Workflow: Harness Generator

## When to use
Use this workflow when you are acting as the **Generator** (Implementer) agent. This workflow ensures that you are properly oriented, verify safety baselines, implement features surgical-by-surgical, test continuously on runtime, and commit clean states back to the repository.

## Planning Authorization

This workflow starts only after the user approves `feature_list.json` and `sprint-contract.md` in one dated `docs/product/<YYYY-MM-DD>-<feature-short-name>/` workspace created by `harness-planning`. That approval authorizes implementation of the selected slice. Do not generate or request approval for a duplicate implementation plan in this workflow; the active feature description, sprint acceptance criteria, design, and verification commands are the implementation plan of record.

---

## 🔁 Gate Failure Resolution Policy

When **any** gate check fails during the pipeline (verification commands, checklist items, lifecycle checks, install commands, etc.), **do not stop the pipeline**. Instead, apply the following resolution loop **for each failing gate item independently**:

1. **Diagnose**: Read the full error output. Identify the root cause (compilation error, test failure, lint violation, missing file, etc.).
2. **Fix**: Apply a targeted, minimal fix for that specific failure. Follow all project rules (no suppressions, no workarounds).
3. **Re-run**: Re-execute **only** the failing gate command to confirm the fix resolved it.
4. **Retry limit**: Allow up to **3 fix attempts per gate item**. If a gate item still fails after 3 attempts, mark it as `⚠️ unresolved` in the summary, log the last error output, and **continue to the next gate item**.
5. **After all gate items are processed**: If any gate item remains `⚠️ unresolved`, mark the stage as `⚠️ partial` (not ✅) in the summary and list all unresolved items. Do **not** block the entire pipeline — proceed to the next stage, but clearly document the gap so the next session or evaluator can address it.

> [!WARNING]
> The resolution loop must never introduce suppression annotations, baseline changes, or rule exclusions to force a gate to pass. Only genuine code fixes are acceptable.

---

## 🔄 Stage Execution Pipeline

> **Routing**: If the active feature's tracker status is `To be fixed`, **stop here** — this workflow does not apply. Instead, follow the **[harness-fix workflow](harness-fix.md)** in full. It runs the Fix Mode Pipeline (resolve every `code_review` / `test_review` finding and update the per-finding status inside those reports, then transition to `To be human reviewed`). Stages 1–9 below apply only when implementing a new slice (status `In Progress` / `Awaiting implementation approval`).

### Stage 1 — Orient
Before making any changes or planning code, gather complete session and git context. Select the next task to implement.
*   **Action**: **INVOKE** the `feature-orient` skill via the Skill tool (name: `feature-orient`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
*   **Objective**: Run `bash harness/scripts/check-feature-lifecycle.sh`, select the approved `docs/product/` workspace from the Harness Feature Tracker by status, reconstruct the prior session, establish the per-slice source of truth (`$FEATURE_DIR/summary_{feature_id}.md`), read and validate `$FEATURE_DIR/platform-capability-matrix.md`, and select one task from `$FEATURE_DIR/feature_list.json`. If the slice affects UI, read `docs/product/design_system.md`, the approved feature `design.md`, and its mockups before implementation.

### Stage 2 — Setup
Verify target emulator/device runtime environment readiness.
*   **Action**:
    1. Run command line tools to check for active ADB devices:
        ```bash
        adb devices
        ```
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Setup** stage status to completed (✅) with notes and current timestamp.
*   **Objective**: Confirm device availability for runtime testing. Always use an emulator for instrumented UI tests (e.g. `ANDROID_SERIAL=emulator-5554`), and fallback to a connected physical device only when no emulator is present. Register progress in the summary.

### Stage 3 — Verify Baseline
Ensure that the existing codebase compiles and all tests pass before making any changes. The previous session or developer may have introduced bugs or broken tests.
*   **Action**:
    1. Run full static checks and JVM test suites:
        ```bash
        ./gradlew assembleDebug
        ./gradlew testDebugUnitTest
        ```
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Verify Baseline** stage status to completed (✅) with notes and current timestamp.
*   **Objective**: Confirm the repository is in a perfectly stable, compilable, and green state. If the baseline is broken, stop and fix existing regressions first! Register status in `$FEATURE_DIR/summary_{feature_id}.md`.

### Stage 4 — Implement
Build out the selected feature across the necessary layers.
*   **Action**:
    1. **INVOKE** the `android-implementation` skill via the Skill tool (name: `android-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Implement** stage status to completed (✅) with list of created/modified files.
*   **Objective**: All layers successfully implemented, `./gradlew assembleDebug` compiles cleanly, UI changes conform to `docs/product/design_system.md` plus approved feature exceptions, and progress is logged in the summary.

### Stage 5 — Test
Verify the correctness of the implemented behavior visually and logically.
*   **Action**:
    1. **INVOKE** the `android-testing` skill via the Skill tool (name: `android-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Implement every `Acceptance Test Cases` row in the selected user story. The primary acceptance test must exercise the production entry point; an isolated helper or use-case test cannot substitute for user-visible or cross-layer behavior. Verify through the actual UI/API and meet code coverage targets (overall project **≥ 80%**, ViewModel & Use Case **≥ 90%**).
    2. For every `platform_validation.real_boundary_test_ids` entry listed in the selected slice's `acceptance_test_ids`, run the declared instrumented test against the required runtime using the real shipped Android boundary. Do not replace it with a fake recognizer, JVM-only intent assertion, or manually emitted callback. If the emulator, device, model, locale, permission, or platform service is unavailable, let the command fail and record the gate as `Blocked`/`Revise`; do not mark it skipped or passing. A slice that does not own a declared real-boundary test validates the contract without being blocked on a later slice's unimplemented boundary.
    3. Run `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"` and attach its exit status and output to the feature evidence. The no-slice command remains mandatory during final feature evaluation after every boundary-owning slice is complete.
    4. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Test** stage status to completed (✅) detailing coverage percentages, passed test counts, platform matrix results, and any blocked runtime explicitly.
*   **Objective**: All local tests pass cleanly, coverage targets are fully met, and verification evidence is documented in the summary.

### Stage 6 — Code Quality Fix
Run all static check suites, lint rules, and custom compliance rules, and resolve all violations.
*   **Action**: **INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
*   **Objective**: Diagnose and resolve all formatting, quality, localization, and architectural style guidelines issues, logging check success in `$FEATURE_DIR/summary_{feature_id}.md`.

### Stage 7 — Update State
Update repository history, project task logs, and product documentation to reflect completion.

> [!IMPORTANT]
> **Strict Verification Gate**: You **CANNOT** directly or arbitrarily change a feature's status to `passing` in `feature_list.json`. Transitioning a feature to `passing` is a gate controlled exclusively by executing successful verification commands.
>
> **Gate Check Policy**:
> 1. **Identify Gate Criteria**: Read the selected user story in `$FEATURE_DIR/sprint-contract.md`. Every `Acceptance Test Cases` command is a mandatory gate. The active feature's `"verification"` field must reference the same Test IDs and commands.
> 2. **Execute Each Command**: Run every verification command (e.g., `./gradlew testDebugUnitTest` or specific test runner script). Process them **one by one**.
> 3. **On Failure — Apply Gate Failure Resolution Policy**: If any verification command fails (exit code `non-zero`), **do not stop**. Apply the **Gate Failure Resolution Policy** (diagnose → fix → re-run, up to 3 attempts) for that specific failing command before moving to the next one.
> 4. **Validate & Attach Evidence**:
>    *   The status can **ONLY** transition to `passing` if **every** acceptance-test command eventually executes successfully (exit code `0`) — either on the first run or after resolution.
>    *   You **MUST** attach objective evidence for every Test ID, including the command, exit status, fix attempts (if any), and final result, inside the `"evidence"` field of the active feature object.
>    *   If any verification command remains unresolved after 3 fix attempts, the status must be marked as `blocked` or returned to `in_progress`. Document all unresolved items.
>    *   A slice that owns a declared real platform boundary test cannot transition to `passing` unless `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"` exits `0`. A non-owning slice must run the same slice-scoped command to validate the capability contract; missing matrices, pending/unavailable runtime rows, skipped environments, or fake-only recognizer tests remain hard failures for the boundary-owning slice and final feature evaluation.
>    *   A visual-verification owner cannot transition to `passing` unless `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"` exits `0`. This requires a non-empty screenshot and a `visual_evidence/reference-anchor-verification.md` row for every visual Test ID; the row must connect the approved reference to a visual bounds `testTag`, a runtime assertion, and a concrete measured relationship.

*   **Action**:
    1. Once verification passes and evidence is attached, update `$FEATURE_DIR/feature_list.json` and `$FEATURE_DIR/progress.md`.
    2. Update `docs/product/product.md` directly:
        *   Update the **Product Portfolio Summary** to reflect the delivered slice.
        *   Add the feature to **Current Product Capabilities** with its delivered behavior and notable implementation notes.
        *   Remove the feature from the **Roadmap — Planned Features** section if it is fully delivered, or update its priority column to reflect remaining sub-features.
        *   Update the `*Document last updated*` date at the bottom of the file.
        *   If every feature in `$FEATURE_DIR/feature_list.json` is now `passing`, update the Harness Feature Tracker status to `To be reviewed` in place and update its date/notes (do not move or rename the workspace). **NEVER transition directly to `To be human reviewed`** — only the Evaluator agent (via `harness-evaluation`) is authorized to make that transition after scoring. Otherwise, keep the Harness Feature Tracker `In Progress` while slices remain.
        *   Run `bash harness/scripts/check-feature-lifecycle.sh` after the tracker update. Do not claim completion or commit if it fails.
    3. Commit only the **source code, test changes, and product documentation** for the implemented feature:
        ```bash
        git commit -m "feat(<area>): <short description of implemented feature>"
        ```
    4. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Update State** stage status to completed (✅), logging the commit hash and verification execution outcome.
*   **Objective**: Ensure all state updates are backed by mechanical, verifiable evidence. The stable product workspace remains at the same path throughout delivery.

### Stage 8 — Clean Exit
Ensure that the final repository state is clean, verified, and fully prepared for the next developer or agent session.

> [!IMPORTANT]
> **Checklist & Handoff Policy**:
> 1. **Run Clean State Checklist**: Execute and verify every single item in the **[`clean-state-checklist-template.md`](../../harness/templates/clean-state-checklist-template.md)**. Process each checklist item **one by one**. If any item fails, **do not stop** — apply the **Gate Failure Resolution Policy** (diagnose → fix → re-run, up to 3 attempts per item) before moving to the next checklist item. After processing all items, all checks **SHOULD** pass; any remaining `⚠️ unresolved` items must be documented in the session handoff.
> 2. **Produce Session Handoff**: Create or update **`$FEATURE_DIR/session-handoff.md`** by strictly following the format and fields defined in **[`session-handoff-template.md`](../../harness/templates/session-handoff-template.md)**. Detail what is working, what changed, unverified paths, risks, unresolved gate items, and next steps.
> 3. **Never move the feature directory.** Its `docs/product/` path is stable; only tracker and per-slice statuses change.

*   **Action**:
    1. Execute the verification command one last time to ensure no regression was introduced, verify all checklist criteria, and write `$FEATURE_DIR/session-handoff.md`.
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Clean Exit** stage status to completed (✅), transition the selected slice summary to Complete, and document key outcomes, open items, and handoff decisions.
*   **Objective**: Leave the repository in a completely green, stable, and self-documenting state that a fresh session can immediately pick up and resume.

### Stage 9 — Install App To Device
Install the completed debug build to all connected devices and emulators as the final generator step.

*   **Action**:
    1. Install the app to every connected device and emulator:
        ```bash
        ./gradlew installDebug
        ```
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Install App To Device** stage status to completed (✅), logging the connected device IDs, install command, timestamp, and exit status.
*   **Objective**: Leave the implemented feature installed on every connected runtime device for immediate manual review.
*   **Gate**: The install command exits with code `0`. If the install fails, apply the **Gate Failure Resolution Policy** (diagnose → fix → re-run, up to 3 attempts). If no device is connected, mark this stage blocked with the `adb devices` output and do not claim the generator session is fully complete.
