---
name: harnesslens
summary: Collect app-private runtime state and analytics evidence from a real Android/iOS test build, using agent-device for UI actions and hlens for verification.
---

# HarnessLens agent workflow

Use when you need internal UI/ViewModel state evidence or analytics event contract verification during real-app exploratory QA.

## Mandatory workflow

1. Confirm target is authorized debug Android app or iOS Simulator. Never use on a production account/device. Confirm SDK is integrated (Android install + state hook or Swift state hook, analytics decorator if required).
2. Read `README.md` and contract. Do not synthesize expected observations from code or guesses.
3. Run `hlens capture start --platform PLATFORM --app-id APP_ID`. Retain the `run_id` in test evidence.
4. Drive **the actual app** with `agent-device`; run against approved staging real APIs. AppProbe/HarnessLens does not control UI.
5. Inspect `hlens state get` or `hlens state await` as needed, and screenshots/HTTP evidence separately.
6. Run `hlens capture stop` then `hlens capture export --out ARTIFACT.ndjson`.
7. Run `hlens state verify` and/or `hlens analytics verify` using approved contracts. Preserve JSON/Markdown reports and evidence paths.
8. FAIL means a contract mismatch. INCONCLUSIVE means capture or required state is missing; diagnose instrumentation rather than inventing a product bug.
9. Preserve reproducible regressions in the appropriate tests. Never silently edit the contract to make the implementation pass.

## Responsibilities

- `agent-device`: app navigation, UI observation, screenshots.
- `mitmproxy`: optional real HTTP inspection (with authorized debug trust configuration).
- `hlens`: internal selected state/analytics, local app-private NDJSON, contract gates.
- Backend verification: staging API/database evidence when the acceptance criteria need it.

## Safety

All collected fields must be allowlisted. No production release instrumentation, auth secrets, PII, hidden HTTP bodies, or external transmission of captured data.
