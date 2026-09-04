# CI Checks

## Purpose
Defines the minimum set of checks that must pass before a change is considered ready to merge.

---

## Required Checks

### 1. Build
```bash
./gradlew assembleDebug
```
**Must pass.** A failing build is a hard blocker.

### 2. Unit and Integration Tests
```bash
./gradlew testDebugUnitTest
```
**Must pass.** All tests in `app/src/test/` must be green.

### 3. Coverage
```bash
./gradlew koverLog
./gradlew :app:koverHtmlReportDebug
./gradlew :app:koverXmlReportDebug
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
bash harness/scripts/tests/coverage-contract-test.sh
```
**Must pass threshold:**
- Overall project: ≥ 80% line coverage
- New ViewModel classes: ≥ 90%
- New domain use case classes: ≥ 90%

The coverage checker computes weighted line coverage from the Kover XML report and
supports explicit per-file thresholds with `--min-file <path>=<percent>`.

### 4. Ktlint (formatting)
```bash
./gradlew ktlintCheck
```
**Must pass.** Auto-fix with `./gradlew ktlintFormat` before committing.

### 5. Detekt (static analysis)
```bash
./gradlew detekt
```
**Must pass** for errors. Warnings are informational.

### 6. Android Lint
```bash
./gradlew lintDebug
```
**Must pass** for errors. Review warnings in changed files.

### 7. Compose Rules
```bash
bash harness/scripts/check-compose-rules.sh
```
Windows:
```powershell
harness\scripts\check-compose-rules.cmd
```
**Must pass.** Catches Compose-specific violations not covered by Ktlint/Detekt:
- Hardcoded strings (must use `stringResource()`)
- Hardcoded colors (must use `LocalAppColors.current.<token>`)
- Interactive elements without `Modifier.testTag(...)`
- `hiltViewModel()` / `viewModel()` used inside `*Content` composables
- Repository / UseCase calls inside Composables
- Unstable `testTag` values (string interpolation)
- `Column` + `forEach` instead of `LazyColumn`

### 8. Navigation Rules
```bash
bash harness/scripts/check-navigation-rules.sh
bash harness/scripts/tests/navigation-rules-contract-test.sh
```
**Must pass.** Catches raw route literals and prefixes, unencoded dynamic arguments,
invalid required/optional argument defaults, and missing production navigation tests.

### 8a. Kotlin AST Checker Contract
```bash
bash harness/scripts/tests/ast-checkers-contract-test.sh
```
**Must pass.** Verifies the shared AST-backed Compose, localization, architecture,
navigation, and rendering-assertion entry points ignore rule-shaped comments/literals
and reject actual violations.

### 9. Rule Applicability Harness Contract
```bash
bash harness/scripts/tests/rule-applicability-contract-test.sh
```
**Must pass.** Ensures requirement artifacts carry all nine rule decisions and that the
stage gate rejects incomplete matrices.

### 10. Acceptance-Test Traceability Contract
bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --evaluate
bash harness/scripts/tests/acceptance-test-traceability-contract-test.sh

**Must pass** before a harness slice is marked tested or evaluated. It proves that
each acceptance Test ID maps to one declared Kotlin test method, a suite-scoped Gradle
or instrumented selector, its declared shared JSON scenario(s), and successful
evidence.

### 10a. Evaluation/Fix Lifecycle Contract
bash harness/scripts/check-evaluation-fix-contract.sh "$FEATURE_DIR" --evaluation
bash harness/scripts/tests/review-lifecycle-contract-test.sh

**Must pass** whenever evaluator/fix workflows, review templates, or their artifact
validators change. It rejects score/routing mismatches, contradictory successful
evidence, and fix passes that advance beyond a blocked stage or leave review findings
without in-report resolution status.

### 10b. Gate Failure Stop Contract
```bash
bash harness/scripts/tests/gate-failure-stop-contract-test.sh
```
**Must pass.** Ensures generator and fix workflows stop immediately when a required gate
fails or its prerequisite is unavailable.

### 10c. Production Journey Contract
```bash
bash harness/scripts/tests/journey-test-contract-test.sh
```
**Must pass** for navigation, saved-state, back-stack, destination-recreation, and
post-return persistence regressions. It rejects direct-ViewModel or Content-only tests
when they are declared as production journey evidence and verifies that the stage gate
requires a named production-entry test, real UI gesture, return boundary, and visible
post-return assertion.

### 11. Platform Capability Evidence (when a platform boundary is in scope)
```bash
# Generator: validates the selected slice's platform-boundary ownership.
bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"

# Final feature evaluation: validates every declared real boundary.
bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate
```
**Must pass.** A non-owning slice validates the declared contract without waiting for a later slice's boundary test. The boundary-owning slice and final feature evaluation reject missing capability matrices, pending/unavailable/skipped runtime evidence, and fake-only platform-boundary tests.

### 12. Visual Evidence Contract (when visual verification is required)
```bash
bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"
```
**Must pass.** Every visual verification method in the final owner's `feature_list.json` must have a matching `TC-*-VIS-*` row in `sprint-contract.md`, an acceptance-test ID, successful connected-test evidence, a non-empty screenshot, and one matching reference-anchor row in `visual_evidence/reference-anchor-verification.md`. Each row names the approved design asset, visual bounds `testTag`, runtime test, concrete bounds relationship, and screenshot.

### 13. Keyboard-Visible Planning Mockup (when a planned screen or bottom sheet has text input)
```bash
bash harness/scripts/check-keyboard-mockup-contract.sh "$FEATURE_DIR"
```
**Must pass during harness planning.** A design with a bottom-sheet textbox, text field, search field, or other text input — or screen content with text input and a bottom toolbar — must describe the keyboard-visible state and reference distinct non-empty base and keyboard-visible mockup assets. For a bottom sheet, the keyboard-visible state must state that the sheet stays open (tapping the text input must not dismiss it). When the text input is on screen content with a bottom toolbar (no modal sheet), the keyboard-visible state must state that the bottom toolbar is dismissed while the keyboard is visible. Both follow the Keyboard / IME Behavior rule in `.agents/rules/compose-rules.md`.

---

## Conditional Checks

### Instrumented UI tests (when UI changed)
```bash
./gradlew connectedDebugAndroidTest
```
Run when the change modifies Composable screens or navigation.
