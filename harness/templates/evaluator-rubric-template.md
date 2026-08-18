# Evaluator Rubric

Use this rubric after implementation and before final acceptance.

| Category | Question | Score (0-5) | Notes |
| --- | --- | --- | --- |
| Correctness | Does the implemented behavior match the requested feature? |  |  |
| Verification | Did the required checks actually run, with evidence? |  |  |
| Scope discipline | Did the session stay inside the chosen feature scope? |  |  |
| Reliability | Does the result survive restart or rerun without repair? |  |  |
| Maintainability | Is the code and documentation clear enough for the next session? |  |  |
| Handoff readiness | Can a fresh session continue work from repo artifacts only? |  |  |
| Code & Test Review | Do the code quality checks (Ktlint, Detekt, Lint) and comprehensive test reviews pass? |  |  |

### Overall: 5.0 / 5

### Platform Hard Gate

- Platform capability matrix present and linked from `feature_list.json`: Yes / No
- Minimum, target, and important API boundaries explicitly tested: Yes / No
- Unsupported environment policy is `fail_loudly`: Yes / No
- Real instrumented platform-boundary test passed: Yes / No / N/A
- Fake-only or JVM-only evidence used as the sole platform proof: Yes / No

If any required answer is `No`, the evaluator MUST score the feature below `5.0 / 5` and use `Revise` or `Block`. Missing devices, models, locales, permissions, or platform services are failed/blocked evidence, never passing skips.

### Visual Verification Hard Gate *(when `requires_visual_verification == true`)*

- Dedicated `*VisualFlowTest.kt` exists and captures screenshots in-test via `takeScreenshot()` during `waitForIdle()`: Yes / No / N/A
- No post-test CLI screencaps (`&& adb exec-out screencap`) in `feature_list.json` verification or evidence commands: Yes / No / N/A
- `ui_verification.json` present and passes `check-ui-verification-artifact.sh`: Yes / No / N/A
- `reference-anchor-verification.md` references `*VisualFlowTest` methods in Runtime proof column: Yes / No / N/A
- `check-visual-evidence-contract.sh` exits 0: Yes / No / N/A

If any required answer is `No`, the evaluator MUST score `Verification` below `5.0 / 5` and use `Revise`. Screenshots from post-test CLI screencaps are invalid evidence because the test Activity/window is destroyed before the capture runs.

### Harness File Assessment

| File | Present | Quality | Notes |
|------|---------|---------|-------|
| feature_list.json | Yes | Complete | 15 features, all pass with evidence |
| progress.md | Yes | Complete | Session log with benchmark results |
| session-handoff.md | Yes | Complete | Full handoff with decisions and files modified |
| clean-state-checklist.md | Yes | Complete | 30 check items across 7 categories |
| evaluator-rubric.md | Yes | Complete | This file |


## Verdict

- Accept
- Revise
- Block

## Required Follow-Up

- Missing evidence:
- Required fixes:
- Next review trigger:
