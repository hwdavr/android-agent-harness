# Suite report

Blank example for `.qa-artifacts/<suite-id>/suite-report.md`. No QA execution or approval
is recorded here. Fill observations from actual execution and link evidence in run folders.

## Run context

| Item | Value |
|---|---|
| Suite ID / feature | `<suite-id>` / `<feature>` |
| Merged PR / SHA | `<PR reference>` / `<commit SHA>` |
| QA artifact / SHA-256 / app version | `<artifact reference>` / `<hash>` / `<version/build>` |
| Platform / device / OS | `<android or ios>` / `<serial or UDID>` / `<OS version>` |
| Backend / QA environment / flags | `<deployment version>` / `<staging environment>` / `<flags>` |
| QA account | `<approved disposable account alias; no credentials>` |
| Sources / tools / original settings | `<source hashes, tool versions, original routing/settings and inspection receipts>` |

## Approval

- Status: **Pending user approval**.
- Test plan: `<test_plan_vN.md>`; SHA-256: `<approved plan hash>`.
- Bound inputs: `<source/contract/fixture hashes, artifact, device, environment and scope/budget>`.
- User response / approver / date: **Not yet received**.

Record the actual response only after approval. Preserve each approval entry; append
renewed approvals rather than rewriting history. Hash the plan and inputs, not this report.

## Planned acceptance

No cases executed. Add one row per actual case attempt; skipped cases need a reason.

| Case / AC | Attempt / run folder | Status / reason | Expected / actual summary | Evidence |
|---|---|---|---|---|

Use PASS, FAIL, INCONCLUSIVE or SKIPPED. Link each run's `report.json`/`report.md`, assertion,
UI/backend/state/analytics and mock-hit evidence as required by the approved case.
Keep failed attempts and explain the final case disposition; a retry does not erase failure.

- AC coverage / gaps: **Not established; no execution evidence**.
- Unselected cases / unresolved failures: `<case IDs, reasons, impact and owner>`.

## Exploratory findings

- Budget / used / stop reason: `<approved minutes/actions>` / **Not started** / `<reason>`.
- Investigated risks / visited journeys: **None recorded; investigation not run**.
- Confirmed defects: **None recorded; investigation not run**.
- Suspected issues / hypotheses / unvisited risks: `<risk IDs, uncertainty and priority>`.
- Evidence: `<links to exploration run reports, action logs, screenshots and network/state observations>`.

For a confirmed defect, include build/device/environment, minimal reproduction steps,
expected behavior/source, actual behavior, severity and evidence. Exploration does not
automatically establish AC coverage.

### Regression candidates

Not assessed. List only confirmed defects with established expected behavior, finding ID,
setup/actions, proposed assertions, fixture references and a suitable test layer.

## Release readiness

- Recommendation: **INCONCLUSIVE — acceptance and exploration have not run**.
- Critical failures / evidence gaps: **Required acceptance proof is missing**.
- Residual risks / dispositions / owners: `<open decisions and owners>`.
- Human product/UAT/release sign-off: **Pending**.

Use BLOCKED for known critical failures/defects. Missing critical evidence cannot PASS.
READY FOR HUMAN SIGN-OFF requires the workflow's gates and verified cleanup; it does not
authorize release promotion by itself.

## Cleanup

No suite resources activated. During execution, record each run's restoration result here.

| Run / resource changed | Restoration action / result | Receipt |
|---|---|---|

Link native cleanup/stop receipts retained in run folders. Failed or unverified cleanup
keeps readiness INCONCLUSIVE unless a known critical failure already makes it BLOCKED.
