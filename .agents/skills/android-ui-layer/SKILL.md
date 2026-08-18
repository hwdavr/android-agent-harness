---
name: android-ui-layer
description: Implements UI screens and components in Compose with unidirectional state flow.
---

# Skill — Android UI Layer

## Purpose
Implement UI layer changes: ViewModels, UiState, UI models, UI mappers, Composable screens, and navigation wiring.

---

## Load
- `docs/product/design_system.md` — mandatory project-wide visual tokens and component contracts
- `skills/ui-verification/SKILL.md`
- `rules/compose-rules.md`
- `rules/navigation-rules.md`
- `rules/analytics-rules.md`
- `rules/localization-rules.md`
- `rules/implementation-rules.md`
- `docs/current/implementation_plan_v<N>.md` (Implementation Plan stage output)
- `docs/current/spec_v<N>.md` — UiState design from the Requirement, Impact & Design Analysis stage

---

## Execute

### 1. ViewModel
1. Implement or update the ViewModel using the ViewModel pattern in `skills/android-feature/SKILL.md`
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
6. Reuse semantic tokens from `LocalAppColors` and established shared components according to `docs/product/design_system.md`; do not add raw colors or a parallel component style without an explicit approved design exception

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

Update `docs/current/coding_report_v<N>.md` with a UI Layer section:
```
## UI Layer Changes

### Files Changed
| File | Action | Notes |
|------|--------|-------|

### UiState Implemented
<confirm all states are covered: loading / success / empty / error>

### testTags Added
<list key testTag values added>
```

Update `summary_v<N>.md`: mark the UI Layer stage complete.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**
- [ ] ViewModel does not import `retrofit2.*`, `androidx.room.*`, or any data-layer class
- [ ] Composable screens do not contain business logic
- [ ] All user-visible text uses `stringResource()` — no hardcoded strings (`grep -r '"[A-Z]' ui/`)
- [ ] All interactive elements have `Modifier.testTag(...)` with a stable name
- [ ] UI uses `docs/product/design_system.md` semantic tokens/components and documents every approved exception
- [ ] UiState covers loading, success, empty, and error states
- [ ] Navigation arguments are serializable types
- [ ] No dummy code in UI-layer files — no `TODO()`, `NotImplementedError`, stub return values, no-op handlers (`{}` or log-only), or `// dummy implementation` comments in `ui/` sources; every ViewModel method, UiState branch, and Composable callback implements the actual requirement behavior. `@Preview` composables may use sample `UiState` values for tooling (see the rule's "Allowed exceptions"); production composables and `UiState` data classes are still in scope (see `rules/implementation-rules.md`)
- [ ] Build passes: `./gradlew assembleDebug`

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.
