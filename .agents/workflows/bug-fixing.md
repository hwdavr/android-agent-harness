---
description: You are a senior Android developer diagnosing and fixing a bug.
---

# Workflow: Bug Fixing

## When to use
- A defect, crash, ANR, or production issue
- A regression or test failure
- Unexpected app behavior

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
**INVOKE** the `requirement-analysis` skill via the Skill tool (name: `requirement-analysis`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Adapt for bugs:
- Bug description, expected vs. actual behavior
- Fault localization (UI → VM → UC → Repo → API)
- Root cause statement (triggered when \<cond\>, causing \<behavior\>)
- Design the fix (UiState changes if needed)

Output: `docs/current/spec_v<N>.md` created; `docs/current/summary_v<N>.md` updated with bug context, fault area, and root cause.
Gate: root cause is specific enough that a reproduction test can be written. Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing requirement-analysis` — must exit 0.

---

### Stage 2 — Bug Reproduction (TDD) ⛔ STOP
**INVOKE** the `bug-reproduction` skill via the Skill tool (name: `bug-reproduction`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Write a failing test that mechanically proves the root cause before any fix is written.

Output: Failing reproduction test file created; `docs/current/spec_v<N>.md` updated with a Reproduction Test section; `docs/current/summary_v<N>.md` updated.
Gate: test exits RED (non-zero), failure message matches root cause, no application code modified.
**STOP — if root cause cannot be reproduced by a test, surface to user before continuing.**

---

### Stage 3 — Fix Plan ⛔ STOP
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

Output: Unit tests, integration tests, and shared JSON scenarios created or updated; `docs/current/summary_v<N>.md` updated with test count and coverage.
Gate: tests pass, coverage targets met.

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

## Human-in-the-Loop Confirmation Points

1. **After Bug Context, Localization & Root Cause** — if root cause is uncertain, ask user
2. **After Bug Reproduction** — if the bug cannot be reproduced by a test, surface to user *(mandatory stop)*
3. **After Fix Plan** — user approves fix plan *(mandatory always)*