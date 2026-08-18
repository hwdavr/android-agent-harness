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

Link the feature workspace artifact: `platform-capability-matrix.md`.

The matrix MUST declare the minimum API, target API, every important API boundary, the single owner of each device resource, the input/output contract, and the required fallback for unsupported platforms. A missing emulator, device, model, locale, permission, hardware capability, or platform service is an evidence failure—not a passing skip. The exact failure policy is `fail_loudly`: the command must exit non-zero or the feature must be marked `Blocked`/`Revise`.

Platform-bound features MUST declare at least one real instrumented boundary test. A fake adapter, fake recognizer, JVM-only intent test, or manually emitted callback is supplemental evidence and cannot satisfy the platform gate by itself. The test must exercise the shipped Android boundary and record a successful `connectedDebugAndroidTest` result in `feature_list.json` evidence.

---

## Spec Coverage Matrix *(required)*

Map every `FR-*` and `AC-*` from the approved source spec. Also map each edge case, non-functional constraint, verification expectation, and changed design requirement to a user story, or record the approved out-of-scope reason. Preserve source IDs verbatim.

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

Every acceptance criterion must have exactly one primary automated test case. A secondary test may be listed only when it verifies a distinct layer. Do not use manual inspection as the sole proof of a user-visible criterion.

| Test ID | Covers AC | Test layer | Test file and method | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|
| TC-US-1-01 | AC-US-1-01 | JVM integration / Instrumented UI | `app/src/.../[Class]Test.kt#[method]` | Given [fixture], when [event] | Assert [state, output, and observable result] | `./gradlew [task] --tests "[fully.qualified.Class]"` |
| TC-US-1-02 | AC-US-1-02 | JVM unit / Instrumented UI | `app/src/.../[Class]Test.kt#[method]` | Given [fixture], when [event] | Assert [state, output, and observable result] | `./gradlew [task] --tests "[fully.qualified.Class]"` |
| TC-US-1-VIS | AC-US-1-01 | Visual verification *(only for the final user-reachable slice with `requires_visual_verification == true`)* | State-verifying screenshot capture | Given the production app is navigated to the completed target state and that state is asserted by a deterministic UI test or accessibility query, when the capture command runs | The state assertion passes and the non-empty screenshot is saved at `$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png` for visual review against `$FEATURE_DIR/design.md` | `<target-state-assertion-command> && mkdir -p "$FEATURE_DIR/visual_evidence" && adb exec-out screencap -p > "$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png" && test -s "$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png"` |

**Verification Rules**:

1. The test must execute the production entry point for this user story. A unit test of an uncalled helper or use case is insufficient.
2. A user-visible flow that crosses presentation, domain, or data boundaries must include an integration or instrumented test covering the complete path.
3. The assertions must cover every named outcome in the linked AC, including fallback, error, and persistence behavior where required.
4. Record the Test ID, command, exit status, and result in the feature evidence before a status can become `passing`.
5. **Visual verification gate** *(applies only when the slice's `requires_visual_verification` flag in `feature_list.json` is `true`)*: select one final user story that has a stable production entry point and makes the completed visual flow reviewable. That story MUST include one `TC-US-*-VIS` row per visually distinct completed-flow state that needs visual assessment; intermediate UI slices do not need screenshot rows. Each visual row's `Exact command` MUST first prove the named production screen state with a deterministic instrumented UI assertion or an accessibility-query assertion, then capture the screenshot in the same verified state. It must save the image at `$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png` and verify that the file is non-empty. A bare `adb exec-out screencap` command is invalid because it can capture an unrelated app screen. The Generator cannot transition the visual-verification owner to `passing` until every declared `TC-US-*-VIS` row has exit code 0, a saved screenshot, and recorded target-state proof. The Evaluator then visually compares the captured screenshot against `$FEATURE_DIR/design.md` and records any deviation in layout, typography, color, spacing, or control placement as a review finding — canvas/photo content may legitimately differ between mockup and real app, so the comparison focuses on UI chrome, not image content.
   Before the visual owner can pass, create `$FEATURE_DIR/visual_evidence/reference-anchor-verification.md` from `harness/templates/visual-reference-anchor-verification-template.md`. It must contain exactly one row per `TC-US-*-VIS-*`, cite the non-empty approved `design/` asset and matching actual screenshot, name the visual-bounds `testTag` and runtime test method, and state a concrete bounds relation. If the reference concerns a visual that sits inside a larger touch target, measure a test tag attached to the visual shape—not only the touch target.
   The visual owner's `feature_list.json` must mirror these rows in `acceptance_test_ids`, include each visual method in `verification`, and record successful connected-test evidence for each row. Run `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"` to enforce this alignment.
6. **Platform verification gate**: run `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --planning` during planning. During delivery, run `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"`; a slice that owns a declared real-boundary test cannot be accepted or marked `passing` until this exits 0. A non-owning slice validates the planned contract with the same slice-scoped command, while `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate` remains mandatory before final feature evaluation.

---

### US-2: [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Criterion**:

1. **AC-US-2-01 Given** [initial state], **When** [action], **Then** [observable expected outcome]

**Acceptance Test Cases** *(required for implementation authorization)*:

| Test ID | Covers AC | Test layer | Test file and method | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|
| TC-US-2-01 | AC-US-2-01 | JVM integration / Instrumented UI | `app/src/.../[Class]Test.kt#[method]` | Given [fixture], when [event] | Assert [state, output, and observable result] | `./gradlew [task] --tests "[fully.qualified.Class]"` |

---

### US-3: [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Criterion**:

1. **AC-US-3-01 Given** [initial state], **When** [action], **Then** [observable expected outcome]

**Acceptance Test Cases** *(required for implementation authorization)*:

| Test ID | Covers AC | Test layer | Test file and method | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|
| TC-US-3-01 | AC-US-3-01 | JVM integration / Instrumented UI | `app/src/.../[Class]Test.kt#[method]` | Given [fixture], when [event] | Assert [state, output, and observable result] | `./gradlew [task] --tests "[fully.qualified.Class]"` |
---

[Add more user stories as needed (US-4, US-5, …), each with an assigned priority]

---

## 📊 Sprint Log
> The audit trail tracking each agent's execution phase, revisions, and evaluation scores.

| Phase | Agent | Target / Outcome | Notes & Core Decisions |
| :--- | :--- | :--- | :--- |
| **Planning** | Planner | `sprint-contract.md` compiled | Criteria defined and scope boundaries set. |
| **Implementation** | Generator | `{Initial implementation / Code written}` | |
| **Review 1** | Evaluator | `{Score X/5 / Findings list}` | |
| **Revision 1** | Generator | `{Fixes applied}` | |
| **Final Review** | Evaluator | APPROVED (Score: `X/5`) | All criteria successfully validated. |
