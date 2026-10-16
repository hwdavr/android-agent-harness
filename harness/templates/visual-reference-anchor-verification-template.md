# Visual Reference Anchor Verification

**Reference design**: `design/<approved_mockup_or_screenshot>.png`

Record one row for every `TC-US-*-VIS-*` visual test. The approved reference asset must be
non-empty. A visual inside a larger touch target must use the visual shape's own bounds
tag, not only the target's tag. Handle anchors must not use an interactive identifier ending in
`_handle` or `-handle`; use a distinct visual-shape identifier such as `*_handle_visual`.

**Roborazzi requirement**: The `JVM proof` column must reference a dedicated
`*RoborazziTest.kt` method that calls `captureRoboImage()` and is covered by a successful
`verifyRoborazziDebug` receipt. Device screenshots are not visual-comparison evidence.

**Capture scope requirement**: When the paired visual acceptance row claims app-shell chrome
(for example global tabs, system bars, or a full-page shell), its `Setup and action` cell must
declare `Capture scope: app-shell; production root: <ComposableOrActivity>.` The named
`RoborazziTest` must invoke that root. Use `Comparison scope: component` only when shell chrome is
explicitly outside the proof. Record the same scope and root in the `JVM proof` cell.

## Reference Anchor Verification

| Visual Test ID | Reference anchor | JVM proof | Measured relationship | Reference PNG | Result |
|----------------|------------------|-----------|-----------------------|---------------|--------|
| TC-US-1-VIS-01 | <exact relationship from the approved reference> | `<Feature>RoborazziTest#capture<State>`; comparisonScope: component; testTag: `<visual_bounds_tag>` | `<visualBounds>.<edge> == <anchorBounds>.<edge> ± <tolerance>dp` | `design/mockup_<screen>_<state>.png` | PASS / FAIL |
