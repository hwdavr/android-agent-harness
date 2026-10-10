---
description: Deliver an Android feature end-to-end through approved implementation, testing, and quality gates.
---

# Workflow: Feature Delivery

## When to use
- Use this workflow when you are acting as the **Generator** (Implementer) agent.
- Implementing a new feature
- Enhancing an existing feature
- Integrating a backend or API change

This workflow is for production-grade delivery — not quick prototyping.

---

## Core Principle

Do not jump directly into coding.
**The Implementation Plan must be approved before any code is written.**
**Every stage's skill must be invoked via the Skill tool — reading the SKILL.md manually is not a substitute.**
**Memory of prior approval does not bypass stages. Source of truth is on-disk artifacts in `docs/current/`. If an artifact is missing, re-run the stage via its skill.**

Pipeline: Requirement, Impact & Design → Plan → [User Approval] → Implementation → Testing → Code Quality Fix → Product Document Update → Install App To Device

---

## Stage Execution

### Stage 1 — Requirement, Impact & Design Analysis
The specification must include the complete ten-row Rule Applicability matrix, and the
stage gate must reject missing or unsupported decisions.
**INVOKE** the `requirement-analysis` skill via the Skill tool (name: `requirement-analysis`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: `docs/current/spec_v<N>.md` created; `docs/current/summary_v<N>.md` updated with Context Provenance and stage evidence. For UI changes, also create `docs/current/UI_contract.md` from `harness/templates/UI_contract-template.md`. The summary references the approved Rule Applicability matrix in the spec rather than copying it.
Gate: requirements clear, impacted files identified, API classified, UiState/Navigation designed. Complete the UI branch below when applicable, then run `bash harness/scripts/check-stage-artifacts.sh feature-delivery requirement-analysis` — must exit 0.

**If the feature involves new screens or UI changes:**
- Read `docs/product/design_system.md` before writing requirements or design artifacts. Treat it as the project-wide visual source of truth; record any explicit user-approved exception in `docs/current/UI_contract.md`.
- Declare every visually distinct screen/state in the spec's `## Screen States` table. Inspect existing runtime states and controls, then copy the complete inventory to `UI_contract.md`, giving each state a unique design reference, deterministic runtime fixture, comparison mode, and plan stage ID. The requirement-analysis gate checks set equality.
- **If user provided a screenshot or mockup image**: Save image(s) unchanged to `docs/current/design/` and map each approved state image in `docs/current/UI_contract.md`. Invoke `pen-design-editor` only for states the supplied images do not cover.
- **If NO screenshot/mockup was provided**: **INVOKE** the `pen-design-editor` skill via the Skill tool (name: `pen-design-editor`). Reading SKILL.md manually is not a substitute. Use the canonical `.pen` design source (or create one), create missing screen/state frames, then output `docs/current/UI_contract.md` plus a verified `docs/current/design/mockup_*.png` export for each state. Render and inspect every export for correct icons and missing glyphs. The `.pen` file is the editable source; the PNGs are review artifacts.
- After the user approves a generated design, follow `pen-design-editor`'s finalization contract: promote the validated `.pen` over the original source, retain the approved PNG review asset, and delete only run-owned intermediate outputs. All later feature-delivery stages and approval gates remain unchanged.

---

### Stage 2 — Implementation Plan ⛔ STOP
The implementation and test plans must link the canonical Rule Applicability record
and identify evidence for each `Required` row.
**INVOKE** the `implementation-plan` skill via the Skill tool (name: `implementation-plan`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: `docs/current/implementation_plan_v<N>.md` created; `docs/current/test_plan_v<N>.md` created; `docs/current/summary_v<N>.md` updated.
For UI changes, include a `## UI State Stages` table in the implementation plan with one implementation and verification step for each Plan stage ID in `UI_contract.md`.
Gate: Run `bash harness/scripts/check-stage-artifacts.sh feature-delivery implementation-plan` — must exit 0. **STOP — present plan to user. Do not proceed until user explicitly approves.**

---

### Stage 3 — Implementation (Data + Domain + UI)
**INVOKE** the `android-implementation` skill via the Skill tool (name: `android-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Feature delivery is implementation-first: implement the approved plan before the Testing stage.

Output: All required source files across Data, Domain, UI, or test-infrastructure layers created or modified;
`docs/current/summary_v<N>.md` updated with Implementation stage marked complete. Test-infrastructure changes must
keep fixture state in the test target and leave production ViewModels/repositories unaware of fixture selection.
Gate: `./gradlew assembleDebug` passes, all layer rules are satisfied, and UI changes conform to `docs/product/design_system.md` plus any explicit approved exception in `docs/current/UI_contract.md`.

---

### Stage 4 — Testing
**INVOKE** the `android-testing` skill via the Skill tool (name: `android-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Create or complete the approved tests against the implementation and verify them GREEN. Do not
introduce a separate feature-level RED/TDD stage.

Output: Unit tests, integration tests, loopback-boundary tests when required, and shared JSON scenarios created or
updated; `docs/current/summary_v<N>.md` updated with test count, request-receipt evidence, and coverage.
Gate: tests pass, coverage targets met. Additionally, run `bash harness/scripts/check-journey-registry.sh --run-all` to verify no existing critical journey is regressed. For any instrumented claim that rich text or an inline formatting mark is visibly rendered, run `bash harness/scripts/check-rendered-output-contract.sh` for the named method and require source-fed `captureToImage()` plus an explicit pixel comparison; state-only marks and a non-empty screenshot are supplemental evidence.

---

### Stage 5 — Code Quality Fix
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: All violations resolved; `docs/current/summary_v<N>.md` updated with code quality results.
Gate: `ktlintCheck`, `detekt`, `lintDebug`, and all custom check scripts exit with code 0.

---

### Stage 6 — Product Document Update
Update `docs/product/product.md` to reflect the newly shipped feature.

**Actions**:
1. Move the feature row(s) in the **Product Portfolio Summary** from `🔜 Next` / `📋 Planned` to `✅ Complete`.
2. Add the feature to **Current Product Capabilities** with its delivered capabilities and any notable implementation notes.
3. Remove the feature from the **Roadmap — Planned Features** section if it is fully delivered, or update its priority column to reflect remaining sub-features.
4. Record execution metrics in the `## Observability & Execution Metrics` section of `docs/current/summary_v<N>.md` and verify with `bash harness/scripts/check-harness-metrics.sh --validate docs/current/summary_v<N>.md`.

Output: `docs/product/product.md` updated with current shipped state; `docs/current/summary_v<N>.md` updated with observability metrics following [`harness/templates/summary-template.md`](../../harness/templates/summary-template.md).
Gate: the file is saved, the feature no longer appears as Planned or Next for all delivered capabilities, and `check-harness-metrics.sh --validate` exits 0.


---

### Stage 7 — Install App To Device
Install the completed debug build when the feature affects UI, requires instrumented/platform
verification, or the user explicitly requests installation. Otherwise record an explicit
non-runtime N/A.

**Actions**:
1. Install the app to every connected device and emulator:
    ```bash
    ./gradlew installDebug
    ```
2. Record the install command, connected device IDs, and exit status in `docs/current/summary_v<N>.md`.

Output: Debug app installed on every connected device and emulator.
Gate: when required, installation exits 0; failure or no connected device is blocked. Otherwise
the feature-specific N/A rationale completes the stage.

---

## Rollback Routes

| Failure | Return to |
|---------|-----------|
| Requirement ambiguity or Plan rejection | Requirement, Impact & Design Analysis |
| Compilation error | Implementation (Data + Domain + UI) |
| Test failure or Coverage gap | Testing (fix implementation if needed, then re-test) |
| Quality check violation | Code Quality Fix (fix root cause, re-run checks) |
| Install failure or missing connected device | Install App To Device |

---

## Human-in-the-Loop Confirmation Points

1. **After Requirement, Impact & Design Analysis** — ask only when assumptions, scope, or a design choice remains unresolved
2. **After Implementation Plan** — user approves implementation plan *(mandatory always)*
