# Sprint Contract Template

Use this template when producing the sprint contract in the **Requirement Analysis & Scoping** stage of the Planner agent.

---

## 🏃 Sprint Overview

*   **Sprint:** `{sprint-id}` (e.g., P05-03)
*   **Feature:** `{feature-name}` (e.g., Multi-turn Q&A conversation history)
*   **Duration:** `{sprint-duration}` (e.g., 1 sprint)

---

## 🎯 Scope

### In Scope
> Explicit list of target capabilities, user flows, and technical components to be implemented.
*   [ ] `{In-scope capability 1}`
*   [ ] `{In-scope capability 2}`
*   [ ] `{In-scope capability 3}`

### Out of Scope
> Explicit list of boundaries, exclusions, and related features deferred to future sprints.
*   *   `{Out-of-scope item 1}` (separate feature/deferred)
*   *   `{Out-of-scope item 2}` (separate feature/deferred)

## Platform Capability & Environment Contract *(required)*

Declared via `platform_validation` in `feature_list.json`. When `required: true`, link `platform-capability-matrix.md` and declare real instrumented boundary tests; missing platform resources fail loudly (`fail_loudly`). When `required: false`, the JSON declaration plus reason is the complete contract.

## Rule Applicability Contract *(required)*

Copy the approved ten-row matrix from the requirement artifact. The decision must be `Required`, `Not applicable — <feature-specific reason>`, or `Exception — approved by <user/date>`. Every `Required` row must map to implementation and verification evidence before a slice can pass.

| Rule ID | Rule document | Decision | Slice evidence |
|---|---|---|---|
| ARCH | `android-architecture.md` | <decision> | |
| IMPL | `implementation-rules.md` | <decision> | |
| TEST | `testing-strategy.md` | <decision> | |
| SUI | `compose-rules.md` | <decision> | |
| L10N | `localization-rules.md` | <decision> | |
| NAV | `navigation-rules.md` | <decision> | |
| API | `api-contract-rules.md` | <decision> | |
| OBS | `observability.md` | <decision> | |
| ANL | `analytics-rules.md` | <decision> | |
| SEC | `android-security.md` | <decision> | |

---

## Generated Context Index *(execution aid — no new authority)*

At the start of each complex-feature slice, run:

```bash
bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"
```

The output is derived from this approved contract and `feature_list.json`. It reports
the selected slice, source hashes, rule IDs that are `Required` or exceptions, and
execution flags. It is a disposable lookup for selecting context, never an approval
artifact. Do not copy its contents, this matrix, or acceptance criteria into the slice
summary; cite these authoritative source paths and hashes instead.

---

## Production Journey Planning Contract *(required)*

Classify every user-story slice explicitly. Set **Yes** when any acceptance
criterion crosses a destination, navigation graph, back stack, saved state,
destination recreation, or post-return persistence boundary. `NAV: Required` in
the Rule Applicability Contract must have at least one **Yes** row. A **Yes** row
must name the production entry point, the planned instrumented test method, the
real UI actions, the return boundary, and the visible post-return assertion.
Use **No** with a feature-specific reason when the slice has no such boundary.
The same contract is mirrored by `production_journey` in `feature_list.json`.

| User story | Journey required | Journey reason | Journey acceptance test ID | Production entry point | Planned test file and method | User actions | Return boundary | Post-return assertion |
|---|---|---|---|---|---|---|---|---|
| US-1 | Yes / No | `{why this slice does or does not cross a production boundary}` | `TC-US-1-01` or `N/A` | `AppNavigationHost` or `N/A` | `app/src/androidTest/.../[Class]Test.kt#[method]` or `N/A` | `{real UI gestures}` | `{back/pop/destination-selection boundary}` or `N/A` | `{visible result after return}` or `N/A` |

The planning gate validates that every feature has a classification, that every
**Yes** row maps to an instrumented acceptance-test row, and that navigation or
lifecycle signals in an acceptance test cannot be left without a journey owner.

## Journey Registry Update *(conditional — when journey_required is Yes)*

When a slice declares `Journey required: Yes`, the generator must register the
journey in `harness/journey-registry.yaml` during the Finalize stage. The registry
entry becomes a permanent regression gate for all future features.

---

## Spec Coverage Matrix *(required)*

Map every `FR-*` and `AC-*` from the approved source spec. Also map each edge case, non-functional constraint, verification expectation, and changed design requirement to a user story, or record the approved out-of-scope reason. Preserve source IDs verbatim.

An `FR-*` that promises multiple outcomes (happy path plus fallback/error/boundary/compatibility) must have one `AC-*` per outcome, each with its own acceptance test. A single AC for a multi-outcome FR is a coverage gap; if the spec did not decompose it, add the missing ACs here rather than silently mapping only the happy path.

| Source requirement | Requirement summary | Primary user story | Primary acceptance test | Handling |
|---|---|---|---|---|
| FR-001 | `{concise requirement text}` | US-1 | TC-US-1-01 | In scope |
| AC-001 | `{concise acceptance text}` | US-1 | TC-US-1-01 | In scope |
| Edge case: `{name}` | `{required behavior}` | US-2 | TC-US-2-02 | In scope |
| NFR: `{name}` | `{constraint}` | US-2 | TC-US-2-01 | In scope |
| Design: `{name}` | `{changed design behavior}` | US-3 | TC-US-3-01 | In scope |

---

## User Scenarios & Testing *(mandatory)*

### US-1: [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Criterion**:

1. **AC-US-1-01 Given** [initial state], **When** [action], **Then** [observable expected outcome]
2. **AC-US-1-02 Given** [initial state], **When** [action], **Then** [observable expected outcome]

**Acceptance Test Cases** *(required for implementation authorization)*:

Every acceptance criterion must have exactly one primary automated test case. A secondary test may be listed only when it verifies a distinct layer. Do not use manual inspection as the sole proof of a user-visible criterion. Do not let one AC bundle multiple named outcomes — split it so each outcome gets its own test; a fallback, error, boundary, or compatibility path promised by an FR needs its own AC and test, not a secondary assertion inside the happy-path test.

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-US-1-01 | AC-US-1-01 | JVM integration / Instrumented UI | `app/src/.../[Class]Test.kt#[method]` | `sharedContracts/test-scenarios/<scenario>.json` or `N/A — no API` | Given [fixture], when [event] | Assert [state, output, and observable result] | `./gradlew [task] --tests "[fully.qualified.Class]"` |
| TC-US-1-02 | AC-US-1-02 | JVM unit / Instrumented UI | `app/src/.../[Class]Test.kt#[method]` | `sharedContracts/test-scenarios/<scenario>.json` or `N/A — no API` | Given [fixture], when [event] | Assert [state, output, and observable result] | `./gradlew [task] --tests "[fully.qualified.Class]"` |
| TC-US-1-VIS | AC-US-1-01 | Visual verification | Dedicated `*VisualFlowTest.kt#capture<State>` in-test screenshot capture | N/A — no API | Capture scope: component. Given the target production Composable is rendered in the target visual state, when the test is idle and the active window is captured | The in-test capture produces a non-empty PNG on device, pulled to the feature visual evidence directory for review against the feature design | `env ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=<package>.<Feature>VisualFlowTest#capture<State> && adb -s emulator-5554 pull /sdcard/Download/<screen_id>_<state>.png "$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png" && test -s "$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png"` |

When a row claims that rich text or an inline formatting mark is visibly rendered,
its named instrumented method must also capture the relevant Compose node(s) with
`captureToImage()` and assert an explicit pixel comparison (`differingPixelCount`,
`assertPixels`, or an equivalent checked comparison). Model marks, toolbar state,
text content, and a non-empty full-screen screenshot do not prove rendered
appearance; the acceptance and visual validators enforce this source-fed contract.

**Verification Rules**:

1. Tests must execute production entry points and cover all linked AC outcomes (including fallback and error paths).
2. Traceability: Validate with `bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --test "$FEATURE_ID"` (and `--evaluate "$FEATURE_ID"` after recording passing evidence).
3. **Visual gate** (when `requires_visual_verification == true`): The final reviewable user story declares `TC-US-*-VIS` rows targeting dedicated `*VisualFlowTest.kt` methods. In-test captures save to `/sdcard/Download/<name>.png` and pull to `$FEATURE_DIR/visual_evidence/<name>.png`. Validate alignment via `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"`. Complete `visual_evidence/reference-anchor-verification.md`. Post-test external screencaps are strictly forbidden.
4. **Platform gate**: Validate during planning via `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --planning` and during delivery via `--evaluate --slice "$FEATURE_ID"`.

---

### US-2: [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Criterion**:

1. **AC-US-2-01 Given** [initial state], **When** [action], **Then** [observable expected outcome]

**Acceptance Test Cases** *(required for implementation authorization)*:

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-US-2-01 | AC-US-2-01 | JVM integration / Instrumented UI | `app/src/.../[Class]Test.kt#[method]` | `sharedContracts/test-scenarios/<scenario>.json` or `N/A — no API` | Given [fixture], when [event] | Assert [state, output, and observable result] | `./gradlew [task] --tests "[fully.qualified.Class]"` |

---

### US-3: [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Criterion**:

1. **AC-US-3-01 Given** [initial state], **When** [action], **Then** [observable expected outcome]

**Acceptance Test Cases** *(required for implementation authorization)*:

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-US-3-01 | AC-US-3-01 | JVM integration / Instrumented UI | `app/src/.../[Class]Test.kt#[method]` | `sharedContracts/test-scenarios/<scenario>.json` or `N/A — no API` | Given [fixture], when [event] | Assert [state, output, and observable result] | `./gradlew [task] --tests "[fully.qualified.Class]"` |
---

[Add more user stories as needed (US-4, US-5, …), each with an assigned priority]

---

## 📊 Sprint Log
> Execution audit trail and evaluation records are tracked in `feature_list.json` (`execution_records`) and slice summaries.
