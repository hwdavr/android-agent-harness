# Test Plan — <Feature Name>

**Feature ID**: `<feature-id>`
**Workspace**: `.scratch/<YYYY-MM-DD>-<feature-id>/`

Use this template in the **Implementation Plan** stage, beside `implementation-plan.md` (the bug
sections are written earlier, in bug-context and reproduction). It owns everything about tests;
`implementation-plan.md` owns how the code changes.

The test plan contains planned cases, preconditions, numbered steps, and expected outcomes only.
Record actual execution status, observations, evidence links, and cleanup results in
`summary.md` (sliced lane: `summary_<FEATURE_ID>.md` per slice); keep verbose artifacts in the run
directory. Do not add execution records, result tables, or actual evidence to this plan — except
the RED reproduction result, which is the bug-reproduction stage's planned evidence.

---

## Rule Applicability Test Mapping

Canonical decisions: [`implementation-plan.md#rule-applicability`](implementation-plan.md#rule-applicability).
Do not duplicate the ten-row matrix. Map every `Required` row to a test, static check, review
evidence, or documented blocking failure. Update the implementation plan's matrix if a new test
trigger appears.

| Required Rule ID | Planned verification |
|---|---|
| <RULE_ID> | <test IDs, planned command, review check, or verification gap> |

## Reproduction Test *(bug-fixing lane only; written in the bug-reproduction stage)*

- File: `app/src/test/java/<package>/<Class>Test.kt`
- Test name: `<method>`
- Production activity: `<Activity>` *(IME/keyboard bugs only)*
- Run result: FAILED — <assertion excerpt proving the bug>

## Exploratory QA Handoff *(only when the bug came from an exploratory QA finding)*

- Report: `.qa-artifacts/<run-id>/report.json`
- Finding: `<finding-id>`

## Acceptance Test Cases

Every `AC-###` in the approved feature block has exactly one primary automated test case. A
secondary test is allowed only for a distinct layer. A fallback, error, boundary, or compatibility
outcome needs its own `AC-###` and its own test. Visual appearance is approved through
`## UI State Verification`, not here.

**Single lane** — one flat table:

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-01 | AC-### | JVM integration / Instrumented UI | `app/src/.../<Class>Test.kt#<method>` | `sharedContracts/test-scenarios/<scenario>.json` or `N/A — no API` | Given <fixture>, when <event> | Assert <state, output, observable result> | `./gradlew <task> --tests "<fully.qualified.Class>"` |

**Sliced lane** — one subsection per user story, in priority order:

### US-1 — <Brief title>

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-US-1-01 | AC-### | JVM integration / Instrumented UI | `app/src/.../<Class>Test.kt#<method>` | `N/A — no API` | Given <fixture>, when <event> | Assert <…> | `./gradlew <task> --tests "<…>"` |

## Spec Coverage Matrix *(sliced lane only)*

Map every `FR-###`, `AC-###`, and `SC-###` in the approved feature block(s) to its user story and
primary acceptance test, or give the approved out-of-scope reason. (The single lane needs no
matrix: its acceptance table already maps every `AC-###` to a test.)

| Source requirement | Capability file | Requirement summary | User story | Primary acceptance test | Handling |
|---|---|---|---|---|---|
| FR-### | `<capability>.md` | <concise text> | US-1 | TC-US-1-01 | In scope |
| AC-### | `<capability>.md` | <concise text> | US-1 | TC-US-1-01 | In scope |
| SC-### | `<capability>.md` | <concise text> | US-1 | TC-US-1-02 | In scope |

## Production Journey Planning Contract *(sliced lane only)*

Classify every user story. **Yes** when any acceptance criterion crosses a destination,
navigation graph, back stack, saved state, destination recreation, or post-return persistence
boundary; `NAV: Required` needs at least one **Yes**. Mirror each row in
`feature_list.json` `production_journey`. The single lane skips this table and declares its NAV
journey directly in `## Production Journey Boundary` below.

| User story | Journey required | Journey reason | Journey acceptance test ID | Production entry point | Planned test file and method | User actions | Return boundary | Post-return assertion |
|---|---|---|---|---|---|---|---|---|
| US-1 | Yes / No | <reason> | `TC-US-1-01` or `N/A` | `AppNavigationHost` or `N/A` | `app/src/androidTest/.../<Class>Test.kt#<method>` or `N/A` | <real gestures> | <boundary> or `N/A` | <visible result> or `N/A` |

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
| <screen> | <input testTag> | <shipped Activity> | app/src/androidTest/java/<package>/<ImeTest>.kt#<openMethod> | app/src/androidTest/java/<package>/<ImeTest>.kt#<dismissMethod> | ANDROID_SERIAL=<device> bash harness/scripts/run-android-instrumented-tests.sh --class <package>.<ImeTest>#<openMethod> --class <package>.<ImeTest>#<dismissMethod> | evidence/android-instrumented.xml |

The XML is the JUnit report emitted by the direct AndroidJUnitRunner wrapper. Copy it from the
run-specific `.qa-artifacts/android-instrumented/` directory into the declared evidence path,
alongside the raw `.log`. Validate source and results with the active Testing/UI verification
stage gate. Static keyboard previews, configuration-only tests, and Content fixtures are
supplemental evidence and cannot justify declaring the production bug fixed.

## UI State Verification *(UI scope; remove otherwise)*

One row per Plan stage ID in `UI_contract.md`. Appearance is approved through a conformance
review, never a screenshot golden: (1) a deterministic review capture rendered at the state's
`UI_contract.md` viewport (the Pen frame's dp size and density) via `@Config` qualifiers, placed
side by side with the approved design for user approval; (2) a structural check on the semantics
tree — required `testTag`s present, in order, with bounds within the contract tolerance.

| Stage ID | Review capture (test#method) | Structural check (test#method) | Command |
|---|---|---|---|
| UI-01 | `app/src/test/java/<package>/review/<Feature>ReviewCaptureTest.kt#<state>` | `app/src/test/java/<package>/<Feature>StructureTest.kt#<state>` | `./gradlew testDebugUnitTest --tests "<package>.<Feature>StructureTest" --tests "<package>.review.<Feature>ReviewCaptureTest"` |

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

### Rendered Output Contract *(when a claim concerns rich text or inline formatting)*

A claim that formatted text is visible (bold, italic, underline, strikethrough, code, monospace)
needs a test that asserts the rendered node's `AnnotatedString` span styles through the semantics
tree, plus the state's review capture in `## UI State Verification`. Toolbar state or model marks
alone are supplemental.

| Claim | Test file and method | Asserted span styles |
|---|---|---|
| `<exact visible formatting claim>` | `app/src/test/java/<package>/<Feature>RenderedTextTest.kt#<method>` | `<SpanStyle(fontWeight = Bold) over "<text>">` |

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
ANDROID_SERIAL=<device> bash harness/scripts/run-android-instrumented-tests.sh --all  # instrumented UI tests (when UI changed)
```
