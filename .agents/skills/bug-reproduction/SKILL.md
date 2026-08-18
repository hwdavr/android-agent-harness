---
name: bug-reproduction
description: Reproduces a bug with a failing test before fixing it.
---

# Skill — Bug Reproduction (TDD)

## Purpose

Prove the root cause is correct by writing a **failing test** that mechanically reproduces the bug.
The test must turn RED before any fix is written.
This is the gate that separates "we believe we found it" from "we have proven it".

Do not implement any fix in this stage.

---

## Load

- `skills/android-unit-test/SKILL.md`
- `skills/android-instrumented-ui-test/SKILL.md`
- `skills/shared-json-scenarios/SKILL.md`
- `rules/testing-strategy.md`
- `docs/current/spec_v<N>.md` — root cause statement

---

## Execute

### 1. Select the reproduction test layer

Read `rules/testing-strategy.md` and pick the **lowest** layer that is sufficient to reproduce the bug:

| Bug type | Preferred layer |
|---|---|
| Logic / calculation error | Unit test (`app/src/test/`) |
| Data-flow / API mapping / error state | Integration test (`app/src/test/`) |
| Visual glitch / unresponsive element | Instrumented UI test (`app/src/androidTest/`) |
| Navigation crash / deep-link issue | Instrumented UI test (`app/src/androidTest/`) |

### 2. Write the reproduction test — RED phase

Follow the **Prove-It Pattern** to write a failing test that reproduces the defect before attempting a fix:

#### The Prove-It Pattern Flow
```
Bug report arrives
       │
       ▼
  Write a test that demonstrates the bug
       │
       ▼
  Test FAILS (confirming the bug exists)
       │
       ▼
  Implement the fix
       │
       ▼
  Test PASSES (proving the fix works)
       │
       ▼
  Run full test suite (no regressions)
```

#### Example (Kotlin/Android)
```kotlin
// Bug: "ViewModel doesn't emit error state when saving a note with empty title"

// Step 1: Write the reproduction test (it should FAIL)
@Test
fun givenNoteWithEmptyTitle_whenSaving_thenEmitsError() {
    val note = Note(id = "1", title = "")
    coEvery { repository.saveNote(note) } throws IllegalArgumentException("Empty title")

    viewModel.saveNote(note)

    // This assertion fails because the ViewModel currently ignores the error and stays in Success
    assertEquals(EditorUiState.Error("Empty title"), viewModel.uiState.value)
}

// Step 2: Implement the fix in the ViewModel
fun saveNote(note: Note) {
    viewModelScope.launch {
        try {
            repository.saveNote(note)
        } catch (e: IllegalArgumentException) {
            _uiState.value = EditorUiState.Error(e.message ?: "Invalid title")
        }
    }
}

// Step 3: Test passes -> bug fixed, regression guarded
```

1. **Write the test first**: Do not write the fix first. Do not touch application code.
2. **Name the test descriptively**: The test name should read as a specification of the failure.
   - Pattern: `"given <precondition>, when <action>, then <expected outcome>"`
   - Example: `"given a note with empty title, when saving, then an error state is emitted"`
3. **Write the minimal test** that targets the root cause statement in `spec_v<N>.md`.
4. **Do not write the fix**. Do not adjust application code to make the test pass.
5. **Use shared JSON scenarios** if an API response is involved — do not inline mock data.
6. **Add `@Ignore("BUG: <short description> — remove when fixed")`** if the test would block CI before the fix lands; remove the annotation in the Implementation stage.

### 3. Run the test — confirm RED

```bash
./gradlew testDebugUnitTest --tests "<FullyQualifiedTestClass>"
```

or for instrumented tests:

```bash
./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=<FullyQualifiedTestClass>
```

**The test must fail.** A test that passes immediately means one of:
- The bug is already fixed (re-examine the root cause)
- The test is not actually reproducing the bug (fix the test)

Do not advance until you have observed a RED result.

---

## Output

The new (failing) reproduction test file, committed with `@Ignore` if needed.

Append to `docs/current/spec_v<N>.md`:

```
## Reproduction Test

- File: `<relative path to test file>`
- Class: `<TestClassName>`
- Test name: `<test function name>`
- Layer: Unit | Integration | Instrumented UI
- Run result: FAILED ✓ (expected — bug confirmed)
- Failure message: <paste the key assertion failure line>
```

Update `summary_v<N>.md`: mark this stage complete.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**

- [ ] A reproduction test exists that targets the root cause statement in `spec_v<N>.md`
- [ ] `./gradlew testDebugUnitTest` (or `connectedDebugAndroidTest`) exits **non-zero** for the new test, confirming RED
- [ ] The failure message matches the root cause — not a compilation error or unrelated assertion
- [ ] No application source code has been modified in this stage
- [ ] `spec_v<N>.md` is updated with the Reproduction Test section

**APPROVED →** Return to the active workflow file and proceed to the Fix Plan stage.
