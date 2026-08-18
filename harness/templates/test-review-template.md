# Test Review — <Feature ID or vN>

## Review Scope and Evidence Provenance

| Item | Value |
|---|---|
| Feature / slice | |
| Current commit | |
| Baselines reviewed | `spec.md`, `sprint-contract.md`, `implementation_plan`, `test_plan` |
| Changed production files reviewed | |
| Changed test files reviewed | |

### Command Evidence

| Command | Exit code | Timestamp | Commit | Provenance | Result / failure detail |
|---|---:|---|---|---|---|
| `./gradlew testDebugUnitTest` | | | | Independently executed / Recorded / Up-to-date / Not run | |
| `./gradlew koverLog` | | | | Independently executed / Recorded / Up-to-date / Not run | |
| `./gradlew connectedDebugAndroidTest` | | | | Independently executed / Recorded / Up-to-date / Not run | |

Do not label recorded, up-to-date, skipped, or unexecuted evidence as a fresh pass.

## Requirement-to-Test Traceability

List every FR, AC, and documented edge case from the active specification and sprint contract.

| Source ID | Required behavior | Test file + method | Production trigger exercised | Observable assertion | Evidence status | Result |
|---|---|---|---|---|---|---|
| FR-001 | | | | | | PASS / REVISION REQUIRED / N/A |

## Test Quality Findings

- [ ] Names describe the real Given / When / Then behavior.
- [ ] Each mapped test exercises a production trigger, not only a setter, reducer, helper, or preloaded final state.
- [ ] Each mapped test has a direct observable assertion for the requirement.
- [ ] No unused capture variables, tautological assertions, empty verifies, or assertion-free interaction tests.
- [ ] Unit/integration/UI test isolation is appropriate for its layer.
- [ ] API tests use shared JSON scenarios where applicable.
- [ ] Import hygiene passes.

### Conditional Categories

| Category | In scope? | Coverage / N/A reason | Result |
|---|---|---|---|
| Runtime permissions | | | PASS / REVISION REQUIRED / N/A |
| Asynchronous callbacks and animation | | | PASS / REVISION REQUIRED / N/A |
| Lifecycle and navigation cleanup | | | PASS / REVISION REQUIRED / N/A |
| Error and retry behavior | | | PASS / REVISION REQUIRED / N/A |
| API/data error matrix | | | PASS / REVISION REQUIRED / N/A |

## Coverage Distribution

| Scope / class | Coverage | Branches or requirements not proven | Result |
|---|---:|---|---|
| Overall project | | | PASS / REVISION REQUIRED |
| New ViewModel / use case | | | PASS / REVISION REQUIRED / N/A |

## Regression Verification

| Item | Evidence | Result |
|---|---|---|
| Reproduction test red before fix (bug fixes only) | | PASS / REVISION REQUIRED / N/A |
| Reproduction test green after fix | | PASS / REVISION REQUIRED / N/A |
| No uncontrolled timing or threading | | PASS / REVISION REQUIRED / N/A |

## Verdict

**APPROVED / REVISION REQUIRED** — List every unverified required traceability row and the next owner/stage. An approved verdict requires all in-scope rows to pass.
