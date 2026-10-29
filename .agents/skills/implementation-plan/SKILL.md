---
name: implementation-plan
description: Create a detailed implementation and test plan before coding.
---

# Skill — Implementation Plan

## Purpose
Produce a concrete, reviewable plan before any code is written.
This is the final gate before implementation begins.

---

## Load
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read
- `rules/testing-practices.md`
- `harness/templates/rule-applicability-template.md`
- `harness/templates/implementation-plan-template.md`
- `harness/templates/test-plan-template.md`
- `docs/current/spec_v<N>.md` (Requirement & Impact Analysis output)
- Approved `docs/current/UI_contract.md` and its canonical Pen/reference mappings for UI scope.

When the approved `SEC` decision is `Required` or excepted, load
`rules/android-security.md` and carry its required boundary, failure-mode, and test
evidence into the plan.
Load `rules/testing-runtime-evidence.md` only when the planned evidence includes a
platform, instrumented runtime, end-to-end journey, or visual claim.

---

## Execute

### Step 1: Generate Implementation Plan
Using the clarified requirements and the approved outputs of the separate **UX Design** stage
for UI scope, compile a complete implementation plan.

Start by reading the approved **Rule Applicability** matrix in the active specification.
Link that exact `spec_v<N>.md#rule-applicability` record from both plans instead of
copying its ten decisions. Every `Required` row needs concrete work and verification
evidence. `Not applicable` and `Exception` rationales remain canonical in the
specification. Do not introduce analytics events or logs solely because their rows
exist.

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
- **UI State Stages**: For UI work, copy every Plan stage ID from `UI_contract.md` into its own
  implementation and runtime-verification row. Do not collapse selected subtools into one row.
- **Navigation Flow**: Reference routes, arguments, and backstack details from the design.
- **Risks & Mitigations**: Identify technical risks (such as payload changes, synchronization issues, database migration) and document their mitigation strategies.
- **Rule Applicability Implementation**: Link the canonical specification record and
  map every required rule to planned files and evidence; update the specification if a
  non-applicable or exception decision no longer holds.

### Step 2: Generate Test Plan

Classify each verification item as maintained regression or ephemeral exploration before
selecting a test layer. Temporary WireMock/device exploration uses `exploratory-qa` with
`agent-device`, run-scoped fixtures/evidence, and cleanup; do not turn it into an
`androidTest` class or CI dependency. Apply the per-endpoint integration requirement below
to maintained API changes/tests, not endpoints merely exercised in an ephemeral QA run.
Populate the test template's `Ephemeral Test Cases` section when that lane is selected:
use a concise table for each QA ID, intent, fixture/preconditions, and expected outcome,
then provide concrete, ordered, numbered execution steps for every QA ID below the table.
Include real device actions, request/result verification checkpoints, and planned cleanup.
The test plan contains planned procedures only; do not add execution records, actual results,
or collected evidence links. Record `Not run` and subsequent outcomes, observations, run/build/
device identity, evidence links, and cleanup receipts in `summary_v<N>.md`, keyed by QA ID.
Keep verbose artifacts under `.qa-artifacts/<run-id>/` and link them from the summary.
Create a separate, comprehensive test plan document following [test-plan-template.md](../../harness/templates/test-plan-template.md).

The test plan must include:
- **Test Layer Selection**: Use `testing-strategy.md` (already loaded) to decide the minimum test layers needed (start at the lowest layer that provides enough confidence).
- **Required Tests Coverage**: Check the active task's "Required tests" table in `docs/current/task-list.md` and ensure all specified test cases are explicitly covered in your test plan.
- **Test Case Definition**: Define test cases per class (Mapper, ViewModel, UI) with Given/When/Then and a unique ID for each test case.
- **API Integration Tests**: **MANDATORY** to include at least one integration test using a shared JSON scenario for each affected API endpoint. If the claim requires the real app process and Retrofit/OkHttp, the owning test may live in `app/src/androidTest/` beside a loopback server; name the server harness, shipped-client path, receipts, and runtime gate explicitly.
- **Rule-Driven Verification**: Link the canonical specification record and map each
  required applicability row to test IDs, static checks, review evidence, or an
  explicit reason no executable test is needed.

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
2. **Iteration**: Route visual feedback to the separate UX Design stage and update only its design
   artifacts. Return to requirements analysis only when behavior, scope, data, navigation, or the
   required state inventory changes. Plan-only feedback stays in this stage. Reconcile the affected
   plan/test bindings after an approved design or requirements change and request plan approval again.
3. **Approval**: The agent returns to the active workflow file and proceeds to the next stage defined there.

Do not write any code, create any source files, or call any file-editing tools until the user explicitly approves.

**APPROVED by user →** Return to the active workflow file and proceed to the next stage defined there.
