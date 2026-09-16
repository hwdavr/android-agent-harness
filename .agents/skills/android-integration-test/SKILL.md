---
name: android-integration-test
description: Implement Android integration tests below the UI layer.
---

# Android integration test skill

Use this skill for Android integration tests below the UI layer.

## Execute
- **Coverage per API endpoint**: Success (2xx), 4xx client error, 5xx server error, malformed payload, timeout, unknown enum fallback.
- **Shared Scenarios**: Use shared JSON scenarios from `sharedContracts/test-scenarios/` — **never inline mock response data**.
- **Layer assertions**: Assert `expected.ui` when endpoint is consumed by ViewModel; assert `expected.domain` when consumed only by repo/use case.
- **Mocking**: Use MockWebServer for mocking network traffic.
- **Persistence**: Use in-memory Room database for local persistence integration tests.

