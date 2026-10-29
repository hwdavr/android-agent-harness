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

Static Gboard images and component Roborazzi tests prove deterministic appearance only. Clearing
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
During an ad-hoc Testing stage, run each affected registered journey with
`bash harness/scripts/check-journey-registry.sh --run-one <journey-id>`. Run `--run-all`
when the active harness or review workflow requires the full journey regression gate.

## Visual Evidence Capture

When `requires_visual_verification` is true, a dedicated JVM `*RoborazziTest.kt` must render every
contract state with deterministic fixtures and call `captureRoboImage()` against the approved Pen
export. Each visual Test ID requires `./gradlew app:verifyRoborazziDebug` evidence and a
reference-anchor row tied to a visual-bounds `testTag`, JVM method, measured relationship, and
tolerance.

Instrumented tests prove interaction, navigation, and platform behavior. They do not capture or
provide visual-comparison acceptance evidence. `UiAutomation.takeScreenshot()`, `captureToImage()`,
and ADB screencaps are not substitutes for a passing Roborazzi comparison.

## Rendered Rich-Text Evidence

Claims that bold, italic, underline, strikethrough, code, monospace, or another inline style is
visibly rendered require a Roborazzi comparison of the named deterministic state. The reference
must contain the approved formatted appearance and the JVM test must call `captureRoboImage()`.

Model marks, `AnnotatedString` contents, toolbar state, text content, and a non-empty PNG are
supplemental and do not prove rendered appearance. Run
`bash harness/scripts/check-rendered-output-contract.sh` for the named method.

## Visual Comparison Contract

- Roborazzi is the binding visual-comparison engine. Every target declares
  `comparison.engine: roborazzi`, `content_alignment: exact`, and a `scope` of `screen` or
  `component`.
- A whole-screen comparison requires the Pen export and deterministic JVM fixture to contain the
  same visible content. When surrounding content differs, export the approved static component
  from the Pen design and compare that component in isolation; do not replace the comparison with
  an instrumented screenshot or an implementation-recorded golden.
- The approved reference is a PNG exported from the canonical `.pen` source named by `pen_source` and `pen_node_id` in `visual_evidence/visual-target.json`. A screenshot recorded from the implementation is never promoted as a golden.
- `visual_evidence/visual-target.json` is the canonical feature-owned target manifest. It defines
  appearance, logical size, locale, named deterministic content states, the approved Pen source,
  and the comparison scope. Each contract row names one stable state ID directly; a runtime
  screenshot map is not used.
- Time, user content, identifiers, and keyboard variation must each be explicitly fixed, cropped, absent, or narrowly masked with an approval rationale. Masks may exclude only genuinely variable content; they cannot make fundamentally different design and runtime screens count as the same pixel target.
- Missing, ambiguous, or mismatched references fail; they are never silently skipped.
- Preserve Roborazzi compare/actual artifacts when verification finds a difference.
