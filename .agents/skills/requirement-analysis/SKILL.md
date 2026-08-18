---
name: requirement-analysis
description: Analyzes requirements, classifies APIs, and designs UI states and navigation flow.
---

# Skill — Requirement, Impact & Design Analysis

## Purpose
Understand what is being built, identify affected files, and design the core UI state and navigation before implementation.
Do not write any code in this stage.

---

## Load
- `skills/spec-driven-development/SKILL.md`
- `rules/android-architecture.md`
- `rules/api-contract-rules.md`
- `rules/navigation-rules.md`
- `rules/testing-strategy.md`

---

## Execute

### 1. Requirement & Impact Analysis
1. Read the user's feature request in full. Do not assume anything that is not explicitly stated.
2. **Read `harness/templates/evaluator-rubric-template.md`** for final quality evidence and issues that require follow-up.
3. Search the codebase for all affected files (Screens, ViewModels, UseCases, Repos, DTOs, Tests).
4. Classify changes (`modify`, `extend`, `new`, `delete`).
5. **API & Contract Check**:
   - Classify API changes and state force update requirement.
   - **Identify needed APIs**: List all existing or new endpoints that must be called to fulfill the requirement.

### 2. UI State & Navigation Design
1. **Design UiState**: For any new or modified screen, define all possible states (Loading, Success, Empty, Error).
   - Prefer a single immutable `data class`.
2. **Design Navigation**: If navigation is affected, define routes, serializable arguments, and back-stack behavior.
3. **DI Scope**: Identify the required Hilt scope for new components (`@Singleton`, `@ViewModelScoped`).

---

## Output

Create `docs/current/` directory, if there are existing files, remove them inside the folder.

If the user provides a design screenshot or mockup, save it to **`docs/current/design/`** so it can be referenced during UI Verification.

Produce **`docs/current/summary_v<N>.md`** — create this file **first**, before `spec_v<N>.md`.
Use the template from `harness/templates/progress-template.md`.
The Stage Progress table must list every stage from the **active workflow** in order. Use the matching table below.
All **Timestamp** values must be in `YYYY-MM-DD HH:MM` format:

**Type**: feature / bugfix / api / refactor
**Started**: YYYY-MM-DD HH:MM
**Status**: In Progress / Complete

**`feature-delivery` workflow:**

| Stage | Status | Timestamp | Notes |
|-------|--------|-----------|-------|
| Requirement Analysis | ⏳ In Progress | YYYY-MM-DD HH:MM | |
| Implementation Plan | | | Approved by user: — |
| Implementation | | | |
| Testing | | | |
| Code Quality Fix | | | |
| Knowledge Capture | | | |

**`bug-fixing` workflow:**

| Stage | Status | Timestamp | Notes |
|-------|--------|-----------|-------|
| Bug Context & Root Cause | ⏳ In Progress | YYYY-MM-DD HH:MM | |
| Bug Reproduction | | | Reproduction test: RED |
| Fix Plan | | | Approved by user: — |
| Implementation | | | |
| Testing | | | |
| Code Quality Fix | | | APPROVED / REVISION REQUIRED |
| Knowledge Capture | | | |

**`api-contract-update` workflow:**

| Stage | Status | Timestamp | Notes |
|-------|--------|-----------|-------|
| Requirement Analysis | ⏳ In Progress | YYYY-MM-DD HH:MM | |
| Implementation Plan | | | Approved by user: — |
| Data Layer | | | |
| Domain Layer | | | |
| UI Layer | | | Skipped if no UI changes |
| Testing | | | |
| Code Quality Fix | | | APPROVED / REVISION REQUIRED |
| Knowledge Capture | | | Skipped if straightforward |

**`create-ui-and-verify` workflow:**

| Stage | Status | Timestamp | Notes |
|-------|--------|-----------|-------|
| UI Implementation | ⏳ In Progress | YYYY-MM-DD HH:MM | |
| UI Verification | | | Loop count: — |
| Code Quality Fix| | | APPROVED / REVISION REQUIRED |

Mark the first row as ✅ Complete when this stage's gate passes.

Produce **`spec_v<N>.md`** (inside `docs/current/`).
Use the template from `harness/templates/spec-template.md`.

---

## Done When

**This stage is complete when all of the following are true:**
- [ ] `docs/current/summary_v<N>.md` exists with the Stage Progress table filled in.
- [ ] `docs/current/spec_v<N>.md` exists with requirement, impact, and design sections filled.
- [ ] Every affected file is listed with a change type.
- [ ] UiState design covers all visual states.
- [ ] API change is classified.

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.
