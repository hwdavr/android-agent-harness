---
name: android-implementation
description: Implements a user story or feature across data, domain, and UI layers sequentially.
---

# Skill — Android Implementation (Data + Domain + UI)

## Purpose
Implement the full change across all three layers — Data, Domain, and UI — in a single pass.
Work in small, vertically-sliced increments: implement one layer, verify the build, then proceed to the next.

> This is the **compact implementation stage** used by `feature-delivery` and `bug-fixing` workflows.
> For granular layer-by-layer control, use the individual stages `android-data-layer/SKILL.md`, `android-domain-layer/SKILL.md`, and `android-ui-layer/SKILL.md`.

---

## Load

**Always load:**
- `docs/product/design_system.md` — mandatory visual tokens and reusable component contracts for UI-affecting work
- `skills/ui-verification/SKILL.md`
- `rules/android-architecture.md`
- `rules/api-contract-rules.md`
- `rules/compose-rules.md`
- `rules/navigation-rules.md`
- `rules/analytics-rules.md`
- `rules/localization-rules.md`
- `rules/observability.md`
- `rules/implementation-rules.md`

**Adhoc workflows** (`feature-delivery`, `bug-fixing`):
- `docs/current/implementation_plan_v<N>.md` — implementation plan approved by user
- `docs/current/spec_v<N>.md` — requirement summary, impact analysis, UiState & navigation design
- `docs/current/design.md` — screen purpose, layout, visual/interaction states, copy, components inventory (if UI changes involved)
- `docs/current/design/` — user-provided screenshots or AI-generated `mockup_*.png` images (view these for visual layout reference before implementing UI)

**Harness workflow** (`harness-generator`):
- `$FEATURE_DIR/design.md` — screen purpose, layout, visual/interaction states, copy, components inventory, accessibility
- `$FEATURE_DIR/design/` — user-provided screenshots or AI-generated `mockup_*.png` images (view these images to understand the intended visual layout before implementing UI)
- `$FEATURE_DIR/spec.md` — screen specifications, functional requirements, edge cases, persistence schema
- `$FEATURE_DIR/sprint-contract.md` — acceptance criteria, scope boundaries, verification plan
- `$FEATURE_DIR/summary_{feature_id}.md` — single source of truth for the active feature (key decisions, files changed, stage progress)

---

## Execute

### Layer 1 — Data Layer

#### 1.1 API / DTO changes
If the API contract changed:
1. Update `sharedContracts/openapi.yaml` to reflect the new contract — **do this first**
2. Create or modify DTO data classes in `data/remote/dto/`
3. Use correct nullability: `String?` for optional fields, `String` for required fields
4. Handle unknown enum values with a fallback variant:
   ```kotlin
   enum class NoteStatus {
       ACTIVE, ARCHIVED, UNKNOWN;
       companion object {
           fun fromString(value: String) = entries.firstOrNull { it.name == value } ?: UNKNOWN
       }
   }
   ```

#### 1.2 Room / local data changes
If local storage is affected:
1. Create or modify Room entity in `data/local/`
2. Update DAO with new query methods
3. **Increment `AppDatabase` version**
4. Add a migration — only use `fallbackToDestructiveMigration` if data loss is explicitly acceptable and stated in the plan

#### 1.3 Repository implementation & Mapper
1. Implement or update the repository method
2. Map DTO → Domain model inside the repository — **never pass DTOs to upper layers**
3. Translate API errors to domain errors before they leave this layer
4. Map every field explicitly — no reflection, no structural mapping
5. Handle null defensively: `dto.field ?: defaultValue`

---

### Layer 2 — Domain Layer

#### 2.1 Domain model changes
1. Add or remove fields in domain model data classes
2. Import **no Android framework classes** (`Context`, `Bundle`, SDK types)
3. If an enum is added, include an `UNKNOWN` / fallback variant

#### 2.2 Repository interface changes
1. Add or update method signatures in the repository interface (defined in domain layer)
2. Keep interfaces stable and framework-independent
3. Use `suspend` functions or `Flow` based on existing conventions in the codebase
4. Confirm the interface change matches the Data Layer implementation above

#### 2.3 Use case changes
1. Create or update use cases — one use case does one thing
2. Use cases may coordinate multiple repository methods but must not call data sources directly
3. Implement business validation, filtering, and decision logic here — not in the ViewModel

**Business logic that belongs in use cases (not ViewModel or Composable):**
- Access permission checks
- Filter / sort logic driven by business rules
- Validation before mutations
- Data combination from multiple repositories

---

### Layer 3 — UI Layer

#### 3.1 ViewModel
1. Expose screen state as `StateFlow<UiState>` — one state object per screen
2. Handle all states: loading, success, empty, error, retry, permission
3. Emit one-off events (navigation, toast, dialog) via a separate `Channel<Event>`
4. Call use cases only — **never call repositories or data sources directly**
5. Do not import `retrofit2.*`, `androidx.room.*`, or any data-layer class
6. Add structured logs at state transitions and error boundaries — follow `rules/observability.md` for tag format and level selection (DEBUG for state snapshots, WARN for recoverable errors, ERROR for failures)

#### 3.2 UI model and mapper
1. Create or update UI model data classes if the domain model needs formatting for display
2. Create or update the Domain → UI mapper in the Presentation layer
3. Do not pass domain models directly to Composables when UI formatting is needed

#### 3.3 Composable screen
1. Split every screen into stateless `Content` + stateful `Screen` wrapper (see `rules/compose-rules.md`)
2. The stateless `Content` Composable receives `UiState` and callbacks — it does not call the ViewModel
3. **View the mockup images** in the active design directory (`$FEATURE_DIR/design/` or `docs/current/design/`) before writing UI code — use both `design.md` text and visual mockup images (user-provided or generated) as visual context for component layout, spacing, and visual hierarchy
4. Use `stringResource()` for all user-visible text — **no hardcoded strings**
5. Add `Modifier.testTag("stable_name")` to all interactive elements and key content areas
6. Map every visual choice to `docs/product/design_system.md` semantic tokens/shared components or to an explicit approved exception in the active `design.md`; do not introduce raw colors or a parallel component family

#### 3.4 Navigation, Analytics & String resources
1. Update the navigation graph if new routes are added — use serializable argument types only
2. Fire analytics events from the ViewModel — not from Composables
3. Add all new user-visible text to `res/values/strings.xml`

---

## Output

Update `summary_{feature_id}.md` (or `summary_v<N>.md` depending on the active workflow): mark the Implementation (Data + Domain + UI) stage complete.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**
- [ ] `sharedContracts/openapi.yaml` updated (if API changed)
- [ ] No DTOs referenced outside the data layer
- [ ] All new enum fields have an `UNKNOWN` / fallback variant
- [ ] Room schema version incremented and migration added (if schema changed)
- [ ] Repository methods return domain models, not DTOs
- [ ] No Android framework classes imported in domain layer (`grep -r "import android\." domain/`)
- [ ] Use cases are single-responsibility
- [ ] ViewModel does not import `retrofit2.*`, `androidx.room.*`, or any data-layer class
- [ ] Composable screens do not contain business logic
- [ ] All user-visible text uses `stringResource()` — no hardcoded strings
- [ ] All interactive elements have `Modifier.testTag(...)` with a stable name
- [ ] UI conforms to `docs/product/design_system.md` plus explicit approved feature exceptions
- [ ] UiState covers loading, success, empty, and error states
- [ ] Log statements use `<AppName>/<ClassName>` tag, correct level, and no PII (see `rules/observability.md`)
- [ ] No dummy code in production sources — `grep -rn "TODO()\|NotImplementedError\|// dummy\|// placeholder\|// stub" app/src/main/ sharedContracts/` returns 0 matches; no function, branch, or callback returns a hardcoded value or no-op where the spec requires a real computation or action (see `rules/implementation-rules.md`)
- [ ] Build passes: `./gradlew assembleDebug`

**APPROVED →** Return to the active workflow file. 
