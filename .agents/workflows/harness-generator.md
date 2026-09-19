---
description: Implement an approved complex Android feature slice through harness-generator stages.
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
*   **Action**: Run `bash harness/scripts/check-stage-artifacts.sh harness-generator orient "$FEATURE_DIR" "$FEATURE_ID"` after the orientation skill completes. If it fails, record Stage 1 as `⚠️ Blocked` and stop.
*   **Objective**: Run `bash harness/scripts/check-feature-lifecycle.sh`, select the approved `docs/product/` workspace from the Harness Feature Tracker by status, run `bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"`, and establish the sprint contract plus `feature_list.json` as the only requirement/execution authorities. The slice summary must exist at `$FEATURE_DIR/summary_{feature_id}.md` and records their paths and hashes as Context Provenance; it does not duplicate scope, acceptance criteria, or the Rule Applicability matrix. Read and validate `$FEATURE_DIR/platform-capability-matrix.md` when the feature is platform-bound (`platform_validation.required: true`). If the index reports `affects_ui: true`, read `docs/product/design_system.md`, the approved feature `design.md`, and its mockups before implementation.
*   **Gate**: `check-stage-artifacts.sh harness-generator orient` must exit `0` and find the exact `$FEATURE_DIR/summary_{feature_id}.md` file. A missing summary or missing feature id is `⚠️ Blocked`; do not advance to Setup.

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
*   **Objective**: Only the layers and conditional rules selected by the approved slice are implemented, including
    test-target infrastructure when the slice owns a deterministic loopback boundary. `./gradlew assembleDebug`
    compiles cleanly, UI changes conform to `docs/product/design_system.md` plus approved feature exceptions, and
    production ViewModels/repositories remain unaware of fixture selection.

This workflow is implementation-first; do not insert a feature-level RED/TDD stage before Stage 4.

### Stage 5 — Test
Verify the correctness of the implemented behavior visually and logically.
*   **Action**:
    1. **INVOKE** the `android-testing` skill via the Skill tool (name: `android-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Implement every `Acceptance Test Cases` row in the selected user story. The primary acceptance test must exercise the production entry point; an isolated helper or use-case test cannot substitute for user-visible or cross-layer behavior. When the selected slice owns a loopback HTTP server, the acceptance test must drive the shipped app Retrofit/OkHttp path, assert redacted server receipts, and fail on listener/setup failure. Verify through the actual UI/API and meet code coverage targets (overall project **≥ 80%**, ViewModel & Use Case **≥ 90%**).
    2. For every `platform_validation.real_boundary_test_ids` entry listed in the selected slice's `acceptance_test_ids`, run the declared instrumented test against the required runtime using the real shipped Android boundary. Do not replace it with a fake recognizer, JVM-only intent assertion, or manually emitted callback. If the emulator, device, model, locale, permission, or platform service is unavailable, let the command fail and record the gate as `Blocked`/`Revise`; do not mark it skipped or passing. A slice that does not own a declared real-boundary test validates the contract without being blocked on a later slice's unimplemented boundary.
    3. If the selected slice declares `requires_visual_verification: true`, **INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`). Before capture, create and obtain approval for one canonical `visual_evidence/visual-target.json` manifest. It is the single source of truth for the target appearance, concrete device, logical size, locale, and every named deterministic content state. Run `bash harness/scripts/visual-target-prompt.sh --target "$FEATURE_DIR/visual_evidence/visual-target.json" --state <content_state_id>` when generating each mockup, and use the same manifest for the emulator with `bash harness/scripts/prepare-visual-runtime.sh --target "$FEATURE_DIR/visual_evidence/visual-target.json"`. The `visual_evidence/reference-map.json` then contains only one explicit `state_id` mapping per runtime screenshot; no filename/token inference or duplicated metadata is allowed. The same state ID must appear in that capture's sprint-contract row, and each target state must record approved handling for time, user content, identifiers, and keyboard variation. A mask is allowed only with an approval rationale. The anchor report must declare the same appearance, device, logical size, and locale. Run `bash harness/scripts/compare-visual-evidence.sh --feature "$FEATURE_DIR" --crop-insets`, classify any Critical or unresolved Major deviation, and preserve the report and diff overlays. Finally run `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate`; it requires both binding approved-mockup comparison and structural-anchor proof. A missing target manifest, state mapping, target mismatch, unapproved mask, emulator setup mismatch, comparator failure, or unresolved visual finding is `⚠️ Blocked`.
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
> **Strict Verification Gate**: A slice transitions to `passing` **only** after every acceptance-test command from `$FEATURE_DIR/sprint-contract.md` exits `0`, with evidence attached per Test ID. Up to 3 fix retries per failing command; unresolved after 3 → `blocked`. Reuse Test-stage evidence only when `bash harness/scripts/check-evidence-receipt.sh` validates unchanged source/config/command/runtime hashes. Platform-boundary owners require `check-platform-evidence.sh --evaluate --slice "$FEATURE_ID"` exit 0. Visual-verification owners require `check-visual-evidence-contract.sh --evaluate` exit 0 with explicit approved mockup mappings and passing reference-anchor rows.

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
> Follow [`clean-state-checklist-template.md`](../../harness/templates/clean-state-checklist-template.md) (Core + triggered sections; omit with `N/A — <reason>`). Produce `$FEATURE_DIR/session-handoff.md` per [`session-handoff-template.md`](../../harness/templates/session-handoff-template.md). Run `bash harness/scripts/check-harness-metrics.sh --validate "$FEATURE_DIR/summary_{feature_id}.md"`. Never move the feature directory.

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
