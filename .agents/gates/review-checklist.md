# Review Checklist

## Purpose
Checklist for reviewing any code change before it is considered complete.

---

## Layer Boundaries

- [ ] UI layer does not call repositories or data sources directly
- [ ] ViewModel does not import Retrofit, Room, or data-layer classes
- [ ] Domain layer has no Android framework imports (`Context`, `Bundle`, SDK types)
- [ ] DTOs are not exposed outside the data layer
- [ ] No domain models are used directly in Compose without mapping to UI models (if formatting is needed)
- [ ] No fully-qualified class names used inline in **any** file — production **or** test code — all classes referenced via `import` at the top of the file (e.g. no `com.example.Foo()` in function bodies, no `io.mockk.mockk` in property declarations)

---

## State and UI

- [ ] Each modified screen renders from a single `UiState`
- [ ] All user-visible text uses `stringResource()` — no hardcoded strings
- [ ] All colors use `LocalAppColors.current.<token>` — no hardcoded `Color(0x...)` or `Color.Red` etc.
- [ ] All interactive elements have `Modifier.testTag(...)` with stable names
- [ ] One-off events (navigation, toast, dialog) use `Channel` or `SharedFlow` — not permanent `UiState` fields
- [ ] Loading, success, empty, and error states are all handled in `UiState`

---

## Testing

- [ ] New use cases, ViewModels, and mappers have unit tests
- [ ] At least one integration test per new API endpoint
- [ ] Shared JSON scenarios used — no inline mock data in test cases
- [ ] Platform capability matrix exists and covers minimum, target, and important API boundaries
- [ ] Unsupported runtime/device/model/locale/permission conditions fail loudly; no skipped environment is recorded as pass
- [ ] Platform-bound behavior has a real instrumented boundary test; fake recognizers and JVM-only intent tests are supplemental only
- [ ] `koverLog` coverage ≥ 80% overall, ≥ 90% for new classes
- [ ] All tests pass: `./gradlew testDebugUnitTest`

## Test Code Quality

- [ ] No fully-qualified class names in test files — use top-level `import` declarations (e.g. no `io.mockk.mockk(...)` or `com.example.Foo` inline in property/parameter declarations)
- [ ] No wildcard imports in test files — all imports must be fully explicit (e.g. no `import io.mockk.*`)
- [ ] Test file imports are sorted lexicographically with no blank lines between them

---

## Scope Discipline

- [ ] No unrelated changes mixed into this diff
- [ ] No speculative refactoring of files not required by the task
- [ ] Gradle/plugin versions not changed unless explicitly required
- [ ] No broad theming redesign or repository-wide package moves

---

## Security

- [ ] No secrets, API keys, or tokens hardcoded in source
- [ ] No PII (name, email, phone) logged
- [ ] Sensitive data not stored in plaintext
- [ ] No unsafe WebView or deep link handling introduced
- [ ] Auth/session behavior not weakened

---

## Build and Quality

- [ ] `./gradlew assembleDebug` passes
- [ ] `./gradlew testDebugUnitTest` passes
- [ ] `./gradlew ktlintCheck` passes
- [ ] `./gradlew detekt` passes
- [ ] `./gradlew lintDebug` passes (errors only)
