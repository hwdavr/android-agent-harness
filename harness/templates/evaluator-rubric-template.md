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
| Code & Test Review | Do Ktlint, Detekt, Lint, the full-source rules bundle, and comprehensive test reviews pass? |  |  |
| Rule Applicability | Does every approved rule decision have diff-trigger reconciliation and evidence in both review reports? |  |  |

### Overall: <arithmetic mean of the eight category scores, rounded to one decimal> / 5

The eight category scores are the machine-checkable source of the overall score. Use
their arithmetic mean, rounded to one decimal place; do not choose an independent
overall score. A perfect 5.0 / 5 requires an Accept verdict and routes the tracker
to To be human reviewed. Any lower score requires Revise or Block and routes the
tracker to To be fixed.

### Platform Hard Gate

- Platform capability matrix present and linked from `feature_list.json`: Yes / No
- Minimum, target, and important API boundaries explicitly tested: Yes / No
- Unsupported environment policy is `fail_loudly`: Yes / No
- Real instrumented platform-boundary test passed: Yes / No / N/A
- Fake-only or JVM-only evidence used as the sole platform proof: Yes / No

If any required answer is `No`, the evaluator MUST score the feature below `5.0 / 5` and use `Revise` or `Block`. Missing devices, models, locales, permissions, or platform services are failed/blocked evidence, never passing skips.

### Rule Applicability Hard Gate

- Complete approved matrix exists in the feature specification: Yes / No
- Code review includes all ten reconciliation rows: Yes / No
- Test review includes all ten reconciliation rows: Yes / No
- Every `Not applicable` / exception decision is supported by the diff and cited approval: Yes / No

If any required answer is `No`, the evaluator MUST use `Revise`.

### UI Conformance Review Hard Gate *(when the slice owns the conformance review: `requires_visual_verification == true`)*

- Every `UI_contract.md` state has a review capture rendered at its Viewport (Pen frame size and density): Yes / No / N/A
- Every state's structural check (`testTag`s present, ordered, bounds within tolerance) passes: Yes / No / N/A
- The user approved every state side by side with its approved design in `ui_verification.json`: Yes / No / N/A
- `ui_verification.json` passes `check-ui-verification-artifact.sh`; no screenshot golden was recorded or compared: Yes / No / N/A
- Each state's reused registered components are called from the changed UI files, and the compose "Registered design-system components" rule passes: Yes / No / N/A
- `check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate` exits 0: Yes / No / N/A
- Rich-text/inline-formatting appearance claims assert the rendered AnnotatedString span styles: Yes / No / N/A

If any required answer is `No`, the evaluator MUST score `Verification` below `5.0 / 5` and use `Revise`.

### Harness File Assessment

| File | Present | Quality | Notes |
|------|---------|---------|-------|
| feature_list.json | Yes | Complete | 15 features, all pass with evidence |
| summary.md / summary_<slice>.md | Yes | Complete | Stage evidence and execution metrics |
| session-handoff.md | Yes | Complete | Full handoff with decisions and files modified |
| clean-state-checklist.md | Yes | Complete | 30 check items across 7 categories |
| evaluator-rubric.md | Yes | Complete | This file |

### Evidence Contract

The evaluator's static-quality evidence must include
`bash harness/scripts/check-full-source-rules.sh` (or the Windows `.cmd` launcher),
not only a changed-file checker invocation.

Before changing the tracker status, run:

```bash
bash harness/scripts/check-evaluation-fix-contract.sh "$FEATURE_DIR" --evaluation
```

This hard gate verifies arithmetic score routing, successful non-contradictory
evidence, acceptance-test traceability, and the required review artifacts.


## Verdict

- Accept
- Revise
- Block

## Required Follow-Up

- Missing evidence:
- Required fixes:
- Next review trigger:
