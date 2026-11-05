---
name: test-design
description: Select traceable post-merge mobile feature acceptance cases and separate exploratory risk targets.
---

# Feature acceptance test design

Use only for Stage 2 post-merge Android/iOS feature acceptance. Decide **what** planned
tests to run and which risks merit exploration. The
[feature-acceptance workflow](../../workflows/feature-acceptance.md) owns approval,
orchestration and release gating; [exploratory-qa](../exploratory-qa/SKILL.md) executes
the approved plan and performs separate adaptive investigation.
Do not replace pre-PR implementation/test planning or execute deterministic cases here.

## Select the evidence sources

1. Read the approved feature requirements and acceptance criteria with stable IDs and
   approval references, UI contract/design where relevant, API/OpenAPI and tracking
   contracts, existing feature tests/shared scenarios, prior defects and relevant dependency
   contracts. Resolve paths from the consuming app root. Use supplied artifacts or linked
   `docs/current/`, `.scratch/`, or dated `docs/product/` feature records; do not assume the
   newest document belongs to this feature. Read affected living capability requirements.
2. Record each source's path/section, revision/hash and approval evidence. Link the approved
   spec's canonical Rule Applicability decisions; do not duplicate or change its matrix.
   Missing approval, conflicting contracts, ambiguous outcomes or unavailable test oracles
   are coverage gaps. Code can reveal routes, selectors, dependencies and instrumentation;
   it cannot define expected business behavior. Never invent an AC or silently amend it.
3. Identify relevant feature journeys and business invariants, including durable outcomes,
   ownership/authorization, idempotency or recovery where specified. Inventory dependencies
   and entry points that can alter those outcomes. Review existing unit/integration coverage
   to avoid repeating its input matrix at the UI layer.

## Choose a small representative set

Map every in-scope requirement/AC to one or more representative feature-level cases or an
explicit gap/defer reason. Prioritize critical positive, negative and recovery journeys
required by the AC or business impact. Assign priority and release criticality **before**
execution, with a rationale; keep them distinct from a discovered defect's severity.

Choose independent oracles and evidence channels capable of proving each outcome; respect
[API evidence limits](../api-mocking/SKILL.md#ownership-and-evidence). A missing critical
oracle is a coverage gap, never a reason to weaken the assertion.

Search and reuse existing tests, stable `.ad` replays, shared scenarios, native WireMock
mappings, synthetic fixtures and validation contracts first. Record exact paths/hashes or
an explicit absence. A lower-layer test is supporting evidence, not proof this integrated
build passed a device journey. Use the [shared artifact layout](../exploratory-qa/references/artifact-layout.md)
and exploratory-qa's [ephemeral execution scope](../exploratory-qa/SKILL.md#target-and-scenario)
for temporary assets.

Classify each case's API mode using [api-mocking's backend policy](../api-mocking/SKILL.md):

- `real`: approved staging APIs; list the relevant services and backend oracle.
- `hybrid`: selected hard-to-reproduce failures/delays/orderings mocked, with other requests
  using real staging. Explain why control is needed and name mocked/real operations.
- `mocked`: selected feature interactions are synthetic; state precisely which real-backend
  claims remain unproven and whether another real case is required.

Reference separate fixture files and mapping names in cases; keep response bodies out of
ACs and steps. Delegate matching, timeout injection, passthrough and verification to api-mocking.

## Produce the test plan

Use one `test_plan_v<N>.md` in `.qa-artifacts/<suite-id>/`, based on the existing
[test plan template](../../../harness/templates/test-plan-template.md), for Phase 1.
Reuse the existing approved test plan when it already covers the exact acceptance scope
and bound inputs. If details are missing, revise that plan for user review rather than
creating a parallel acceptance plan. The [node-sharing example](examples/node-sharing.md)
shows the case/coverage/risk distinction within one Markdown plan.

Use the template's case overview and numbered detailed steps for every case; table rows
alone are not an executable plan. Put traceability and exploratory targets in separate
sections of this same plan, with expected observations and evidence beside each case.
Link existing regression evidence and mark inapplicable implementation/test-authoring
sections with a Stage 2 scope-specific reason. Do not modify the shared template or
generate Stage 1 tests. Keep actual observations/statuses in the suite's `suite-report.md`
and execution evidence, outside the approved test plan.

Required plan content:

- Scope and sources: feature, platform, suite ID, exact scope, provenance and approval references.
- Acceptance coverage: every in-scope requirement/AC ID, selected case IDs or gap IDs. List out-of-scope
  ACs separately with reasons. Preserve the approved criticality or record who must decide it.
- Execution order: deterministic case IDs, prerequisite relationships and isolation/reset needs.
- Test cases: unique ID and feature; requirement/AC IDs; priority/risk and release criticality; preconditions
  and fixture references; ordered user actions; expected outcome; individually identified
  assertions with source oracle and bounded observation; required UI/backend/HarnessLens/
  analytics evidence (or a feature-specific reason a channel is not required); API mode,
  real/mocked operations and separate mock scenario references; existing test/replay/contract
  references; cleanup. Include required mapping names/hit bounds and post-timeout follow-up
  requests. Bind a repeated submission to the business idempotency oracle, not just HTTP counts.
- Coverage gaps: AC ID, ambiguity/missing capability/oracle, impact/criticality, owner and
  needed clarification/evidence. A gap never counts as covered.
- Exploratory risk targets: separate IDs, risk hypothesis, relevant screen/state/transition,
  suggested fault conditions and priority. These are optional investigative starting points,
  not ordered mandatory cases or AC coverage claims. Include a proposed time/action budget.

Before handing off, check every case has a fixed assertion/oracle and evidence requirement,
all IDs/references resolve, every in-scope AC is accounted for, critical gaps are visible,
mocks are selective and external, and exploratory targets are outside the planned case order.
Return the plan path, gaps and reusable assets to the workflow's
[plan review](../../workflows/feature-acceptance.md#generate-the-test-plan-and-request-review--stop).
Planning produces no execution or release-readiness claim.

Example invocation: “Use `$test-design` for the merged `<feature>` QA build and approved
spec `<path>`; save the Stage 2 plan under `.qa-artifacts/<suite-id>/`, defaulting to real staging.”
