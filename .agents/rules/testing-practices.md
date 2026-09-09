# Testing Authoring and Review Practices

## Structure

- Use Arrange, Act, Assert with visible separation between the three phases.
- Keep one main business scenario and one assertion concept per test.
- Prefer descriptive, self-contained tests over deeply shared setup.
- Test public inputs, state, and outputs rather than private implementation details or interaction
  ordering.
- Recreate mutable test state in setup; tests must be isolated and rerunnable.

## Test Doubles

- Prefer real domain models, mappers, and deterministic in-memory implementations.
- Mock only external or nondeterministic boundaries.
- Fakes, mocks, stubs, and fixture constants are allowed in test source sets.
- API response bodies belong in shared JSON scenarios, not inline test strings.

## Reliability

- Use coroutine test dispatchers and Compose idling APIs instead of timing assumptions.
- A test that passes with `0/0`, is ignored/skipped, or fails for fixture compilation does not prove
  behavior.
- Expected negative fixtures must assert the non-zero exit and the intended diagnostic.

## Assertion Quality

- Assert observable behavior, not only that an envelope such as HTML, SVG, or JSON is non-empty.
- For rendered-output claims, follow `.agents/rules/testing-runtime-evidence.md`.
- Run `bash harness/scripts/check-test-assertions-quality.sh` for repository test sources.

## Naming and Imports

- Test class names use the repository layer suffix (`Test.kt` or `IntegrationTest.kt`).
- Do not use fully qualified names or wildcard imports inline; keep explicit imports sorted.
