# Visual Reference Anchor Verification

**Reference design**: `design/<approved_mockup_or_screenshot>.png`

Record one row for every `TC-US-*-VIS-*` visual test. The reference asset and actual screenshot
must be non-empty. A visual inside a larger touch target must use the visual shape's own bounds
tag, not only the target's tag.

## Reference Anchor Verification

| Visual Test ID | Reference anchor | Runtime proof | Measured relationship | Actual screenshot | Result |
|----------------|------------------|---------------|-----------------------|-------------------|--------|
| TC-US-1-VIS-01 | <exact relationship from the approved reference> | `<TestClass>#<method>`; testTag: `<visual_bounds_tag>` | `<visualBounds>.<edge> == <anchorBounds>.<edge> ± <tolerance>dp` | `visual_evidence/<screen>_<state>.png` | PASS / FAIL |
