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
- `rules/android-architecture.md`
- `rules/testing-strategy.md`
- `harness/templates/rule-applicability-template.md` as the conditional-rule trigger catalog
- Load `rules/compose-rules.md`, `rules/localization-rules.md`, `rules/api-contract-rules.md`,
  `rules/navigation-rules.md`, `rules/observability.md`, `rules/analytics-rules.md`, and
  `rules/android-security.md`
  only after their row is `Required`, excepted, or newly triggered by inspected scope.

---

## Execute

### 1. Requirement & Impact Analysis
1. Read the user's feature request in full. Do not assume anything that is not explicitly stated.
2. Search the codebase for all affected files (Screens, ViewModels, UseCases, Repos, DTOs, Tests).
3. Classify changes (`modify`, `extend`, `new`, `delete`).
4. **API & Contract Check**:
   - Classify API changes and state force update requirement.
   - **Identify needed APIs**: List all existing or new endpoints that must be called to fulfill the requirement.
5. **Rule Applicability**:
   - Copy the complete matrix from `harness/templates/rule-applicability-template.md`.
   - Record a decision for all ten rules before planning: `Required`, `Not applicable — <feature-specific reason>`, or `Exception — approved by <user/date>`.
   - For every `Required` row, record the concrete trigger and planned evidence. Do not delete a conditional-rule row when its trigger is absent.
   - Assess analytics and observability explicitly. Use `Not applicable — analytics: none` when no product event is justified; do not add logging or analytics only to satisfy the matrix.

### 2. UI State & Navigation Design
1. **Design UiState**: For any new or modified screen, define all possible states (Loading, Success, Empty, Error).
   - Prefer a single immutable `data class`.
2. **Design Navigation**: If navigation is affected, define routes, serializable arguments, and back-stack behavior.
3. **DI Scope**: Identify the required Hilt scope for new components (`@Singleton`, `@ViewModelScoped`).

---

## Output

Create `docs/current/` if needed. Choose the next unused `v<N>` and preserve existing artifacts; never delete an earlier feature's evidence.

If the user provides a design screenshot or mockup, save it to **`docs/current/design/`** so it can be referenced during UI Verification.

Produce **`docs/current/summary_v<N>.md`** — create this file **first**, before `spec_v<N>.md`.
Use the template from `harness/templates/summary-template.md`.
The Stage Progress table must list every stage from the **active workflow** in order.
Load and copy only `harness/templates/summary-profiles/<active-workflow>.md`; do not load inactive
profiles or maintain a second stage table in this skill.

All **Timestamp** values must be in `YYYY-MM-DD HH:MM` format:

**Type**: feature / bugfix / api / refactor
**Started**: YYYY-MM-DD HH:MM
**Status**: In Progress / Complete

Mark the first row as ✅ Complete when this stage's gate passes.

Produce **`spec_v<N>.md`** (inside `docs/current/`).
Use the template from `harness/templates/spec-template.md`.
- Record every assumption the analysis required — never silently fill an ambiguous requirement.
- Reframe vague requests into concrete, testable verification expectations the user can confirm.
- Include the complete **Rule Applicability** matrix with a concrete decision, trigger or rationale, and planned evidence for all ten rules.
- Keep the spec alive — when scope or decisions change, update `spec_v<N>.md` first.

---

## Done When

**This stage is complete when all of the following are true:**
- [ ] `docs/current/summary_v<N>.md` exists with the Stage Progress table filled in.
- [ ] `docs/current/spec_v<N>.md` exists with requirement, impact, and design sections filled.
- [ ] Every affected file is listed with a change type.
- [ ] UiState design covers all visual states.
- [ ] API change is classified.
- [ ] Rule Applicability contains all ten rows with no implicit or missing decision.

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.
