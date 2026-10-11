# Harness Retrospective — Roborazzi Visual Gate

**Date:** 2026-10-11  
**Classification:** `TEST_EVIDENCE_GAP`

## Incident

Visual acceptance evidence was defined as an active instrumented `*VisualFlowTest` screenshot.
The affected rule was [`.agents/rules/testing-runtime-evidence.md`](../../../.agents/rules/testing-runtime-evidence.md), and the affected gate was [`harness/scripts/check-visual-evidence-contract.sh`](../../../harness/scripts/check-visual-evidence-contract.sh).

That approach treated a device capture as the visual comparison result even though the project uses
Roborazzi for deterministic JVM image verification.

## Root Cause

The rule, workflow guidance, templates, and contract validator were inconsistent with the current
Roborazzi test runner. The validator accepted an `app/src/androidTest/...VisualFlowTest.kt` method
with `connectedDebugAndroidTest` evidence and a runtime screenshot.

## Invariant

Every visual acceptance target is a deterministic JVM `*RoborazziTest` that calls
`captureRoboImage()` and passes `verifyRoborazziDebug` against its approved Pen export; device
tests prove behavior and platform boundaries only.

## Harness Repair

- Updated the runtime-evidence rule, visual verification skill, UI workflows, review gate, and
  templates to require `comparison.engine: roborazzi`, exact content, and `screen` or `component`
  comparison scope.
- Updated `check-visual-evidence-contract.sh`, `check-acceptance-test-traceability.sh`,
  `check-ui-verification-artifact.sh`, `check-ui-contract.py`, and the rendered-output checker.
- The rendered-output checker now reports: “rendered appearance claims must call
  `captureRoboImage()` in a Roborazzi JVM test”.
- Added regression fixtures that reject the obsolete instrumented `captureToImage()` route and
  accept a `*RoborazziTest` with `captureRoboImage()`.
- Repaired the pre-existing instruction-budget test: it resolves the product design system from
  the parent repository when the harness is embedded, and the L1 context was reduced below its
  documented 23,000-byte limit.

## Verification

All commands exited `0`:

```bash
bash -n android-agent-harness/harness/scripts/check-visual-evidence-contract.sh
PYTHONPYCACHEPREFIX=/private/tmp/python-pyc python3 -m py_compile android-agent-harness/harness/scripts/kotlin_ast_checker.py android-agent-harness/harness/scripts/check-ui-contract.py
bash android-agent-harness/harness/scripts/tests/visual-evidence-contract-test.sh
bash android-agent-harness/harness/scripts/tests/acceptance-test-traceability-contract-test.sh
bash android-agent-harness/harness/scripts/tests/rendered-output-contract-test.sh
bash android-agent-harness/harness/scripts/tests/bug-reproduction-stage-contract-test.sh
bash android-agent-harness/harness/scripts/tests/visual-comparison-contract-test.sh
bash android-agent-harness/harness/scripts/tests/ui-verification-artifact-contract-test.sh
bash android-agent-harness/harness/scripts/tests/ui-contract-contract-test.sh
git -C android-agent-harness diff --check
```

The visual-evidence regression test reports: “visual evidence requires JVM Roborazzi tests and
rejects the obsolete instrumented capture path.”

## Scope And Risk

No application source was changed by this retrospective. A visual feature without a configured
Roborazzi task now fails its visual evidence gate clearly, which is the intended outcome.
