# Visual Reference Anchor Verification

**Reference design**: `design/<approved_mockup_or_screenshot>.png`

Record one row for every `TC-US-*-VIS-*` visual test. The reference asset and actual screenshot
must be non-empty. A visual inside a larger touch target must use the visual shape's own bounds
tag, not only the target's tag.

**Screenshot capture requirement**: The `Runtime proof` column must reference a dedicated
`*VisualFlowTest.kt` test method that captures the screenshot from within the running test via
`InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()` or `captureToImage()`
during `composeRule.waitForIdle()`. Post-test CLI screencaps (`&& adb exec-out screencap`) are
prohibited because the test Activity/window is already destroyed when the test runner finishes.

## Reference Anchor Verification

| Visual Test ID | Reference anchor | Runtime proof | Measured relationship | Actual screenshot | Result |
|----------------|------------------|---------------|-----------------------|-------------------|--------|
| TC-US-1-VIS-01 | <exact relationship from the approved reference> | `<Feature>VisualFlowTest#capture<State>`; testTag: `<visual_bounds_tag>` | `<visualBounds>.<edge> == <anchorBounds>.<edge> ± <tolerance>dp` | `visual_evidence/<screen>_<state>.png` | PASS / FAIL |

