---
name: android-instrumented-ui-test
description: Implement Android UI tests on a real device or emulator runtime.
---

# Android instrumented UI test skill

Use this skill for Android UI tests on real runtime.

## Execute
- **Scope**: Gestures, navigation flows, critical multi-screen paths, and platform behavior on emulator/device. Roborazzi JVM tests own pixel comparison against approved visual references.
- **Framework**: ComposeTestRule (`createComposeRule` for stateless UI, `createAndroidComposeRule` for stateful).
- **Identifiers**: Locate elements via `hasTestTag("stable_name")` — **never by static text**.
- **Timing**: Use `waitForIdle()` or `waitUntil` — **never `Thread.sleep()`**.
- **Evidence**: Record device assertions for interaction and platform behavior. Do not use device screenshots as visual acceptance evidence; the matching `*RoborazziTest` and `verifyRoborazziDebug` receipt provide that evidence.
