# Navigation Rules

## Purpose
Rules for implementing navigation in this project using Navigation Compose.

---

## Route Definition

- Define all routes as constants or sealed classes — not raw strings inline
- Route arguments must be serializable types (`String`, `Int`, `Boolean`, `Long`)
- Do not pass complex objects as navigation arguments — pass an ID and fetch the object from the destination

---

## Argument Rules

Pass the minimum data needed:
```kotlin
// ✅ Pass ID, fetch in destination
NoteDetailRoute(noteId = "note-123")

// ❌ Don't serialize full objects
NoteDetailRoute(note = serializedNote)
```

Argument nullability:
- Optional arguments must have a `defaultValue` defined in the nav graph
- Required arguments must use non-nullable types — navigating without them is a programming error

---

## Back Stack Behavior

Define back-stack behavior explicitly for each navigation action.

Common patterns:
- **Open detail**: push on stack — default behavior
- **Login → Home after auth**: `popUpTo(LoginRoute) { inclusive = true }` — remove login from back stack
- **Bottom nav tab switch**: `launchSingleTop = true` — avoid duplicate destinations

Always verify back-stack behavior matches the intended UX during review.

---

## Navigation from ViewModel

Navigation events are emitted from ViewModel as one-off effects, not as UiState fields:

```kotlin
// In ViewModel
private val _navigationEvents = Channel<NoteDetailNavEvent>()
val navigationEvents = _navigationEvents.receiveAsFlow()

// In Screen
LaunchedEffect(Unit) {
    viewModel.navigationEvents.collect { event ->
        when (event) {
            is NoteDetailNavEvent.NavigateBack -> navController.popBackStack()
        }
    }
}
```

Do not encode navigation destinations as boolean flags in `UiState`.

---

## Deep Links

If deep links are added:
- Define them in the nav graph alongside the route
- Validate all arguments from deep links — they are untrusted input
- Test with `adb shell am start -W -a android.intent.action.VIEW -d "<deeplink>"`

---

## Testability

- Navigation routes must be reachable in tests without multi-step setup
- Add direct navigation helpers for test scenarios where needed
- Prefer deterministic fake/seed data at navigation entry points
