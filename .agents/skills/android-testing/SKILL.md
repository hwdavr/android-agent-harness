---
name: android-testing
description: Implements unit, integration, and instrumented UI tests according to the test plan.
---

# Skill — Android Testing

## Purpose
After implementation, write or complete all approved tests and mechanically verify they pass.
This stage **generates** — it does not evaluate quality. That is the Test Review stage's job.

Bug fixes perform RED reproduction through the `bug-reproduction` skill before implementation;
this skill performs the later GREEN verification. Feature and enhancement workflows implement
approved behavior before invoking this skill.

---

## Load

**At a new session, load L1:**
- `rules/testing-strategy.md`

**Then load only the selected test-layer guidance:**
- `rules/testing-practices.md` for test structure, doubles, reliability, and assertion quality
- `skills/android-unit-test/SKILL.md` for unit or JVM integration coverage
- `skills/android-instrumented-ui-test/SKILL.md` for UI, navigation, visual, or platform-bound coverage
- `rules/testing-runtime-evidence.md` only for UI, navigation, visual, platform, or runtime claims
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

### 1. Execute Planned Tests
For ad-hoc workflows, read the approved `docs/current/test_plan_v<N>.md`. For the harness workflow, read the selected user story and its acceptance-test rows in `$FEATURE_DIR/sprint-contract.md`, plus the matching `verification` and `production_journey` entries in `$FEATURE_DIR/feature_list.json`. When `production_journey.required` is `true`, implement the named acceptance-test owner as a production-entry journey with the declared actions, return boundary, and visible post-return assertion. Read the approved Rule Applicability matrix. Every required Rule Applicability row must have test, static-check, or review evidence.

### 2. Unit tests (`app/src/test/`)
Write unit tests for all new or modified:
- Domain use case logic
- ViewModel state transitions
- Mapper logic (DTO → Domain, Domain → UI)
- Formatting and fallback logic

Rules:
- All ViewModel unit tests inherit from `BaseViewModelTest`
- Class name ends with `Test.kt`
- One main scenario per test
- 90% line coverage target for new ViewModel and domain classes

### 3. Integration tests (`app/src/test/`)
Write integration tests if an API is involved.

For each changed API endpoint, test:
- Success response (2xx)
- 4xx client error
- 5xx server error
- Malformed or partial payload
- Network timeout / disconnect
- Unknown enum value (must not crash — must return fallback)

Rules:
- All ViewModel integration tests inherit from `BaseViewModelIntegrationTest`
- Class name ends with `IntegrationTest.kt`
- **Use shared JSON scenarios — do not inline mock data** (read `skills/shared-json-scenarios/SKILL.md`)
- Store scenarios in `sharedContracts/test-scenarios/`
- If API used by a ViewModel: assert `expected.ui` from the scenario
- If API used only by repo / use case: assert `expected.domain`

### 4. Instrumented UI tests (`app/src/androidTest/`)
Write instrumented tests only when Android runtime or real UI rendering is required.

Rules:
- Target device selection: Use an Android emulator for instrumented UI tests (e.g. `ANDROID_SERIAL=emulator-5554`). Only when an emulator is missing/not connected, use a connected physical device.
- Use `createComposeRule()` for isolated rendering and callback tests. Use `createAndroidComposeRule` or a production Activity when the Activity, navigation graph, `SavedStateHandle`, destination lifecycle, or post-return state is part of the declared journey.
- Test the stateless `Content` Composable for isolated rendering, but do not use a `Content`-only test as evidence for a required production journey. Journey tests must mount the production entry point and use real UI semantics/test tags across the return boundary.
- Do not use `Thread.sleep` — use `waitUntil` or `waitForIdle`
- One main business scenario per test

### 5. Import hygiene — applies to ALL test layers
These rules apply to every test file regardless of layer:

- **No fully-qualified class names** inline in property declarations, function parameters, or function bodies — always use a top-level `import` statement
  - ❌ `private val mock: com.example.auth.AuthManager = io.mockk.mockk(relaxed = true)`
  - ✅ `import com.example.auth.AuthManager` + `import io.mockk.mockk` then `private val mock: AuthManager = mockk(relaxed = true)`
- **No wildcard imports** — all imports must be explicit
  - ❌ `import io.mockk.*`
  - ✅ `import io.mockk.mockk`, `import io.mockk.every`, `import io.mockk.verify`
- **Imports sorted lexicographically** with no blank lines between entries

### 6. Verification pass (after implementation)
```bash
./gradlew testDebugUnitTest
./gradlew koverLog
./gradlew :app:koverXmlReportDebug
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
```
If instrumented tests were added: run on an emulator (e.g. `ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest`), using a connected physical device only if no emulator is present.

Record the exact command, exit code, test count, and coverage percentage in the stage evidence. Keep verbose tool output in a referenced log or generated report; do not copy it into the summary.

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

Record the declared methods, shared scenarios, exact selectors, GREEN test counts, and coverage
in the active summary. Bug reproduction RED evidence remains in the bug specification and its
dedicated stage evidence.

---

## Done When

**Post-implementation verification is complete when all of the following are true — all must be mechanically verifiable:**
- [ ] `./gradlew testDebugUnitTest` — exit code 0
- [ ] `./gradlew koverLog` — overall ≥ 80%, new classes ≥ 90%
- [ ] `bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml` — weighted line thresholds pass
- [ ] Total test count `> 0` (not `0/0` — this is a gate failure)
- [ ] At least one integration test per new or changed API endpoint (when API is in scope)
- [ ] Shared JSON scenarios used — no inline mock response data in test files (when API is in scope)
- [ ] Instrumented tests pass (if added): `./gradlew connectedDebugAndroidTest`
- [ ] Harness workflow: acceptance-test traceability gate passes in evaluation mode for the selected slice

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.

**REVISION REQUIRED →**
- If `total_tests == 0` → add the missing approved tests and rerun verification
- If coverage < 80% → return to Verification, add missing unit tests
- If test failures exist → return to Implementation to fix the application root cause, then Verification
- If a compilation error was introduced → return to the stage that caused it

**Iteration cap:** 2 rounds of test revision. If still failing, surface the specific failure to the user.
