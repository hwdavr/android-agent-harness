---
name: android-instrumented-ui-test
description: Implement Android UI tests on a real device or emulator runtime.
---

# Android instrumented UI test skill

Use this skill for Android UI tests on real runtime.

## Execute
- **Scope**: Gestures, navigation flows, critical multi-screen paths, visual verification on emulator/device.
- **Framework**: ComposeTestRule (`createComposeRule` for stateless UI, `createAndroidComposeRule` for stateful).
- **Identifiers**: Locate elements via `hasTestTag("stable_name")` — **never by static text**.
- **Timing**: Use `waitForIdle()` or `waitUntil` — **never `Thread.sleep()`**.
- **Visual Verification**: When required, capture screen in-test (e.g. `takeScreenshot()`) and pull via adb into `visual_evidence/`. Never use post-test CLI screencap.

