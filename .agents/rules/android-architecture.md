# Android Architecture Rules

## Purpose
These rules define the mandatory layer boundaries and patterns for this project.
All contributors (human and AI) must follow these rules. Any change that violates these rules must be rejected unless this file is updated with explicit justification in the same change.

---

## Layer Model

```
UI → Presentation → Domain ← Data
```

Dependencies flow inward only. No upward or cross-layer dependencies.

---

## Layer Responsibilities

### UI Layer
Files: Compose screens, components  
Responsibilities:
- Render from `UiState`
- Send user actions/events to ViewModel
- Handle UI-only concerns (focus, local animation, navigation callbacks)

Must NOT:
- Call repositories directly
- Contain business rules
- Parse API responses
- Perform DTO → domain mapping
- Access remote or local data sources directly
- Import data layer classes

---

### Presentation Layer
Files: ViewModels, UI mappers, UI event/state reducers  
Responsibilities:
- Expose screen state as a single `UiState` via `StateFlow`
- Coordinate use cases
- Transform domain models into UI models
- Manage loading / success / error state transitions
- Emit one-off events (navigation, toast, dialog) via `Channel` or `SharedFlow`

Must NOT:
- Call Retrofit/service/database directly
- Contain persistent storage logic
- Contain heavy business logic that belongs to domain
- Import Retrofit, Room, or data-layer implementation classes

---

### Domain Layer
Files: Use cases, domain models, repository interfaces, business rules  
Responsibilities:
- Define business behavior
- Define repository contracts (interfaces only)
- Contain business validation and decision logic
- Remain platform-independent

Must NOT:
- Depend on Android framework classes (`Context`, `Bundle`, SDK types)
- Depend on UI classes
- Depend on Retrofit or Room implementation details

Scoped exception — domain boundaries:
- Features with complex processing (e.g. AI summarizer, rich text parser) may define domain contracts, keeping framework dependencies encapsulated in data layer implementations.
- The feature must document the boundary and keep all heavy processing off the main thread.

---

### Data Layer
Files: Repository implementations, remote data sources, local data sources, DTOs, mappers  
Responsibilities:
- Fetch and store data
- Map external data models (DTOs) to domain models
- Implement repository interfaces from domain

Must NOT:
- Expose DTOs to presentation or UI layers
- Contain UI state logic
- Make navigation decisions

---

## Dependency Rules

Allowed:
- UI → Presentation
- Presentation → Domain
- Data → Domain (implements interfaces)
- `app` module wires dependencies together via Hilt

Not allowed:
- UI → Data (direct)
- Domain → UI
- Domain → Android SDK / framework
- Presentation → data source implementations (only domain interfaces)
- UI imports DTOs from data layer

---

## Dependency Injection

- Use **Hilt** for all dependency injection
- Correct scoping is mandatory:
  - `@Singleton` — app-scoped singletons (repositories, network clients)
  - `@ViewModelScoped` — scoped to a single ViewModel instance
- Do not pass `Context` into domain or data layer unless unavoidable

---

## State Management

- Each screen renders from a single primary `UiState` data class
- Prefer a single immutable `data class` with nullable content fields
- Use `sealed class` only when screen modes are truly distinct
- Never use scattered boolean flags across a screen
- One-off events (toast, navigation) must use a separate `Channel` or `SharedFlow` — not permanent state fields

---

## Mapping Rules

Allowed:
- DTO → Domain in Data layer
- Domain → UI model in Presentation layer

Not allowed:
- DTO → UI directly in UI layer
- Domain → DTO in UI layer
- API response objects passed to Compose directly

---

## Forbidden Patterns

These are never allowed without explicit architectural justification:

- Composable calling repository directly
- ViewModel calling Retrofit API directly
- DTO used outside data layer
- Business rules inside Composable or Fragment
- Domain layer importing Android framework classes
- Adding feature logic without tests
- AI-generated code merged without review
- Fully-qualified class names used inline in **any** file — production **or** test code (e.g. `com.example.Foo()` in function bodies, `io.mockk.mockk` in property declarations) — always use `import` at the top of the file
- Wildcard imports (e.g., `import com.example.*`) and unsorted imports — always keep imports clean and sorted alphabetically according to standard Android Studio / Ktlint guidelines

---

## Architecture Verification

Automated structural checks are the evidence for mechanically detectable rules:

```bash
bash harness/scripts/check-architecture-rules.sh
./gradlew ktlintCheck
./gradlew detekt
```

The repository-wide `bash harness/scripts/check-full-source-rules.sh` remains the
required CI evidence; run an individual checker only to diagnose a failure. Do not
repeat automated checker findings as manual review work.

When the diff introduces or changes an architectural boundary, review only the
semantic risks it triggers:

- **Business-logic ownership** — decisions and validation belong in Domain or a
  ViewModel, never in a Composable or persistence/network adapter.
- **Layer boundaries** — dependencies flow inward and DTOs remain in Data.
- **State and event design** — state has a clear owner, transitions are complete,
  and one-off events are not retained as persistent UI state.
- **Mappings** — DTO → Domain stays in Data and Domain → UI stays in ViewModel
  or its dedicated mapper.
- **DI scope** — dependencies have an appropriate app or screen lifetime and do
  not leak `RoomDatabase`, `Retrofit`, or implementation types across layers.

The code-review report records only the applicable items above. Human approval and
any user-approved exception are governed by the review and merge workflow in
[`review-checklist.md`](../gates/review-checklist.md), not by duplicated per-rule documentation.

---

## Package Structure

Mandatory feature folder layout:

```
ui/<feature>/
  screen/          # Compose screens
  components/      # Feature-specific Compose components
  viewmodel/       # ViewModel + UiState

  model/           # UI model data classes
  mapper/          # Domain → UI mapper

domain/<feature>/
  usecase/         # Use case classes
  model/           # Domain model data classes
  repository/      # Repository interfaces

data/<feature>/
  remote/          # Retrofit services, DTOs
  local/           # Room entities, DAOs
  repository/      # Repository implementations
  mapper/          # DTO → Domain mappers
```

### Kover Coverage Boundary

The `screen/` and `components/` subpackages are **excluded from code coverage** because Composables cannot be meaningfully measured by Kover.
The `viewmodel/` subpackage is **included in coverage** and must meet the 90% line coverage target.

Rule: **Never place a `@Composable` function inside `viewmodel/`**, and **never place a `ViewModel` class inside `screen/` or `components/`**.
This boundary is what makes the Kover `packages()` wildcard exclusion reliable.

Kover excludes in `build.gradle.kts` must use `packages()` wildcard patterns — not per-class strings — to stay maintainable:
```kotlin
excludes {
    packages(
        "*.screen",
        "*.components",
        // or "<package>.**.screen", "<package>.**.components"
        // other structural exclusions...
    )
}
```
