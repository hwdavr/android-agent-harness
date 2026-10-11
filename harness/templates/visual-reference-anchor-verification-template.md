# Visual Reference Anchor Verification

**Reference design**: `design/<approved_mockup_or_screenshot>.png`

Record one row for every `TC-US-*-VIS-*` visual test. The reference asset and actual screenshot
must be non-empty. A visual inside a larger touch target must use the visual shape's own bounds
tag, not only the target's tag. Handle anchors must not use an interactive identifier ending in
`_handle` or `-handle`; use a distinct visual-shape identifier such as `*_handle_visual`.

**Screenshot capture requirement**: The `Runtime proof` column must reference a dedicated
`*VisualFlowTest.kt` test method that captures the screenshot from within the running test via
`InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()` or `captureToImage()`
during `composeRule.waitForIdle()`. Post-test CLI screencaps (`&& adb exec-out screencap`) are
prohibited because the test Activity/window is already destroyed when the test runner finishes.

**Capture scope requirement**: When the paired visual acceptance row claims app-shell chrome
(for example global tabs, system bars, or a full-page shell), its `Setup and action` cell must
declare `Capture scope: app-shell; production root: <ComposableOrActivity>.` The named
`VisualFlowTest` must invoke that root. Use `Capture scope: component` only when shell chrome is
explicitly outside the proof. Record the same scope and root in the `Runtime proof` cell.

## Reference Anchor Verification

| Visual Test ID | Reference anchor | Runtime proof | Measured relationship | Actual screenshot | Result |
|----------------|------------------|---------------|-----------------------|-------------------|--------|
| TC-US-1-VIS-01 | <exact relationship from the approved reference> | `<Feature>VisualFlowTest#capture<State>`; captureScope: component; testTag: `<visual_bounds_tag>` | `<visualBounds>.<edge> == <anchorBounds>.<edge> ± <tolerance>dp` | `visual_evidence/<screen>_<state>.png` | PASS / FAIL |
