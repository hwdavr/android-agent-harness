---
name: android-ui-layer
description: Implement Compose UI with unidirectional state flow — as the UI step of a planned change, or as the direct lane for an appearance-only tweak that an existing approved design or the design system already defines.
---

# Skill — Android UI Layer

## Purpose
Implement UI layer changes: ViewModels, UiState, UI models, UI mappers, Composable screens, and navigation wiring.

Used in two ways:

- **Within a workflow** (`single-lane-generator` Stage 4, `bug-fixing`, `sliced-lane-generator`): implement the
  approved plan's UI State Stages.
- **Direct lane** for a small appearance-only adjustment to an existing screen (spacing, color,
  icon, copy wording, reordering existing elements, aligning with the design system). No spec block,
  plan, or tracker row.

## Direct lane — entry check

Use the direct lane only when **every** item holds; otherwise stop and route to `harness-planning`
(or `bug-fixing` for a defect):

- [ ] No new or changed UI state, interaction, gesture, navigation, data, persistence, or API.
- [ ] No new screen or component; only existing registered components are used.
- [ ] The target appearance is already defined by an approved design (existing `UI_contract.md`
      state or Pen frame) or by `docs/product/design_system.md` tokens and components.
- [ ] Copy changes keep `stringResource()` and pass the localization rules.

State the check result to the user before editing. A direct-lane change still needs the user's
go-ahead on the described edit.

## Direct lane — verification

After the edit, run the `ui-verification` skill for the affected states: review capture at the
reference's Viewport, structural check, and side-by-side approval against the existing approved
design (or the design-system definition). Record the result in a short workspace
`.scratch/<YYYY-MM-DD>-<tweak-id>/ui_verification.json` with a one-paragraph `summary.md`; no tracker
row is needed. Then run the Done When checks below and `code-quality-fix`.

---

## Load
- `docs/product/design_system.md` — mandatory project-wide visual tokens and component contracts
- `rules/android-architecture.md` (skip if already loaded this session — L1 is session-scoped)
- `rules/compose-rules.md`
- `rules/navigation-rules.md`
- `rules/analytics-rules.md`
- `rules/localization-rules.md`
- `rules/implementation-rules.md`
- `rules/android-security.md` when the change handles deep links, URI grants,
  permissions, WebView, exported entry points, AI/model output, or sensitive UI data
- Within a workflow: `$FEATURE_DIR/implementation-plan.md` (UiState design, UI State Stages and their
  reused registered components) and `$FEATURE_DIR/UI_contract.md`.
- Direct lane: the existing approved design or design-system definition named in the entry check.

---

## Execute

### 1. ViewModel
1. Implement or update the ViewModel using the ViewModel pattern in `rules/android-architecture.md`
2. Expose screen state as `StateFlow<UiState>` — one state object per screen
3. Handle all states: loading, success, empty, error, retry, permission
4. Emit one-off events (navigation, toast, dialog) via a separate `Channel<Event>`
5. Call use cases only — never call repositories or data sources directly
6. Do not import Retrofit, Room, or data-layer classes

### 2. UI model and mapper
1. Create or update UI model data classes if the domain model needs formatting for display
2. Create or update the Domain → UI mapper in the Presentation layer
3. Do not pass domain models directly to Composables when UI formatting is needed

### 3. Composable screen
1. Split every screen into stateless content + stateful wrapper (see `rules/compose-rules.md`)
2. The stateless `Content` Composable receives `UiState` and callbacks — it does not call the ViewModel
3. Keep Composables small — extract reusable UI to `components/`
4. Use `stringResource()` for all user-visible text — **no hardcoded strings**
5. Add `Modifier.testTag("stable_name")` to all interactive elements and key content areas
6. Reuse semantic tokens from `LocalAppColors` and the registered components in the design-system Component Registry; never call a Material primitive that has a registered wrapper (the compose "Registered design-system components" rule enforces this), add raw colors, or create a parallel component style without an approved design exception

### 4. Navigation wiring
1. Update the navigation graph if new routes are added or arguments changed
2. Pass only serializable types as navigation arguments
3. Confirm back-stack behavior matches the design

### 5. Analytics
Fire analytics events from the ViewModel — not from Composables.
Follow `rules/analytics-rules.md` for daily log and payload rules.

### 6. String resources
Add all new user-visible text to `res/values/strings.xml` with descriptive keys following `rules/localization-rules.xml`.

---

## Output

Updated / created:
- ViewModel file
- UiState and UI model files
- UI mapper file
- Composable screen and component files
- Navigation graph (if changed)
- `strings.xml` (for all new copy)

Record the UI layer changes in the active summary (`$FEATURE_DIR/summary.md`, or the slice
summary): files changed, UiState branches covered, testTags added, and registered components reused.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**
- [ ] ViewModel does not import `retrofit2.*`, `androidx.room.*`, or any data-layer class
- [ ] Composable screens do not contain business logic
- [ ] All user-visible text uses `stringResource()` — no hardcoded strings (`grep -r '"[A-Z]' ui/`)
- [ ] All interactive elements have `Modifier.testTag(...)` with a stable name
- [ ] UI uses `docs/product/design_system.md` semantic tokens and registered components, and documents every approved exception
- [ ] `bash harness/scripts/check-compose-rules.sh` exits 0
- [ ] UiState covers loading, success, empty, and error states
- [ ] Navigation arguments are serializable types
- [ ] No dummy code in UI-layer files — no `TODO()`, `NotImplementedError`, stub return values, no-op handlers (`{}` or log-only), or `// dummy implementation` comments in `ui/` sources; every ViewModel method, UiState branch, and Composable callback implements the actual requirement behavior. `@Preview` composables may use sample `UiState` values for tooling (see the rule's "Allowed exceptions"); production composables and `UiState` data classes are still in scope (see `rules/implementation-rules.md`)
- [ ] Build passes: `./gradlew assembleDebug`

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.
