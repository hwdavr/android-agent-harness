---
name: android-unit-test
description: Requirements and instructions for Android unit test coverage and verification.
---

# Android Unit Test Skill

## Purpose
This skill defines the standards for unit and integration testing in the Android application. JVM-based tests in `src/test` are the primary verification layer for logic, ViewModel state, API handling, and data flow.

## Coverage Requirements

### 1. Overall Project Coverage
- The overall application line coverage must be at least **80%**.
- Verified by running `./gradlew :app:koverLog` or checking the Kover HTML report.

### 2. New Feature Coverage
- All **new ViewModels** must have at least **90%** line coverage.
- All **new Domain classes** (repositories, use cases, mappers) must have at least **90%** line coverage.

## Testing Layers & Naming

### 1. Unit Tests
- **Scope**: Single class logic (business rules, mappers, reducers, ViewModel state transitions).
- **Naming**: Class name must end with **Test** (e.g., `HomeViewModelTest.kt`).
- **Base Class**: ViewModel unit tests should inherit from `BaseViewModelTest` (located under `app/src/test/java/<package_path>/base/BaseViewModelTest.kt`).
- **Tooling**: Use **MockK** for all dependencies.

### 2. Integration Tests
- **Scope**: Multiple layers interacting (ViewModel + Repository + Mocked API). Used for API handling, retry logic, and data flow from API to UI state.
- **Naming**: Class name must end with **IntegrationTest** (e.g., `HomeViewModelIntegrationTest.kt`).
- **Base Class**: ViewModel integration tests should inherit from `BaseViewModelIntegrationTest` (located under `app/src/test/java/<package_path>/base/BaseViewModelIntegrationTest.kt`).
- **Tooling**: Use **MockWebServer** and shared JSON scenarios.

### 3. Shared JSON Scenario Rules
- Each API should have at least one integration test.
- If an API is used by a ViewModel, assert the `UiState` against `expected.ui`.
- If used only by domain logic, assert `expected.domain`.
- Cover success, 4xx/5xx errors, malformed payloads, and timeouts.

## Testing Standards

### 1. Verification Logic
- **No UI assertions**: Assert `UiState` properties instead of rendered UI components.
- **Deterministic**: Tests must be 100% deterministic (no `delay` or unpredictable timing).
- **One Scenario**: One main scenario per test method.

### 2. Mocking & Coroutines
- Use `runTest` and `advanceUntilIdle()` to handle asynchronous logic.
- Use `coEvery` and `coVerify` for suspend functions in MockK.

## Verification Workflow

1.  **Run Tests**:
    ```bash
    ./gradlew :app:testDebugUnitTest
    ```
2.  **Generate Report**:
    ```bash
    ./gradlew :app:koverHtmlReportDebug
    ```
3.  **Verify Coverage**:
    Check the HTML report at `app/build/reports/kover/htmlDebug/index.html` to ensure the **80% overall** and **90% per-class** targets are met.

## Troubleshooting
- If Robolectric is required (e.g., for `Context` or `Uri`), use `@RunWith(RobolectricTestRunner::class)` and `ApplicationProvider.getApplicationContext()`.
- Ensure all launched coroutines are completed or cancelled before the test finishes.
