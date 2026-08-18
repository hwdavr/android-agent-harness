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
```
**Must pass threshold:**
- Overall project: ≥ 80% line coverage
- New ViewModel classes: ≥ 90%
- New domain use case classes: ≥ 90%

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

### 8. Platform Capability Evidence (when a platform boundary is in scope)
```bash
# Generator: validates the selected slice's platform-boundary ownership.
bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"

# Final feature evaluation: validates every declared real boundary.
bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate
```
**Must pass.** A non-owning slice validates the declared contract without waiting for a later slice's boundary test. The boundary-owning slice and final feature evaluation reject missing capability matrices, pending/unavailable/skipped runtime evidence, and fake-only platform-boundary tests.

### 9. Visual Evidence Contract (when visual verification is required)
```bash
bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"
```
**Must pass.** Every visual verification method in the final owner's `feature_list.json` must have a matching `TC-*-VIS-*` row in `sprint-contract.md`, an acceptance-test ID, successful connected-test evidence, a non-empty screenshot, and one matching reference-anchor row in `visual_evidence/reference-anchor-verification.md`. Each row names the approved design asset, visual bounds `testTag`, runtime test, concrete bounds relationship, and screenshot.

### 10. Keyboard-Visible Planning Mockup (when a planned bottom sheet has text input)
```bash
bash harness/scripts/check-keyboard-mockup-contract.sh "$FEATURE_DIR"
```
**Must pass during harness planning.** A design with a bottom-sheet textbox, text field, search field, or other text input must describe the keyboard-visible state and reference distinct non-empty base and keyboard-visible mockup assets.

---

## Conditional Checks

### Instrumented UI tests (when UI changed)
```bash
./gradlew connectedDebugAndroidTest
```
Run when the change modifies Composable screens or navigation.
