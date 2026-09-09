# Clean State Checklist

Copy the Core checks and only the conditional sections triggered by the approved Rule
Applicability matrix, execution flags, or submitted diff. For each omitted conditional section,
record `N/A — <feature-specific reason>`. A diff-triggered rule overrides an unsupported N/A and
must be reviewed as a planning defect.

Reference fresh evidence from earlier stages when its source, build configuration, command, and
runtime fingerprints are unchanged. Do not rerun a valid gate merely to copy its output.

## Core Checks

- [ ] Build/compile evidence is successful for every affected module.
- [ ] `./gradlew ktlintCheck`, `./gradlew detekt`, and applicable Android Lint commands exit 0.
- [ ] `bash harness/scripts/check-full-source-rules.sh` exits 0 against the complete source tree.
- [ ] Required tests run with non-zero test counts and applicable coverage thresholds pass.
- [ ] No new suppression, baseline, exclusion, placeholder, dummy, no-op, or secret is introduced.
- [ ] Changed files stay within approved scope and architectural boundaries.
- [ ] Required artifacts, lifecycle state, progress, and handoff evidence are current.
- [ ] No stale or orphan artifact created by this change remains.

## Conditional: API

Include when API is Required/excepted or the diff changes endpoints, DTOs, schemas, or error
contracts.

- [ ] DTOs and mappings match `sharedContracts/openapi.yaml`.
- [ ] Shared JSON integration scenarios and defensive error/unknown-value cases pass.

## Conditional: ROOM

Include when persistence, Room entities/DAOs, migrations, caches, or restart behavior changes.

- [ ] Migration/schema evidence and restart persistence tests pass without data corruption.
- [ ] Dispatcher, transaction, cache invalidation, and cleanup behavior match the approved plan.

## Conditional: NAV

Include when NAV is Required/excepted or the diff changes routes, destinations, saved state,
back-stack, deep links, or post-return behavior.

- [ ] The declared production-entry journey passes through real UI gestures and visible outcome.
- [ ] `bash harness/scripts/check-journey-registry.sh --run-all` exits 0.

## Conditional: UI

Include when SUI/L10N is Required/excepted, `affects_ui` is true, or a Composable/resource changes.

- [ ] Design-system, state, accessibility, semantics/test-tag, localization, and interaction checks pass.
- [ ] When visual verification is required, visual artifact, reference-anchor, golden comparison,
  and applicable rendered-output validators exit 0 with in-test screenshots.

## Conditional: PLATFORM

Include when `platform_validation.required` is true or the behavior depends on an Android SDK,
device, hardware feature, model, locale, permission, or external service.

- [ ] The capability matrix is complete and its unsupported-environment policy is `fail_loudly`.
- [ ] Every owned real boundary test runs against the declared runtime and exits 0; fake/JVM tests
  remain supplemental.

## Conditional: OBS

Include when OBS is Required/excepted or the diff adds/changes application logging or diagnostics.

- [ ] Logs follow `.agents/rules/observability.md` tag and level policy.
- [ ] No PII, secret, user-generated sensitive content, raw payload, prompt, or token is logged.
- [ ] Do not add logging only to make this section applicable.

## Conditional: RESET

Include only when the approved behavior adds or changes reset, deletion, cache clearing, database
clearing, or preference clearing.

- [ ] The reset is explicitly authorized, scoped, idempotent, and verified without unrelated data loss.
- [ ] Required failure diagnostics follow `.agents/rules/observability.md`.

## Conditional: ADR

Include when the change makes an architectural decision, changes a public contract, or creates a
reusable non-obvious pitfall.

- [ ] The ADR, change record, or pitfall documents the decision, evidence, compatibility, and risks.

## Conditional Results

| Trigger | Result | Evidence or feature-specific N/A reason |
|---|---|---|
| API | PASS / FAIL / `N/A — <feature-specific reason>` | |
| ROOM | PASS / FAIL / `N/A — <feature-specific reason>` | |
| NAV | PASS / FAIL / `N/A — <feature-specific reason>` | |
| UI | PASS / FAIL / `N/A — <feature-specific reason>` | |
| PLATFORM | PASS / FAIL / `N/A — <feature-specific reason>` | |
| OBS | PASS / FAIL / `N/A — <feature-specific reason>` | |
| RESET | PASS / FAIL / `N/A — <feature-specific reason>` | |
| ADR | PASS / FAIL / `N/A — <feature-specific reason>` | |
