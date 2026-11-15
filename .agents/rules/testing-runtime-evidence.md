# Runtime Testing Evidence Rules

## When to Load

Load this rule when the approved scope or submitted diff touches Compose rendering, user gestures,
navigation/back stack, `SavedStateHandle`, destination recreation, post-return persistence, Android
SDK behavior, hardware/device services, models, locales, permissions, or visual evidence.

## Runtime Selection and Execution

First classify the request using `testing-strategy.md`. For an ephemeral exploratory run,
drive the installed app through `agent-device`; collect actual UI actions, state, request
receipts, and cleanup under `.qa-artifacts/<run-id>/`. Do not translate a WireMock/device
journey into a permanent instrumented test merely because it crosses Android networking.
The instrumented source/XML requirements below govern maintained feature/bug regression
acceptance; they do not require authoring test code for standalone exploratory QA.

- Prefer an emulator for instrumented UI tests; use a connected physical device only when no
  emulator is present.
- Use `createComposeRule()` for isolated rendering/callback checks.
- Use `createAndroidComposeRule` or the production Activity/navigation graph when Activity,
  navigation, lifecycle, saved state, or post-return behavior is part of the claim.
- Use stable semantics/test tags and real UI gestures.
- Do not use `Thread.sleep`; use `waitUntil` or `waitForIdle`.
- Do not call a real production backend; use deterministic local fixtures.
- When an instrumented loopback server supplies the endpoint, start it before
  app launch, pass a validated local URL through composition or DI, record
  redacted method/path/status receipts, and stop it during teardown. Listener
  failure, missing URL, zero requests, or a live-network fallback is blocked
  evidence.

## Platform-Bound Evidence

A platform-bound feature requires a real instrumented boundary test in addition to deterministic
JVM/fake tests. The test must exercise the shipped adapter against the declared Android API or
resource and assert an observable platform result.

Fake adapters, fake callbacks, JVM-only intent assertions, and seam instantiation are supplemental.
If a required runtime, device, model, locale, permission, hardware feature, SDK, or service is
unavailable, the command must fail or record `Blocked`/`Revise`; it cannot pass by skip or warning.

## IME Window Boundary

Editable inputs require full-window closed/open designs and an explicit layout policy in the
UI contract's `IME State Coverage` inventory. Keep the focused input and required actions visible;
record the dismissed state, which may reuse the closed design when identical.

IME geometry is a production Activity claim even when navigation is unchanged. Primary evidence
launches `createAndroidComposeRule<ProductionActivity>()` with its shipped manifest configuration
and content. Do not call `setContent` to replace it. Follow the observed app route, tap the real
input, wait for settled non-zero IME insets/visibility, and assert input/panel/result/action bounds
in window coordinates against the real keyboard top. Dismiss the keyboard, wait for zero/hidden
insets, and assert restoration. Record the selected open/dismiss methods and runner XML in the
test plan's `IME Production Boundary` table. A configuration assertion alone is supplemental.

Static Gboard images and JVM review captures prove deterministic appearance only. Clearing
focus before capture, a prefilled query, or a generic Activity fixture cannot establish the
shipped IME boundary or justify skipping a production replay. The gate checks source structure
and selected executed JUnit cases; it does not infer correctness from method names alone.

## Production Journey Boundary

For navigation, saved-state, back-stack, destination recreation, or post-return persistence:

- Mount the production Activity or navigation graph.
- Perform real UI gestures through stable semantics/test tags.
- Cross the declared return boundary.
- Assert the visible result after returning.

Direct ViewModel calls, internal state mutation, manually invoked callbacks, and Content-only tests
are supplemental. Register shipped required journeys in `docs/product/journey-registry.yaml`.
During a single-lane Testing stage, run each affected registered journey with
`bash harness/scripts/check-journey-registry.sh --run-one <journey-id>`. Run `--run-all`
when the active harness or review workflow requires the full journey regression gate.

## UI Conformance Evidence

UI appearance is approved by a conformance review, never by a screenshot golden. A design-tool export
and a Compose render differ in text rasterization, hinting, anti-aliasing, and stroke rounding, so a
pixel comparison between them is not a fair or passable gate. For every `UI_contract.md` state:

- **Review capture**: a JVM `*ReviewCaptureTest` under `app/src/test/java/<package>/roborazzi/` renders the
  production Composable at the state's Viewport (the Pen frame's dp size and density, via `@Config`
  qualifiers) with its deterministic fixture, theme, locale, and font scale. Never resize a capture or
  an export to make them match. Capture tests run only with `-Proborazzi.test.record=true`; normal
  unit-test and CI runs exclude the `roborazzi` package. Structural tests stay outside that package.
- **Structural check**: a JVM semantics or instrumented test asserts that required `testTag`s are
  present, ordered, visible, unclipped, and within the contract tolerance (default 4dp
  position/spacing, 5% size).
- **Registered components**: the state's reused design-system components are called from the planned
  UI files, and no wrapped Material primitive is called outside its wrapper.
- **Approval**: the user reviews the capture beside the approved design; the decision is recorded per
  state in `ui_verification.json`.

`recordRoborazziDebug`, `verifyRoborazziDebug`, and `verifyAndRecordRoborazziDebug` are not acceptance
evidence, and an implementation-recorded screenshot is never promoted to a golden. Instrumented tests
prove interaction, navigation, and platform behavior; `UiAutomation.takeScreenshot()`,
`captureToImage()`, and ADB screencaps may support a review but are not the review capture of record.

## Rendered Rich-Text Evidence

Claims that bold, italic, underline, strikethrough, code, monospace, or another inline style is
visibly rendered require a test that asserts the rendered node's `AnnotatedString` span styles through
`SemanticsProperties.Text`, plus the state's review capture. Model marks, toolbar state, text content,
and a non-empty PNG alone are supplemental. Run `bash harness/scripts/check-rendered-output-contract.sh`
for the named method.
