# Clean State Checklist

Run this checklist before committing and at the end of each session to ensure codebase health, architectural integrity, and seamless handoff.

---

## 🛠️ 1. Build & Compilation
*   [ ] **Compile Check**: Run `./gradlew assembleDebug` locally to ensure the project compiles cleanly with zero compilation errors.
*   [ ] **Warning Check**: Verify that there are zero compiler warnings in active development modules.
*   [ ] **Dependency Safety**: Ensure no duplicate dependencies or class conflicts exist in the build configurations.
*   [ ] **Ktlint Verification**: Run `./gradlew ktlintCheck` and verify that all source code complies with styling standards with zero style violations.
*   [ ] **Static Analysis**: Run `./gradlew detekt` static analysis and ensure that zero rule violations remain unresolved.
*   [ ] **Suppression Audit**: Verify that no new `@Suppress`, `@SuppressLint`, `tools:ignore`, ktlint/detekt disable comment, baseline, or broader rule exclusion was added to make checks pass. Any genuine false positive must be approved by the user and documented.

---

## 📐 2. Architecture & Standards
*   [ ] **Layer Boundaries**: Verify strict layered architecture boundaries: Data layer must not leak DTOs or DB entities to Domain or UI layers.
*   [ ] **Domain Isolation**: Ensure the Domain layer contains pure Kotlin business logic with no Android framework imports.
*   [ ] **State Hoisting**: Confirm all ViewModel state management uses unidirectional data flow (UDF) with stateless UI Composables.
*   [ ] **Secret Scanner**: Ensure no secrets (API keys, credentials, tokens) are hardcoded in source code; use `local.properties` and `BuildConfig`.
*   [ ] **API Alignments**: Cross-reference and verify all API model structures against OpenAPI spec definitions in `sharedContracts/openapi.yaml`.

---

## 💻 3. Runtime & Stability
*   [ ] **Data Persistence**: Verify database interactions (Room) survive app restarts without crash or schema corruption.
*   [ ] **Resource Management**: Verify proper lifecycle handling (e.g. no memory leaks or active listeners lingering in inactive states).
*   [ ] **Navigation Integrity**: Confirm navigation backstack behaves gracefully, handling configuration changes and deep link entries without crashing.
*   [ ] **Secure Sandbox**: Verify that the application starts up within performance benchmarks and secure sandbox preferences.
*   [ ] **Dispatcher discipline**: Ensure all async operations are launched on the correct dispatchers (e.g. `Dispatchers.IO` for IO-bound work).

---

## 🧪 4. Testing & Quality
*   [ ] **Test Run**: Run `./gradlew testDebugUnitTest` and confirm all unit and integration tests exit GREEN.
*   [ ] **Global Coverage**: Verify that overall project line coverage meets the minimum threshold of **80%** (via `koverLog`).
*   [ ] **Feature Coverage**: Verify that new ViewModel and domain Use Cases hit the minimum target of **90%** coverage.
*   [ ] **Visual Reference Anchors**: When visual verification is required, run `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"`; each visual Test ID must have a non-empty screenshot and reference-anchor proof tied to a visual bounds `testTag` and a runtime assertion.
*   [ ] **Platform Capability Matrix**: Verify `platform-capability-matrix.md` declares minimum/target/API-boundary behavior and the `fail_loudly` unsupported-environment policy.
*   [ ] **Real Platform Boundary**: For platform-bound behavior, the slice that owns the declared real instrumented test must run it; fake/JVM-only tests are supplemental and missing environments must fail or be marked `Blocked`/`Revise`. Non-owning slices must run `check-platform-evidence.sh --evaluate --slice "$FEATURE_ID"`; the no-slice evaluation remains required before final feature evaluation.
*   [ ] **Mock Data Discipline**: Ensure no inline mock data is used; utilize shared JSON scenarios loaded from `sharedContracts/test-scenarios/`.
*   [ ] **TDD Cleanup**: Verify that any temporary `@Ignore` or `@Disabled` annotations added during the TDD bug-reproduction phase are completely removed.

---

## 📊 5. Observability & Logging
*   [ ] **Invocation Audits**: Ensure every IPC channel and background service invocation is logged.
*   [ ] **Standardized Logs**: Verify all logs utilize structured formats (JSON log payloads) with clear severity levels (VERBOSE to ASSERT).
*   [ ] **Context Payloads**: Ensure service tags and contextual payloads (documentId, sizeBytes, execution durations) are attached to relevant events.
*   [ ] **Warn on Hard Reset**: Confirm that database resetting or hard failures log a warning (`WARN` or `ERROR`) level event.

---

## 🧹 6. Cleanliness & State Reset
*   [ ] **Reset Execution**: Verify that clean state reset clears all databases, local caches, and preferences cleanly.
*   [ ] **Idempotence**: Ensure that database resetting is idempotent—running it multiple times in a row leaves the system in a consistent empty state.
*   [ ] **Artifact Cleanup**: Confirm that no stale or orphan artifacts remain in intermediate directories (e.g. run a cleanup script if available).

---

## 📝 7. Documentation & Handoff
*   [ ] **Progress Audit**: Update progress logs and task checklists in the changes audit directory.
*   [ ] **Session Handoff**: Create or update the `session-handoff.md` file detailing modifications and next steps.
*   [ ] **ADRs & Pitfalls**: Confirm that all new features and public API changes are accompanied by ADRs or knowledge updates.
*   [ ] **Harness Lifecycle**: For complex features, run `bash harness/scripts/check-feature-lifecycle.sh`; verify the stable product workspace, status, completion evidence, and active-feature count are consistent.
