---
name: android-code-review
description: Performs a structured code review across correctness, security, performance, and architecture.
---

# Skill — Android Code Review

## Purpose
An evaluator pass covering the implementation — build quality, static analysis, architecture compliance, and rule adherence — always run as the second half of a review cycle, immediately after Test Review.

---

## Load

Load before starting (android-test-review SKILL.md context should already be loaded — do not re-load what is already in context):

- `skills/code-review-and-quality/SKILL.md`
- `skills/android-code-quality-checks/SKILL.md`
- `rules/android-architecture.md`
- `rules/compose-rules.md`
- `rules/localization-rules.md`
- `rules/navigation-rules.md`  *(if navigation changed)*
- `rules/api-contract-rules.md` *(if API or data layer changed)*
- `rules/analytics-rules.md`   *(if analytics events changed)*
- `rules/implementation-rules.md`
- `gates/review-checklist.md`
- Ad-hoc workflows: `docs/current/spec_v<N>.md`, `implementation_plan_v<N>.md`, `test_plan_v<N>.md`, and `test_review_v<N>.md`
- Harness evaluation: `$FEATURE_DIR/spec.md`, `$FEATURE_DIR/design.md` (if present), `$FEATURE_DIR/sprint-contract.md`, the active slice summary, and `test_review_{feature_id}.md`
- The active diff, its merge base or prior reviewed commit, all changed production files, and the tests mapped to the changed behavior

---

## Execute

### 1. Build and Static Quality Checks

Run all checks and record results:
```bash
./gradlew assembleDebug
./gradlew ktlintCheck
./gradlew detekt
./gradlew lintDebug
bash harness/scripts/check-compose-rules.sh
bash harness/scripts/check-localization-rules.sh
bash harness/scripts/check-architecture-rules.sh
```

On Windows (using PowerShell or Command Prompt), run the native script launchers instead:
```powershell
harness\scripts\check-compose-rules.cmd
harness\scripts\check-localization-rules.cmd
harness\scripts\check-architecture-rules.cmd
```

For every command, record its exact exit code, timestamp, commit, and complete failure details in the review report. A non-zero global gate is a review failure even when the violation is outside the changed feature; identify the source and whether it appears pre-existing, but do not report the gate as passing or approve the review without an explicit user waiver.

### 1a. Evidence integrity and changed-file scope

1. Record the current commit, merge base or reviewed baseline, and every changed file.
2. Distinguish independently executed checks, recorded stage evidence, up-to-date tasks, and skipped checks. Do not describe the latter three as fresh execution.
3. Record all checker failures verbatim enough to identify file, line, rule, and exit code. Scope classification (introduced / pre-existing / unknown) supplements the failure; it does not erase it.

### 1b. Requirement-to-production and completion-path tracing

Build a review table for every functional requirement, acceptance criterion, and documented edge case in the active specification and sprint contract:

| Source ID | Required behavior | Production entry point | Completion / cleanup path | Test evidence | Result |
|---|---|---|---|---|---|

For each changed behavior, trace from user/system input through state updates, coroutines, callbacks, and final observable outcome. In particular:

- Find every transition flag, loading state, callback, delayed job, listener, or cleanup method introduced or changed.
- Verify the method that completes or clears the state has a reachable **production** call site; a call from test code does not prove production wiring.
- Flag placeholder branches, empty/no-op handlers, unreachable code, stale flags, ignored callback results, feature paths only backed by manually preloaded UI state, and code that is never reached from an in-scope entry point.
- For permission, lifecycle, navigation, and external-callback requirements, verify the real boundary is invoked and its result reaches the specified UI or cleanup behavior.

Any required row without a reachable production path is **REVISION REQUIRED**.

### 2. Architecture & Design Validation

Review every changed file against the designs in `spec_v<N>.md`:
- **UiState compliance**: Does the implementation match the designed `UiState`?
- **Layer boundary check**:
  - UI → Presentation only
  - Presentation → Domain only
  - Data → Domain (implements interfaces only)
  - No upward or cross-layer dependencies
- **DI Scope**: Verify Hilt scopes (`@Singleton`, `@ViewModelScoped`) match the plan.
- **Domain purity**: No Android framework classes in domain layer.

### 3. Per-Rule Diff Review

**Mandatory process — must not be skipped:**

For every rules file loaded in the **Load** section, scan every changed file against it and record each violation explicitly. Work through each rule file in turn:

#### 3a. `rules/compose-rules.md`

Only run this section if the change touches Compose (UI `*.kt`) files. Otherwise mark the entire section N/A in the review report.

**Step 1 — Run the script (Scripted rules)**

The script has already run in step 1. Refer to its output to fill in the 🤖 rows in the Compose Rules Enforcement table. Mark each as ✅ (no violations) or ❌ (violations — list them in the Violations column).

Rules automatically covered by the script:
- **1.6** No hardcoded strings (`Text()`, `label=`, etc.) → Check 1
- **1.7** No hardcoded colors `Color(0x...)` / named `Color.*` → Check 2a/2b
- **1.3 / 2.2** `hiltViewModel()` / `viewModel()` not in `*Content` → Check 4
- **1.4** No repository/use-case calls inside Composable → Check 5
- **3.1** Files with interactive elements but no `testTag` → Check 3
- **3.3** No string interpolation in `testTag` values → Check 6
- **4.1** All user-visible text uses `stringResource()` → Check 1
- **5.1** No `Color(0x...)` outside `AppColors.kt` → Check 2a
- **5.2** No named `Color.*` outside `AppColors.kt` → Check 2b
- **8.1** `LazyColumn` instead of `Column + forEach` → Check 7

**Step 2 — Evaluate remaining rules (Evaluator rules)**

For each changed Composable file, read the source and evaluate the following rules that the script cannot check:
- **1.1** Composable receives `UiState` + callbacks as params — no data objects from lower layers exposed directly
- **1.2** Composable only renders state — no sorting, filtering, or formatting logic inside composable body
- **1.5** No business logic or data transformation anywhere inside the composable body
- **2.1** Each screen has a `*Screen` stateful wrapper and a `*Content` stateless composable pair
- **2.3** UI tests target `*Content`, not `*Screen` (check test files)
- **3.2** Key content containers (list items, empty/error states, loading indicators, nav elements) have `testTag`
- **3.3** `testTag` names are descriptive — flag any `"btn"`, `"item"`, or single-word tags
- **4.2** String resource keys follow `<screen>_<element>_<type>` naming pattern
- **5.3** Colors accessed via `LocalAppColors.current.<token>` — not via module-level `val` workarounds
- **5.4** Color token names describe semantic purpose (`textSecondary`) not value (`gray`)
- **5.5** Any new color added to **both** `LightAppColors` and `DarkAppColors` in `AppColors.kt`
- **6.1** Repeated UI structure extracted to `components/` when it appears on more than one screen
- **6.2** Components with internal state or complexity extracted to their own composable
- **6.3** Each component has one visual responsibility
- **7.1** State hoisted to the lowest common ancestor that needs it
- **7.2** State not hoisted higher than necessary
- **7.3** No `remember {}` inside `*Content` composables
- **8.2** Stable types passed as parameters (no raw `List<>`, `Map<>`, inline lambdas that cause recomposition)
- **8.3** `key()` used in `items()` / `itemsIndexed()` when items have stable IDs
- **8.4** Lambdas passed as parameters — not created inside the composable body

**Step 3 — Mark unchecked rules**

For any rule in the Compose Rules Enforcement table that was neither run by the script nor evaluated in Step 2, set the Status to `👁️ Human` in the review report. This flags it explicitly for human review before merge.

#### 3b. `rules/localization-rules.md`

Only skip this section if the change adds no user-visible text and no Kotlin UI file is modified. Otherwise mark the entire section N/A in the review report.

**Step 1 — Run the script (Scripted rules)**

The script has already run in step 1. Refer to its output to fill in the 🤖 rows in the Localization Rules Enforcement table. Mark each as ✅ (no violations) or ❌ (violations — list them in the Violations column).

Rules automatically covered by the script:
- **1.1** `Text()` called with a raw string literal → Check 1
- **1.2** `label=`, `title=`, `placeholder=`, `hint=` set as a raw string → Check 2
- **1.3** Local UI label variables assigned a raw string → Check 3
- **6.2** `contentDescription = null` on interactive icons → Check 4

**Step 2 — Evaluate remaining rules (Evaluator rules)**

For each changed source file and `strings.xml`, read the code and evaluate the following rules that the script cannot check:
- **2.1** All new string values are defined in `strings.xml` — not as Kotlin `const val` or companion object properties
- **3.1** Every new string resource key follows the `<screen>_<component>_<type>` naming pattern
- **4.1** Any count-dependent text uses `<plurals>` — not `if (count == 1)` string concatenation
- **4.2** Plural strings are accessed via `pluralStringResource()` at the call site
- **5.1** Strings with dynamic values use format arguments (`%s`, `%d`) in `strings.xml` — not string concatenation in Kotlin
- **5.2** Format arguments are passed correctly via `stringResource(R.string.key, arg)` at the call site
- **6.1** All non-text interactive elements (icon buttons, image buttons) have a non-null `contentDescription = stringResource(...)` — not missing entirely

**Step 3 — Mark unchecked rules**

For any rule in the Localization Rules Enforcement table that was neither run by the script nor evaluated in Step 2, set the Status to `👁️ Human`.

#### 3c. `rules/android-architecture.md`

Only skip this section if the change touches no Kotlin source files. Otherwise mark the entire section N/A in the review report.

**Step 1 — Run the script (Scripted rules)**

The script has already run in step 1. Refer to its output to fill in the 🤖 rows in the Architecture Rules Enforcement table. Mark each as ✅ (no violations) or ❌ (violations — list them in the Violations column).

Rules automatically covered by the script:
- **1.1 / 1.6** UI files with `data.(remote|local|repository)` imports → §1a
- **1.4** UI files importing DTO/Entity/Request/Response types → §1b
- **1.5** UI files calling `ApiService.*` or DAO directly → §1c §1d
- **2.6** ViewModel importing Retrofit / Room / calling ApiService → §2a §2b §2c
- **2.9** ViewModel importing `data.(remote|local)` packages → §2d
- **3.1** Domain files importing `android.*` / `androidx.*` → §3a
- **3.2** Domain files importing `ui.*` → §3e
- **3.3** Domain files importing `retrofit2.*` → §3b
- **3.4** Domain files importing `androidx.room.*` → §3c
- **3.5** Domain files importing `data.*` → §3d
- **4.1** Non-data-layer files importing DTO/Entity → §4a
- **4.2** Data-layer files referencing `UiState` → §4b
- **5.3** ViewModel with ≥3 `StateFlow<Boolean>` → §5a
- **2.5 / 5.4** Permanent state fields named `showDialog`, `navigateTo`, etc. → §5b
- **6.1** Domain files importing DTO types → §6b
- **6.3** UI files importing DTO/ApiModel types → §6a
- **7.2** RepositoryImpl missing `@Singleton` → §7b
- **3.1 / 7.4** Domain constructors receiving `Context` → §7a
- **8.1** Fully-qualified class names used inline → §8a
- **8.2** `enqueue` / `execute` / `await` in ViewModel bodies → §8b
- **8.3** `when/if` on domain model fields inside `@Composable` → §8c
- **8.4** ViewModel without matching test file → §8d
- **9.1–9.4** Misplaced ViewModel / UseCase / RepositoryImpl / Mapper files → §9a–d

**Step 2 — Evaluate remaining rules (Evaluator rules)**

For each changed source file, read the code and evaluate the following rules that the script cannot check:
- **1.2** No business rules (sorting, filtering, validation logic) inside Composable or Fragment
- **1.3** UI never parses or interprets API response fields directly
- **2.1** Each ViewModel has one primary `StateFlow<*UiState>` — not multiple independent streams
- **2.2** ViewModel injects domain use cases or repository interfaces — not concrete data implementations
- **2.3** Domain → UI model mapping is invoked in ViewModel or mapper, not inside Composables
- **2.4** All three states (loading / success / error) are represented in UiState and rendered
- **2.7** ViewModel body contains no Room / file I/O calls
- **2.8** Complex business logic lives in a UseCase, not inline in ViewModel `launch {}` blocks
- **4.3** Data-layer classes contain no NavController references or route strings
- **5.1** Screen renders from a single consolidated UiState — not from multiple scattered streams
- **5.2** `sealed class` used only when screen modes are truly distinct — prefer `data class` with nullable fields
- **6.2** Domain → UI mapping is invoked in Presentation layer only — not inside Composables or data classes
- **6.4** Composable parameters are domain or UI model types — no raw API response objects passed in
- **7.1** All dependencies are provided via Hilt — no manual `= MyRepository()` construction
- **7.3** Hilt modules use `@ViewModelScoped` for ViewModel-bound bindings
- **9.5** Domain → UI mapper files live under `ui/**/mapper/` — not in `domain/`

**Step 3 — Mark unchecked rules**

For any rule in the Architecture Rules Enforcement table that was neither run by the script nor evaluated in Step 2, set the Status to `👁️ Human` in the review report. Rule **8.5** (AI-generated code reviewed before merge) is always `👁️ Human`.

#### 3d. `rules/navigation-rules.md` *(if navigation changed)*
- [ ] Check against navigation rules — record any violations or mark N/A.

#### 3e. `rules/api-contract-rules.md` *(if API or data layer changed)*
- [ ] Check against API contract rules — record any violations or mark N/A.

#### 3f. `rules/analytics-rules.md` *(if analytics events changed)*
- [ ] Check against analytics rules — record any violations or mark N/A.

#### 3g. `gates/review-checklist.md` — full checklist
Work through every item and mark it PASS, FAIL, or N/A. Do not leave items blank.

#### 3h. `rules/implementation-rules.md`

Only run this section if the change touches any production source file (anything under `app/src/main/`, `sharedContracts/`, or any module's `main` source set). Otherwise mark the entire section N/A in the review report.

Test sources (`src/test/`, `src/androidTest/`, `src/commonTest/`) are exempt — fakes, mocks, and stubs used as test doubles are permitted and expected there. `@Preview` composables may use sample `UiState` values for tooling; the production composables and `UiState` data classes themselves are still in scope.

For every changed production source file, read the code and evaluate each rule below. There is no scripted check — every rule is 🧠 Evaluator.

- [ ] **1.1** No function returns a hardcoded value where the requirement specifies a computation, query, or transformation. Cross-reference §1b requirement-to-production tracing — a function whose output never reaches the specified outcome is a violation even if it returns a plausible value. Examples to flag: `fun totalPrice(...): Double = 0.0`, `suspend fun search(...): List<T> = emptyList()`.
- [ ] **1.2** No `TODO()`, `TODO("...")`, `throw NotImplementedError(...)`, or any equivalent marker that lets a function compile without implementing its behavior.
- [ ] **1.3** No comments indicating the surrounding code is not the real implementation: `// dummy implementation`, `// placeholder`, `// stub for now`, `// TODO: real implementation later`, `// temporary — replace before merge`, `// hardcoded for now`, or any equivalent.
- [ ] **1.4** No no-op handler bodies (`{}`, `/* TODO */`, or log-only) where the requirement specifies the callback must perform a real action (navigate, persist, dispatch, emit, etc.). Cross-reference §1b — a callback registered in production but with no observable effect is a violation.
- [ ] **1.5** No function, class, branch, or path that compiles cleanly but does not perform the behavior defined in the active `spec.md`, `implementation_plan_v<N>.md`, `feature_list.json`, or `sprint-contract.md` requirement it claims to fulfill. Includes: early-return branches with placeholder values, methods that delegate to another stub instead of implementing behavior, classes that satisfy an interface by throwing or returning defaults for every member, and reachable `when` / `if` paths that never produce the specified outcome.

Any violation of §3h is **REVISION REQUIRED** — do not approve the review. The Coder must return to implementation and deliver the real behavior. The only acceptable waiver is an explicit, documented user-approved false positive recorded in the code review report with a justification, matching the AGENTS.md rule on suppressed violations.

### 4. UI Verification (if `affects_ui == true` for the active slice, or any Composable changed in the diff)

Run this section when EITHER condition holds:
- The active slice's `feature_list.json` entry has `"affects_ui": true` (authoritative trigger — set by the Planner during `slice-planning`), OR
- Any `*.kt` file under a `ui/**` or `**/screen/**` package is in the active diff (safety net for slices missing the flag).

For harness-evaluation reviews, the `affects_ui` flag is the source of truth. If the flag is `false` but a Composable changed, record that as a planning-defect finding ("`affects_ui` should be `true`") and proceed with verification anyway.

When `requires_visual_verification == true`, use the planned state-verifying visual command. It must navigate to and assert the target state before capture. When it is `false`, do not capture an arbitrary screen; run the slice's automated UI/integration acceptance tests instead and record which final user story owns visual verification. Verify no raw string literals appear in any UI-dump output used as state proof — all text must be resolved from `strings.xml`.

When a requirement depends on a system permission, lifecycle event, navigation event, or external callback, UI verification must exercise that boundary directly or document why the chosen deterministic test seam proves the same production wiring. Rendering a pre-populated final `UiState` alone is insufficient.

**Visual verification gate** *(required when `requires_visual_verification == true`)*: For each `TC-US-*-VIS` Test ID row listed in the active slice's user story in `$FEATURE_DIR/sprint-contract.md`, re-run its state-verifying `Exact command`. Attach the target-state proof, captured screenshot path, and command's exit status to the code review report. Then visually compare the captured screenshot against `$FEATURE_DIR/design.md` and record any deviation in layout, typography, color, spacing, or control placement as a review finding — canvas/screen content may legitimately differ between mockup and real app, so the comparison focuses on UI chrome, not image content. A non-zero exit code, missing target-state proof, or missing/empty screenshot is a review-blocking finding — record it under the §3g `gates/review-checklist.md` outcome and do not mark the slice Approved. When `affects_ui == true` but `requires_visual_verification == false`, verify the slice's automated UI/integration acceptance tests and record `DEFERRED — visual verification is owned by <US-ID>`; do not capture an unrelated screen.

### 5. Security and Release Risk
Verify secrets, PII logging, and backward compatibility. Perform a source-level log audit of every changed file and flag user-generated text, transcripts, image data, identifiers, or sensitive payloads written to logs. "On-device" processing does not permit logging the content.

---

## Output

Produce a report from `harness/templates/code-review-template.md`:

- Ad-hoc workflows: `docs/current/code_review_v<N>.md`
- Harness evaluation: `$FEATURE_DIR/code_review_{feature_id}.md`

---

## Done When

All conditions must pass before returning to the workflow:

- [ ] `assembleDebug` — exit code 0
- [ ] `ktlintCheck` — exit code 0
- [ ] `detekt` — exit code 0
- [ ] `check-compose-rules.sh` or `check-compose-rules.cmd` — exit code 0 (or skipped with no Compose changes)
- [ ] `check-localization-rules.sh` or `check-localization-rules.cmd` — exit code 0
- [ ] `check-architecture-rules.sh` or `check-architecture-rules.cmd` — exit code 0
- [ ] Compose Rules Enforcement table completed — every rule is ✅, ❌ (acknowledged), ⏭, or `👁️ Human` (no blanks)
- [ ] All `❌` compose rule violations are either fixed or explicitly accepted with justification
- [ ] All compose `👁️ Human` rows acknowledged by the human reviewer before merge
- [ ] Localization Rules Enforcement table completed — every rule is ✅, ❌ (acknowledged), ⏭, or `👁️ Human` (no blanks)
- [ ] All `❌` localization rule violations are either fixed or explicitly accepted with justification
- [ ] All localization `👁️ Human` rows acknowledged by the human reviewer before merge
- [ ] Architecture Rules Enforcement table completed — every rule is ✅, ❌ (acknowledged), ⏭, or `👁️ Human` (no blanks)
- [ ] All `❌` architecture rule violations are either fixed or explicitly accepted with justification
- [ ] All architecture `👁️ Human` rows (including rule 8.5) acknowledged by the human reviewer before merge
- [ ] `navigation-rules.md` — all checks PASS or N/A
- [ ] `api-contract-rules.md` — all checks PASS or N/A
- [ ] `analytics-rules.md` — all checks PASS or N/A
- [ ] `implementation-rules.md` — all §3h checks PASS or N/A (entire section N/A is acceptable when no production source files changed); any violation is REVISION REQUIRED and cannot be waived without an explicit user-approved false positive recorded in the review report
- [ ] `gates/review-checklist.md` — every item marked PASS or N/A
- [ ] **Visual verification gate** (when `requires_visual_verification == true` for the active slice): every declared `TC-US-*-VIS` row re-run with its state-verifying command — exit code 0, target-state proof and captured screenshot path recorded in the code review report, and the Evaluator's visual comparison against `$FEATURE_DIR/design.md` (focusing on UI chrome, not canvas/screen content) recorded as a finding or explicit PASS. For intermediate UI slices, record the final visual-verification owner instead.
- [ ] UI matches the designed states in `spec_v<N>.md`
- [ ] Every FR, AC, and documented edge case has a requirement-to-production result.
- [ ] Every new or changed transition, callback, lifecycle cleanup, and asynchronous completion path has a reachable production call site.
- [ ] Changed source files have no logs containing user-generated or sensitive content.
- [ ] Every quality-gate result includes command, exit code, provenance, and failure detail; no non-zero gate is labelled passing.
- [ ] The active workflow's code-review report exists with all sections completed and an evidence-based verdict.

**APPROVED →** Return to the active workflow only when every required requirement-to-production row and quality gate passes.

**REVISION REQUIRED →** Return to Implementation for unreachable, placeholder, missing-completion, privacy, or architecture defects; return to Testing for evidence gaps.
