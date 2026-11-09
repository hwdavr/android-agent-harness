# Feature Acceptance Test Plan — <feature> v<N>

Plan Stage 2 acceptance for one build, platform, device, and environment. Keep execution
results, approvals, findings, and cleanup receipts in the suite report and execution leaves.
Follow the [test-design skill](../../.agents/skills/test-design/SKILL.md),
[feature-acceptance workflow](../../.agents/workflows/feature-acceptance.md), and
[artifact layout](../../.agents/skills/exploratory-qa/references/artifact-layout.md).

## Scope and target

- Suite ID / feature / platform: `<suite-id>` / `<feature>` / `<platform>`
- In scope / out of scope: `<journeys and exclusions with reasons>`
- Merged PR / branch / SHA: `<references>`
- QA artifact / hash / installed identity and provenance: `<references and receipts>`
- Device / OS / locale / environment / account alias: `<verified values>`
- Fixtures, contracts, settings, and their hashes: `<references or explicit absence>`
- Existing tests, replays, and prior evidence: `<paths and hashes or explicit absence>`

## Sources and Rule Applicability

| Source / section | Revision or SHA-256 | Approval reference / purpose |
|---|---|---|
| `<approved spec, design, API or tracking contract>` | `<revision or hash>` | `<approval evidence and use>` |

Canonical Rule Applicability: `<approved spec path>#rule-applicability`. Map applicable
decisions to cases or gaps below; do not duplicate the matrix. Record missing approvals,
conflicts, or absent sources as gaps.

## Acceptance coverage and execution order

| Requirement / AC ID | Selected case ID(s) or gap | Priority / release criticality and rationale |
|---|---|---|
| `<ID>` | `<case or gap ID>` | `<decision or owner needed>` |

Out-of-scope ACs and reasons: `<IDs and reasons, or none>`.

Execution order and prerequisites: `<case order, dependencies, isolation and reset>`.

## Case overview

| Case ID | Requirement / AC IDs | Priority / release criticality | Preconditions / fixture | Expected outcome |
|---|---|---|---|---|
| `<CASE-01>` | `<IDs>` | `<priority, criticality, rationale>` | `<starting state and references>` | `<observable outcome>` |

## Detailed cases

### <CASE-01> — <title>

- Requirements / source oracle: `<IDs and approved source sections>`
- Preconditions / isolation: `<device, account, data, fixture and reset>`
- API mode: `real | hybrid | mocked`; operations and real-backend limitations: `<details>`
- Mappings / fixture hashes / hit bounds: `<references, or feature-specific reason not needed>`
- Existing replay / test / contract: `<path and hash, or explicit absence>`
- Evidence: `<UI, backend, HarnessLens and analytics evidence, or reason each is not required>`

1. `<Perform a specific user action and observe its bounded result.>`
2. `<Perform the next action; assert each outcome against its source oracle.>`
3. `<For timeouts or repeated submissions, specify follow-up and the relevant status or idempotency oracle.>`
4. `<Export evidence and perform the case-specific cleanup.>`

Assertions: `<unique assertion IDs, expected values, independent oracles, and observation bounds>`.
Repeat this section for every case in the overview. Keep actual outcomes in the suite report.

## Coverage gaps

| Gap ID / affected AC | Missing or ambiguous capability, source, or oracle | Impact / criticality | Owner and resolution needed |
|---|---|---|---|
| `<G-01 / IDs>` | `<detail>` | `<impact>` | `<owner and action>` |

## Exploratory risk targets

Budget: `<minutes>` or `<actions>`, whichever comes first. Exploration follows approved
planned cases and uses a separate execution leaf.

| Risk ID / priority | Hypothesis and screen, state, or transition | Starting investigation / fault condition |
|---|---|---|
| `<R-01>` | `<risk>` | `<suggested investigation>` |

## Cleanup and approval inputs

- Per-case synthetic data cleanup and verification: `<procedure and receipts>`
- Provider, routing, device settings, and session restoration: `<procedure and original values>`
- Inputs bound for plan approval: `<source, contract, fixture, build, device, environment, scope, and budget hashes or identities>`
- Outstanding gaps for reviewer: `<gap IDs and owners>`

Present this complete versioned plan and stop for explicit approval before execution.
Record the actual response and approved plan/input hashes in the suite report.
