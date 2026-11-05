---
description: Gate post-merge Android/iOS feature acceptance with planned cases and separate exploratory risk findings.
---

# Workflow: Feature Acceptance — Stage 2

Use after a PR has merged into the integration/QA branch and before release promotion.
This workflow consumes approved requirements and the integrated QA build. It does not
change Stage 1 implementation, development verification, review, or merge gates.

| Owner | Responsibility |
|---|---|
| [test-design](../skills/test-design/SKILL.md) | Select planned acceptance cases and identify separate exploratory risk targets. |
| This workflow | Obtain plan approval, invoke QA execution, consolidate evidence and manage the release gate. |
| [exploratory-qa](../skills/exploratory-qa/SKILL.md) | Execute the approved test plan, then investigate separate risk targets adaptively; keep results distinct. |
| [api-mocking](../skills/api-mocking/SKILL.md) | Own backend routing, fixtures, isolation, verification and mock cleanup. |

Invoke skills through the available skill interface. If unavailable, read the complete
linked `SKILL.md`, follow it, and record the unavailable interface in the suite's
`suite-report.md` under `Run context`.

## Phase 0 — Bootstrap

Prepare the run and inspect prerequisites without starting device journeys, changing
routing, applying mocks, mutating QA data or starting captures. Activate those resources
only after the Phase 1 test-plan review and explicit user approval.

1. Create the suite and `suite-report.md` using the shared
   [artifact layout and Run context contract](../skills/exploratory-qa/references/artifact-layout.md).
   Keep each platform/build/device/environment combination in a separate suite.
2. Verify the commit was merged into the named branch and the CI artifact was built
   from it. Compare **the installed app** with that artifact: package/bundle ID,
   versionName/versionCode or CFBundleShortVersionString/CFBundleVersion, signing/build
   metadata and installed artifact identity where available. Version text alone cannot
   establish the SHA. Retain installation/package inspection receipts and CI provenance;
   absent or conflicting identity is INCONCLUSIVE. Do not substitute the checkout HEAD.
3. Select approved disposable QA accounts, isolated fixture identifiers and devices.
   Use QA/debug builds for internal instrumentation. No production operations, customer
   accounts or real payment instruments. Use synthetic data and approved staging APIs.
   Discover the actual app ID; example IDs in existing skills are not target defaults.
4. Inspect device/capture prerequisites through [exploratory-qa](../skills/exploratory-qa/SKILL.md)
   and backend prerequisites through [api-mocking](../skills/api-mocking/SKILL.md).
   Record required capability gaps and optional limitations; do not add instrumentation
   or install/upgrade tools during acceptance. Verify physical iOS capture support separately.
5. Bootstrap failure still proceeds to consolidation and cleanup with partial evidence.

## Phase 1 — Planned feature acceptance

### Generate the test plan and request review — STOP

Before executing any case, invoke `test-design` to finalize
`.qa-artifacts/<suite-id>/test_plan_v<N>.md` with the verified build/environment and
available capabilities. Follow its [plan-content contract](../skills/test-design/SKILL.md#produce-the-test-plan)
without maintaining another case schema here.

Present the complete versioned test plan to the user, highlight gaps and the proposed
exploration budget, and **stop for explicit approval before planned execution or Phase 2**.
Record the actual user response, approver/date and approved plan version/SHA-256 in the
suite's `suite-report.md` under `Approval`, binding the plan's source/contract/fixture hashes, build/artifact,
platform/device, environment and exploration scope/budget. Never invent approval or infer
it from silence. On resume, verify that those inputs still match. If they change, revise
the plan and request approval again before affected planned execution; preserve prior versions/results.
Keep approval entries unchanged when appending results or renewed approvals. Hash the
approved plan and bound inputs, not the evolving report that contains the approval record.

After explicit approval, invoke [exploratory-qa](../skills/exploratory-qa/SKILL.md) in
**approved-plan** mode to execute `test_plan_v<N>.md`. Pass the approved test plan,
the suite's `Approval` record and the bound inputs required by that mode. Collect every
case/attempt result and evidence link under `Planned acceptance`; the skill owns execution.

### Mock-flow replanning

When real-server testing is blocked, preserve its attempt and unproven backend assertions
as INCONCLUSIVE. Invoke `exploratory-qa` in **acceptance-support** mode to investigate an
isolated mock flow within the approved exploration scope/budget; obtain approval for that
investigation first if it is not covered. Apply api-mocking's
[local-state boundary](../skills/api-mocking/SKILL.md#local-state-side-effects).

Then invoke `test-design` to revise the plan with the investigated flow, API mode,
fixture hashes, restoration and remaining real-backend evidence gaps. Return to
[plan review](#generate-the-test-plan-and-request-review--stop) for renewed explicit approval
before running the revised acceptance cases. Preserve prior plans, approvals and attempts;
continue unchanged independent cases where safe. An execution addendum cannot replace this approval.

## Phase 2 — Exploratory QA

Invoke `exploratory-qa` in **acceptance-support** mode with feature scope, separate risk
targets, planned coverage/results and gaps, environment/build identity, available mock
providers, suite ID and an explicit time/action budget (for example 20 minutes/60 actions,
stopping at whichever limit is reached first). Use fresh execution leaves from the shared
artifact layout. Collect the skill's findings and stop reason under `Exploratory findings`;
follow its [adaptive investigation procedure](../skills/exploratory-qa/SKILL.md#adaptive-investigation-in-acceptance-support-mode).

## Phase 3 — Consolidate and gate

Consolidate results using the shared [suite report contract](../skills/exploratory-qa/references/artifact-layout.md#suite-report).
An AC is covered only when all its required selected cases/assertions PASS. List unselected
ACs with rationale; report any ratio only over the explicitly enumerated approved AC set.
A leaf reporter's PASS covers only its declared checks; verify the approved case's complete
oracles before assigning AC coverage. Exploration contributes risk evidence separately.

Apply these gate rules in order; evidence tables are required, not optional narrative:

1. Critical planned acceptance FAILs or confirmed critical exploratory defects → BLOCKED.
   A missing critical oracle/evidence, broken environment, unknown build identity, critical
   SKIPPED/INCONCLUSIVE case or unresolved critical AC gap → INCONCLUSIVE when no known
   critical defect already blocks. Both recommendations prohibit release promotion.
2. Noncritical failures/gaps and exploratory hypotheses remain explicit risk decisions with
   owner and disposition. They do not automatically fail other acceptance cases. An unresolved
   risk needing an owner decision prevents a ready recommendation. Never downgrade criticality
   during execution to obtain a passing gate.
3. Passing planned cases contribute to readiness. Exploration contributes a separate risk
   assessment. `READY FOR HUMAN SIGN-OFF` requires complete critical planned proof, no open
   critical defects, completed bounded exploration (or an explicit human disposition of its
   missing investigation), disposition of residual risks and verified cleanup. It authorizes
   neither deployment nor promotion; human product/UAT/release sign-off still applies.
4. Post-merge defects go through a fix PR or authorized revert. Test the resulting integrated
   QA build in a new run with targeted revalidation plus related acceptance/recovery checks;
   do not patch the app or redefine ACs inside an acceptance session. Link old/new builds and
   evidence. Never overwrite the failing report or mark lifecycle status from exploration alone.

## Phase 4 — Cleanup (always)

Require [exploratory-qa cleanup](../skills/exploratory-qa/SKILL.md#cleanup) for every activated
run, including interrupted or failed runs. Verify receipts in the suite's `Cleanup` section
against the original settings and resources. Failed/unverified restoration makes readiness
INCONCLUSIVE unless already BLOCKED; finalize the release recommendation only after this check.

## Invocation examples

- “Follow `.agents/workflows/feature-acceptance.md` for merged PR 42, integration SHA
  `<sha>`, Android QA build `<artifact>`, staging deployment `<version>`, and approved spec
  `<path>`. Use a 20-minute/60-action exploratory budget.”
- “Repeat Stage 2 for the iOS QA artifact `<artifact>` on simulator `<UDID>` with the same
  approved ACs; record unavailable instrumentation separately.”

See the [node-sharing test plan](../skills/test-design/examples/node-sharing.md) for the
planned/exploratory distinction. It is illustrative and does not replace approved product requirements.
