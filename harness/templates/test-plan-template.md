# Test Plan Template

Use this template when producing the test plan in the **Implementation Plan** stage (alongside the implementation plan).

---

## Feature / Bug

> One line description of what is being tested.

## Rule Applicability Test Mapping

Canonical decisions: [`spec_v<N>.md#rule-applicability`](spec_v<N>.md#rule-applicability).
Do not duplicate the ten-row matrix. Map every `Required` row from that exact approved
specification to a test, static check, review evidence, or documented blocking failure.
Its `Not applicable` and `Exception` rationales remain canonical in the specification;
update the specification if a new test trigger appears.

| Required Rule ID | Test / evidence |
|---|---|
| <RULE_ID> | <test IDs, command, or blocking evidence> |

---

## Layer Selection

| Layer | Included | Reason |
|-------|----------|--------|
| Unit tests (`app/src/test/`) | ✅ / ❌ | |
| Integration tests (`app/src/test/` or instrumented loopback boundary) | ✅ / ❌ | |
| Instrumented UI tests (`app/src/androidTest/`) | ✅ / ❌ | |

---

## Production Journey Boundary

> **MANDATORY when `NAV` is `Required` for navigation, saved-state, back-stack,
> destination-recreation, or post-return persistence behavior.** Name the real
> instrumented journey that enters through the shipped Activity or navigation graph,
> uses UI gestures, crosses the return boundary, and asserts the visible result.

- Test file: `<path under app/src/androidTest/>`
- Test method: `<named @Test method>`
- Production entry point: `<Activity, AppNavigationHost, or production graph function>`
- User actions: `<real UI gestures and stable test tags>`
- Return boundary: `<back/pop/destination selection and resulting return>`
- Post-return assertion: `<visible result asserted after returning>`

The stage gate invokes `bash harness/scripts/check-journey-test-contract.sh` for the
declared file and method. Direct ViewModel, internal UiState, manually invoked
callback, and Content-only tests remain supplemental and do not satisfy this section.

---

## Test Cases

List every test case grouped by the class under test. Assign a short ID (e.g. `T1`) so cases can be referenced in reviews and PRs.

### `<ClassName>Test.kt` — Unit

| ID | Given | When | Then |
|----|-------|------|------|
| T1 | \<precondition\> | \<action / trigger\> | \<expected outcome\> |
| T2 | \<precondition\> | \<action / trigger\> | \<expected outcome\> |

### `<ClassName>IntegrationTest.kt` or `<FixtureServer>InstrumentedTest.kt` — Integration

> **MANDATORY**: Every new or exercised API endpoint must have at least one integration test using a shared JSON
> scenario. When a real app-process HTTP boundary is required, the owning test may run in the instrumented target
> beside a local loopback server and must assert request receipts plus the shipped client's observable result.

| ID | Given | When | Then | Shared Scenario |
|----|-------|------|------|-----------------|
| T3 | \<precondition\> | \<action / trigger\> | \<expected outcome\> | `scenario.json` |
| T4 | API returns error | load data | show error UiState | `scenario-error.json` |

### `<Feature>VisualFlowTest.kt` — Dedicated Visual Flow *(only when `requires_visual_verification == true`)*

> **MANDATORY**: When visual verification is required, write a dedicated `*VisualFlowTest.kt` instrumented test class that renders the active Composable in each critical visual state, calls `composeRule.waitForIdle()`, and captures a screenshot from within the running test via `InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()`. Screenshots are saved to `/sdcard/Download/<name>.png` and pulled via `adb pull`. Post-test CLI screencaps (`&& adb exec-out screencap`) are prohibited.

| ID | Visual State | Composable Under Test | Capture Method | Output File |
|----|-------------|----------------------|----------------|-------------|
| T-VIS-1 | \<state name (e.g. default content)\> | \<Composable name\> | `takeScreenshot()` during `waitForIdle()` | `visual_evidence/<screen>_<state>.png` |
| T-VIS-2 | \<state name (e.g. expanded/fullscreen)\> | \<Composable name\> | `takeScreenshot()` during `waitForIdle()` | `visual_evidence/<screen>_<state>.png` |

---

Each visual row's sprint-contract command must select the exact method using
-Pandroid.testInstrumentationRunnerArguments.class=<package>.<Feature>VisualFlowTest#<method>,
then pull the in-test screenshot with adb pull and verify it is non-empty.

### `<ScreenName>RoborazziMockupTest.kt` — Pen-export comparison *(when the visual target is `.pen`-backed)*

The JVM Compose test renders the same deterministic state and calls
`captureRoboImage("<reference>.png")`. The reference PNG must be exported from the canonical
`pen_source`/`pen_node_id` in `visual-target.json`; it must not be recorded from the implementation.
The binding command is `./gradlew app:verifyRoborazziDebug`. `recordRoborazziDebug` and
`verifyAndRecordRoborazziDebug` are authoring/recovery commands only and are not acceptance evidence.

| ID | Pen source/node | Composable under test | Verification command | Reference PNG |
|----|----------------|-----------------------|----------------------|---------------|
| T-VIS-R1 | `UX/NotesApp.pen#<node-id>` | `<Composable name>` | `./gradlew app:verifyRoborazziDebug` | `app/src/test/roborazzi/<screen>.png` |

### Rendered Output Contract *(when a visual claim concerns rich text or inline formatting)*

If a test-plan, acceptance, or reproduction claim says that formatted text is
visible or renders a style (for example, bold, italic, underline, strikethrough,
code, or monospace), record the source-fed proof in the same named instrumented
method:

| Claim | Test file and method | Runtime proof required |
|---|---|---|
| `<exact visible formatting claim>` | `app/src/androidTest/.../*Test.kt#<method>` | Capture plain and formatted Compose nodes with `captureToImage()` and assert `differingPixelCount(...) > 0`, `assertPixels(...)`, or an equivalent explicit pixel comparison |

The rendered-output contract checker validates this method during acceptance,
visual-evidence, and bug-reproduction gates. Assertions about marks, toolbar state,
`AnnotatedString`, text content, or a non-empty full-screen screenshot are
supplemental and cannot replace the rendered-node pixel comparison.

## Shared JSON Scenarios

| Scenario File | API Mock | Expected Domain | Expected UI |
|---------------|----------|-----------------|-------------|
| `scenario.json` | ✅ | ✅ | ✅ |

Location: `sharedContracts/test-scenarios/` or a feature-owned JSON resource catalog in the test target.

---

## Coverage Targets

| Scope | Minimum |
|-------|---------|
| Overall project | ≥ 80% line coverage |
| New ViewModel / UseCase classes | ≥ 90% line coverage |
| Compose screens | excluded |

---

## Verification Commands

```bash
./gradlew testDebugUnitTest          # unit + integration tests
./gradlew :app:koverXmlReportDebug   # machine-readable coverage report
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
./gradlew connectedDebugAndroidTest  # instrumented UI tests (when UI changed)
```
