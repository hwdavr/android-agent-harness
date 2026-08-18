---
name: android-test-review
description: Verifies test suite completion, requirement traceability, boundary testing, and coverage targets.
---

# Skill — Android Test Review

## Purpose

An adversarial evaluator pass covering requirement-to-test traceability, test quality, shared-scenario use, coverage, and regression verification. It runs immediately before Code Review and must not approve a feature merely because a test has a plausible name or the aggregate coverage percentage is high.

## Load

Identify the active workflow first. The test-review report is an **output**, never an input.

- **Ad-hoc review**: `docs/current/spec_v<N>.md`, `implementation_plan_v<N>.md`, `test_plan_v<N>.md`, `summary_v<N>.md`, and any testing-stage evidence such as `test_report_v<N>.md`.
- **Harness evaluation**: `$FEATURE_DIR/spec.md`, `$FEATURE_DIR/sprint-contract.md`, `$FEATURE_DIR/feature_list.json`, the active slice summary, and testing-stage evidence recorded in `$FEATURE_DIR/progress.md` or the slice summary.
- All test files mapped by the active plan or sprint contract, plus the production files that implement the mapped behavior.
- `rules/testing-strategy.md` and `harness/templates/test-review-template.md`.

If a required baseline or test-evidence artifact is missing, record it as a blocking finding. Do not substitute a prior `test_review_*.md` for the missing source evidence.

## Execute

### B1. Establish review scope and evidence provenance

1. Record the current commit, changed files, selected feature/slice, and the source paths used for review.
2. For every recorded test or coverage result, capture the command, exit code, timestamp, commit (when available), and whether it was:
   - **Independently executed** during this review;
   - **Recorded testing-stage evidence**; or
   - **Up-to-date / not executed**.
3. Do not call recorded or up-to-date evidence a fresh passing execution. Runtime commands belong to Stage 4 of the active review workflow; cite their result once that stage has run.

### B2. Build complete requirement-to-test traceability

List every functional requirement, acceptance criterion, and documented edge case from the active `spec.md` and `sprint-contract.md`. Add one row per requirement to the review report with:

| Source ID | Required behavior | Test file + method | Production trigger exercised | Observable assertion | Evidence status | Result |
|---|---|---|---|---|---|---|

Use the exact requirement ID where available. A mapped test is **not sufficient** unless it both exercises the production trigger and asserts the required observable outcome.

Mark a row **REVISION REQUIRED** when any of the following is true:

- The requirement has no mapped test.
- The named test method or test file does not exist.
- The test sets `UiState`, calls a reducer/setter, injects a final callback, or pre-populates success state instead of exercising the production event it claims to cover.
- The test clicks a control but does not assert the callback result, state transition, navigation result, system permission result, or user-visible outcome required by the source requirement.
- The test asserts a callback was invoked but does not assert the resulting UI or lifecycle effect where the requirement is user-visible.
- The test is the only caller of a completion callback or state transition that has no production call site.

### B3. Review test quality and boundaries

For every mapped test file, check:

- **Naming**: names describe the real Given / When / Then behavior.
- **Production realism**: the event source, callback, permission result, lifecycle event, or navigation action is represented at the lowest reliable test layer.
- **Assertiveness**: assertions verify the required externally observable result; flag unused capture variables, setter-only tests, empty verification blocks, `assertTrue(true)`, and `assertNotNull` without a behavior assertion.
- **Isolation**: unit tests isolate external boundaries; integration tests use real in-memory components where appropriate; UI tests use deterministic fakes or DI overrides.
- **Shared scenarios**: API tests use shared JSON scenarios. Flag inline API payloads, including triple-quoted JSON, unless the test is not API-related and the reason is recorded.
- **Import hygiene**: no fully-qualified names inline, wildcard imports, or unsorted imports.

### B4. Check conditional behavior categories

When the source requirements include the category below, verify both the success path and the stated failure/boundary path. Mark the category N/A only when the active specification has no such behavior, and state why.

| Category | Required review check |
|---|---|
| Runtime permissions | Manifest declaration where needed, request launch, grant path, denial/permanent-denial UI, and Settings action if specified. |
| Asynchronous callbacks / animation | Production completion callback is reachable; tests do not invoke it directly as a substitute for production wiring. |
| Lifecycle / navigation | Dismiss, mode switch, back navigation, recreation, and cleanup requirements use the real lifecycle or navigation trigger. |
| Error / retry | Error state, retry trigger, bounded retry behavior, and user-visible recovery result are asserted. |
| API / data | Every endpoint has success, 4xx, 5xx, malformed payload, and unknown-enum coverage as applicable. |

### B5. Coverage and regression review

From evidence with clear provenance, assess whether coverage is concentrated on trivial code rather than behavior branches. Flag new domain use cases and ViewModels below 90% and overall coverage below 80%.

For bug fixes, confirm that the reproduction test was red before the fix, is green afterward, and contains no uncontrolled timing or threading.

## Output

Produce a report from `harness/templates/test-review-template.md`:

- **Ad-hoc workflows**: `docs/current/test_review_v<N>.md`
- **Harness evaluation**: `$FEATURE_DIR/test_review_{feature_id}.md`

The report must include evidence provenance, the complete traceability matrix, test-quality findings, coverage distribution, and an overall verdict. Update the active summary only after both test and code review verdicts are known.

## Done When

All of the following are mechanically verifiable:

- [ ] Every FR, AC, and documented edge case in the active baseline has a traceability row.
- [ ] Every row identifies a real production trigger and an observable assertion, or is explicitly marked `REVISION REQUIRED`.
- [ ] Test, coverage, and runtime-check evidence records command, exit code, provenance, and scope.
- [ ] No mapped test is approved when it is setter-only, assertion-free, test-only callback wiring, or otherwise detached from the specified behavior.
- [ ] API endpoints, permission paths, callbacks, lifecycle, navigation, and errors are reviewed when in scope; N/A rows include a reason.
- [ ] Regression reproduction is confirmed for bug fixes.
- [ ] The active workflow's test-review report exists with an evidence-based verdict.

**APPROVED →** Return to the active workflow and proceed to Code Review.

**REVISION REQUIRED →** Return to Testing or Implementation according to the missing behavior's root cause. Do not approve a feature with an unverified required traceability row.
