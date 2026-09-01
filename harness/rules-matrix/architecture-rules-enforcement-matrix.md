# Architecture Rules — Enforcement Matrix

Rules from [`android-architecture.md`](../../.agents/rules/android-architecture.md), categorised by how each is enforced.

**Legend**

| Badge | Meaning |
|---|---|
| 🤖 **Scripted** | [`check-architecture-rules.sh`](../scripts/check-architecture-rules.sh), Detekt `ForbiddenImport` rules, or their Windows launcher detects this automatically on every CI run. The canonical owner is recorded in `rule-enforcement.json`. |
| 🧠 **Evaluator** | AI code review can reliably identify this — pattern recognition, semantic understanding |
| 👁️ **Human** | Requires design judgement, visual inspection, or context that neither script nor AI can fully substitute |

A rule can carry more than one badge when layered enforcement is needed.

---

## Section 1 — UI Layer

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 1.1 | UI must not call repositories directly | 🤖 Scripted + 🧠 Evaluator | AST visitor: repository/use-case/data-source call nodes inside UI `@Composable` bodies; Detekt handles forbidden imports | Script catches direct body calls; AI catches indirect calls through locally constructed objects |
| 1.2 | UI must not contain business rules | 🧠 Evaluator | — | Too semantic for regex; AI checks for domain-logic branches inside Composable bodies |
| 1.3 | UI must not parse API responses | 🧠 Evaluator | — | AI checks that no DTO fields are accessed directly inside Composables |
| 1.4 | UI must not perform DTO → domain mapping | 🤖 Scripted + 🧠 Evaluator | Detekt `ForbiddenImport` for DTO/Entity/Request/Response dependencies | Script catches imports; AI verifies mapping logic is absent |
| 1.5 | UI must not access remote or local data sources directly | 🤖 Scripted | AST visitor: DAO method call nodes in UI files and repository/use-case/data-source call nodes in UI composables; Detekt handles imports | |
| 1.6 | UI must not import data-layer classes | 🤖 Scripted | Detekt `ForbiddenImport` for data-layer packages | |

---

## Section 2 — Presentation Layer (ViewModel)

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 2.1 | Expose screen state as a single `UiState` via `StateFlow` | 🧠 Evaluator | — | AI verifies each ViewModel has one primary `StateFlow<*UiState>` property |
| 2.2 | Coordinate use cases — not repositories | 🧠 Evaluator | — | AI confirms ViewModel injects use cases or repository interfaces, not implementations |
| 2.3 | Transform domain models into UI models in Presentation — not in UI | 🧠 Evaluator | — | AI verifies mappers are invoked in ViewModel/mapper layer, not in Composables |
| 2.4 | Manage loading / success / error state transitions | 🧠 Evaluator | — | AI verifies all three states are represented in UiState and handled |
| 2.5 | One-off events (toast, navigation) use `Channel` / `SharedFlow` — not permanent state | 🤖 Scripted + 🧠 Evaluator | §5b: permanent state field names (`showDialog`, `navigateTo`, etc.) | Script flags named patterns; AI catches semantically equivalent fields with different names |
| 2.6 | Must not call Retrofit/service/database directly | 🤖 Scripted | AST visitor: API-service method call nodes in ViewModel files; Detekt handles Retrofit/Room imports | |
| 2.7 | Must not contain persistent storage logic | 🧠 Evaluator | — | AI checks that Room or file I/O calls are absent from ViewModel bodies |
| 2.8 | Must not contain heavy business logic (belongs in Domain) | 🧠 Evaluator | — | AI reviews complex calculation/decision logic that should be a UseCase |
| 2.9 | Must not import data-layer implementation classes | 🤖 Scripted | Detekt `ForbiddenImport` for data-layer implementation packages | |

---

## Section 3 — Domain Layer

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 3.1 | Must not depend on Android framework classes (`Context`, `Bundle`, SDK) | 🤖 Scripted | AST visitor: `android.*` / `androidx.*` imports and `Context` in domain constructor parameter nodes | |
| 3.2 | Must not depend on UI classes | 🤖 Scripted | Detekt `ForbiddenImport` for `<package>.ui.*` dependencies | |
| 3.3 | Must not depend on Retrofit implementation details | 🤖 Scripted | Detekt `ForbiddenImport` for `retrofit2.*` dependencies | |
| 3.4 | Must not depend on Room implementation details | 🤖 Scripted | Detekt `ForbiddenImport` for `androidx.room.*` dependencies | |
| 3.5 | Must not import data-layer classes | 🤖 Scripted | Detekt `ForbiddenImport` for `<package>.data.*` dependencies | |
| 3.6 | Must remain platform-independent | 🤖 Scripted + 🧠 Evaluator | Detekt import rules plus AST constructor checks | Script catches direct dependencies; AI catches indirect platform coupling via method signatures |

---

## Section 4 — Data Layer

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 4.1 | Must not expose DTOs to presentation or UI layers | 🤖 Scripted | Detekt `ForbiddenImport` for DTO/Entity dependencies outside data | DI module (`di/`) is explicitly excluded |
| 4.2 | Must not contain UI state logic | 🤖 Scripted | AST visitor: `UiState` identifier nodes in data-layer files | |
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
| 6.1 | DTO → Domain mapping happens only in the Data layer | 🤖 Scripted + 🧠 Evaluator | Detekt `ForbiddenImport` for DTO dependencies in domain files | Script catches imports; AI verifies mapping logic location |
| 6.2 | Domain → UI model mapping happens only in the Presentation layer | 🧠 Evaluator | — | AI confirms mappers are invoked in ViewModel/mapper, not inside Composables or data classes |
| 6.3 | No DTO → UI direct shortcut | 🤖 Scripted | Detekt `ForbiddenImport` for DTO/ApiModel/Entity dependencies in UI | |
| 6.4 | No API response objects passed directly to Compose | 🧠 Evaluator | — | AI verifies Composable parameters are domain or UI model types only |

---

## Section 7 — Dependency Injection

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 7.1 | Use Hilt for all DI — no manual dependency construction | 🧠 Evaluator | — | AI checks for `= MyRepository()` or `= Retrofit.Builder()` in production classes |
| 7.2 | Repository implementations are `@Singleton` scoped | 🤖 Scripted | §7b: RepositoryImpl files missing `@Singleton` annotation | |
| 7.3 | ViewModel-scoped dependencies use `@ViewModelScoped` | 🧠 Evaluator | — | AI verifies Hilt modules use `@ViewModelScoped` for ViewModel-bound bindings |
| 7.4 | `Context` must not be passed into domain or data layer (unless unavoidable) | 🤖 Scripted | AST visitor: `Context` in domain constructor parameter nodes | |

---

## Section 8 — Forbidden Patterns

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 8.1 | No fully-qualified class names used inline in any file | 🤖 Scripted | §8a: fully-qualified identifiers in function/property bodies | |
| 8.2 | ViewModel must not call Retrofit directly | 🤖 Scripted + 🧠 Evaluator | §8b: `enqueue` / `execute` / `await` call nodes in ViewModel class bodies | AST visitor catches calls; AI reviews equivalent patterns |
| 8.3 | No business rules inside Composable or Fragment | 🤖 Scripted + 🧠 Evaluator | §8c: `when/if` condition nodes on domain model fields inside `@Composable` | AST visitor is conservative; AI reviews subtle logic placement |
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
| 🤖 Scripted only | 20 | 1.5, 1.6, 2.6, 2.9, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 6.3, 7.2, 7.4, 8.1, 8.4, 9.1, 9.2, 9.3, 9.4 |
| 🧠 Evaluator only | 16 | 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.7, 2.8, 4.3, 5.1, 5.2, 6.2, 6.4, 7.1, 7.3, 9.5 |
| 👁️ Human only | 1 | 8.5 |
| 🤖 + 🧠 Scripted + Evaluator | 9 | 1.1, 1.4, 2.5, 3.6, 5.3, 5.4, 6.1, 8.2, 8.3 |
| **Total rules** | **46** | |

> [!NOTE]
> Only rule **8.5** (AI-generated code reviewed before merge) is Human-only — it is a process gate enforced by the review workflow, not detectable by any automated tool.

---

## Script Coverage Map

All Kotlin checks below are visitors over the shared structural AST
(`harness/scripts/kotlin_ast_checker.py`). The Unix and Windows entry points use
the same implementation, so comments and string/character literals are ignored
consistently across platforms.

The [`check-architecture-rules.sh`](../scripts/check-architecture-rules.sh) script and Windows [`check-architecture-rules.cmd`](../scripts/check-architecture-rules.cmd) launcher currently cover the following structural checks. Import boundaries remain owned by Detekt as recorded in `rule-enforcement.json`.

| AST visitor | Rules Covered |
|---|---|
| **§1** — DAO method call nodes in UI files | 1.5 |
| **§1** — Repository/use-case/data-source call nodes inside UI `@Composable` bodies | 1.1 · 1.5 |
| **§2** — API-service method call nodes in ViewModel files | 2.6 |
| **§4** — `UiState` identifier nodes in data-layer files | 4.2 |
| **§5** — ViewModel properties typed as `StateFlow<Boolean>` (three or more) | 5.3 |
| **§5** — Permanent one-off event property declarations | 2.5 · 5.4 |
| **§3** — Android framework import nodes in domain files | 3.1 |
| **§7** — `Context` in domain constructor parameter nodes | 3.1 · 7.4 |
| **§7** — `RepositoryImpl` class declarations without `@Singleton` | 7.2 |
| **§8** — Fully-qualified call/type expression nodes | 8.1 |
| **§8** — `enqueue` / `execute` / `await` call nodes in ViewModel classes | 8.2 |
| **§8** — `when` / `if` condition nodes on domain-model properties inside `@Composable` | 8.3 |
| **§8** — ViewModel class declarations without a matching test file | 8.4 |
| **§9** — ViewModel/UseCase/RepositoryImpl class declarations in non-canonical paths and domain mapper files | 9.1 · 9.2 · 9.3 · 9.4 |
| **§10** — New suppression directives in added diff lines | — |
