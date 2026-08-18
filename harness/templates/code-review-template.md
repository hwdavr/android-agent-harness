# Review Template

Use this template when producing the review summary in the relevant stage.

---

## Review Summary

**Feature / Bug**: `<brief description>`  
**Reviewer**: Agent  
**Date**: `<date>`

---

## Review Scope and Evidence Provenance

| Item | Value |
|---|---|
| Current commit | |
| Merge base / prior reviewed commit | |
| Baselines reviewed | `spec`, `sprint contract`, plan, test review |
| Changed production files reviewed | |
| Changed tests reviewed | |
| Independently executed checks | |
| Recorded / up-to-date / skipped checks | |

## Requirement-to-Production Traceability

List every FR, AC, and documented edge case from the active specification and sprint contract.

| Source ID | Required behavior | Production entry point | Completion / cleanup path | Test evidence | Result |
|---|---|---|---|---|---|
| FR-001 | | | | | PASS / REVISION REQUIRED / N/A |

## State Completion and Reachability Audit

| Changed state, callback, job, or listener | Set / entry point | Production completion or cleanup call site | Test-only substitute found? | Result |
|---|---|---|---|---|
| | | | Yes / No | PASS / REVISION REQUIRED |

Required: flag completion paths called only from tests, stale transition flags, ignored callbacks, placeholder/no-op branches, and final-state rendering that lacks a real production trigger.

---

## Build & Test Results

| Check | Exit code | Timestamp / commit | Provenance | Result | Failure detail / scope |
|-------|---:|---|---|---|---|
| `assembleDebug` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `testDebugUnitTest` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `koverLog` overall | | | Independently executed / Recorded / Up-to-date / Not run | ✅ X% ≥ 80% / ❌ | |
| `koverLog` new classes | | | Independently executed / Recorded / Up-to-date / Not run | ✅ X% ≥ 90% / ❌ | |
| `connectedDebugAndroidTest` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL / ⏭ SKIPPED | |
| `ktlintCheck` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `detekt` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `lintDebug` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `check-compose-rules.sh` or `check-compose-rules.cmd` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL / ⏭ SKIPPED | |
| `check-localization-rules.sh` or `check-localization-rules.cmd` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `check-architecture-rules.sh` or `check-architecture-rules.cmd` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| Suppression audit | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | Confirm no new suppressions, ignores, baselines, or rule exclusions were added to make checks pass. |

Any non-zero required gate makes the verdict non-approved, even when the source is pre-existing. Record the source and scope above.

---

## Compose Rules Enforcement

> Skip this section entirely if the change contains no Compose (`*.kt` UI) file modifications.

For each rule, record how it was checked for **this change** and its outcome.

**Status key**

| Symbol | Meaning |
|--------|---------|
| ✅ | Checked — no violations found |
| ❌ | Checked — violation(s) found (list below) |
| 👁️ **Human** | Not checked by script or AI — requires human review before merge |
| ⏭ | Not applicable to this change |

### Section 1 — Composable Responsibilities

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 1.1 Receives `UiState` + callbacks as params | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 1.2 Only renders state — no derived computation | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 1.3 Never calls ViewModel directly | 🤖 Check 4 + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 1.4 No use case / repository calls | 🤖 Check 5 + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 1.5 No business logic / data transformation | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 1.6 No hardcoded strings — uses `stringResource()` | 🤖 `check-localization-rules.sh` / `.cmd` | ✅ / ❌ | |
| 1.7 No hardcoded colors — uses `LocalAppColors` | 🤖 Check 2 | ✅ / ❌ | |

### Section 2 — Stateless / Stateful Pattern

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 2.1 Screen split into `*Screen` + `*Content` pair | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 2.2 Only `*Screen` calls `hiltViewModel()` / `collectAsStateWithLifecycle()` | 🤖 Check 4 + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 2.3 UI tests target `*Content`, not `*Screen` | 🧠 Evaluator | ✅ / ❌ / ⏭ | |

### Section 3 — Test Tags

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 3.1 All interactive elements have `testTag` | 🤖 Check 3 + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 3.2 Key content containers have `testTag` | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 3.3 `testTag` names are descriptive and stable | 🤖 Check 6 + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 4 — String Resources

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 4.1 All user-visible text uses `stringResource()` | 🤖 `check-localization-rules.sh` / `.cmd` | ✅ / ❌ | |
| 4.2 Resource keys follow `<screen>_<element>_<type>` naming | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 5 — Colors

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 5.1 No `Color(0x...)` outside `AppColors.kt` | 🤖 Check 2a | ✅ / ❌ | |
| 5.2 No named `Color.*` outside `AppColors.kt` | 🤖 Check 2b | ✅ / ❌ | |
| 5.3 Colors accessed via `LocalAppColors.current.<token>` | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 5.4 Color tokens named by semantic purpose | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 5.5 New color added to both Light **and** Dark theme | 🤖 Script + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 6 — Component Extraction

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 6.1 Reused UI extracted to `components/` | 👁️ Human + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 6.2 Complex / stateful components extracted | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 6.3 One visual responsibility per component | 👁️ Human + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 7 — State Hoisting

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 7.1 State hoisted to the lowest common ancestor | 👁️ Human + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 7.2 State not hoisted higher than necessary | 👁️ Human + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 7.3 No `remember {}` inside `*Content` composables | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 8 — Performance

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 8.1 `LazyColumn` instead of `Column` + `forEach` | 🤖 Check 7 | ✅ / ❌ | |
| 8.2 Stable parameter types to avoid recompositions | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 8.3 `key()` used in lazy lists with stable IDs | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 8.4 Lambdas passed as parameters, not created inline | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Compose Rule Violations Detail

> List each violation found above. Delete this section if there are none.

- **Rule X.Y** — `<file>:<line>`: `<description>`

---

## Localization Rules Enforcement

> Skip this section entirely if the change adds no user-visible text and no Kotlin UI file is modified.

For each rule, record how it was checked for **this change** and its outcome.

**Status key**

| Symbol | Meaning |
|--------|---------|
| ✅ | Checked — no violations found |
| ❌ | Checked — violation(s) found (list below) |
| 👁️ **Human** | Not checked by script or AI — requires human review before merge |
| ⏭ | Not applicable to this change |

### Section 1 — String Resources Are Mandatory

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 1.1 `Text()` uses `stringResource()` — no raw string literals | 🤖 Check 1 | ✅ / ❌ | |
| 1.2 Composable params (`label=`, `placeholder=`, etc.) use `stringResource()` | 🤖 Check 2 | ✅ / ❌ | |
| 1.3 Local UI label variables not assigned raw strings | 🤖 Check 3 | ✅ / ❌ | |

### Section 2 — Where to Define Strings

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 2.1 All strings defined in `strings.xml` | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 3 — Naming Convention

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 3.1 Resource keys follow `<screen>_<component>_<type>` pattern | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 4 — Plural Strings

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 4.1 Count-dependent text uses `<plurals>` — not conditional string concatenation | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 4.2 Plurals accessed via `pluralStringResource()` | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 5 — Dynamic Content

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 5.1 Strings with runtime values use format arguments in `strings.xml` | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 5.2 Format arguments passed via `stringResource(R.string.key, arg)` | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 6 — Content Descriptions

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 6.1 Non-text interactive elements have `contentDescription = stringResource(...)` | 🤖 Check 4 + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 6.2 `contentDescription` never `null` on interactive icons | 🤖 Check 4 | ✅ / ❌ | |

### Localization Rule Violations Detail

> List each violation found above. Delete this section if there are none.

- **Rule X.Y** — `<file>:<line>`: `<description>`

---

## Architecture Rules Enforcement

> Skip this section entirely if the change contains no Kotlin source file modifications.

For each rule, record how it was checked for **this change** and its outcome.

**Status key**

| Symbol | Meaning |
|--------|---------|
| ✅ | Checked — no violations found |
| ❌ | Checked — violation(s) found (list below) |
| 👁️ **Human** | Not checked by script or AI — requires human review before merge |
| ⏭ | Not applicable to this change |

### Section 1 — UI Layer

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 1.1 No repository calls from UI | 🤖 §1a + 🧠 Evaluator | ✅ / ❌ / ⏭ | |
| 1.2 No business rules in UI | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 1.3 No API response parsing in UI | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 1.4 No DTO → domain mapping in UI | 🤖 §1b + 🧠 Evaluator | ✅ / ❌ / ⏭ | |
| 1.5 No direct data source / DAO access from UI | 🤖 §1c §1d | ✅ / ❌ / ⏭ | |
| 1.6 No data-layer imports in UI | 🤖 §1a | ✅ / ❌ / ⏭ | |

### Section 2 — Presentation Layer (ViewModel)

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 2.1 Single `UiState` `StateFlow` per screen | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 2.2 Coordinates use cases — not repositories | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 2.3 Domain → UI mapping in Presentation only | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 2.4 Loading / success / error states all handled | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 2.5 One-off events via `Channel` / `SharedFlow` | 🤖 §5b + 🧠 Evaluator | ✅ / ❌ / ⏭ | |
| 2.6 No direct Retrofit / DAO calls in ViewModel | 🤖 §2a §2b §2c | ✅ / ❌ / ⏭ | |
| 2.8 No heavy business logic in ViewModel | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 2.9 No data-layer implementation imports in ViewModel | 🤖 §2d | ✅ / ❌ / ⏭ | |

### Section 3 — Domain Layer

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 3.1 No Android framework imports in domain | 🤖 §3a §7a | ✅ / ❌ / ⏭ | |
| 3.2 No UI imports in domain | 🤖 §3e | ✅ / ❌ / ⏭ | |
| 3.3 No Retrofit imports in domain | 🤖 §3b | ✅ / ❌ / ⏭ | |
| 3.4 No Room imports in domain | 🤖 §3c | ✅ / ❌ / ⏭ | |
| 3.5 No data-layer imports in domain | 🤖 §3d | ✅ / ❌ / ⏭ | |

### Section 4 — Data Layer

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 4.1 DTOs not exposed outside data layer | 🤖 §4a | ✅ / ❌ / ⏭ | |
| 4.2 No `UiState` logic in data layer | 🤖 §4b | ✅ / ❌ / ⏭ | |
| 4.3 No navigation decisions in data layer | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 5 — State Management

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 5.1 Single consolidated `UiState` per screen | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 5.3 No scattered boolean flags | 🤖 §5a + 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 5.4 One-off events via `Channel` / `SharedFlow` | 🤖 §5b + 🧠 Evaluator | ✅ / ❌ / ⏭ | |

### Section 6 — Mapping Rules

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 6.1 DTO → Domain mapping in data layer only | 🤖 §6b + 🧠 Evaluator | ✅ / ❌ / ⏭ | |
| 6.2 Domain → UI mapping in presentation only | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 6.3 No DTO → UI direct shortcut | 🤖 §6a | ✅ / ❌ / ⏭ | |
| 6.4 No API response objects passed to Compose | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Section 7 — Dependency Injection

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 7.1 Hilt used for all DI | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 7.2 RepositoryImpl annotated `@Singleton` | 🤖 §7b | ✅ / ❌ / ⏭ | |
| 7.3 ViewModel-scoped deps use `@ViewModelScoped` | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |
| 7.4 No `Context` injected into domain/data | 🤖 §7a | ✅ / ❌ / ⏭ | |

### Section 8 — Forbidden Patterns

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 8.1 No fully-qualified class names inline | 🤖 §8a | ✅ / ❌ | |
| 8.2 ViewModel does not call Retrofit directly | 🤖 §8b + 🧠 Evaluator | ✅ / ❌ / ⏭ | |
| 8.3 No business rules inside Composable / Fragment | 🤖 §8c + 🧠 Evaluator | ✅ / ❌ / ⏭ | |
| 8.4 Every new ViewModel has a test file | 🤖 §8d | ✅ / ❌ | |
| 8.5 AI-generated code reviewed before merge | 👁️ Human | 👁️ Human | |

### Section 9 — Package Structure

| Rule | How Checked | Status | Violations |
|------|-------------|--------|------------|
| 9.1 ViewModel files in `viewmodel/` folder | 🤖 §9a | ✅ / ❌ / ⏭ | |
| 9.2 UseCase files in `usecase/` folder | 🤖 §9b | ✅ / ❌ / ⏭ | |
| 9.3 RepositoryImpl in `data/repository/` | 🤖 §9c | ✅ / ❌ / ⏭ | |
| 9.4 DTO→Domain mappers not in `domain/` | 🤖 §9d | ✅ / ❌ / ⏭ | |
| 9.5 Domain→UI mappers in `ui/` layer | 🧠 Evaluator | ✅ / ❌ / 👁️ Human | |

### Architecture Rule Violations Detail

> List each violation found above. Delete this section if there are none.

- **Rule X.Y** — `<file>:<line>`: `<description>`

---

## Layer Violations

- [ ] None found
- Violations found:
  - `<file>`: `<description of violation>`

---

## Unrelated Changes

- [ ] None found
- Found:
  - `<file>`: `<description>`

---

## UI Verification

- [ ] Skipped (no UI changes)
- [ ] Texts verified against design via `adb uiautomator dump`
- [ ] Screenshot captured and compared
- [ ] Design-critical reference anchors have bounds-based runtime proof tied to visual `testTag`s
- [ ] Differences remaining: `<list or "none">`

---

## Security

- [ ] No secrets or tokens hardcoded
- [ ] No user-generated text, transcript, image content, identifier, or other sensitive content logged
- [ ] Sensitive data not stored unencrypted
- Concerns: `<list or "none">`

---

## Release Risk

**Level**: low / medium / high  
**Reason**: `<explanation>`

- Backward compatible: yes / no
- Feature flag required: yes / no
- Force update required: yes / no
- Backend deployment dependency: yes / no

---

## Remaining Risks

1. `<risk>`
2. `<risk>`

---

## Recommendation

- ✅ Ready to merge
- ⚠️ Merge with noted risks
- ❌ Do not merge — `<blocking issue>`
