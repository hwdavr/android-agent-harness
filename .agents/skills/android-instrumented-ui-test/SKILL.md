---
name: android-instrumented-ui-test
description: Use this skill for Android UI tests on real runtime.
---

# Android instrumented UI test skill

Use this skill for Android UI tests on real runtime.

## Good targets
- list screen renders mocked items
- loading / empty / error / success UI states
- click and visible reaction
- click and navigation
- critical multi-screen happy paths
- real UI wiring from mocked backend or fake repository to screen

## Required process
1. inspect existing BaseUiTest/TestCase and similar tests
2. reuse Screen objects and helpers
3. arrange deterministic mocked input through:
   - MockWebServer
   - fake repository
   - DI override
   - fixture loader
4. use Given / When / Then through step blocks
5. assert user-visible behavior only

## Shared JSON scenario usage
If a shared JSON scenario exists:
1. load apiMocks
2. launch the screen under test
3. assert expected.ui

## Implementation Details

### 1. Stateless UI Testing (Lightest Layer)
**Goal:** Verify rendering and interaction logic of a single Composable in isolation.
- **Pattern:** Test the stateless `Content` Composable — do not involve a ViewModel or real DI wiring.
- **Rule:** Use `createComposeRule()` (NOT `createAndroidComposeRule`).
- **Setup:**
    - Initialize a pure `UiState` object (e.g., `FoldersUiState.Success(...)`).
    - Mock interaction callbacks using lambda expressions or mocks.
- **Naming:** `<ScreenName>Test.kt` (e.g., `FoldersScreenTest.kt`).

### 2. Stateful Screen Testing (Medium Layer)
**Goal:** Verify the wiring between the ViewModel and the Composable.
- **Rule:** Use `createAndroidComposeRule<ComponentActivity>()`.
- **Setup:**
    - Override the ViewModel with a mock or fake.
### 3. Dedicated Visual Flow Testing (`*VisualFlowTest.kt`)
**Goal:** Verify visual states of components/screens and produce genuine screenshot evidence for UI verification.
- **Rule:** Write a dedicated visual test class (or test methods) exercising each critical visual state.
- **In-Test Capture Helper:**
```kotlin
private fun captureVisualEvidence(fileName: String) {
    composeRule.waitForIdle()
    val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        ?: error("Could not capture visual evidence: $fileName")
    val directory = InstrumentationRegistry.getInstrumentation().targetContext
        .getExternalFilesDir("visual_evidence")
        ?: error("External files directory unavailable")
    directory.mkdirs()
    val screenshot = File(directory, "$fileName.png")
    screenshot.outputStream().use { output ->
        check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) {
            "Could not write visual evidence: $fileName"
        }
    }
    InstrumentationRegistry.getInstrumentation().uiAutomation
        .executeShellCommand("cp ${screenshot.absolutePath} /sdcard/Download/$fileName.png")
        .use { }
}
```
- **Pulling Screenshots:** Retrieve files via `adb pull /sdcard/Download/<name>.png <destination>`.
- **Constraint:** Never use post-test CLI screencaps (e.g. `&& adb screencap`) because the Composable is unmounted before the command runs.

## Rules
- Target device selection: Use an Android emulator for instrumented UI tests (e.g. `ANDROID_SERIAL=emulator-5554`). Only when an emulator is missing/not connected, use a connected physical device.
- one scenario per test
- no Thread.sleep — use `waitUntil` or `waitForIdle`
- stable selectors only (`Modifier.testTag`)
- prefer destination screen assertion for navigation
- do not duplicate the full API error matrix here (cover in integration tests instead)