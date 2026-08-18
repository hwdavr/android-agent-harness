---
description: You are a senior Android developer delivering a new feature end-to-end.
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
**INVOKE** the `requirement-analysis` skill via the Skill tool (name: `requirement-analysis`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: `docs/current/spec_v<N>.md` created; `docs/current/summary_v<N>.md` updated with requirements, impacted files, API classification, and UiState/Navigation design.
Gate: requirements clear, impacted files identified, API classified, UiState/Navigation designed. Run `bash harness/scripts/check-stage-artifacts.sh feature-delivery requirement-analysis` — must exit 0.

**If the feature involves new screens or UI changes:**
- Read `docs/product/design_system.md` before writing requirements or design artifacts. Treat it as the project-wide visual source of truth; record any explicit user-approved exception in `docs/current/design.md`.
- **If user provided a screenshot or mockup image**: Save image(s) unchanged to `docs/current/design/`, write `docs/current/design.md` referencing them. Do **NOT** invoke the `ux-design` skill.
- **If NO screenshot/mockup was provided**: **INVOKE** the `ux-design` skill via the Skill tool (name: `ux-design`). Reading SKILL.md manually is not a substitute. Output: `docs/current/design.md` + `docs/current/design/mockup_*.png` AI-generated visual mockup images.

---

### Stage 2 — Implementation Plan ⛔ STOP
**INVOKE** the `implementation-plan` skill via the Skill tool (name: `implementation-plan`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: `docs/current/implementation_plan_v<N>.md` created; `docs/current/test_plan_v<N>.md` created; `docs/current/summary_v<N>.md` updated.
Gate: Run `bash harness/scripts/check-stage-artifacts.sh feature-delivery implementation-plan` — must exit 0. **STOP — present plan to user. Do not proceed until user explicitly approves.**

---

### Stage 3 — Implementation (Data + Domain + UI)
**INVOKE** the `android-implementation` skill via the Skill tool (name: `android-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: All source files across Data, Domain, and UI layers created or modified; `docs/current/summary_v<N>.md` updated with Implementation stage marked complete.
Gate: `./gradlew assembleDebug` passes, all layer rules are satisfied, and UI changes conform to `docs/product/design_system.md` plus any explicit approved exception in `docs/current/design.md`.

---

### Stage 4 — Testing
**INVOKE** the `android-testing` skill via the Skill tool (name: `android-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: Unit tests, integration tests, and shared JSON scenarios created or updated; `docs/current/summary_v<N>.md` updated with test count and coverage.
Gate: tests pass, coverage targets met.

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

Output: `docs/product/product.md` updated with current shipped state.
Gate: the file is saved and the feature no longer appears as Planned or Next for all delivered capabilities.

---

### Stage 7 — Install App To Device
Install the completed debug build to all connected devices and emulators as the final delivery step.

**Actions**:
1. Install the app to every connected device and emulator:
    ```bash
    ./gradlew installDebug
    ```
2. Record the install command, connected device IDs, and exit status in `docs/current/summary_v<N>.md`.

Output: Debug app installed on every connected device and emulator.
Gate: install command exits with code 0. If no device is connected, mark this stage blocked with the `adb devices` output and do not claim delivery is fully complete.

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

1. **After Requirement, Impact & Design Analysis** — user confirms assumptions and designs
2. **After Implementation Plan** — user approves implementation plan *(mandatory always)*
