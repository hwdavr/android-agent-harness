---
name: harnesslens
summary: Collect app-private runtime state and analytics evidence from a real Android/iOS test build, using agent-device for UI actions and hlens for verification.
---

# HarnessLens agent workflow

Use when you need internal UI/ViewModel state evidence or analytics event contract verification during real-app exploratory QA.

## Mandatory workflow

1. Confirm target is authorized debug Android app or iOS Simulator. Never use on a production account/device. Confirm SDK is integrated (Android install + state hook or Swift state hook, analytics decorator if required).
2. Read `README.md` and contract. Do not synthesize expected observations from code or guesses.
3. Create `.qa-artifacts/<run-id>/` in the consuming project for all generated JSON, NDJSON, reports and screenshots. Copy approved contracts into that run and record their hashes before UI actions; reusable source contracts remain in source control. Run `hlens capture start --platform PLATFORM --app-id APP_ID --device-id DEVICE_ID`. Retain its native `run_id` and selected app/device identity in the run evidence.
4. Drive **the actual app** with `agent-device`; run against approved staging real APIs. AppProbe/HarnessLens does not control UI.
5. Inspect `hlens state get` or `hlens state await` against approved expectations. For each required state checkpoint, record its pre-action sequence, perform the real action, and export a snapshot before proceeding. Require a fresh state record after the action; a later final state does not prove earlier checkpoints. Retain screenshots/HTTP evidence separately in the same run directory.
6. Run `hlens capture stop` then `hlens capture export --out .qa-artifacts/<run-id>/harnesslens/capture.ndjson`, with the same explicit platform/app/device and native run ID for export. Keep all checkpoint snapshots under that run's `harnesslens/checkpoints/`.
7. Run `hlens state verify --out .qa-artifacts/<run-id>/harnesslens/reports/state-<checkpoint>/report.json` and `hlens analytics verify --report-dir .qa-artifacts/<run-id>/harnesslens/reports/analytics` using the appropriate capture, `--run-id` and approved contract. Verify both when used by [Exploratory QA](../exploratory-qa/SKILL.md); follow its [manifest and checkpoint contract](../exploratory-qa/references/harnesslens.md). Preserve expected/actual state values, analytics results and evidence paths. Never substitute a manually declared PASS for verifier output.
8. FAIL means a contract mismatch. INCONCLUSIVE means capture or required state is missing; diagnose instrumentation rather than inventing a product bug.
9. Preserve reproducible regressions in the appropriate tests. Never silently edit the contract to make the implementation pass.

## Responsibilities

- `agent-device`: app navigation, UI observation, screenshots.
- `mitmproxy`: optional real HTTP inspection (with authorized debug trust configuration).
- `hlens`: internal selected state/analytics, local app-private NDJSON, contract gates.
- Backend verification: staging API/database evidence when the acceptance criteria need it.

## Safety

All collected fields must be allowlisted. No production release instrumentation, auth secrets, PII, hidden HTTP bodies, or external transmission of captured data.
