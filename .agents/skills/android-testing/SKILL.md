---
name: android-testing
description: Implement planned Android unit, integration, and instrumented UI tests.
---

# Skill — Android Testing

## Purpose
After implementation, write or complete all approved tests and run the tests related to the
change. Decide whether a real Android runtime is required before selecting test commands.
This stage **generates** — it does not evaluate quality. That is the Test Review stage's job.

Bug fixes perform RED reproduction through the `bug-reproduction` skill before implementation;
this skill performs the later GREEN verification. Feature and enhancement workflows implement
approved behavior before invoking this skill.

---

## Load

**At a new session, load L1:**
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read

**Then load only the selected test-layer guidance:**
- `rules/testing-practices.md` for test structure, doubles, reliability, and assertion quality
- `skills/android-unit-test/SKILL.md` for unit or JVM integration coverage
- `skills/ui-verification/SKILL.md` for approved visual comparison through JVM Roborazzi tests
- `rules/testing-runtime-evidence.md` for instrumented UI, navigation, platform, or other runtime claims; visual claims use the Roborazzi contract
- `skills/shared-json-scenarios/SKILL.md` only when an API endpoint or shared fixture is in scope
- `rules/android-security.md` when the test covers a security boundary; use its
  required real-runtime boundary evidence and fail loudly when the runtime is unavailable

**Adhoc workflows** (`feature-delivery`, `bug-fixing`):
- `docs/current/test_plan_v<N>.md` — test cases, layers, and coverage targets approved by user

**Harness workflow** (`harness-generator`):
- Run `bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"`.
- Read only the selected acceptance-test rows and matching `feature_list.json` entry. Read the summary only for prior evidence, blockers, and handoff decisions.

---

## Execute

### 1. Analyze runtime and test scope
For ad-hoc workflows, read the approved `docs/current/test_plan_v<N>.md`. For the harness workflow, read the selected user story and its acceptance-test rows in `$FEATURE_DIR/sprint-contract.md`, plus the matching `verification` and `production_journey` entries in `$FEATURE_DIR/feature_list.json`. When `production_journey.required` is `true`, implement the named acceptance-test owner as a production-entry journey with the declared actions, return boundary, and visible post-return assertion. Read the canonical specification's Rule Applicability matrix. Every `Required` Rule Applicability row must have test, static-check, or review evidence.

First determine whether any affected behavior requires instrumented evidence: Compose interaction,
navigation, lifecycle, Android SDK or platform behavior, permissions, device capabilities, or an
instrumented loopback boundary. Load `rules/testing-runtime-evidence.md` when it does. Identify
the named instrumented methods and required runtime before selecting JVM tests. If a required
runtime is unavailable, record `Blocked` or `Revise`; do not substitute a JVM or fake test.

Then list the affected production paths, the approved test cases, the RED regression test for a
bug, and any existing tests that cover the changed behavior. Select explicit test classes or
methods for each required layer. Record why each selected test is related to the change.

### 2. Unit tests (`app/src/test/`)
Write unit tests for all new or modified use cases, ViewModels, mappers, and formatters.
Follow `skills/android-unit-test/SKILL.md` for framework, naming, and coverage rules.

### 3. Integration tests (`app/src/test/` or `app/src/androidTest/` loopback boundary)
Write integration tests if an API is involved. Test success, 4xx, 5xx, malformed payload, timeout, and unknown enum fallback per endpoint.
Follow `skills/android-integration-test/SKILL.md` — use shared JSON scenarios, do not inline mock data. When the
instrumented target owns a loopback server, start it before app launch, drive the shipped Retrofit/OkHttp client,
assert redacted receipts and decoded results, and fail if listener or endpoint setup is missing.

### 4. Instrumented UI tests (`app/src/androidTest/`)
Write instrumented tests only when Android runtime or real UI rendering is required.
Follow `rules/testing-runtime-evidence.md` — use stable test tags, not static text, and no `Thread.sleep`.

### 5. Import hygiene — applies to ALL test layers
These rules apply to every test file regardless of layer:

- **No fully-qualified class names** inline in property declarations, function parameters, or function bodies — always use a top-level `import` statement
  - ❌ `private val mock: com.example.auth.AuthManager = io.mockk.mockk(relaxed = true)`
  - ✅ `import com.example.auth.AuthManager` + `import io.mockk.mockk` then `private val mock: AuthManager = mockk(relaxed = true)`
- **No wildcard imports** — all imports must be explicit
  - ❌ `import io.mockk.*`
  - ✅ `import io.mockk.mockk`, `import io.mockk.every`, `import io.mockk.verify`
- **Imports sorted lexicographically** with no blank lines between entries

### 6. Run the selected tests (after implementation)
Run every selected test with a suite-scoped selector. For example:

```bash
./gradlew :app:testDebugUnitTest --tests '<fully.qualified.TestClass>'
ANDROID_SERIAL=<device-serial> ./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=<fully.qualified.InstrumentedTestClass>
```

Use the exact method selector when the runner supports it. For Roborazzi, use the approved
state's scoped verification command. Run instrumented tests whenever the runtime analysis
requires them, including existing tests affected by the change; adding a new instrumented test
is not the only trigger. Prefer an emulator, using a connected physical device when the
required capability or availability calls for one. Do not run unfiltered
`testDebugUnitTest` or `connectedDebugAndroidTest`, `koverLog`, or full coverage reports in this
skill. The later workflow or CI gate owns repository-wide test and coverage evidence.

Record each selected test ID or method, exact command, exit code, non-zero executed test count,
and runtime in the stage evidence. Keep verbose output in a referenced log or generated report.
Do not report project coverage from a scoped test run.

For the harness workflow, after writing tests and before leaving this stage, run the
acceptance-test traceability checker in evaluation mode:

    bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --evaluate "$FEATURE_ID"

The gate requires every selected acceptance Test ID to name a real Kotlin test method,
a suite-scoped Gradle selector, and any declared shared JSON scenario to be referenced
from the named method. For a required production journey, also run
`bash harness/scripts/check-journey-test-contract.sh` with the planned test file,
method, and production entry point; the source checker must find the real graph,
gestures, return boundary, and visible post-return assertion.

---

## Output

New or updated test files.
New or updated shared JSON scenarios in `sharedContracts/test-scenarios/`.

Record the declared methods, shared scenarios, exact selectors, and GREEN test counts in the
active summary. Record coverage later from the repository-wide gate. Bug reproduction RED
evidence remains in the bug specification and its dedicated stage evidence.

---

## Done When

**Scoped post-implementation verification is complete when all of the following are true:**
- [ ] The runtime decision and affected-test selection are recorded with reasons
- [ ] Every selected JVM and instrumented test command exits 0 and executes a non-zero test count
- [ ] The bug's RED reproduction test is GREEN when this is a bug fix
- [ ] At least one integration test per new or changed API endpoint (when API is in scope), owned by the lowest useful target; an instrumented loopback boundary is valid when the real app process is part of the claim
- [ ] Shared JSON scenarios used — no inline mock response data in test files (when API is in scope)
- [ ] Every required instrumented boundary passes on the declared runtime; unavailable required runtimes are `Blocked`/`Revise`
- [ ] Harness workflow: acceptance-test traceability gate passes in evaluation mode for the selected slice

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.

**REVISION REQUIRED →**
- If a selected command runs zero tests → fix the selector or add the missing approved test
- If the later repository-wide coverage gate fails → add relevant tests and rerun this stage's affected selectors, then rerun that gate
- If test failures exist → return to Implementation to fix the application root cause, then Verification
- If a compilation error was introduced → return to the stage that caused it

**Iteration cap:** 2 rounds of test revision. If still failing, surface the specific failure to the user.
