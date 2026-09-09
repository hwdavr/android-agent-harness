# Runtime Testing Evidence Rules

## When to Load

Load this rule when the approved scope or submitted diff touches Compose rendering, user gestures,
navigation/back stack, `SavedStateHandle`, destination recreation, post-return persistence, Android
SDK behavior, hardware/device services, models, locales, permissions, or visual evidence.

## Runtime Selection and Execution

- Prefer an emulator for instrumented UI tests; use a connected physical device only when no
  emulator is present.
- Use `createComposeRule()` for isolated rendering/callback checks.
- Use `createAndroidComposeRule` or the production Activity/navigation graph when Activity,
  navigation, lifecycle, saved state, or post-return behavior is part of the claim.
- Use stable semantics/test tags and real UI gestures.
- Do not use `Thread.sleep`; use `waitUntil` or `waitForIdle`.
- Do not call a real production backend; use deterministic local fixtures.

## Platform-Bound Evidence

A platform-bound feature requires a real instrumented boundary test in addition to deterministic
JVM/fake tests. The test must exercise the shipped adapter against the declared Android API or
resource and assert an observable platform result.

Fake adapters, fake callbacks, JVM-only intent assertions, and seam instantiation are supplemental.
If a required runtime, device, model, locale, permission, hardware feature, SDK, or service is
unavailable, the command must fail or record `Blocked`/`Revise`; it cannot pass by skip or warning.

## Production Journey Boundary

For navigation, saved-state, back-stack, destination recreation, or post-return persistence:

- Mount the production Activity or navigation graph.
- Perform real UI gestures through stable semantics/test tags.
- Cross the declared return boundary.
- Assert the visible result after returning.

Direct ViewModel calls, internal state mutation, manually invoked callbacks, and Content-only tests
are supplemental. Register shipped required journeys in `docs/product/journey-registry.yaml` and
run `bash harness/scripts/check-journey-registry.sh --run-all` during verification.

## Visual Evidence Capture

When `requires_visual_verification` is true, a dedicated `*VisualFlowTest.kt` must render every
contract state and capture evidence while the test is active and idle, using
`UiAutomation.takeScreenshot()` or `captureToImage()`. Save to `/sdcard/Download/<name>.png` and
retrieve with `adb pull`.

Post-test external screencaps are prohibited because the test window has already been destroyed.
Every visual Test ID requires a non-empty screenshot and a reference-anchor row tied to a
visual-bounds `testTag`, runtime method, measured relationship, and tolerance.

## Rendered Rich-Text Evidence

Claims that bold, italic, underline, strikethrough, code, monospace, or another inline style is
visibly rendered require Compose-node pixels. Capture plain and formatted nodes with
`captureToImage()` and assert an explicit checked pixel difference such as
`differingPixelCount(...) > 0` or `assertPixels(...)`.

Model marks, `AnnotatedString` contents, toolbar state, text content, and a non-empty full-screen
PNG are supplemental and do not prove rendered appearance. Run
`bash harness/scripts/check-rendered-output-contract.sh` for the named method.

## Visual Comparison Contract

- Structural conformance is binding through reference-anchor bounds assertions.
- Golden regression is binding at similarity >= 0.95 with zero high-severity violations.
- Mockup conformance is informational because generated/reference copy cannot pixel-match runtime.
- Each non-anchor-only contract screenshot must have a promoted golden baseline.
- `reference-map.json` may map a capture to a reference, a masked reference, or `null` for an
  explicit anchor-only state.
- Missing or ambiguous references fail as `NO_REFERENCE`; they are never silently skipped.
- Preserve actual captures, comparison reports, and diff overlays under `visual_evidence/`.
