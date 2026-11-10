# Implementation Plan — <Feature Name>

**Feature ID**: `<feature-id>`
**Workspace**: `.scratch/<YYYY-MM-DD>-<feature-id>/`
**Workflow**: harness-planning / bug-fixing / api-contract-update
**Lane**: single / sliced *(fixed at Specify: no user stories → single; two or more → sliced)*
**Date**: YYYY-MM-DD
**Status**: Draft / Approved — <user, YYYY-MM-DD>

Use this template in the **Implementation Plan** stage of every lane. It is written once per workspace and
revised in place; do not create `_v<N>` copies. The living capability files own product intent
(WHAT/WHY); this plan owns HOW, the Rule Applicability decisions, and verification ownership.
`test-plan.md` owns everything about tests. The sliced lane adds `tasks.md` (ordered work per
story) and `feature_list.json` (slice status and evidence); the single lane uses neither.

---

## Product Requirements

One row per capability file that carries this feature's block. The SHA-256 is computed over
the text between `<!-- feature: <feature-id> -->` and `<!-- /feature: <feature-id> -->`
(exclusive) and is recorded when the specification is approved. A changed block requires
re-approval before the plan can pass the analyze gate.

| Capability file | Feature block | Requirement IDs | Approved block SHA-256 | Approved by / date |
|---|---|---|---|---|
| `docs/product/requirements/<capability>.md` | `<feature-id>` | FR-###, FR-### | `<64 hex characters>` | <user, YYYY-MM-DD> |

Bug-fixing lane without a block: write `none — restores <capability>.md#FR-###` in the
Feature block column and `N/A` for the hash.

## Summary

<Two or three sentences: the primary requirement and the chosen technical approach.>

## Root Cause & Reproduction *(bug-fixing lane only; remove these bug sections otherwise)*

Written in the bug-context stage, before the rest of the plan.

- **Violated requirement**: `<capability>.md#FR-###` / `AC-###`
- **Observed vs expected**: <observed behavior> vs <behavior the requirement promises>
- **Root cause**: <file, function, and the faulty assumption>

## Screen States *(UI bug only; the screen/state pairs the fix touches)*

| Screen | State ID | Requirement | Acceptance Criteria |
|---|---|---|---|
| <screen> | <screen-state> | FR-### | AC-### |

## Technical Context

- **Language/Version**: Kotlin <version>, Java/Kotlin 17
- **Primary dependencies**: <Compose, Room, Hilt, Retrofit, … plus any new library and version>
- **Storage**: <Room entities/migrations, DataStore, files, or "No persistence change">
- **Network/API**: <endpoints in `sharedContracts/openapi.yaml`, or "None">
- **Testing**: <JVM unit / integration / instrumented layers and UI review captures in scope>
- **Target platform**: minSdk 24 / targetSdk 34; <devices, locales, permissions, services>
- **Constraints**: <performance, offline, security, accessibility>
- **Unknowns**: <list each as `NEEDS RESEARCH: …`, or "None">

## Rule Applicability

The project's rules gate and the canonical matrix for this change. Keep all ten rows. Use
`Required`, `Not applicable — <feature-specific reason>`, or `Exception — approved by <user/date>`.
Decide every row before Phase 0, and re-check the decisions after Phase 1 design: a design that
introduces a new trigger updates its row. A deviation from a rule is never silent — it is an
`Exception — approved by <user/date>` row whose evidence column states the approved boundary.
Reviews independently reconcile all ten decisions against the diff.

| Rule ID | Rule document | Decision | Feature-specific trigger or reason | Planned work and evidence |
|---|---|---|---|---|
| ARCH | `android-architecture.md` | <decision> | | |
| IMPL | `implementation-rules.md` | <decision> | | |
| TEST | `testing-strategy.md` | <decision> | | |
| SUI | `compose-rules.md` | <decision> | | |
| L10N | `localization-rules.md` | <decision> | | |
| NAV | `navigation-rules.md` | <decision> | | |
| API | `api-contract-rules.md` | <decision> | | |
| OBS | `observability.md` | <decision> | | |
| ANL | `analytics-rules.md` | <decision> | | |
| SEC | `android-security.md` | <decision> | Authentication, sensitive storage, URI/IPC, exported components, network/TLS, WebView, AI/model, SDK, or release-security boundary. | |

## Phase 0 — Research

Resolve every `NEEDS RESEARCH` item. For each: decision, rationale, alternatives considered.
Write long findings to `research.md` in the workspace and link it; otherwise record
"No unknowns".

| Unknown | Decision | Rationale | Alternatives considered |
|---|---|---|---|
| <unknown> | <decision> | <why> | <rejected options> |

## Phase 1 — Design

### Project Structure

| Layer | Files affected | Change type |
|---|---|---|
| UI | `path/to/Screen.kt` | new / modify / delete |
| Presentation | `path/to/ViewModel.kt` | |
| Domain | `path/to/UseCase.kt` | |
| Data | `path/to/Repository.kt`, `path/to/Dto.kt` | |
| Navigation | `path/to/NavGraph.kt` | |
| Test infrastructure | `path/to/FixtureServer.kt` | |
| Tests | `path/to/ViewModelTest.kt` | |

### Data Model & Persistence

<Entities, fields, relationships, validation, state transitions. Room schema version and
migration, or "No persistence change". Write long models to `data-model.md` and link it.>

### API Contract Changes

- **Classification**: none / backward compatible / backward compatible but risky / breaking
- **Force update required**: yes / no / unknown
- **OpenAPI status**: <already defined in `sharedContracts/openapi.yaml` / requires update: …>
- **Shared JSON scenarios**: <`sharedContracts/test-scenarios/<scenario>.json` to add or reuse>

### UiState Design *(UI scope)*

```kotlin
data class ExampleUiState(
    val isLoading: Boolean = false,
    val content: ExampleUiModel? = null,
    val error: UiError? = null,
)
```

States covered: Loading · Content · Empty · Error · Retry · Permission/Auth (if applicable)

### UI State Stages *(UI scope; remove otherwise)*

Copy each Plan stage ID from `UI_contract.md` and name the registered design-system Composables
the state reuses. How each state is verified (review capture and structural check) is planned in
`test-plan.md` under `## UI State Verification`.

| Stage ID | Reused registered components | Implementation |
|---|---|---|
| UI-01 | `NoteCard`, `TopActionBar` | <state-specific change> |

## Platform Capability & Environment Contract *(platform-bound changes only)*

Declare whether the change crosses an Android device/platform boundary (runtime, device, model,
locale, permission, or system service). When it does, link `platform-capability-matrix.md`; the
real instrumented boundary tests are planned in `test-plan.md`, and missing platform resources
fail loudly. The sliced lane mirrors this declaration in `feature_list.json` `platform_validation`.

- **Platform-bound**: No — <reason> / Yes — see `platform-capability-matrix.md`

## Test Strategy

Test design lives in [`test-plan.md`](test-plan.md) (from `harness/templates/test-plan-template.md`):
Rule Applicability test mapping, reproduction (bugs), Spec Coverage Matrix, acceptance test cases,
Production Journey Planning Contract, UI state verification, and layer selection.

## Delivery

- **Single lane**: this plan, [`test-plan.md`](test-plan.md), and [`summary.md`](summary.md)
  (plus `UI_contract.md` for UI). One approval covers the spec block, design, and both plans.
- **Sliced lane**: adds [`tasks.md`](tasks.md) and [`feature_list.json`](feature_list.json) (one
  slice per user story); each slice records evidence in `summary_<FEATURE_ID>.md`.

## Risks & Migration Notes

1. Risk: <what could go wrong> — Mitigation: <how it is reduced>
2. Migration/compatibility: <Room migration, phased rollout, backward compatibility, or "None">

## Explicit Assumptions

1. <technical assumption>
