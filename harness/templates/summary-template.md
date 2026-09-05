# Change Summary — <Slice or Feature Title>

**Type**: feature / bugfix / api / refactor
**Started**: YYYY-MM-DD HH:MM
**Status**: In Progress / Complete
**Feature ID**: <US-X / Task ID>
**Workspace**: `docs/product/<YYYY-MM-DD-feature-name>/` (or `docs/current/` for ad-hoc)

---

## Stage Progress

Copy the stage progress table matching your workflow.

### Complex Feature (`harness-generator` workflow)

| Stage | Status | Timestamp | Notes |
|---|---|---|---|
| Orient | ✅ Complete | YYYY-MM-DD HH:MM | Lifecycle validated; <US-X> selected from active workspace. |
| Setup | ✅ Complete | YYYY-MM-DD HH:MM | Runtime & emulator readiness confirmed. |
| Verify Baseline | ✅ Complete | YYYY-MM-DD HH:MM | Prior test suite & build pass before changes. |
| Implement | ✅ Complete | YYYY-MM-DD HH:MM | Production changes implemented across layers. |
| Test | ✅ Complete | YYYY-MM-DD HH:MM | Acceptance tests, unit/integration, and journey regression pass. |
| Code Quality Fix | ✅ Complete | YYYY-MM-DD HH:MM | Formatters, linters, detekt, and architecture rules pass (0 violations). |
| Update State | ✅ Complete | YYYY-MM-DD HH:MM | State updated in feature_list.json and product.md. |
| Clean Exit | ✅ Complete | YYYY-MM-DD HH:MM | Clean-state checklist verified; handoff recorded. |
| Install App To Device | ✅ Complete | YYYY-MM-DD HH:MM | Installed debug APK to target device/emulator. |

### Ad-hoc Feature (`feature-delivery` workflow)

| Stage | Status | Timestamp | Notes |
|---|---|---|---|
| Requirement Analysis | ✅ Complete | YYYY-MM-DD HH:MM | Spec created; scope and UI states analyzed. |
| Implementation Plan | ✅ Complete | YYYY-MM-DD HH:MM | Plan approved by user. |
| Implementation | ✅ Complete | YYYY-MM-DD HH:MM | Data, domain, and UI layers implemented. |
| Testing | ✅ Complete | YYYY-MM-DD HH:MM | Unit, integration, and journey regression tests passing. |
| Code Quality Fix | ✅ Complete | YYYY-MM-DD HH:MM | Static analysis, ktlint, and detekt passing. |
| Knowledge Capture | ✅ Complete | YYYY-MM-DD HH:MM | ADRs and learnings captured. |

---

## Baseline Goals and Scope

- <Goal 1>
- <Goal 2>

## Key Decisions

- <Decision 1>
- <Decision 2>

## Knowledge Artifacts

- `docs/knowledge/...` — <Rationale / Context>

## Open Items

- <Unresolved item or "None — all acceptance criteria verified.">

---

## Stage Evidence

### Orient
- Command: `bash harness/scripts/check-feature-lifecycle.sh`
- Result: exit 0

### Setup
- Command: `adb devices`
- Result: exit 0

### Verify Baseline
- `./gradlew testDebugUnitTest` — exit 0
- `./gradlew assembleDebug` — exit 0

### Implement
- Created / Modified files:
  - `...`

### Test
- Acceptance test commands and results:
  - `<test command>` — exit 0
- Unit & integration coverage:
  - Line coverage: XX%
- Journey regression gate:
  - `bash harness/scripts/check-journey-registry.sh --run-all` — exit 0

### Code Quality Fix
- `./gradlew ktlintCheck` — exit 0
- `./gradlew detekt` — exit 0
- `bash harness/scripts/check-architecture-rules.sh` — exit 0

---

## Observability & Execution Metrics

### Human-Readable Overview

| Metric | Value |
|---|---|
| **Model** | <Model Name, e.g. Claude 3.7 Sonnet / Gemini 2.5 Flash> |
| **Total Wall-Clock Time** | <Duration, e.g. 25m 30s> |
| **Files Read / Modified** | <Read Count> / <Modified Count> |
| **Commands Executed** | <Total Commands> (First-pass rate: <Percentage>%) |
| **Gate Failure Retries** | <Retry Count> |
| **Estimated Tokens** | ~<Estimated Token Count> |

### Stage Breakdown

| Stage | Status | Duration | Retries | Commands Run |
|---|---|---|---|---|
| Orient | ✅ Complete | <Duration> | 0 | 1 |
| Setup | ✅ Complete | <Duration> | 0 | 1 |
| Verify Baseline | ✅ Complete | <Duration> | 0 | 2 |
| Implement | ✅ Complete | <Duration> | 0 | 0 |
| Test | ✅ Complete | <Duration> | 0 | 5 |
| Code Quality Fix | ✅ Complete | <Duration> | 0 | 3 |
| Update State | ✅ Complete | <Duration> | 0 | 1 |
| Clean Exit | ✅ Complete | <Duration> | 0 | 1 |

### Machine-Readable Metrics

```json:metrics
{
  "slice_id": "<US-X or task-id>",
  "model": "<Model Name>",
  "total_duration_sec": 1530,
  "files_read_count": 12,
  "files_modified_count": 5,
  "commands_executed": 14,
  "first_pass_command_rate": 92.8,
  "gate_retries_total": 1,
  "gate_failure_causes": ["check-compose-rules.sh"],
  "tokens_estimated": 125000,
  "stages": {
    "orient": {"duration_sec": 60, "retries": 0, "commands": 1},
    "setup": {"duration_sec": 30, "retries": 0, "commands": 1},
    "verify_baseline": {"duration_sec": 120, "retries": 0, "commands": 2},
    "implement": {"duration_sec": 720, "retries": 0, "commands": 0},
    "test": {"duration_sec": 360, "retries": 0, "commands": 5},
    "code_quality_fix": {"duration_sec": 180, "retries": 1, "commands": 3},
    "update_state": {"duration_sec": 60, "retries": 0, "commands": 1}
  }
}
```
