---
name: requirement-analysis
description: Analyze requirements, API impact, UI states, and navigation flow.
---

# Skill — Requirement & Impact Analysis

Follow `.agents/rules/product-documentation.md`. Read affected `docs/product/requirements/<capability>.md` files and update those same files for behavior changes. Keep dated change contracts/evidence in `.scratch/`. New specs include `## Product Requirements` with capability links, changed requirements, and approval-time SHA-256 hashes. Completion reconciles verified behavior or records `Confirmed unchanged` for an already-correct bug contract.

## Purpose
Clarify what is being built, identify affected files, and define UI-state and navigation behavior
before the separate UX Design stage. Visual layout, Pen edits, and mockup exports belong to UX.
Do not write any code in this stage.

---

## Load
- `rules/android-architecture.md` (skip if already loaded this session — L1 is session-scoped)
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read
- `harness/templates/rule-applicability-template.md` as the conditional-rule trigger catalog
- Load `rules/compose-rules.md`, `rules/localization-rules.md`, `rules/api-contract-rules.md`,
  `rules/navigation-rules.md`, `rules/observability.md`, `rules/analytics-rules.md`, and
  `rules/android-security.md`
  only after their row is `Required`, excepted, or newly triggered by inspected scope.

---

## Execute

### Entry from an existing Exploratory QA finding

When bug-fixing receives a QA report, use `harness/scripts/read-qa-bug-context.py --report <report.json> --finding <id>`.
Reuse its target, steps, expected/actual result, and evidence as the runtime reproduction; record the report/finding
references in the bug spec's `## Exploratory QA Handoff`. Inspect the relevant current source for the root cause
and load only missing requirement/UI-contract context. Reuse existing approved states when they cover the defect.
Do not repeat the QA session or copy its full report. Fill only a demonstrated evidence gap; source-fingerprint
changes call for relevance review rather than an automatic full device replay.

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
   - Inspect existing runtime controls and flows. Enumerate each visually distinct screen/state
     pair in the spec's `## Screen States` table; include selected subtools and overlays, not only
     loading/content/error categories. Record what the user sees and can do in each state.
     Hand this inventory to UX Design; do not require images, Pen nodes, or `UI_contract.md`
     to complete feature-delivery requirements analysis.
2. **Design Navigation**: If navigation is affected, define routes, serializable arguments, and back-stack behavior.
3. **DI Scope**: Identify the required Hilt scope for new components (`@Singleton`, `@ViewModelScoped`).

---

## Output

Create `docs/current/` if needed. Choose the next unused `v<N>` once for a new delivery and
preserve existing artifacts. Reuse that active version during the delivery; visual revisions
do not allocate new spec or summary versions.

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
- Update the spec only when clarified behavior, scope, data, navigation, or the required state
  inventory changes. Visual feedback within that contract stays in the UX Design stage.
- For UI changes, hand the state inventory and preserved visual inputs to `ux-design`.
  Workflows with their own bug/reference gates retain those gates; this skill does not generate designs.
- Update the summary at this stage's completion, approval, or a blocker, not after each visual edit.

---

## Done When

**This stage is complete when all of the following are true:**
- [ ] `docs/current/summary_v<N>.md` exists with the Stage Progress table filled in.
- [ ] `docs/current/spec_v<N>.md` exists with requirements, impact, and state/navigation behavior filled.
- [ ] Every affected file is listed with a change type.
- [ ] UiState design covers all visual states.
- [ ] For UI changes, the required screen/state inventory is ready for the separate UX Design stage.
- [ ] API change is classified.
- [ ] Rule Applicability contains all ten rows with no implicit or missing decision.

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.
