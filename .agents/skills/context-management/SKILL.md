---
name: context-management
description: Optimizes agent context setup. Use when starting a new session, when agent output quality degrades, when switching between tasks, or when you need to configure rules files and context for a project.
---

# Context Management

## Session Start — Load in Order

1. `AGENTS.md`
2. `rules/android-architecture.md`
3. `rules/testing-strategy.md`
4. The workflow file that matches the task
5. The skill(s) for the current stage only
6. Source files for the specific feature area (ViewModel, use case, repository interface)

**Rule:** Never preload all skills at once. Load what the current stage requires.

---

## What to Load per Layer

| Layer | Load these files |
|-------|-----------------|
| UI / Presentation | Screen composable · `UiState` · ViewModel · UI model · mapper |
| Domain | Use case · domain model · repository interface |
| Data | Repository impl · DAO · DTO · mapper |

---

## Workflow Selection

| Task type | File to load |
|-----------|-------------|
| New feature or enhancement | `workflows/feature-delivery.md` |
| Bug, crash, or regression | `workflows/bug-fixing.md` |
| UI implementation or update | `workflows/create-ui-and-verify.md` |
| API contract change | `workflows/api-contract-update.md` |

---

## Project Map Quick Reference

| Directory | Contains |
|-----------|----------|
| `app/src/main/java/...` | App code (`ui/`, `domain/`, `data/`) |
| `app/src/test/` | Unit and integration tests (JVM) |
| `app/src/androidTest/` | Instrumented UI tests |
| `sharedContracts/` | API specs and shared JSON test scenarios |
| `docs/knowledge/` | Historical decisions and known pitfalls |

---

## Context Drift — Warning Signs

- Wrong package structure or naming conventions
- Composable calling a repository directly
- `Thread.sleep` in tests instead of `waitUntil`
- Hardcoded strings instead of `stringResource()`
- Missing `testTag` on interactive elements
- `LiveData` instead of `StateFlow`
- DTO outside the data layer
- Hallucinated class names

## Context Drift — Recovery

1. Stop generating code
2. Re-read the violated rule file
3. Re-read the affected source files
4. State the correction explicitly before rewriting

---

## Session Start Checklist

- [ ] `AGENTS.md` + both rule files loaded
- [ ] Correct workflow identified
- [ ] Only current-stage skill(s) loaded
- [ ] Feature-area source files loaded
- [ ] No unresolved assumptions
