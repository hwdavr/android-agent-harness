---
name: android-unit-test
description: Implement and verify Android unit-test coverage.
---

# Android Unit Test Skill

## Purpose
This skill defines the standards for unit and integration testing in the Android application. JVM-based tests in `src/test` are the primary verification layer for logic, ViewModel state, API handling, and data flow.

## Execute
- **Scope**: ViewModel state transitions, domain use case logic, mappers (DTO → Domain, Domain → UI), formatting/fallback.
- **Framework**: JUnit 4, MockK (`coEvery`, `coVerify`), Turbine, Coroutines `runTest`.
- **Naming**: File ends with `Test.kt` (ViewModel tests inherit from `BaseViewModelTest`), descriptive Given/When/Then names.
- **Conventions**: Follow AAA pattern, test public API, one main scenario per test. Prefer real model instances over mocks.

