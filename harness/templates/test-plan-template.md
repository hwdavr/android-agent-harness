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

Declare each item's execution intent before choosing a layer: maintained regression for
the approved app change, or ephemeral exploration using `exploratory-qa`/`agent-device`.
For ephemeral WireMock checks, name the run-scoped scenario, UI journey, request evidence,
and cleanup; do not invent a permanent test class, shared regression fixture, or CI job.
The integration and instrumented requirements below apply to maintained regression scope.

| Layer | Included | Reason |
|-------|----------|--------|
| Unit tests (`app/src/test/`) | ✅ / ❌ | |
| Integration tests (`app/src/test/` or instrumented loopback boundary) | ✅ / ❌ | |
| Instrumented UI tests (`app/src/androidTest/`) | ✅ / ❌ | |

---

## Ephemeral Test Cases

Required when ephemeral exploration is included; otherwise record `Not applicable` with
a scope-specific reason. Assign stable `QA-xx` IDs and trace them to the relevant
requirement or exploratory question. These cases use `exploratory-qa`/`agent-device`
against the installed app. Keep generated scenarios, native WireMock mappings, captures,
reports, and cleanup receipts under `.qa-artifacts/<run-id>/`.

### Planned cases

| ID | Requirement / question | Preconditions / temporary fixtures | agent-device actions | Expected result | Evidence required |
|---|---|---|---|---|---|
| QA-01 | <requirement ID or question> | <installed build/device, starting state, session-owned fixture> | <actual UI entry, gestures, and request trigger> | <observable UI/state/network outcome> | <screenshots, state checkpoint, correlated request receipt, report> |
| QA-02 | <error/recovery requirement> | <temporary error fixture> | <real UI trigger and recovery actions> | <expected failure/recovery behavior> | <UI/state evidence and fixture receipt> |

### Execution results

Fill this table after execution. Use `Not run` during planning, then `PASS`, `FAIL`, or
`INCONCLUSIVE` with actual evidence. A planned case is not evidence that it was tested.
Reference the run's report and case-specific artifacts; do not copy generated run JSON
into this document. Missing runtime, routing, required hooks, or receipts cannot PASS.

| Case ID | Run ID / build / device | Outcome | Actual result | Evidence paths | Cleanup result / receipt |
|---|---|---|---|---|---|
| QA-01 | <run-id, APK hash/version, device/OS> | Not run | <observed result or missing prerequisite> | `.qa-artifacts/<run-id>/report.json` and <case evidence> | <routing restored, session mocks reset, owned processes stopped; receipt> |
| QA-02 | <run-id, APK hash/version, device/OS> | Not run | <observed result or missing prerequisite> | <case evidence> | <cleanup outcome and receipt> |

### Session cleanup

Declare the original routing and other settings to restore, session-owned mappings to
remove, and any reverse rules or server processes created for the run. Verify/export
before cleanup, perform cleanup even on failure, and record its result separately from
the case outcome. Ephemeral cases create no permanent app test or CI requirement.

---

## Ephemeral Test Cases

Required when ephemeral exploration is included; otherwise record `Not applicable` with
a scope-specific reason. Assign stable `QA-xx` IDs and trace them to the relevant
requirement or exploratory question. These cases use `exploratory-qa`/`agent-device`
against the installed app. Keep generated scenarios, native WireMock mappings, captures,
reports, and cleanup receipts under `.qa-artifacts/<run-id>/`.

### Planned cases

| ID | Requirement / question | Preconditions / temporary fixtures | agent-device actions | Expected result | Evidence required |
|---|---|---|---|---|---|
| QA-01 | <requirement ID or question> | <installed build/device, starting state, session-owned fixture> | <actual UI entry, gestures, and request trigger> | <observable UI/state/network outcome> | <screenshots, state checkpoint, correlated request receipt, report> |
| QA-02 | <error/recovery requirement> | <temporary error fixture> | <real UI trigger and recovery actions> | <expected failure/recovery behavior> | <UI/state evidence and fixture receipt> |

### Execution results

Fill this table after execution. Use `Not run` during planning, then `PASS`, `FAIL`, or
`INCONCLUSIVE` with actual evidence. A planned case is not evidence that it was tested.
Reference the run's report and case-specific artifacts; do not copy generated run JSON
into this document. Missing runtime, routing, required hooks, or receipts cannot PASS.

| Case ID | Run ID / build / device | Outcome | Actual result | Evidence paths | Cleanup result / receipt |
|---|---|---|---|---|---|
| QA-01 | <run-id, APK hash/version, device/OS> | Not run | <observed result or missing prerequisite> | `.qa-artifacts/<run-id>/report.json` and <case evidence> | <routing restored, session mocks reset, owned processes stopped; receipt> |
| QA-02 | <run-id, APK hash/version, device/OS> | Not run | <observed result or missing prerequisite> | <case evidence> | <cleanup outcome and receipt> |

### Session cleanup

Declare the original routing and other settings to restore, session-owned mappings to
remove, and any reverse rules or server processes created for the run. Verify/export
before cleanup, perform cleanup even on failure, and record its result separately from
the case outcome. Ephemeral cases create no permanent app test or CI requirement.

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

## IME Production Boundary

Mandatory for every input in `UI_contract.md`'s IME State Coverage, even when `NAV` is Not
applicable. Predeclare targets during planning; the source and result XML must exist by Testing.
Use `createAndroidComposeRule<ProductionActivity>()` with the shipped content and manifest.
Replacing Activity content via `setContent` makes the fixture supplemental. Follow the observed
entry route, focus the real input, wait for settled IME visibility/non-zero insets, and assert
window-coordinate control bounds against the keyboard edge. Dismiss and assert restoration.
Open and dismissal may share a method when that method proves the complete transition.

| Screen | Input tag | Production activity | Open test | Dismiss test | Command | Result XML |
|---|---|---|---|---|---|---|
| <screen> | <input testTag> | <shipped Activity> | app/src/androidTest/java/<package>/<ImeTest>.kt#<openMethod> | app/src/androidTest/java/<package>/<ImeTest>.kt#<dismissMethod> | ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=<package>.<ImeTest> | evidence/<runner-results>.xml |

The XML is the copied raw Android runner result, with the selected class/methods executed and
not failed, errored, or skipped. Validate source and results with the active Testing/UI verification
stage gate. Static keyboard previews, configuration-only tests, and Content fixtures are
supplemental evidence and cannot justify declaring the production bug fixed.

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

### `<Feature>RoborazziTest.kt` — Dedicated Visual Comparison *(only when `requires_visual_verification == true`)*

> **MANDATORY**: When visual verification is required, write a dedicated JVM `app/src/test/java/<package>/roborazzi/*RoborazziTest.kt` class that renders the active Composable in every critical visual state with deterministic fixtures and calls `captureRoboImage()` against the approved Pen PNG. The binding command is `./gradlew app:verifyRoborazziDebug`; device screenshots are not visual acceptance evidence.

| ID | Visual State | Composable Under Test | Comparison Scope | Approved Reference |
|----|-------------|----------------------|------------------|--------------------|
| T-VIS-1 | \<state name (e.g. default content)\> | \<Composable name\> | `screen` / `component` | `design/mockup_<screen>_<state>.png` |
| T-VIS-2 | \<state name (e.g. expanded/fullscreen)\> | \<Composable name\> | `screen` / `component` | `design/mockup_<screen>_<state>.png` |

---

Each visual row's sprint-contract command must scope `verifyRoborazziDebug` to the exact
`<package>.<Feature>RoborazziTest.<method>` with `--tests`.

### Roborazzi target contract

The JVM Compose test renders the same deterministic scope, including visible text, images, and
selection, and calls `captureRoboImage("<reference>.png")`. The reference PNG must be exported
from the canonical `pen_source`/`pen_node_id` in `visual-target.json`; it must not be recorded from
the implementation. If the full screen contains unrelated content, export the approved component
and declare `comparison.scope: component`; do not fall back to an instrumented screenshot. The
binding command is `./gradlew app:verifyRoborazziDebug`. `recordRoborazziDebug` and
`verifyAndRecordRoborazziDebug` are authoring/recovery commands only and are not acceptance evidence.

| ID | Pen source/node | Composable under test | Verification command | Reference PNG |
|----|----------------|-----------------------|----------------------|---------------|
| T-VIS-R1 | `../UI_design/fun_photo_editor.pen#<node-id>` | `<Composable name>` | `./gradlew app:verifyRoborazziDebug --tests "<package>.<ScreenName>RoborazziTest.<method>"` | `design/mockup_<screen>.png` |

### Rendered Output Contract *(when a visual claim concerns rich text or inline formatting)*

If a test-plan, acceptance, or reproduction claim says that formatted text is
visible or renders a style (for example, bold, italic, underline, strikethrough,
code, or monospace), record the source-fed proof in the same named Roborazzi method:

| Claim | Test file and method | Runtime proof required |
|---|---|---|
| `<exact visible formatting claim>` | `app/src/test/java/<package>/roborazzi/*RoborazziTest.kt#<method>` | `captureRoboImage()` verifies the approved Pen reference containing the formatted appearance |

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
