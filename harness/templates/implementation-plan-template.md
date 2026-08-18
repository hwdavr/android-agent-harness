# Implementation Plan Template

Use this template when producing the plan in the **Implementation Plan** stage.

---

## Feature / Bug

> One line description of what is being implemented or fixed.

---

## Requirement Summary

> 2–3 sentences. What is being built, why, and for whom.

---

## Impact Summary

| Layer | Files Affected | Change Type |
|-------|---------------|-------------|
| UI | `path/to/Screen.kt` | modify |
| Presentation | `path/to/ViewModel.kt` | modify |
| Domain | `path/to/UseCase.kt` | new |
| Data | `path/to/Dto.kt`, `path/to/Mapper.kt` | modify |
| Navigation | `path/to/NavGraph.kt` | extend |
| Tests | `path/to/ViewModelTest.kt` | modify |

---

## API Changes

- **Classification**: backward compatible / backward compatible but risky / breaking / none
- **Force update required**: yes / no / unknown
- **Fields added**: `fieldName: Type`
- **Fields removed**: `fieldName`
- **Fields changed**: `fieldName: OldType → NewType`
- **OpenAPI Status**: <Already defined in sharedContracts/openapi.yaml / Requires update: list changes>

---

## Files to Create

| File | Purpose |
|------|---------|
| `path/to/NewFile.kt` | reason |

---

## Files to Modify

| File | What Changes |
|------|-------------|
| `path/to/ExistingFile.kt` | description of change |

---

## Files to Delete

| File | Reason |
|------|--------|
| `path/to/OldFile.kt` | reason |

---

## UiState Design

```kotlin
data class ExampleUiState(
    val isLoading: Boolean = false,
    val content: ExampleUiModel? = null,
    val error: UiError? = null,
)
```

States covered:
- [ ] Loading
- [ ] Success / Content
- [ ] Empty
- [ ] Error
- [ ] Retry
- [ ] Permission / Auth (if applicable)

---

## Test Plan

> Produce a separate test plan document using **[`harness/templates/test-plan-template.md`](test-plan-template.md)** and link it here once created.

---

## Explicit Assumptions

1. <assumption>

---

## Risks

1. Risk: <what could go wrong> — Mitigation: <how to reduce it>

---

## Migration / Compatibility Notes

> Any Room migration, backward compatibility handling, or phased rollout considerations.

---

## Out of Scope

> List anything explicitly NOT being changed in this task to prevent scope creep.
