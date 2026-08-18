# Platform Capability Matrix

## Scope

- Feature/slice: `{feature-id}`
- Platform boundary: `{Android API, device, OS, SDK, or hardware capability}`
- Minimum API: `{minSdk}`
- Target API: `{targetSdk}`
- Single resource owner: `{component that owns the device resource}`
- Input/output contract: `{format, lifecycle, and callback contract}`

## Runtime Matrix

Every required runtime boundary must appear as a row. `Unsupported (explicit fallback)` is valid only when the required fallback is implemented and tested. `Pending`, `Unavailable`, `Blocked`, and `Skipped` are never passing evaluation results.

| Runtime/API | Capability under test | Required behavior | Test ID / exact command | Environment evidence | Status |
|---|---|---|---|---|---|
| API `{minSdk}` | `{capability}` | `{supported behavior or explicit fallback}` | `{test ID and command}` | `{device/model/build evidence}` | `Planned` |
| API `{important boundary}` | `{capability}` | `{supported behavior or explicit fallback}` | `{test ID and command}` | `{device/model/build evidence}` | `Planned` |
| API `{targetSdk}` | `{capability}` | `{supported behavior or explicit fallback}` | `{test ID and command}` | `{device/model/build evidence}` | `Planned` |

## Real Platform Boundary Test

- Required: `{Yes | No — explain why}`
- Test IDs: `{TC-US-*-PLATFORM}`
- Instrumented test file(s): `{app/src/androidTest/...}`
- Real-platform signal: `{production boundary class or Android API referenced by the test}`
- Exact command(s): `{ANDROID_SERIAL=... ./gradlew connectedDebugAndroidTest ...}`
- Fixture/data source: `{deterministic local fixture; no live backend}`
- Assertion: `{observable platform result, not only an intent/fake callback}`

The real-platform test must exercise the shipped Android boundary. A fake recognizer, fake device callback, or JVM-only intent test is supplementary evidence and cannot satisfy this requirement by itself.

## Unsupported Environment Policy

The evaluator must fail loudly when a required emulator, device, model, locale, permission, hardware capability, or platform service is unavailable. The test must return a non-zero result or the feature must be marked `Blocked`/`Revise`; it must not be converted into a passing result through a skip, warning, or missing-evidence note.

- Policy: `fail_loudly`
- Missing environment result: `{non-zero command / Blocked / Revise}`
- Explicit fallback for a genuinely unsupported API: `{fallback behavior and test ID}`
- Evidence owner: `{agent or CI job}`
