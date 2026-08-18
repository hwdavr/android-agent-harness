# Architecture Rules — Enforcement Matrix

Rules from [`android-architecture.md`](../../.agents/rules/android-architecture.md), categorised by how each is enforced.

**Legend**

| Badge | Meaning |
|---|---|
| 🤖 **Scripted** | [`check-architecture-rules.sh`](../scripts/check-architecture-rules.sh) or Windows [`check-architecture-rules.cmd`](../scripts/check-architecture-rules.cmd) detects this automatically on every CI run |
| 🧠 **Evaluator** | AI code review can reliably identify this — pattern recognition, semantic understanding |
| 👁️ **Human** | Requires design judgement, visual inspection, or context that neither script nor AI can fully substitute |

A rule can carry more than one badge when layered enforcement is needed.

---

## Section 1 — UI Layer

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 1.1 | UI must not call repositories directly | 🤖 Scripted + 🧠 Evaluator | §1a: import `data.(remote\|local\|repository)` in UI files | Script catches imports; AI catches indirect calls through locally constructed objects |
| 1.2 | UI must not contain business rules | 🧠 Evaluator | — | Too semantic for regex; AI checks for domain-logic branches inside Composable bodies |
| 1.3 | UI must not parse API responses | 🧠 Evaluator | — | AI checks that no DTO fields are accessed directly inside Composables |
| 1.4 | UI must not perform DTO → domain mapping | 🤖 Scripted + 🧠 Evaluator | §1b: DTO/Entity/Request/Response imports in UI files | Script catches import; AI verifies mapping logic is absent |
| 1.5 | UI must not access remote or local data sources directly | 🤖 Scripted | §1c: `ApiService.*` in UI files; §1d: DAO calls in UI files | |
| 1.6 | UI must not import data-layer classes | 🤖 Scripted | §1a: data-layer package imports in UI files | |

---

## Section 2 — Presentation Layer (ViewModel)

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 2.1 | Expose screen state as a single `UiState` via `StateFlow` | 🧠 Evaluator | — | AI verifies each ViewModel has one primary `StateFlow<*UiState>` property |
| 2.2 | Coordinate use cases — not repositories | 🧠 Evaluator | — | AI confirms ViewModel injects use cases or repository interfaces, not implementations |
| 2.3 | Transform domain models into UI models in Presentation — not in UI | 🧠 Evaluator | — | AI verifies mappers are invoked in ViewModel/mapper layer, not in Composables |
| 2.4 | Manage loading / success / error state transitions | 🧠 Evaluator | — | AI verifies all three states are represented in UiState and handled |
| 2.5 | One-off events (toast, navigation) use `Channel` / `SharedFlow` — not permanent state | 🤖 Scripted + 🧠 Evaluator | §5b: permanent state field names (`showDialog`, `navigateTo`, etc.) | Script flags named patterns; AI catches semantically equivalent fields with different names |
| 2.6 | Must not call Retrofit/service/database directly | 🤖 Scripted | §2a–c: Retrofit import, `ApiService.*` calls, Room/DAO imports in ViewModel files | |
| 2.7 | Must not contain persistent storage logic | 🧠 Evaluator | — | AI checks that Room or file I/O calls are absent from ViewModel bodies |
| 2.8 | Must not contain heavy business logic (belongs in Domain) | 🧠 Evaluator | — | AI reviews complex calculation/decision logic that should be a UseCase |
| 2.9 | Must not import data-layer implementation classes | 🤖 Scripted | §2d: `data.(remote\|local)` imports in ViewModel files | |

---

## Section 3 — Domain Layer

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 3.1 | Must not depend on Android framework classes (`Context`, `Bundle`, SDK) | 🤖 Scripted | §3a: `android.*` / `androidx.*` imports in domain files; §7a: `Context` in domain constructors | |
| 3.2 | Must not depend on UI classes | 🤖 Scripted | §3e: `<package>.ui.*` imports in domain files | |
| 3.3 | Must not depend on Retrofit implementation details | 🤖 Scripted | §3b: `retrofit2.*` imports in domain files | |
| 3.4 | Must not depend on Room implementation details | 🤖 Scripted | §3c: `androidx.room.*` imports in domain files | |
| 3.5 | Must not import data-layer classes | 🤖 Scripted | §3d: `<package>.data.*` imports in domain files | |
| 3.6 | Must remain platform-independent | 🤖 Scripted + 🧠 Evaluator | §3a–e combined | Script catches direct imports; AI catches indirect platform coupling via method signatures |

---

## Section 4 — Data Layer

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 4.1 | Must not expose DTOs to presentation or UI layers | 🤖 Scripted | §4a: non-data-layer files importing DTO/Entity from `data.remote\|local` | DI module (`di/`) is explicitly excluded |
| 4.2 | Must not contain UI state logic | 🤖 Scripted | §4b: `UiState` reference in data-layer files | |
| 4.3 | Must not make navigation decisions | 🧠 Evaluator | — | AI checks for NavController or route strings in data classes/repositories |

---

## Section 5 — State Management

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 5.1 | Each screen renders from a single primary `UiState` data class | 🧠 Evaluator | — | AI verifies ViewModel has one consolidated UiState, not multiple independent streams |
| 5.2 | Prefer a single immutable `data class` with nullable fields over `sealed class` unless modes are truly distinct | 🧠 Evaluator | — | Design-level decision; AI reviews whether a sealed class is justified |
| 5.3 | Never use scattered boolean flags across a screen | 🤖 Scripted + 🧠 Evaluator | §5a: ≥3 `StateFlow<Boolean>` in one ViewModel | Script applies a count heuristic (≥3); AI catches 2 or fewer flags that should be unified |
| 5.4 | One-off events use `Channel` / `SharedFlow` — not permanent state fields | 🤖 Scripted + 🧠 Evaluator | §5b: property names matching `showDialog`, `showToast`, `navigateTo`, etc. | Script matches known bad names; AI catches semantically equivalent patterns |

---

## Section 6 — Mapping Rules

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 6.1 | DTO → Domain mapping happens only in the Data layer | 🤖 Scripted + 🧠 Evaluator | §6b: domain files importing DTO types | Script catches imports; AI verifies mapping logic location |
| 6.2 | Domain → UI model mapping happens only in the Presentation layer | 🧠 Evaluator | — | AI confirms mappers are invoked in ViewModel/mapper, not inside Composables or data classes |
| 6.3 | No DTO → UI direct shortcut | 🤖 Scripted | §6a: UI files importing DTO/ApiModel/Entity types | |
| 6.4 | No API response objects passed directly to Compose | 🧠 Evaluator | — | AI verifies Composable parameters are domain or UI model types only |

---

## Section 7 — Dependency Injection

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 7.1 | Use Hilt for all DI — no manual dependency construction | 🧠 Evaluator | — | AI checks for `= MyRepository()` or `= Retrofit.Builder()` in production classes |
| 7.2 | Repository implementations are `@Singleton` scoped | 🤖 Scripted | §7b: RepositoryImpl files missing `@Singleton` annotation | |
| 7.3 | ViewModel-scoped dependencies use `@ViewModelScoped` | 🧠 Evaluator | — | AI verifies Hilt modules use `@ViewModelScoped` for ViewModel-bound bindings |
| 7.4 | `Context` must not be passed into domain or data layer (unless unavoidable) | 🤖 Scripted | §7a: `Context` as domain constructor parameter | |

---

## Section 8 — Forbidden Patterns

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 8.1 | No fully-qualified class names used inline in any file | 🤖 Scripted | §8a: fully-qualified identifiers in function/property bodies | |
| 8.2 | ViewModel must not call Retrofit directly | 🤖 Scripted + 🧠 Evaluator | §8b: `enqueue` / `execute` / `await` in ViewModel class bodies | Script uses multiline regex; AI reviews for equivalent patterns |
| 8.3 | No business rules inside Composable or Fragment | 🤖 Scripted + 🧠 Evaluator | §8c: `when/if` on domain model fields inside `@Composable` | Script is heuristic; AI reviews for subtle logic placement |
| 8.4 | Every new ViewModel must have a corresponding test file | 🤖 Scripted | §8d: ViewModel files without `*Test.kt` or `*IntegrationTest.kt` | |
| 8.5 | AI-generated code must not be merged without review | 👁️ Human | — | Process control — enforced by the review workflow gate, not a script |

---

## Section 9 — Package Structure

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 9.1 | ViewModel files reside inside a `viewmodel/` folder | 🤖 Scripted | §9a: ViewModel class files outside `viewmodel/` path | |
| 9.2 | UseCase files reside inside a `usecase/` folder | 🤖 Scripted | §9b: UseCase class files outside `usecase/` path | |
| 9.3 | RepositoryImpl files reside in `data/repository/` | 🤖 Scripted | §9c: RepositoryImpl outside `data/repository/` path | |
| 9.4 | DTO→Domain mapper files reside in the `data/` layer, not in `domain/` | 🤖 Scripted | §9d: `*Mapper.kt` files found inside `domain/` | |
| 9.5 | Domain→UI mapper files reside in the `ui/` layer | 🧠 Evaluator | — | Script only checks misplacement in `domain/`; AI verifies `ui/**/mapper/` placement |

---

## Enforcement Summary

| Category | Count | Rules |
|---|---|---|
| 🤖 Scripted only | 12 | 1.5, 1.6, 2.6, 2.9, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 8.1, 8.4, 9.1, 9.2, 9.3, 9.4 |
| 🧠 Evaluator only | 13 | 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.7, 2.8, 3.6\*, 4.3, 6.2, 6.4, 7.1, 7.3, 9.5 |
| 👁️ Human only | 1 | 8.5 |
| 🤖 + 🧠 Scripted + Evaluator | 9 | 1.1, 1.4, 2.5, 3.6, 5.3, 5.4, 6.1, 8.2, 8.3, 7.2\* |
| **Total rules** | **35** | |

> [!NOTE]
> Only rule **8.5** (AI-generated code reviewed before merge) is Human-only — it is a process gate enforced by the review workflow, not detectable by any automated tool.

---

## Script Coverage Map

The [`check-architecture-rules.sh`](../scripts/check-architecture-rules.sh) script and Windows [`check-architecture-rules.cmd`](../scripts/check-architecture-rules.cmd) launcher currently cover:

| Script Section | Rules Covered |
|---|---|
| **§1a** — UI files importing `data.(remote\|local\|repository)` | 1.1 · 1.6 |
| **§1b** — UI files importing DTO/Entity/Request/Response types | 1.4 |
| **§1c** — UI files referencing `ApiService.*` | 1.5 |
| **§1d** — UI files referencing DAO calls | 1.5 |
| **§1e** — `@Composable` calling Repository/UseCase directly (multiline) | 1.1 |
| **§2a** — ViewModel importing `retrofit2.*` | 2.6 |
| **§2b** — ViewModel importing Room/DAO | 2.6 |
| **§2c** — ViewModel calling `ApiService.*` directly | 2.6 |
| **§2d** — ViewModel importing `data.(remote\|local)` packages | 2.9 |
| **§3a** — Domain files importing `android.*` / `androidx.*` | 3.1 · 3.6 |
| **§3b** — Domain files importing `retrofit2.*` | 3.3 · 3.6 |
| **§3c** — Domain files importing `androidx.room.*` | 3.4 · 3.6 |
| **§3d** — Domain files importing `<package>.data.*` | 3.5 · 3.6 |
| **§3e** — Domain files importing `<package>.ui.*` | 3.2 · 3.6 |
| **§4a** — Non-data-layer files importing DTO/Entity | 4.1 |
| **§4b** — Data-layer files referencing `UiState` | 4.2 |
| **§5a** — ViewModel with ≥3 `StateFlow<Boolean>` fields | 5.3 |
| **§5b** — Permanent state fields named `showDialog`, `navigateTo`, etc. | 2.5 · 5.4 |
| **§6a** — UI files importing DTO/ApiModel/Entity types | 6.3 |
| **§6b** — Domain files importing DTO types | 6.1 |
| **§7a** — Domain constructors receiving `Context` | 3.1 · 7.4 |
| **§7b** — RepositoryImpl missing `@Singleton` | 7.2 |
| **§8a** — Fully-qualified class names used inline | 8.1 |
| **§8b** — `enqueue` / `execute` / `await` in ViewModel class bodies | 8.2 |
| **§8c** — `when/if` on domain model fields inside `@Composable` | 8.3 |
| **§8d** — ViewModel files without matching test file | 8.4 |
| **§9a** — ViewModel class files outside `viewmodel/` path | 9.1 |
| **§9b** — UseCase class files outside `usecase/` path | 9.2 |
| **§9c** — RepositoryImpl outside `data/repository/` | 9.3 |
| **§9d** — `*Mapper.kt` files inside `domain/` | 9.4 |
