---
name: implementation-plan
description: Generates a detailed implementation and test plan before coding.
---

# Skill — Implementation Plan

## Purpose
Produce a concrete, reviewable plan before any code is written.
This is the final gate before implementation begins.

---

## Load
- `skills/incremental-implementation/SKILL.md`
- `rules/testing-strategy.md`
- `harness/templates/implementation-plan-template.md`
- `harness/templates/test-plan-template.md`
- `docs/current/spec_v<N>.md` (Requirement, Impact & Design Analysis stage output)

---

## Execute

### Step 1: Generate Implementation Plan
Using all outputs from the **Requirement, Impact & Design Analysis** stage, compile a complete implementation plan. 

> [!IMPORTANT]
> You **MUST** follow the structure and sections in [implementation-plan-template.md](../../harness/templates/implementation-plan-template.md) exactly.

The implementation plan must include:
- **File Breakdown**: List all files to create, modify, or delete.
- **Domain Models**: Detail any new or modified domain model fields.
- **API & DTO Layer**: Outline DTO changes and defensive parsing logic.
- **OpenAPI Verification**: 
  - Check if any new/modified endpoints are in `sharedContracts/openapi.yaml`.
  - If not, explicitly list the OpenAPI spec changes required.
- **UiState Implementation**: Define the new fields and states matching the spec's designed state structure.
- **Navigation Flow**: Reference routes, arguments, and backstack details from the design.
- **Risks & Mitigations**: Identify technical risks (such as payload changes, synchronization issues, database migration) and document their mitigation strategies.

### Step 2: Generate Test Plan
Create a separate, comprehensive test plan document following [test-plan-template.md](../../harness/templates/test-plan-template.md).

The test plan must include:
- **Test Layer Selection**: Read `rules/testing-strategy.md` to decide the minimum test layers needed (start at the lowest layer that provides enough confidence).
- **Required Tests Coverage**: Check the active task's "Required tests" table in `docs/current/task-list.md` and ensure all specified test cases are explicitly covered in your test plan.
- **Test Case Definition**: Define test cases per class (Mapper, ViewModel, UI) with Given/When/Then and a unique ID for each test case.
- **API Integration Tests**: **MANDATORY** to include at least one integration test using a shared JSON scenario for each affected API endpoint.

---

## Output

Write `docs/current/implementation_plan_v<N>.md` (follow `harness/templates/implementation-plan-template.md`).
Write `docs/current/test_plan_v<N>.md` (follow `harness/templates/test-plan-template.md`).
Update `summary_v<N>.md`: mark the Implementation Plan stage complete.

---

## Done When — ⛔ MANDATORY STOP

**You MUST stop here and present the implementation plan to the user.**

### Feedback Loop
1. **Feedback**: The user provides feedback via chat, file comments, or direct edits to the plan.
2. **Iteration**: If feedback requires changes to requirements or design, the agent **MUST return to the Requirement, Impact & Design Analysis stage** to update the analysis/spec first. Then, update `implementation_plan_v<N>.md` and request approval again.
3. **Approval**: The agent returns to the active workflow file and proceeds to the next stage defined there.

Do not write any code, create any source files, or call any file-editing tools until the user explicitly approves.

**APPROVED by user →** Return to the active workflow file and proceed to the next stage defined there.
