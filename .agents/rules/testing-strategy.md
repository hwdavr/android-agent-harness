---
trigger: always_on
---

# Testing Strategy Rules

## Purpose

Define the always-applicable test-layer, coverage, and evidence contract. Load detailed
authoring practices only during testing or review, and load runtime evidence rules only when UI,
navigation, visual, platform, locale, permission, lifecycle, or Android SDK behavior is in scope.

## Test Pyramid

```text
      [Instrumented UI tests]      <- smallest layer
      [Integration tests (JVM)]    <- primary cross-layer verification
      [Unit tests (JVM)]           <- foundation
```

Start at the lowest layer that proves the requirement. A lower layer cannot replace a declared
Android runtime or production-entry boundary.

## Layer Selection

### Unit tests (`app/src/test/`)

Use for business rules, domain use cases, ViewModel state transitions, mappers, formatters,
reducers, and fallback logic that do not require Android runtime behavior.

- ViewModel tests inherit from `BaseViewModelTest`.
- Test class names end with `Test.kt`.
- Keep one main scenario per test.

### Integration tests (`app/src/test/`)

Use for repository/use-case/ViewModel data flow, DTO parsing, error mapping, cache behavior, retry,
and fallback behavior that can run deterministically on the JVM.

- ViewModel integration tests inherit from `BaseViewModelIntegrationTest`.
- Test class names end with `IntegrationTest.kt`.
- API tests use shared JSON scenarios; do not inline mock response bodies.
- Assert `expected.ui` when the ViewModel owns the endpoint and `expected.domain` when only the
  repository or use case owns it.

### Instrumented tests (`app/src/androidTest/`)

Use only when Compose rendering, gestures, navigation, lifecycle, Android SDK behavior, device
capability, permission, locale, or another real runtime boundary is part of the claim. Load
`.agents/rules/testing-runtime-evidence.md` before planning, implementing, or reviewing such
evidence.

Do not use instrumented tests for behavior that a deterministic JVM test proves completely.

## Coverage Requirements

| Scope | Minimum line coverage |
|---|---|
| Overall project | 80% |
| New ViewModel classes | 90% |
| New domain use case classes | 90% |
| Compose screens/components | Excluded; verify with instrumented semantic/visual evidence when triggered |

Machine-readable verification:

```bash
./gradlew :app:koverXmlReportDebug
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
```

## Feature and Bug Policy

- Feature and enhancement workflows implement approved behavior before the Testing stage. The
  Testing stage then creates or completes the planned tests and verifies them GREEN.
- Bug fixing is the only TDD workflow: `bug-reproduction` must produce a relevant RED test before
  the approved fix is implemented, and the later Testing stage must prove it GREEN.
- Every new feature includes ViewModel/state tests, use-case tests when business logic changes,
  mapper tests when mapping is non-trivial, and at least one shared-scenario integration test per
  affected API endpoint.
- Every bug fix includes at least one regression test that proves the reported behavior.

## Evidence Invariants

- A test result is passing only when the declared command ran, exited 0, executed a non-zero test
  count when applicable, and produced the required source-fed evidence.
- Missing runtimes, devices, models, locales, permissions, services, skipped tests, empty output,
  fake-only platform evidence, and unexecuted commands cannot be recorded as passing.
- Reuse a prior successful command only when its source, build configuration, declared command,
  and runtime fingerprints are unchanged and `check-evidence-receipt.sh` accepts its receipt.
- Keep verbose output in a referenced log/report; summaries record the command, exit status, test
  count or coverage, evidence path, and fingerprint receipt.
- Load `.agents/rules/testing-practices.md` during test authoring and test review.

## Shared JSON Scenarios

Every affected API endpoint has at least one integration test backed by
`sharedContracts/test-scenarios/`. A scenario may contain `apiMocks`, `expected.domain`, and
`expected.ui`; each test asserts only the layer it owns.
