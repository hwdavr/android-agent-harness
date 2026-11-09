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
**Must pass.** All tests in `app/src/test/` must be green, including the UI review-capture tests
under `app/src/test/java/**/review/` (they render captures for the conformance review; no golden is
recorded or compared).

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
bash harness/scripts/check-compose-rules.sh --all
```
Windows:
```powershell
harness\scripts\check-compose-rules.cmd --all
```
**Must pass.** Catches Compose-specific violations not covered by Ktlint/Detekt:
- Hardcoded strings (must use `stringResource()`)
- Hardcoded colors (must use `LocalAppColors.current.<token>`)
- Interactive elements without `Modifier.testTag(...)`
- `hiltViewModel()` / `viewModel()` used inside `*Content` composables
- Repository / UseCase calls inside Composables
- Unstable `testTag` values (string interpolation)
- `Column` + `forEach` instead of `LazyColumn`
- A Material primitive called outside the registered design-system wrapper that wraps it
  (design-system Component Registry, "Wraps Material" column)

### 7a. Full Source Rules Bundle
```bash
bash harness/scripts/check-full-source-rules.sh
```
Windows:
```powershell
harness\scripts\check-full-source-rules.cmd
```
**Must pass.** This is the required repository-wide source-rule gate used by
generator, evaluation, fix, and CI flows. It passes `--all` to the architecture,
Compose, and localization AST checkers, scans both test roots for assertion quality,
runs navigation checks, executes every checker after earlier failures, and returns
non-zero if any checker reports a violation. Individual checker commands are useful
for diagnosis but cannot replace this bundle as evidence.

The bundle also runs the AI/WebView security evaluator and its negative-case
contract test. These checks are mandatory in every flow that invokes the
full-source bundle; no separate workflow invocation is required. The evaluator
rejects unsafe cleartext, WebView, Mermaid, AI-input logging, and untrusted-output
sink patterns, while the contract test proves unsafe fixtures fail and reports do
not leak fixture content.

### 7b. Android Security Code Rules

Changes that touch an Android security boundary must load
`.agents/rules/android-security.md` and carry its boundary, failure-mode, and test
evidence into the review. The full-source bundle is the canonical CI enforcement
entry point; Android Lint, Detekt, Ktlint, and the applicable instrumented boundary
tests remain required. A missing runtime or unavailable platform boundary is
blocked evidence, not a passing check.

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

### 8b. Full Source Rules Bundle Contract
```bash
bash harness/scripts/tests/full-source-rules-contract-test.sh
```
**Must pass.** Proves the bundle forces full-source scans, runs every checker even
when an earlier checker fails, and fails on an untouched source violation.

### 9. Rule Applicability Harness Contract
```bash
bash harness/scripts/tests/rule-applicability-contract-test.sh
```
**Must pass.** Ensures `implementation-plan.md` carries all ten rule decisions, `test-plan.md`
maps every Required row, and the stage gate rejects incomplete matrices.

### 9a. Separate UX Design Stage Contract
```bash
python3 harness/scripts/tests/ux-design-stage-contract-test.py
```
**Must pass.** The feature block's Screen States lead to a complete UI_contract inventory before Pen
generation. Inventory gates allow only design-reference fields and Reused components to be Pending;
full UX/planning gates require completed references and registered components. No design.md is required.

### 9b. Dated Workspace and Analyze Gates
```bash
bash harness/scripts/tests/stage-artifacts-lanes-contract-test.sh
bash harness/scripts/tests/spec-plan-consistency-contract-test.sh
```
**Must pass.** Every lane works in one `.scratch/<YYYY-MM-DD>-<feature-id>/` workspace; the analyze
gate keeps the approved feature block(s), `implementation-plan.md`, `test-plan.md`, and (sliced lane)
`tasks.md` and `feature_list.json` consistent.

### 10. Acceptance-Test Traceability Contract
bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --evaluate
bash harness/scripts/tests/acceptance-test-traceability-contract-test.sh

**Must pass** before a harness slice is marked tested or evaluated. It proves that
each acceptance Test ID maps to one declared Kotlin test method, a suite-scoped Gradle
or instrumented selector, its declared shared JSON scenario(s), and successful
evidence. When the row explicitly claims rich-text or inline-formatting appearance,
the same gate invokes the rendered-output contract for the named span-style test.

### 10.0 Rendered Output Evidence Contract
```bash
bash harness/scripts/check-rendered-output-contract.sh \
  --project-root "$PWD" \
  --test-file app/src/test/java/<package>/<Feature>RenderedTextTest.kt \
  --test-method <method> \
  --claim "Following text visibly inherits Bold"
bash harness/scripts/tests/rendered-output-contract-test.sh
```
**Must pass** for any acceptance, reproduction, or visual row that claims formatted
text is visibly rendered. The named test method must assert the rendered node's
`AnnotatedString` span styles through `SemanticsProperties.Text`. ViewModel marks, toolbar state,
text content, and device screenshots are supplemental only. The acceptance,
visual-evidence, and bug-reproduction gates invoke this contract automatically where
the claim is explicit.

### 10.1 Production Journey Planning Contract
```bash
bash harness/scripts/check-journey-planning-contract.sh "$FEATURE_DIR"
bash harness/scripts/tests/journey-planning-contract-test.sh
```
**Must pass during harness planning.** It requires every slice to classify whether
it crosses a production navigation/lifecycle boundary, mirrors that decision in
`feature_list.json`, and assigns navigation/lifecycle acceptance rows to a named
production-entry instrumented journey with real actions, a return boundary, and a
visible post-return assertion.

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

### 10c. Project Documentation Root Contract
```bash
bash harness/scripts/tests/project-doc-location-contract-test.sh
```
**Must pass** when stage artifact location handling changes. Stage artifacts are accepted only
in dated `.scratch/<YYYY-MM-DD>-<feature-id>/` workspaces of the consumer repository; `docs/current/`
and workspaces inside the shared harness checkout are rejected.

### 10d. Production Journey Contract
```bash
bash harness/scripts/tests/journey-test-contract-test.sh
```
**Must pass** for navigation, saved-state, back-stack, destination-recreation, and
post-return persistence regressions. It rejects direct-ViewModel or Content-only tests
when they are declared as production journey evidence and verifies that the stage gate
requires a named production-entry test, real UI gesture, return boundary, and visible
post-return assertion.

### 10e. Role-Profile Alignment Contract
```bash
bash harness/scripts/tests/role-profile-contract-test.sh
```
**Must pass** when role profiles, complex-feature workflows, or named skills change.
It rejects retired `docs/current` paths, obsolete task-selection instructions, invalid
template paths, and unavailable evaluator skill names in `.agents/agents/`.

### 11. Platform Capability Evidence (when a platform boundary is in scope)
```bash
# Generator: validates the selected slice's platform-boundary ownership.
bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"

# Final feature evaluation: validates every declared real boundary.
bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate
```
**Must pass.** A non-owning slice validates the declared contract without waiting for a later slice's boundary test. The boundary-owning slice and final feature evaluation reject missing capability matrices, pending/unavailable/skipped runtime evidence, and fake-only platform-boundary tests.

### 12. UI Conformance Review Contract (when the change has UI scope)
```bash
bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --planning   # at planning
bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate   # before passing
```
**Must pass.** Planning rejects retired `TC-*-VIS` rows and Roborazzi golden commands, and (sliced
lane) requires exactly one final UI slice to own the conformance review. Evaluation requires
`ui_verification.json` with, for every `UI_contract.md` state, a review capture rendered at its
Viewport, a passing structural check, its registered components called from the planned UI files,
and the user's approval.

### 13. Keyboard State Contract (when a planned screen or bottom sheet has text input)
```bash
bash harness/scripts/check-keyboard-mockup-contract.sh "$FEATURE_DIR"
```
**Must pass during harness planning.** This compatibility command validates UI_contract.md through
the shared UI checker. Before Pen, pass `--inventory`: closed/open/dismissed state mappings and
explicit `screen-no-toolbar`, `screen-toolbar-dismissed`, or `sheet-stays-open` behavior are required.
After Pen, run without that flag to require distinct, full-window reference exports. The contract
also checks the focused input/required tags and the IME visible region. No design.md is read.

### 13a. IME State and Production Boundary Contract

```bash
bash harness/scripts/tests/ime-state-boundary-contract-test.sh
```

**Must pass for harness changes.** The UI/bug-fixing gates require an editable-input inventory,
same-window closed/open design frames with `system-ime` visible, and production Activity
open/dismiss tests even when `NAV` is Not applicable. Content replacement, generic test Activities,
missing/skipped/failed JUnit cases, and a command selecting the wrong class are rejected. Review
captures remain appearance evidence; they do not establish real IME window geometry.

## Conditional Checks

### Instrumented UI tests (when UI changed)
```bash
bash harness/scripts/run-android-instrumented-tests.sh --all
```
Run when the change modifies Composable screens or navigation. Set `ANDROID_SERIAL` to the
intended emulator/device; the runner installs APKs in place, runs `AndroidJUnitRunner` directly,
and verifies the app remains installed after the test.
