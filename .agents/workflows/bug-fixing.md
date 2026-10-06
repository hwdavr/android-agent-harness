---
description: Diagnose and fix an Android bug with RED reproduction, approved planning, and GREEN verification.
---

# Workflow: Bug Fixing

## When to use
- A defect, crash, ANR, or production issue
- A regression or test failure
- Unexpected app behavior

Do not use this workflow for a localized, intentional UI-only adjustment to one
existing presentation surface when the change has no API, persistence, domain,
ViewModel behavior, navigation, or new user-journey impact. Route that request to
the **Small UI Patch Triage** direct `android-ui-layer` skill lane; this UI-only triage
does not need this workflow's RED reproduction, fix-plan, or other workflow stages.

This workflow prioritises root-cause analysis over quick patching.

---

## Core Principle

Do not fix symptoms first. Do not guess — prove it with a failing test.
**The reproduction test must be RED before the Fix Plan is written.**
**The Fix Plan must be approved before any fix code is written.**

Pipeline: Bug Context & Root Cause → Bug Reproduction (TDD) → Fix Plan → [User Approval] → Implementation → Testing → Code Quality Fix → Install App To Device

---

## Stage Execution

### Stage 1 — Bug Context, Localization & Root Cause
The specification must include the complete ten-row Rule Applicability matrix. Assess
only the fix scope and preserve an explicit trigger or rationale for every decision.
**INVOKE** the `requirement-analysis` skill via the Skill tool (name: `requirement-analysis`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Adapt for bugs:
- Bug description, expected vs. actual behavior
- Fault localization (UI → VM → UC → Repo → API)
- Root cause statement (triggered when \<cond\>, causing \<behavior\>)
- Design the fix (UiState changes if needed)

For bugs that involve a user journey, Compose rendering, navigation, Android runtime,
external authentication, permissions, lifecycle, or device-specific behavior, reproduce
the report with `agent-device` before writing the test. Open the installed app with
`agent-device open <application-id> --foreground`, use the returned semantic references
to follow the reported path, inspect the resulting UI and logs, and close the session
with `agent-device close`. Record the device, installed build, steps, expected result,
actual result, and any crash or log evidence in the bug context. This runtime exploration
defines the test path; it does not replace the required RED regression test.

Output: `docs/current/spec_v<N>.md` created; `docs/current/summary_v<N>.md` updated with Context Provenance and stage evidence. The summary references the approved Rule Applicability matrix in the spec rather than copying it.
Gate: root cause is specific enough that a reproduction test can be written. Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing requirement-analysis` — must exit 0.

---

### Stage 2 — Bug Reproduction (TDD) ⛔ STOP
**INVOKE** the `bug-reproduction` skill via the Skill tool (name: `bug-reproduction`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Write a failing test that mechanically proves the root cause before any fix is written.
This is the only workflow stage that requires pre-implementation RED/TDD evidence.

When Stage 1 used `agent-device`, translate the observed journey into the lowest
sufficient deterministic test layer. Keep external services such as Auth0 deterministic
in test code while preserving the app-owned transition and visible result that failed on
the device.

Output: Failing reproduction test file created; `docs/current/spec_v<N>.md` updated with a Reproduction Test section; `docs/current/summary_v<N>.md` updated.
Gate: test exits RED (non-zero), failure message matches root cause, no application code modified. For a visual or rich-text rendering reproduction, the named instrumented test must include source-fed `captureToImage()` and an explicit pixel comparison; the stage gate enforces this. Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing bug-reproduction docs/current` — it must exit 0.
**STOP — if root cause cannot be reproduced by a test, surface to user before continuing.**

---

### Stage 3 — Fix Plan ⛔ STOP
The plan must link the approved Rule Applicability record and map every `Required` rule,
including changed triggers and verification evidence.
**INVOKE** the `implementation-plan` skill via the Skill tool (name: `implementation-plan`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Adapt — the plan must include:
- Root cause (reference the reproduction test as evidence)
- Proposed fix (minimal)
- Which `@Ignore` annotation to remove once the fix is applied

Output: `docs/current/implementation_plan_v<N>.md` created; `docs/current/summary_v<N>.md` updated.
Gate: Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing implementation-plan` — must exit 0. **STOP — present fix plan to user. Do not proceed until user explicitly approves.**

---

### Stage 4 — Implementation (Data + Domain + UI as needed)
**INVOKE** the `android-implementation` skill via the Skill tool (name: `android-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Adapt — only implement the layers the bug fix touches. Skip layers that are unaffected.

Output: `docs/current/summary_v<N>.md` updated with Implementation stage marked complete.
Gate: `./gradlew assembleDebug` passes, all affected layer rules satisfied.

---

### Stage 5 — Testing
**INVOKE** the `android-testing` skill via the Skill tool (name: `android-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

For navigation, saved-state, back-stack, destination-recreation, or post-return
persistence defects, the test plan must include a `## Production Journey Boundary`
section naming an instrumented test that mounts the production entry point, performs
the real UI actions, crosses the return boundary, and asserts the visible result.
Direct ViewModel or `*Content` tests are supplemental evidence only.

Output: Unit tests, integration tests, and shared JSON scenarios created or updated; `docs/current/summary_v<N>.md` updated with test count and coverage.
Gate: tests pass, coverage targets met. If `NAV` is `Required`, run
`bash harness/scripts/check-stage-artifacts.sh bug-fixing testing docs/current`; it
must exit 0. For a rich-text or visual rendering fix, also require the named
instrumented test to pass `bash harness/scripts/check-rendered-output-contract.sh`;
model marks, toolbar state, or screenshot existence alone do not prove the fix.

---

### Stage 6 — Code Quality Fix
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Run the code-quality-fix stage to verify complete baseline correctness.

For bug fixes, additionally verify:
- Any `@Ignore` annotation added in the Bug Reproduction stage has been removed
- The reproduction test is GREEN after the fix
- No regressions in the full suite
- The minimal-fix constraint: no unrelated changes slipped in

Output: `docs/current/summary_v<N>.md` updated with code quality results.
Gate:
- All conditions in `skills/code-quality-fix/SKILL.md` pass
- The reproduction test is GREEN after the fix

---

### Stage 7 — Install App To Device
Install the completed debug build when the fix affects UI, requires instrumented/platform
verification, or the user explicitly requests installation. Otherwise record an explicit
non-runtime N/A.

**Actions**:
1. Install the app to every connected device and emulator:
    ```bash
    ./gradlew installDebug
    ```
2. Record the install command, connected device IDs, and exit status in `docs/current/summary_v<N>.md`.
3. When Stage 1 included a runtime journey, use `agent-device` to repeat the original
   journey against the installed debug app. Record the command, device, installed build,
   observed result, and any saved logs or screenshots in `docs/current/summary_v<N>.md`,
   then close the `agent-device` session. This is release smoke evidence; the GREEN
   regression test remains the required automated proof.

Output: Debug app installed on every connected device and emulator.
Gate: when required, installation exits 0 and any declared `agent-device` journey reaches
its expected visible result; failure or no connected device is blocked. Otherwise the
feature-specific N/A rationale completes the stage.
---

## Human-in-the-Loop Confirmation Points

1. **After Bug Context, Localization & Root Cause** — if root cause is uncertain, ask user
2. **After Bug Reproduction** — if the bug cannot be reproduced by a test, surface to user *(mandatory stop)*
3. **After Fix Plan** — user approves fix plan *(mandatory always)*
