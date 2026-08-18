---
name: android-integration-test
description: Use this skill for Android integration tests below the UI layer.
---

# Android integration test skill

Use this skill for Android integration tests below the UI layer.

## Good targets
- repository + MockWebServer
- API success handling
- API error handling
- malformed payload handling
- network failure handling
- DTO to domain mapping
- retry / fallback logic
- ViewModel state transitions from mocked backend responses

## Preferred tools
- JUnit
- MockWebServer
- coroutine test
- fake data sources
- existing repository helpers

## Shared JSON scenario usage
If a shared JSON scenario exists:
1. load apiMocks
2. stub the backend accordingly
3. execute repository / use case / ViewModel logic
4. if the API is used by a ViewModel function, assert the ViewModel-exposed `UiState` against `expected.ui`
5. if the API is used only by domain/repository/use case logic without directly changing UI state, assert `expected.domain`

## Rules
- verify Result / Error / Domain model / UiState outputs at logic level
- do not verify UI here
- prefer the shared JSON scenario contract when it exists, but keep this skill focused on Android-side integration execution
- cover both happy path and error path
- prefer this layer over UI tests for backend error permutations

## Typical cases
- 200 success
- 400 business error
- 401 / 403 auth or permission issue
- 404 not found
- 500 server error
- malformed JSON
- empty body
- disconnect / timeout
