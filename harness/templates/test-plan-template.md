# Test Plan Template

Use this template when producing the test plan in the **Implementation Plan** stage (alongside the implementation plan).

---

## Feature / Bug

> One line description of what is being tested.

---

## Layer Selection

| Layer | Included | Reason |
|-------|----------|--------|
| Unit tests (`app/src/test/`) | ✅ / ❌ | |
| Integration tests (`app/src/test/`) | ✅ / ❌ | |
| Instrumented UI tests (`app/src/androidTest/`) | ✅ / ❌ | |

---

## Test Cases

List every test case grouped by the class under test. Assign a short ID (e.g. `T1`) so cases can be referenced in reviews and PRs.

### `<ClassName>Test.kt` — Unit

| ID | Given | When | Then |
|----|-------|------|------|
| T1 | \<precondition\> | \<action / trigger\> | \<expected outcome\> |
| T2 | \<precondition\> | \<action / trigger\> | \<expected outcome\> |

### `<ClassName>IntegrationTest.kt` — Integration

> **MANDATORY**: Every new API endpoint must have at least one integration test using a shared JSON scenario.

| ID | Given | When | Then | Shared Scenario |
|----|-------|------|------|-----------------|
| T3 | \<precondition\> | \<action / trigger\> | \<expected outcome\> | `scenario.json` |
| T4 | API returns error | load data | show error UiState | `scenario-error.json` |

### `<ScreenName>ScreenTest.kt` — Instrumented UI

| ID | Given | When | Then |
|----|-------|------|------|
| T5 | \<UiModel / UiState\> | render screen | \<visible / hidden elements\> |
| T6 | \<user gesture\> | tap element | \<navigation / state change\> |

---

## Shared JSON Scenarios

| Scenario File | API Mock | Expected Domain | Expected UI |
|---------------|----------|-----------------|-------------|
| `scenario.json` | ✅ | ✅ | ✅ |

Location: `sharedContracts/test-scenarios/`

---

## Coverage Targets

| Scope | Minimum |
|-------|---------|
| Overall project | ≥ 80% line coverage |
| New ViewModel / UseCase classes | ≥ 90% line coverage |
| Compose screens | excluded |

---

## Verification Commands

```bash
./gradlew testDebugUnitTest          # unit + integration tests
./gradlew koverLog                   # coverage gate
./gradlew connectedDebugAndroidTest  # instrumented UI tests (when UI changed)
```
