# Feature Spec — <Feature Name>

**Date**: YYYY-MM-DD
**Status**: Draft / Final
**Related design**: `design.md` *(if applicable)*

---

## Objective

<What is being built, for whom, and the user value.>

## User Goal

As a <user type>, I want to <action> so that <outcome>.

## Scope

### In Scope

- <capability>

### Out Of Scope

- <explicit non-goal>

## Technical Spec

### Libraries & Dependencies

| Library / SDK | Version | Purpose |
|---------------|---------|---------|
| `<library>` | `<version or "latest">` | `<why it's used>` |

### Key Technical Decisions

- **<Decision area>**: `<chosen approach and rationale>`

### External APIs / Services

- `<API or service>` — `<what it provides and any rate/auth constraints>`

### Platform & Compatibility Constraints

- **Min SDK**: `<value or "project default">`
- **Permissions required**: `<list or "None">`
- **Other constraints**: `<e.g., requires camera, network, file access>`

---

## Functional Requirements

- **FR-001**: System MUST <specific capability>.
- **FR-002**: User MUST be able to <specific interaction>.
- **FR-003**: System MUST <state, persistence, validation, or navigation behavior>.

## Acceptance Criteria

- **AC-001**: Given <state>, when <action>, then <observable result>.
- **AC-002**: Given <state>, when <action>, then <observable result>.

## Data And Persistence

- <local state, saved state, database, API, or "No persistence required">

## Edge Cases

- <edge case and required behavior>

## Explicit Assumptions

| # | Assumption | Risk if Wrong |
|---|------------|---------------|
| A1 | <assumption> | <impact if assumption is false> |

## Open Questions

All questions must be ✅ Answered before this document is approved.

| # | Question | Status | Answer |
|---|----------|--------|--------|
| Q1 | <question> | ⚠️ Unanswered / ✅ Answered | <answer> |

<!-- INCLUDE IF: new screen or major UI change -->

## Screen States

| State | Requirement | Acceptance Criteria |
|-------|-------------|---------------------|
| Loading | <requirement> | <AC IDs> |
| Empty | <requirement> | <AC IDs> |
| Content | <requirement> | <AC IDs> |
| Error | <requirement> | <AC IDs> |

## Navigation

- **Entry**: <route or source screen>
- **Back/cancel**: <exact behavior>
- **Success**: <destination or state>
- **Error recovery**: <destination or state>

## Traceability

| Requirement | Design Section | Acceptance Criteria |
|-------------|----------------|---------------------|
| FR-001 | <section> | AC-001 |

<!-- END CONDITIONAL -->

## Verification Expectations

- **Unit**: <state/reducer/domain behavior to test>
- **Integration**: <repository/API/persistence behavior to test, or "Not required">
- **Instrumented UI**: <screen rendering and user journey to test>
- **Manual/visual**: <visual checks or screenshots required>

## No Open Questions Gate

- [ ] All requirements are specific and testable.
- [ ] All non-goals are explicit.
- [ ] No unresolved assumptions remain.
- [ ] All visual states are defined in `design.md` *(if new screen)*.
- [ ] All navigation outcomes are defined *(if new screen)*.
