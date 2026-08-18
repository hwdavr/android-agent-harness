---
name: android-domain-layer
description: Implements domain mappers, models, and domain use cases.
---

# Skill — Android Domain Layer

## Purpose
Implement domain layer changes: use cases, domain models, and repository interfaces.
The domain layer must remain platform-independent.

---

## Load
- `rules/android-architecture.md`
- `rules/implementation-rules.md`
- `docs/current/implementation_plan_v<N>.md` (Implementation Plan stage output)

---

## Execute

### 1. Domain model changes
1. Add or remove fields in domain model data classes
2. Import **no Android framework classes** (`Context`, `Bundle`, SDK types)
3. If an enum is added, include an `UNKNOWN` / fallback variant

### 2. Repository interface changes
1. Add or update method signatures in the repository interface (defined in domain layer)
2. Keep interfaces stable and framework-independent
3. Use `suspend` functions or `Flow` based on existing conventions in the codebase
4. Confirm the interface change matches the implementation added in the Data Layer stage

### 3. Use case changes
1. Create or update use cases — one use case does one thing
2. Use cases may coordinate multiple repository methods but must not call data sources directly
3. Use cases should be easily unit testable with mocked repository implementations
4. Implement business validation, filtering, and decision logic here — not in the ViewModel

**Business logic that belongs in use cases (not ViewModel or Composable):**
- Access permission checks
- Filter / sort logic driven by business rules
- Validation before mutations
- Data combination from multiple repositories

---

## Output

Update `docs/current/coding_report_v<N>.md` with a Domain Layer section:
```
## Domain Layer Changes

### Files Changed
| File | Action | Notes |
|------|--------|-------|

### Use Case Responsibilities
<describe what each new/modified use case does>

### Interface Contract Changes
<list repository interface changes>
```

Update `summary_v<N>.md`: mark the Domain Layer stage complete.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**
- [ ] No Android framework classes imported in domain layer files (`grep -r "import android\." domain/`)
- [ ] Repository interfaces updated and match the Data Layer stage implementation
- [ ] Use cases are single-responsibility (one observable outcome per use case)
- [ ] New enum domain models include `UNKNOWN` / fallback variant
- [ ] No dummy code in domain-layer files — no `TODO()`, `NotImplementedError`, stub return values, no-op handlers, or `// dummy implementation` comments in `domain/` sources; every use case implements the actual business logic. Repository interface declarations are exempt (interfaces have no body by design — see the rule's "Allowed exceptions"); concrete `RepositoryImpl` implementations are checked in the Data Layer stage (see `rules/implementation-rules.md`)
- [ ] Build passes: `./gradlew assembleDebug`

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.
