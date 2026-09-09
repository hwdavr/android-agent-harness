---
name: android-code-review
description: Performs a structured code review across correctness, security, performance, and architecture.
---

# Skill — Android Code Review

## Purpose

Independently review implementation correctness, architecture, security, maintainability, and
static quality after Test Review. The canonical report structure and per-rule checklist live in
`harness/templates/code-review-template.md`; do not reproduce them in this skill.

## Load

- L1 rules already loaded for the session; do not reload them.
- `skills/code-review-and-quality/SKILL.md` and `skills/android-code-quality-checks/SKILL.md`.
- `harness/templates/code-review-template.md` and `gates/review-checklist.md`.
- The approved Rule Applicability matrix and exact conditional rule paths selected from it.
- `rules/testing-practices.md`; add `rules/testing-runtime-evidence.md` when a runtime claim is in
  scope.
- `rules/android-security.md` only when the approved scope or diff touches a security boundary.
- The active diff, merge base/reviewed commit, changed production files, and mapped tests.
- Ad-hoc baseline: `docs/current/spec_v<N>.md`, `implementation_plan_v<N>.md`,
  `test_plan_v<N>.md`, and `test_review_v<N>.md`.
- Complex baseline: `$FEATURE_DIR/spec.md`, optional design, `sprint-contract.md`, selected slice
  metadata/summary, and `test_review_{feature_id}.md`.

## Execute

### 1. Establish scope and evidence provenance

Record the current commit, merge base or reviewed baseline, and changed files. Distinguish fresh
commands from recorded stage evidence, stale results, planned tasks, and skipped checks. A
pre-existing failure remains a failed global gate; classification does not turn it green.

### 2. Rule Applicability Reconciliation

Reconcile ARCH, IMPL, TEST, SUI, L10N, NAV, API, OBS, ANL, and SEC against the submitted diff. Load and
apply each Required or excepted rule. If the diff triggers a rule marked Not applicable, load it
and record a blocking planning defect. An exception without cited user approval is blocking.

For `SEC: Required` or an exception, require the approved trust-boundary and real-runtime evidence;
unavailable required evidence remains failed or blocked.

### 3. Run mechanical gates

```bash
./gradlew assembleDebug
./gradlew ktlintCheck
./gradlew detekt
./gradlew lintDebug
bash harness/scripts/check-full-source-rules.sh
./gradlew :app:koverXmlReportDebug
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
```

The full-source bundle is mandatory and scans all production and test sources. Record command,
exit code, commit, evidence path, and actionable failure details. Reuse a previous successful
result only when `bash harness/scripts/check-evidence-receipt.sh ...` accepts all fingerprints.

### 4. Trace requirements to production

Complete the template's Requirement-to-Production and State Completion tables for every FR, AC,
and edge case. Trace each input through state, coroutine/callback, cleanup, and final observable
result. Verify completion methods have reachable production call sites; test-only invocation does
not prove production wiring.

Treat placeholders, no-op handlers, unreachable branches, stale flags, ignored callback results,
missing cleanup, and unimplemented completion paths as `REVISION REQUIRED`.

### 5. Review applicable rules

Use the canonical template rows and enforcement matrices rather than a second checklist here:

- Architecture: dependencies flow inward, domain remains platform-independent, DTOs remain in
  data, state ownership matches the approved plan, and Hilt scopes are correct.
- Implementation: every reachable production branch implements the requirement; no placeholder,
  dummy, suppression, or no-op path is accepted without explicit documented approval.
- Compose/localization: apply only when UI or user-visible copy is triggered; reconcile scripted,
  evaluator, and human-owned rows in the report.
- Navigation/API/observability/analytics: apply only when Required, excepted, or triggered by the
  diff; otherwise record the approved N/A rationale.
- Security/release: audit secrets, sensitive/user-generated logging, untrusted inputs, exported or
  IPC boundaries, compatibility, and required runtime proof when triggered.

Every loaded rule receives a report result. Any unchecked human-owned row remains visible for
human review rather than being inferred as passing.

### 6. Verify UI/runtime claims conditionally

Run UI verification when the slice says `affects_ui`, or when the diff changes a Composable despite
that flag. Record a planning defect for the mismatch and continue verification. When visual
verification is required, run every declared visual command and validator; require target-state
proof, non-empty in-test capture, reference-anchor evidence, applicable golden comparison, and
rendered-node pixels for rich-text appearance claims.

For UI changes without a visual owner, run the mapped automated acceptance tests and name the
slice that owns final visual verification. Do not capture an unrelated screen.

## Output

Fill `harness/templates/code-review-template.md` completely:

- Ad-hoc: `docs/current/code_review_v<N>.md`.
- Complex: `$FEATURE_DIR/code_review_{feature_id}.md`.

## Done When

- All mandatory mechanical gates exit 0 or the verdict is non-passing.
- Rule Applicability Reconciliation and every applicable template section are complete.
- Every FR, AC, edge case, state transition, callback, cleanup, and asynchronous completion path
  has reachable production evidence.
- Required UI, visual, platform, and security evidence is source-fed and passes its validator.
- No non-zero, skipped, unavailable, fake-only, or stale result is labelled passing.
- The report contains an evidence-based verdict and all human-owned rows remain explicit.

Return to the active workflow only when required rows and gates pass. Route implementation defects
to Implementation and evidence gaps to Testing.
