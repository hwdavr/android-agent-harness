# QA suite and execution-run artifacts

Standalone exploratory QA keeps its existing default `.qa-artifacts/<run-id>/` layout.
Standalone run IDs have no required date/prefix naming scheme. For a test plan with many cases, use
`.qa-artifacts/<suite-id>/` to group the test plan and one `suite-report.md`. Each case attempt
and exploratory session is an independent execution run with the same existing files.

## Suite ID naming

Use this recommended convention for feature-acceptance suites:

```text
YYYYMMDD-<feature-slug>-<platform>-<sequence>
```

## Folder structure

```text
.qa-artifacts/
└── 20261104-node-sharing-android-01/             # suite-id; one build/device/environment
    ├── test_plan_v1.md                          # cases, AC coverage, gaps and risk targets
    ├── suite-report.md                         # context, approval, planned results,
    │                                           # exploratory findings, readiness, cleanup
    ├── cases/
    │   ├── NS-01/
    │   │   └── 20261104-node-sharing-android-01-ns01-a01/  # unique run-id; first attempt
    │   │       ├── scenario.json
    │   │       ├── observations.json
    │   │       ├── report.json                  # existing reporter output
    │   │       ├── report.md
    │   │       ├── dogfood-report.md
    │   │       ├── screenshots/
    │   │       ├── snapshots/
    │   │       ├── network.jsonl                # only when the provider produces it
    │   │       ├── wiremock/                    # fixtures, apply/requests/verify/cleanup
    │   │       └── harnesslens/                 # native run.json, capture, contracts,
    │   │                                       # checkpoints and verifier reports
    │   └── NS-02/
    │       ├── 20261104-node-sharing-android-01-ns02-a01/  # same run files; failed attempt retained
    │       └── 20261104-node-sharing-android-01-ns02-a02/  # fresh retry; no overwritten evidence
    └── exploration/
        └── 20261104-node-sharing-android-01-explore-a01/   # same run files; adaptive findings only
```

Create provider/capture folders only when used. Keep one approved plan covering all
cases and one human-facing suite report. A skipped or blocked case needs an explicit
result/reason in its case-attempt table, not fabricated empty captures. The existing
reporter still creates `report.json`/`report.md` inside each execution leaf; the workflow
maintains the suite report and links that evidence. Never run the reporter against the
suite root or let generated leaf reports overwrite the suite report.

## Suite report

Maintain these sections in `.qa-artifacts/<suite-id>/suite-report.md`.
Use the blank [suite-report.md example](../examples/suite-report.md) as a starting point:

| Section | Content |
|---|---|
| `Run context` | Merged SHA/PR, build/artifact/hash, app/version/platform/device, backend/environment, tool versions, QA account alias, original settings and provenance receipts. |
| `Approval` | Actual user response and approver/date, approved test-plan version/path/hash and bound source/contract/fixture/build/device/environment/scope/budget fingerprints. Pending approval never authorizes execution. |
| `Planned acceptance` | AC/case/attempt/run-path/status table, expected/actual summary, assertion and mock/backend evidence links, all retries, final dispositions and coverage gaps. This table also serves as the execution index. |
| `Exploratory findings` | Linked session reports, budget used/stop reason, investigated paths/risks, confirmed defects, suspected issues, hypotheses, unvisited risks and a separate `Regression candidates` subsection. |
| `Release readiness` | Critical failures, unresolved gaps, residual-risk decisions/owners, recommendation (`BLOCKED`, `INCONCLUSIVE`, `READY FOR HUMAN SIGN-OFF`) and required human product/UAT/release sign-off. |
| `Cleanup` | Per-run restoration status, changed resources/settings, actions/results and links to native cleanup receipts; finalize readiness after checking cleanup. |

Preserve approval entries unchanged; append renewed approvals when required. Hash the
approved plan and bound inputs, not this evolving report. Keep results out of the test
plan. Planned results and exploratory findings remain distinct sections, so an exploratory
observation cannot silently become AC coverage. Retain detailed case/session evidence
in leaves rather than copying it into multiple human-facing reports.

## Identity and isolation

- `suite-id` identifies the approved plan/build/device/environment group; `run-id`
  identifies exactly one case attempt or exploratory session. Run IDs must be unique
  across the suite and concurrent suites; do not use `attempt-01` for every case.
  For compatibility with both mock providers, use an alphanumeric first character,
  then letters/digits/dot/underscore/hyphen, at most 64 characters total.
- Pass the **leaf execution directory** to the existing reporter's `--run-dir` and
  its local `scenario.json` to `--scenario`. Nested directories work with the current
  reporter; no new runner or report schema is needed.
- The WireMock session is exactly the leaf directory's basename, never the suite ID,
  case ID or full filesystem path. Verify/export before session reset and cleanup.
- For mitmproxy, set `QA_RUN_ROOT` to the leaf's parent (`cases/NS-01` in the example),
  then pass the leaf run ID to the existing proxy helper. Its default remains
  `.qa-artifacts` for standalone runs. Keep `QA_MOCK_SCENARIO` in that same leaf.
- Each leaf owns its scenario hash, observations, fixture/contract snapshots, request
  journal window, native HarnessLens run ID and manifest. HarnessLens's 32-hex ID is
  separate from the folder run ID. Never share captures or append retry evidence to
  an earlier attempt. Export/verify/clean one run before beginning the next on a device.
- Evidence paths in a leaf's scenario, observations and manifest stay relative to
  that leaf and cannot escape it. Copy approved contracts and synthetic fixture files
  locally before hashing; `generation.sources` retains their approved project-relative
  source references/hashes. `suite-report.md` links to the leaf reports.
- Keep the approved case set and fixed oracles unchanged. Allocating a fresh attempt
  ID under that scope is not a plan revision; changing the approved build, device,
  environment, fixtures or expectations requires renewed approval. Do not rename or
  move completed runs after recording provenance/hashes. Do not relocate existing runs.

The `Planned acceptance` table has one row per case attempt: case/AC IDs, run ID and suite-relative
directory, attempt number, build identity, status/reason, and links to raw reports and
cleanup receipts. Preserve all attempts and explain the final case disposition rather than
silently taking the latest PASS. Keep exploratory sessions/findings in their own section.
