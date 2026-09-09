---
description: You are a senior Android developer implementing features step-by-step using the harness-generator pipeline.
---

# Workflow: Harness Generator

## When to use
Use this workflow when you are acting as the **Generator** (Implementer) agent. This workflow ensures that you are properly oriented, verify safety baselines, implement features surgical-by-surgical, test continuously on runtime, and commit clean states back to the repository.

## Planning Authorization

This workflow starts only after the user approves `feature_list.json` and `sprint-contract.md` in one dated `docs/product/<YYYY-MM-DD>-<feature-short-name>/` workspace created by `harness-planning`. That approval authorizes implementation of the selected slice. Do not generate or request approval for a duplicate implementation plan in this workflow; the active feature description, sprint acceptance criteria, design, and verification commands are the implementation plan of record.

Before implementation begins, preserve the approved Rule Applicability decisions from
the feature specification in the slice evidence and carry each Required row into its
implementation and verification records.

---

## Gate Semantics

Every required stage gate is a hard stop. A gate may advance only after its command exits
`0` and its required evidence is recorded. Any failure or unavailable prerequisite must
be recorded as `⚠️ Blocked` or non-passing, and the workflow must stop before the next stage.

---

## 🔄 Stage Execution Pipeline

> **Routing**: If the active feature's tracker status is `To be fixed`, **stop here** — this workflow does not apply. Instead, follow the **[harness-fix workflow](harness-fix.md)** in full. It runs the Fix Mode Pipeline (resolve every `code_review` / `test_review` finding and update the per-finding status inside those reports, then transition to `To be human reviewed`). Stages 1–9 below apply only when implementing a new slice (status `In Progress` / `Awaiting implementation approval`).

### Stage 1 — Orient
Before making any changes or planning code, gather complete session and git context. Select the next task to implement.
*   **Action**: **INVOKE** the `feature-orient` skill via the Skill tool (name: `feature-orient`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
*   **Objective**: Run `bash harness/scripts/check-feature-lifecycle.sh`, select the approved `docs/product/` workspace from the Harness Feature Tracker by status, run `bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"`, and establish the sprint contract plus `feature_list.json` as the only requirement/execution authorities. The slice summary records their paths and hashes as Context Provenance; it does not duplicate scope, acceptance criteria, or the Rule Applicability matrix. Read and validate `$FEATURE_DIR/platform-capability-matrix.md` when the feature is platform-bound (`platform_validation.required: true`). If the index reports `affects_ui: true`, read `docs/product/design_system.md`, the approved feature `design.md`, and its mockups before implementation.

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
    1. Run the repository-wide source-rule bundle and JVM test suites:
        ```bash
        bash harness/scripts/check-full-source-rules.sh
        ./gradlew assembleDebug
        ./gradlew testDebugUnitTest
        ```
       The source-rule bundle always scans the complete production and test source
       trees. It runs every checker even when one fails and returns non-zero if any
       checker reports a violation; record the complete output before stopping.
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Verify Baseline** stage status to completed (✅) with notes and current timestamp.
*   **Objective**: Confirm the repository is in a perfectly stable, compilable, and green state. If the baseline is broken, stop and fix existing regressions first! Register status in `$FEATURE_DIR/summary_{feature_id}.md`.

### Stage 4 — Implement
Build out the selected feature across the necessary layers.
*   **Action**:
    1. **INVOKE** the `android-implementation` skill via the Skill tool (name: `android-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Implement** stage status to completed (✅) with list of created/modified files.
*   **Objective**: Only the layers and conditional rules selected by the approved slice are implemented, `./gradlew assembleDebug` compiles cleanly, UI changes conform to `docs/product/design_system.md` plus approved feature exceptions, and progress is logged in the summary.

This workflow is implementation-first; do not insert a feature-level RED/TDD stage before Stage 4.

### Stage 5 — Test
Verify the correctness of the implemented behavior visually and logically.
*   **Action**:
    1. **INVOKE** the `android-testing` skill via the Skill tool (name: `android-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Implement every `Acceptance Test Cases` row in the selected user story. The primary acceptance test must exercise the production entry point; an isolated helper or use-case test cannot substitute for user-visible or cross-layer behavior. Verify through the actual UI/API and meet code coverage targets (overall project **≥ 80%**, ViewModel & Use Case **≥ 90%**).
    2. For every `platform_validation.real_boundary_test_ids` entry listed in the selected slice's `acceptance_test_ids`, run the declared instrumented test against the required runtime using the real shipped Android boundary. Do not replace it with a fake recognizer, JVM-only intent assertion, or manually emitted callback. If the emulator, device, model, locale, permission, or platform service is unavailable, let the command fail and record the gate as `Blocked`/`Revise`; do not mark it skipped or passing. A slice that does not own a declared real-boundary test validates the contract without being blocked on a later slice's unimplemented boundary.
    3. Run `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"` and attach its exit status and output to the feature evidence. The no-slice command remains mandatory during final feature evaluation after every boundary-owning slice is complete.
    4. Run `bash harness/scripts/check-journey-registry.sh --run-all` to verify that the current implementation does not regress any existing critical journey. A failure blocks the pipeline.
    5. Run `bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --test "$FEATURE_ID"` before leaving the Test stage. The command must resolve every selected acceptance row to its source method and, for explicit rich-text appearance claims, the named instrumented method must pass the rendered-output contract.
    6. For every acceptance claim that says rich text or an inline formatting mark is visibly rendered, ensure the named instrumented method passes `bash harness/scripts/check-rendered-output-contract.sh` with source-fed `captureToImage()` and an explicit pixel comparison. A model/state assertion or non-empty screenshot alone is not rendered-output evidence.
    7. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Test** stage status to completed (✅) detailing coverage percentages, passed test counts, platform matrix results, and any blocked runtime explicitly.
*   **Objective**: All local tests pass cleanly, coverage targets are fully met, and verification evidence is documented in the summary.

### Stage 6 — Code Quality Fix
Run all static check suites, lint rules, and custom compliance rules, and resolve all violations.
*   **Action**: **INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
*   **Required gate**: The skill MUST run `bash harness/scripts/check-full-source-rules.sh` after its individual Gradle checks. This bundle is the authoritative repository-wide architecture, Compose, localization, navigation, and test-assertion gate; do not substitute a changed-file invocation.
*   **Objective**: Diagnose and resolve all formatting, quality, localization, and architectural style guidelines issues, logging check success in `$FEATURE_DIR/summary_{feature_id}.md`.

### Stage 7 — Update State
Update repository history, project task logs, and product documentation to reflect completion.

> [!IMPORTANT]
> **Strict Verification Gate**: You **CANNOT** directly or arbitrarily change a feature's status to `passing` in `feature_list.json`. Transitioning a feature to `passing` is a gate controlled exclusively by executing successful verification commands.
>
> **Gate Check Policy**:
> 1. **Identify Gate Criteria**: Read the selected user story in `$FEATURE_DIR/sprint-contract.md`. Every `Acceptance Test Cases` command is a mandatory gate. The active feature's `"verification"` field must reference the same Test IDs and commands.
> 2. **Validate fresh evidence**: Reuse successful Test-stage evidence only after `bash harness/scripts/check-evidence-receipt.sh <receipt.json> --source <hash> --build-config <hash> --command <hash> --runtime <hash>` confirms that the production sources, build/test configuration, declared verification command, runtime target, exit code, and evidence file are unchanged. Re-run only the affected command when validation fails; do not repeat a green acceptance suite solely to copy its output into a later stage.
> 3. **On Failure — bounded diagnosis and retry**: If any verification command fails (exit code `non-zero`), keep the stage non-passing and diagnose, fix, and re-run that specific command up to three times. If it remains non-zero, record the gate as `⚠️ Blocked` or non-passing and stop before the next verification item.
> 4. **Validate & Attach Evidence**:
>    *   The status can **ONLY** transition to `passing` if **every** acceptance-test command eventually executes successfully (exit code `0`) — either on the first run or after resolution.
>    *   You **MUST** attach objective evidence for every Test ID, including the command, exit status, fix attempts (if any), and final result, inside the `"evidence"` field of the active feature object.
>    *   If any verification command remains unresolved after 3 fix attempts, the status must be marked as `blocked` or returned to `in_progress`. Document all unresolved items.
>    *   A slice that owns a declared real platform boundary test cannot transition to `passing` unless `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"` exits `0`. A non-owning slice must run the same slice-scoped command to validate the capability contract; missing matrices, pending/unavailable runtime rows, skipped environments, or fake-only recognizer tests remain hard failures for the boundary-owning slice and final feature evaluation.
>    *   A visual-verification owner cannot transition to `passing` unless `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"` exits `0`. This requires a non-empty screenshot and a `visual_evidence/reference-anchor-verification.md` row for every visual Test ID; the row must connect the approved reference to a visual bounds `testTag`, a runtime assertion, and a concrete measured relationship. For rich-text or inline-formatting appearance claims, the same visual row must name a source method that passes the rendered-output contract (`captureToImage()` plus an explicit pixel comparison); state-only marks and screenshot existence are insufficient. Approval also requires promoting every non-anchor-only contract screenshot to `UX/golden-baselines/` (`compare-visual-evidence.sh --promote-golden`) so the binding golden regression comparison has its reference; design-mockup comparisons are informational and never block the transition.

*   **Action**:
    1. Once verification passes and evidence is attached, update `$FEATURE_DIR/feature_list.json` and `$FEATURE_DIR/progress.md`.
    2. Update `docs/product/product.md` directly:
        *   Update the **Product Portfolio Summary** to reflect the delivered slice.
        *   Add the feature to **Current Product Capabilities** with its delivered behavior and notable implementation notes.
        *   Remove the feature from the **Roadmap — Planned Features** section if it is fully delivered, or update its priority column to reflect remaining sub-features.
        *   Update the `*Document last updated*` date at the bottom of the file.
        *   If every feature in `$FEATURE_DIR/feature_list.json` is now `passing`, update the Harness Feature Tracker status to `To be reviewed` in place and update its date/notes (do not move or rename the workspace). **NEVER transition directly to `To be human reviewed`** — only the Evaluator agent (via `harness-evaluation`) is authorized to make that transition after scoring. Otherwise, keep the Harness Feature Tracker `In Progress` while slices remain.
        *   Run `bash harness/scripts/check-feature-lifecycle.sh` after the tracker update. Do not claim completion or commit if it fails.
    3. If the shipped slice has `production_journey.required: true`, register the journey in `docs/product/journey-registry.yaml` using the sprint-contract values. Run `bash harness/scripts/check-journey-registry.sh --validate` to confirm the entry is well-formed.
    4. Populate the `## Observability & Execution Metrics` section directly in `$FEATURE_DIR/summary_{feature_id}.md` (following [`harness/templates/summary-template.md`](../../harness/templates/summary-template.md), recording model name, duration, files modified, commands executed, retries, and the embedded `json:metrics` block). Run `bash harness/scripts/check-harness-metrics.sh --validate "$FEATURE_DIR/summary_{feature_id}.md"` to verify metrics integrity.

    5. Commit only the **source code, test changes, and product documentation** for the implemented feature:
        ```bash
        git commit -m "feat(<area>): <short description of implemented feature>"
        ```
    6. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Update State** stage status to completed (✅), logging the commit hash and verification execution outcome.
*   **Objective**: Ensure all state updates are backed by mechanical, verifiable evidence. The stable product workspace remains at the same path throughout delivery.

### Stage 8 — Clean Exit
Ensure that the final repository state is clean, verified, and fully prepared for the next developer or agent session.

> [!IMPORTANT]
> **Checklist & Handoff Policy**:
> 1. **Run Clean State Checklist**: Copy the Core checks and only the triggered conditional sections from **[`clean-state-checklist-template.md`](../../harness/templates/clean-state-checklist-template.md)**. Record every omitted trigger as `N/A — <feature-specific reason>`. Reference fresh Test and Code Quality evidence while its receipt remains valid; rerun only invalidated evidence. A failed required item keeps Clean Exit non-passing and stops the pipeline.
> 2. **Produce Session Handoff**: Create or update **`$FEATURE_DIR/session-handoff.md`** by strictly following the format and fields defined in **[`session-handoff-template.md`](../../harness/templates/session-handoff-template.md)**. Detail what is working, what changed, unverified paths, risks, unresolved gate items, and next steps.
> 3. **Verify Observability Metrics**: Run `bash harness/scripts/check-harness-metrics.sh --validate "$FEATURE_DIR/summary_{feature_id}.md"` to confirm execution metrics are complete.
> 4. **Never move the feature directory.** Its `docs/product/` path is stable; only tracker and per-slice statuses change.

*   **Action**:
    1. Verify all checklist criteria, reference fresh Test and Code Quality evidence, and write `$FEATURE_DIR/session-handoff.md`. Re-run only a verification command invalidated by a later relevant change.
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Clean Exit** stage status to completed (✅), transition the selected slice summary to Complete, and document key outcomes, open items, and handoff decisions.
*   **Objective**: Leave the repository in a completely green, stable, and self-documenting state that a fresh session can immediately pick up and resume.

### Stage 9 — Install App To Device
Install the completed debug build when the slice affects UI, requires instrumented/platform
verification, or the user explicitly requests installation. Otherwise record
`N/A — no Android runtime or installation boundary in the approved scope`.

*   **Action**:
    1. Install the app to every connected device and emulator:
        ```bash
        ./gradlew installDebug
        ```
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Install App To Device** stage status to completed (✅), logging the connected device IDs, install command, timestamp, and exit status.
*   **Objective**: Leave the implemented feature installed on every connected runtime device for immediate manual review.
*   **Gate**: When required, the install command must exit 0; failure or no connected device is
    `⚠️ Blocked`. When not required, the explicit N/A rationale completes the stage without an
    install command.
