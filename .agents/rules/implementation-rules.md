# Implementation Rules

## Purpose

Rules for ensuring every line of generated code is the real implementation of the requirement — never a placeholder, stub, or dummy that merely satisfies the compiler. Dummy code that compiles but does not perform the specified behavior is treated as a missing implementation, not a deferred one.

---

## 1. No Dummy Code

All code generated for this project must be the actual implementation of the requirement it claims to fulfill. Dummy, stub, or placeholder code is forbidden in production sources.

**Scope**: every production source file — `app/src/main/`, `sharedContracts/`, and any module's `main` source set. Test sources (`src/test/`, `src/androidTest/`, `src/commonTest/`) are **exempt** — fakes, mocks, and stubs used as test doubles are permitted and expected there.

### 1.1 No stub / placeholder return values

A function must not return a hardcoded value where the requirement specifies a computation, query, or transformation.

```kotlin
// BAD — returns a constant instead of computing the actual sum
fun totalPrice(items: List<CartItem>): Double = 0.0

// BAD — returns an empty list instead of querying the repository
suspend fun searchNotes(query: String): List<Note> = emptyList()

// GOOD — implements the actual requirement
suspend fun searchNotes(query: String): List<Note> =
    repository.search(query).map(::toUiModel)
```

### 1.2 No `TODO()` / `NotImplementedError`

`TODO("...")`, `throw NotImplementedError(...)`, or any equivalent marker that lets a function compile without implementing its behavior is forbidden in production sources.

```kotlin
// BAD
fun applyFilter(filter: Filter): Result = TODO("not implemented")

// BAD
fun loadUser(id: UserId): User {
    throw NotImplementedError("will add later")
}
```

### 1.3 No dummy comments

Comments indicating the surrounding code is not the real implementation are forbidden. Examples:

- `// dummy implementation`
- `// placeholder`
- `// stub for now`
- `// TODO: real implementation later`
- `// temporary — replace before merge`
- `// hardcoded for now`

### 1.4 No no-op handlers

A callback, listener, or event handler must not have a `{}` or log-only body when the requirement specifies the callback must perform a real action (navigate, persist, dispatch, emit, etc.).

```kotlin
// BAD — requirement says "on save, persist note and navigate back"
onSaveClick = { /* TODO */ }

// BAD — requirement says "on error, show error state"; this only logs
onError = { error -> Log.e("Tag", "error", error) }

// GOOD — implements the actual requirement
onSaveClick = viewModel::onSaveClick
```

### 1.5 No "compiles but doesn't implement" code

Any function, class, branch, or path that satisfies the type system and builds cleanly but does not perform the actual behavior defined in the active `spec.md`, `implementation_plan_v<N>.md`, `feature_list.json`, or `sprint-contract.md` requirement it claims to fulfill is a violation.

This includes:
- Branches that return early with a placeholder value before the real logic runs.
- Methods that delegate to another stub instead of implementing the behavior.
- Classes that satisfy an interface contract by throwing or returning defaults for every method.
- Paths in a `when` / `if` cascade that are reachable from an in-scope entry point but never produce the specified outcome.

### Allowed exceptions

The following are **not** violations:

- **Test sources** — `src/test/`, `src/androidTest/`, `src/commonTest/`. Fakes, mocks, and stubs used as test doubles are permitted and expected.
- **Interface declarations** — an interface has no body by design; this is not a stub. Concrete implementations must still follow this rule.
- **Abstract members** — `abstract` functions on `abstract` classes or `sealed interface` hierarchies are permitted; the concrete implementations must follow this rule.
- **`@Preview` composables** — Compose `@Preview` functions may use sample/hardcoded `UiState` values because their purpose is rendering tooling, not production behavior. The `UiState` data classes themselves and all production composables must still follow this rule.
- **Documented user-approved exception** — when a reviewer explicitly accepts a stub as a documented false positive, matching the AGENTS.md rule on suppressed violations. The exception must be recorded in the code review report with a justification.

### Enforcement

Every function, branch, and callback added or modified in a change must implement the actual requirement logic. Reviewers (Evaluator role) must reject any change containing the prohibited patterns above as **REVISION REQUIRED** — the Coder must return to implementation and deliver the real behavior. This rule is non-negotiable and cannot be waived by silence; only an explicit, documented user approval satisfies the exception clause.
