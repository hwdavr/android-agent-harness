# Test Plan — Node sharing (illustrative)

This illustrates the existing test-plan template's case overview and detailed steps.
This is a note-node sharing example grounded in the consuming app's existing API/test
contracts. The AC IDs below illustrate a plan; obtain approved product requirements,
build identity and user approval before an actual run. Contract examples are not live
staging records or evidence that the installed application passed.

## Feature / Bug

Node sharing; suite `20261104-node-sharing-android-01`, Android QA build. Use a separate suite for
iOS. Resolve the exact integrated artifact/device/environment and approved sources before
review. Sources, resolved from the consuming app root:

- `sharedContracts/openapi.yaml`: list/create/update note-share operations.
- `sharedContracts/test-scenarios/note_share_invite_001.json`.
- `sharedContracts/test-scenarios/note_share_duplicate_invite_001.json`.
- `sharedContracts/test-scenarios/note_share_update_role_001.json`.

## Rule Applicability Test Mapping

Link the real approved specification's canonical Rule Applicability decisions and map its
Required rows to evidence. This illustrative example supplies no real approval/matrix.

## Layer Selection

Use ephemeral agent-device execution through exploratory-qa. Maintained unit/integration/
platform/visual test authoring is outside this example; link existing relevant tests as
supporting evidence. Reuse the listed shared scenarios as request/response and expected
outcome references. Search the consuming feature for matching tests, stable `.ad` replays
and WireMock mappings before creating temporary fixtures.

## Acceptance Coverage and Case Overview

| AC | Approved behavior for this example | Case | Priority / criticality | API mode |
|---|---|---|---|---|
| AC-01 | Inviting a new collaborator records a pending read-only share and shows success. | NS-01 | P0 / critical | Real staging |
| AC-02 | Inviting the same email to the same note returns a conflict and shows the duplicate-access error. | NS-02 | P0 / critical | Real staging |
| AC-03 | Updating an active collaborator from read-only to full access persists the new role and shows it in the member list. | NS-03 | P0 / critical | Real staging |

Execution order: NS-01, NS-02, NS-03. Use approved staging owner/collaborator accounts,
a verified QA build and isolated QA notes/memberships for each case. Use an authorized
QA invitation address; do not use customer accounts. Each attempt owns its scenario,
capture and request-evidence window. Resolve exact deadlines and required tracking/state
oracles from approved requirements. No selective mock is needed for these representative
cases; controlled delays/faults remain separate exploratory targets unless an AC requires them.

## Ephemeral Test Cases

### NS-01 — Invite a collaborator

Risk: the UI claims sharing succeeded without the expected membership being recorded.
Preconditions: a QA-owned note and an invitation address with no existing share on that note.
Contract reference: `note_share_invite_001.json`.

1. Open the QA note's sharing flow, enter the approved QA invitation address, select
   read-only access and submit once through the real UI.
2. Within the approved response deadline, assert invite success with no error, using
   AC-01 and the scenario's `expected.ui` as oracles; capture screenshot/accessibility evidence.
3. Verify the app-originated POST returned 201 and list the note's shares through the
   approved staging verification API. Assert the correlated membership has the expected
   address, `accessRole: read_only` and `status: pending`; retain sanitized evidence.
4. Verify required fresh HarnessLens success state and approved invite-event
   analytics contracts, or record the approved feature-specific reason they are not required.

### NS-02 — Reject a duplicate invitation

Risk: repeated invitations create conflicting memberships or misleading success feedback.
Preconditions: an isolated QA note with an existing share for the selected QA address.
Contract reference: `note_share_duplicate_invite_001.json`.

1. Record the existing membership identity, then submit an invitation for the same
   address on the same QA note through the real UI.
2. Verify the correlated POST returns 409. Assert invite success is false and the UI
   shows the scenario's duplicate-access error, using AC-02 and `expected.ui` as oracles.
3. Verify that the existing membership remains and no duplicate membership was created
   through the approved staging verification API; HTTP receipt counts alone are insufficient.
4. Save screenshot/accessibility and network/backend evidence, plus any required fresh
   HarnessLens error state and approved analytics verification.

### NS-03 — Update collaborator access

Risk: the visible role disagrees with the persisted access grant.
Preconditions: an isolated QA note with an active read-only collaborator.
Contract reference: `note_share_update_role_001.json`.

1. Open the note's shared-user list, select the collaborator and change the role to full access.
2. Within the approved response deadline, verify the correlated PATCH returns 200 and
   assert the member list displays the scenario's full-access label, using AC-03 and
   `expected.ui` as oracles.
3. Read the authoritative membership through the approved staging verification API;
   assert the same share ID remains `active` with `accessRole: full_access`.
4. Preserve the action timeline, screenshot/accessibility and network/backend evidence,
   plus any required fresh HarnessLens role state and approved role-change event verification.

## Session Cleanup

Export/verify request and capture evidence before resetting owned mappings, scenarios
and matched journals. Restore original routing and clean only isolated QA data through
approved staging procedures. Preserve sanitized correlation evidence and earlier attempts.
Keep actual observations/statuses in execution reports, outside this plan.

## Coverage Gaps

Before a real run, resolve approved source paths/hashes, build/device/environment,
product ACs, exact response deadlines, QA note/member fixtures, exported hooks and
required tracking assertions. These are critical gaps until resolved by the requirement
owner; this example cannot establish passing acceptance or authorize execution.

## Exploratory Risk Targets — Separate from Planned Cases

Budget: 20 minutes or 60 actions, whichever is reached first. Prioritize these hypotheses
adaptively, using the observed state to choose the next action:

| Target | Risk hypothesis / transition | Suggested fault condition | Priority |
|---|---|---|---|
| R-01 | Repeated invite taps may bypass guards: ready → submitting → result. | Double-tap at varied loading/response boundaries. | High |
| R-02 | Backgrounding may lose pending invite/role identity: pending → background → foreground. | Background while pending, then restore the app. | High |
| R-03 | A delayed member-list refresh may fail to recover: loading → disconnected → restored. | Delay the read, then restore the network. | High |
| R-04 | Late responses may restore a stale member role: role updated → late earlier list. | Deliver permitted responses in an unusual order. | High |

Risk hypotheses are not mandatory acceptance cases unless explicitly required by ACs.
Exploring these targets does not automatically claim AC coverage.
