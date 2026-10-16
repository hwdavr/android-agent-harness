# Harness Retrospective — Roborazzi Visual Gate

## Incident

The post-revert harness still described instrumented `VisualFlowTest` screenshots as visual
comparison evidence. That allowed a connected-device capture to stand in for comparison against an
approved Pen frame, even though the repository's visual target contract already defines Roborazzi
as the pixel-comparison engine.

## Classification

`WORKFLOW_GAP` — the authoritative visual rules and validators did not consistently separate
runtime behavior evidence from visual comparison evidence.

## Invariant

Approved visual comparison must be produced by a deterministic JVM `*RoborazziTest` and a passing
`verifyRoborazziDebug` command; instrumented tests may prove interaction, navigation, and platform
behavior but cannot close a visual-comparison gate.

## Harness change

- Updated `.agents/skills/ui-verification/SKILL.md` to make Roborazzi the visual acceptance path.
- Updated `.agents/rules/testing-runtime-evidence.md`, the instrumented-test skill, workflows, gates,
  templates, and review guidance to keep device tests scoped to runtime behavior.
- Updated `harness/scripts/check-visual-evidence-contract.sh` and its contract fixtures to require
  `app/src/test/*RoborazziTest.kt`, `captureRoboImage()`, and successful `verifyRoborazziDebug` evidence.
- Updated rendered-output checking to require `captureRoboImage()` for rich-text appearance claims.
- Updated the planning/testing guidance so visual rows name Roborazzi methods rather than device
  screenshot methods.

## Verification

- `git diff --check` is the remaining local syntax/whitespace check for this harness-only change.
- Android application source was not changed by this repair; Android build, coverage, and connected
  UI gates are outside this harness-only scope.

## Remaining risk

Existing historical feature records may still contain old instrumented visual rows. They are audit
history and must be migrated only when that feature's visual evidence is regenerated.
