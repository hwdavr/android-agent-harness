# Pen content comparison retrospective

## Incident and classification

`HARNESS_ENVIRONMENT`. The visual workflow required a full-screen Roborazzi comparison against a Pen export even when the export and app capture showed different content. The canonical design for this app is the sibling `../UI_design/fun_photo_editor.pen`; its `Screen / Dark Edit Photo` node `dyLRM` includes the specific image `images/generated-1783783523808.png`. A capture with a different user photo cannot establish full-screen pixel parity against that frame. The old contract test only checked that the Roborazzi command was named, not that it ran successfully.

## Invariant

A visual target must declare whether Pen and runtime content match. Exact-content targets need successful `verifyRoborazziDebug` execution evidence; different-content targets need structural evidence and must explicitly state that full-screen pixel parity was not evaluated.

## Repair

- `.agents/rules/testing-runtime-evidence.md`: “A full-screen pixel comparison is binding only when the Pen export and runtime render the same content state.”
- `.agents/skills/ui-verification/SKILL.md`: requires a content comparison before choosing the pixel or structural mode.
- `harness/templates/visual-target-template.json`: points to the sibling canonical Pen file and defaults to `structural` with `pixel_parity: not-claimed`.
- `harness/scripts/check-visual-evidence-contract.sh`: requires an explicit comparison mode and Pen source, accepts only the sibling `../UI_design/*.pen` path outside the project, rejects pixel claims for different content, and requires successful Roborazzi evidence for exact content.
- `harness/scripts/tests/visual-evidence-contract-test.sh`: covers both valid modes and rejects missing mode, mismatched-content pixel claims, undisclosed mismatch, unexecuted pixel verification, and structural mode with a Roborazzi claim.
- Workflow and report templates now describe the same conditional verification rule.

## Verification

- `bash -n harness/scripts/check-visual-evidence-contract.sh harness/scripts/tests/visual-evidence-contract-test.sh harness/scripts/tests/visual-comparison-contract-test.sh` — exit 0.
- `bash harness/scripts/tests/visual-evidence-contract-test.sh` — exit 0, including expected negative fixtures.
- `bash harness/scripts/tests/visual-comparison-contract-test.sh` — exit 0 from the host app repository, where `docs/product/product.md` exists.
- `git diff --check` — exit 0.

No app source changed, so Android build, coverage, lint, and connected tests were not triggered by this harness repair. The CLI inspected Pen node `dyLRM`; font downloads failed in the restricted environment, so no rendered Pen screenshot is claimed as visual evidence.

## Remaining risk

Structural mode verifies geometry and declared static visual assertions, but it cannot prove full-screen pixel parity with different content. Exact-content use still requires the app to provide a matching deterministic fixture and an executable Roborazzi setup; those are outside this harness repair.
