---
description: Diagnose and fix an Android bug with RED reproduction, approved planning, and GREEN verification.
---

# Workflow: Bug Fixing

Read and follow [Product documentation flow](../rules/product-documentation.md). Load affected living capability requirements before scoping or reviewing this change. Dated complex-change contracts and evidence belong under `.scratch/`.

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

## Entry after Exploratory QA

Start with the existing report and selected finding. A complete QA finding already supplies
the runtime reproduction: package/version/device, binary hash when available, actions,
expected/actual behavior, and retained evidence. Read it once with:

```bash
python3 harness/scripts/read-qa-bug-context.py \
  --report .qa-artifacts/<run-id>/report.json --finding <finding-id>
```

The reader validates the report against its retained scenario, observations, and evidence,
then prints only the selected finding and source-fingerprint changes. A QA verdict of `FAIL`
is expected when an app bug was found. An unrelated inconclusive QA check does not invalidate
a complete selected finding. Setup/environment failures must be routed to their owner.
The reader also accepts `report.md` or `dogfood-report.md` and uses the `report.json` beside it.
If an older detailed report already contains missing structured finding fields, copy those
recorded facts into its observations and regenerate the report from the retained evidence.
Report normalization alone does not require another device run.

Use that output for Stage 1; do not rerun Exploratory QA, regenerate its scenario, or capture
the same device journey/logs again. Inspect the relevant current source to diagnose the cause
and load only missing requirement or UI-contract context. Source changes require review of
their relevance; a changed document or unrelated file alone does not require another device run.
If the selected finding lacks evidence, targets another build/flow, or leaves a runtime fact
needed for diagnosis unresolved, collect only that missing evidence.

Record references in the existing bug spec instead of copying the report into another artifact:

```markdown
## Exploratory QA Handoff

- Report: `.qa-artifacts/<run-id>/report.json`
- Finding: `<finding-id>`
```

The Stage 1 gate validates these references. The report establishes the historical observation;
source-level diagnosis, the RED regression, fix-plan approval, and post-fix verification still
follow the stages below. Existing approved UI designs/contracts may be reused when they cover
the affected state; QA findings do not authorize a new design.

## Skill execution

Apply each stage skill through the available Skill tool. If no Skill tool is exposed, read the
matching repository `SKILL.md`, follow its workflow, and record that interface limitation in the
stage evidence, as required by root `AGENTS.md`. All executable stage gates still apply.

---

## Stage Execution

### Stage 1 — Bug Context, Localization & Root Cause
The specification must include the complete ten-row Rule Applicability matrix. Assess
only the fix scope and preserve an explicit trigger or rationale for every decision.
Apply `requirement-analysis` using the skill execution rule above. With an Exploratory QA handoff,
reuse its recorded context and perform the missing source diagnosis.

Adapt for bugs:
- Bug description, expected vs. actual behavior
- Fault localization (UI → VM → UC → Repo → API)
- Root cause statement (triggered when \<cond\>, causing \<behavior\>)
- Design the fix (UiState changes if needed)

For bugs that involve a user journey, Compose rendering, navigation, Android runtime,
external authentication, permissions, lifecycle, or device-specific behavior, use the complete
Exploratory QA handoff above when available. Otherwise reproduce the missing runtime evidence
with `agent-device` before writing the test. Open the installed app with
`agent-device open <application-id> --foreground`, use the returned semantic references
to follow the reported path, inspect the resulting UI and logs, and close the session
with `agent-device close`. Record the device, installed build, steps, expected result,
actual result, and any crash or log evidence in the bug context. This runtime exploration
defines the test path; it does not replace the required RED regression test.

Output: `docs/current/spec_v<N>.md` created; `docs/current/summary_v<N>.md` updated with Context Provenance and stage evidence. The summary references the approved Rule Applicability matrix in the spec rather than copying it.
Gate: root cause is specific enough that a reproduction test can be written. Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing requirement-analysis` — must exit 0.

---

### Stage 2 — Bug Reproduction (TDD) ⛔ STOP
Apply `bug-reproduction` using the skill execution rule above.

Write a failing test that mechanically proves the root cause before any fix is written.
This is the only workflow stage that requires pre-implementation RED/TDD evidence.

For an IME/keyboard defect, the Reproduction Test section must name `Production activity` and a
`Test name` that opens the real keyboard and asserts controls against its inset boundary. Launch
the shipped Activity without replacing its content; direct `*Content` fixtures, generic test
Activities, window-mode-only assertions, and static keyboard previews are supplemental. The
reproduction gate checks the named method and its reachable helpers against this boundary.

Translate the selected QA finding or new `agent-device` observation into the lowest
sufficient deterministic test layer. A report is not a RED test result. Keep external services
such as Auth0 deterministic in test code while preserving the app-owned transition and visible
result that failed on the device.

Output: Failing reproduction test file created; `docs/current/spec_v<N>.md` updated with a Reproduction Test section; `docs/current/summary_v<N>.md` updated.
Gate: test exits RED (non-zero), failure message matches root cause, no application code modified. For a visual or rich-text rendering reproduction, the named `*RoborazziTest` must call `captureRoboImage()` against the approved Pen export; the stage gate enforces this. Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing bug-reproduction docs/current` — it must exit 0.
**STOP — if root cause cannot be reproduced by a test, surface to user before continuing.**

---

### Stage 3 — Fix Plan ⛔ STOP
The plan must link the approved Rule Applicability record and map every `Required` rule,
including changed triggers and verification evidence.
Apply `implementation-plan` using the skill execution rule above.

Adapt — the plan must include:
- Root cause (reference the reproduction test as evidence)
- Proposed fix (minimal)
- Which `@Ignore` annotation to remove once the fix is applied

For UI fixes, validate `UI_contract.md` against the spec and plan at this gate. Editable inputs
require complete, same-window keyboard-closed/open designs and the template's IME state inventory.
Reuse an approved state only when it covers the entire window relationship. A component crop or
static keyboard preview does not prove that the production Activity moves content above the IME.
The test plan must declare `## IME Production Boundary` even when `NAV` is Not applicable.

Output: `docs/current/implementation_plan_v<N>.md` created; `docs/current/summary_v<N>.md` updated.
Gate: Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing implementation-plan` — must exit 0. **STOP — present fix plan to user. Do not proceed until user explicitly approves.**

---

### Stage 4 — Implementation (Data + Domain + UI as needed)
Apply `android-implementation` using the skill execution rule above.

Adapt — only implement the layers the bug fix touches. Skip layers that are unaffected.

Output: `docs/current/summary_v<N>.md` updated with Implementation stage marked complete.
Gate: `./gradlew assembleDebug` passes, all affected layer rules satisfied.

---

### Stage 5 — Testing
Apply `android-testing` using the skill execution rule above.

For navigation, saved-state, back-stack, destination-recreation, or post-return
persistence defects, the test plan must include a `## Production Journey Boundary`
section naming an instrumented test that mounts the production entry point, performs
the real UI actions, crosses the return boundary, and asserts the visible result.
Direct ViewModel or `*Content` tests are supplemental evidence only.

Output: Unit tests, integration tests, and shared JSON scenarios created or updated; `docs/current/summary_v<N>.md` updated with selected test commands and executed counts.
Gate: the RED reproduction test and every related test selected by `android-testing` pass with non-zero executed counts; required instrumented boundaries pass on the declared runtime. Repository-wide coverage is checked in Code Quality Fix and the full JVM suite in CI. If `NAV` is `Required`, run
`bash harness/scripts/check-stage-artifacts.sh bug-fixing testing docs/current`; it
must exit 0. For a rich-text or visual rendering fix, also require the named
`*RoborazziTest` to pass `bash harness/scripts/check-rendered-output-contract.sh`;
model marks, toolbar state, or device screenshot existence alone do not prove the fix.

Run that Testing gate for UI and IME fixes as well. For every inventoried editable input it checks
production Activity open/dismiss methods and non-skipped, passing JUnit cases. Open tests must
wait for real IME visibility/insets and assert window-coordinate bounds; dismissal must restore
geometry. A passing isolated-content test is insufficient grounds to skip a production replay.

---

### Stage 6 — Code Quality Fix
Apply `code-quality-fix` using the skill execution rule above.

Run the code-quality-fix stage to verify complete baseline correctness.

For bug fixes, additionally verify:
- Any `@Ignore` annotation added in the Bug Reproduction stage has been removed
- The reproduction test is GREEN after the fix
- No failures in the selected related tests; the full JVM suite is checked by CI before merge
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

## Product Requirements Reconciliation

Before closing this change, reconcile affected living capability requirements with verified behavior and link evidence. For an already-correct bug contract, record `Confirmed unchanged` with a reason. Preserve undelivered scope and pending review. Run `python3 harness/scripts/check-product-docs.py` and the lifecycle validator; for new change specs also use `--change-dir <active-workspace>`. Relocation never renews approvals or runtime evidence.
