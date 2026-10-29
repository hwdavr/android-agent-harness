# Test Plan Template

Use this template when producing the test plan in the **Implementation Plan** stage (alongside the implementation plan).

The test plan contains planned cases, preconditions, numbered steps, and expected outcomes only.
Record actual execution status, observations, evidence links, and cleanup results in the change
summary (`summary_v<N>.md`); keep verbose artifacts in the run directory. Do not add execution
records, result tables, or actual evidence to this plan.

---

## Feature / Bug

> One line description of what is being tested.

## Rule Applicability Test Mapping

Canonical decisions: [`spec_v<N>.md#rule-applicability`](spec_v<N>.md#rule-applicability).
Do not duplicate the ten-row matrix. Map every `Required` row from that exact approved
specification to a test, static check, review evidence, or documented blocking failure.
Its `Not applicable` and `Exception` rationales remain canonical in the specification;
update the specification if a new test trigger appears.

| Required Rule ID | Planned verification |
|---|---|
| <RULE_ID> | <test IDs, planned command, review check, or verification gap> |

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
| Ephemeral exploration (`exploratory-qa` / `agent-device`) | ✅ / ❌ | |

---

## Ephemeral Test Cases

Required when ephemeral exploration is included; otherwise record `Not applicable` with a
scope-specific reason. Use `exploratory-qa`/`agent-device` against the installed app. Keep
run artifacts under `.qa-artifacts/<run-id>/`; report the case outcomes and artifact links
in the change summary.

### Case overview

Keep descriptions concise in this table. Every listed ID must also have a detailed
execution procedure below; a table row alone does not define an executable case.

| ID | Requirement / question | Short description | Preconditions / temporary fixture | Expected result |
|---|---|---|---|---|
| QA-01 | <requirement or question> | <brief intent> | <starting screen, installed build/device, session-owned fixture> | <observable outcome> |
| QA-02 | <error/recovery requirement> | <brief failure/recovery intent> | <temporary error fixture and starting state> | <expected failure/recovery behavior> |

### QA-01 — Detailed execution steps

1. Start the session-owned WireMock fixture and establish the declared device-to-host route.
2. Open the actual app screen and verify the required starting state.
3. Select the mock target through the app's runtime routing control and verify its selected state.
4. Trigger the request through the real app UI; name the screen, control, or gesture.
5. Verify the fixture's distinct visible result and correlate the action with its WireMock request receipt.
6. Follow the planned restoration and cleanup procedure.

### QA-02 — Detailed execution steps

1. Prepare the declared error fixture and required app starting state.
2. Select the mock target and trigger the failing request through the real app UI.
3. Verify the expected UI/error/cache behavior and correlate the action with the error-response receipt.
4. Perform the recovery actions and verify their expected result.
5. Follow the planned restoration and cleanup procedure.

Replace these examples with concrete, ordered, numbered steps for every QA ID. Name each
screen/control/gesture and its observable checkpoint. For WireMock cases, explicitly cover
target selection, the shipped-client request trigger, the distinct UI result, and request
correlation. A routing selection or server receipt alone cannot prove the complete journey.

### Session cleanup

Declare the original routing/settings to restore, session-owned mappings to remove, and
reverse rules/server processes to remove or stop. Verify/export before cleanup and perform
cleanup even on failure. Record actual case outcomes, retries, evidence paths, and cleanup
results in the summary, keyed by QA ID. Do not put `Not run`, PASS/FAIL/INCONCLUSIVE result
rows, execution records, or collected evidence in this test plan. Ephemeral cases create no
permanent app test or CI requirement.

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

List every test case grouped by the class under test. Use concise tables for the case descriptions and stable IDs. Provide concrete, ordered, numbered test steps below each table for every case; Given/When/Then rows alone are insufficient.

### `<ClassName>Test.kt` — Unit

| ID | Given | When | Then |
|----|-------|------|------|
| T1 | \<precondition\> | \<action / trigger\> | \<expected outcome\> |
| T2 | \<precondition\> | \<action / trigger\> | \<expected outcome\> |


#### T1 — Detailed steps

1. Arrange the precondition declared in the table.
2. Perform the declared action or trigger.
3. Assert the expected outcome.

#### T2 — Detailed steps

1. Arrange this case's precondition.
2. Perform this case's action or trigger.
3. Assert this case's expected outcome.

### `<ClassName>IntegrationTest.kt` or `<FixtureServer>InstrumentedTest.kt` — Integration

> **MANDATORY**: Every new or exercised API endpoint must have at least one integration test using a shared JSON
> scenario. When a real app-process HTTP boundary is required, the owning test may run in the instrumented target
> beside a local loopback server and must assert request receipts plus the shipped client's observable result.

| ID | Given | When | Then | Shared Scenario |
|----|-------|------|------|-----------------|
| T3 | \<precondition\> | \<action / trigger\> | \<expected outcome\> | `scenario.json` |
| T4 | API returns error | load data | show error UiState | `scenario-error.json` |


#### T3 — Detailed steps

1. Arrange the precondition declared in the table.
2. Perform the declared action or trigger.
3. Assert the expected outcome.

#### T4 — Detailed steps

1. Arrange this case's precondition.
2. Perform this case's action or trigger.
3. Assert this case's expected outcome.

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
