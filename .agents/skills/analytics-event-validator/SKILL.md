---
name: analytics-event-validator
description: Validate app-side analytics events against approved tracking requirements alongside exploratory-QA. Use for missing or duplicate events, parameter checks, and event sequence verification with a compatible Android debug recorder or supplied synthetic captures.
---

# Analytics event validator

Extend [exploratory-QA](../exploratory-qa/SKILL.md); it owns scenario generation and delegates device exploration to dogfood. Reuse its selected APK, device, fixtures, logs, video when requested, and teardown. Do not create another device-action loop or overwrite its report.

## Requirements before observations

Select the feature's approved analytics tracking specification, explicit analytics requirements in its approved spec/test plan, or expectations directly approved by the user. Read [contracts](references/contracts.md) to create `analytics/contract.json` tied to the same `scenario_id` and hashed source sections.

Source call sites are discovery hints. Actual events are observations. Neither is automatically the expected contract. When requirements are missing, draft a tracking contract for review and report the gap; never invent product event requirements or mark a draft as approved. Contract approval metadata records human authorization; it does not grant it.

FunPhotoEditor currently has no discovered analytics tracker/provider or approved tracking spec. Firebase App Distribution is unrelated. No recorder was found in the installed API 33 debug app during adaptation. Recheck the chosen build; do not install instrumentation or rebuild an APK as a side effect of QA.

## Capability and capture

Read [Android capture](references/android-capture.md). Python 3.9+ and ADB are required; the helpers use only the standard library. Follow project device-selection rules and always pin the chosen serial.

From the project root, using the existing exploratory-QA run directory:

```bash
python3 .agents/skills/analytics-event-validator/scripts/capture.py inspect \
  --run-dir .qa-artifacts/<run-id> --serial <selected-serial>
```

Inspect is read-only and writes `analytics/capability.json`. Missing/non-debuggable app, absent recorder, or unsupported protocol is INCONCLUSIVE. Use a fresh run for retries. A healthy capture requires both initialization and a completed flush marker; the supplied starter recorder's ready-only stream needs adaptation before live use.

For an approved contract and already-compatible debug build:

```bash
python3 .agents/skills/analytics-event-validator/scripts/capture.py reset \
  --run-dir .qa-artifacts/<run-id> --serial <selected-serial> \
  --contract .qa-artifacts/<run-id>/analytics/contract.json
# Use exploratory-QA/dogfood to launch and drive the scoped real UI scenario.
# Invoke the existing debug recorder's documented flush barrier before collection.
python3 .agents/skills/analytics-event-validator/scripts/capture.py collect \
  --run-dir .qa-artifacts/<run-id> --serial <selected-serial> \
  --contract .qa-artifacts/<run-id>/analytics/contract.json
python3 .agents/skills/analytics-event-validator/scripts/validate.py \
  --run-dir .qa-artifacts/<run-id> \
  --contract .qa-artifacts/<run-id>/analytics/contract.json
```

Reset stops only the selected package and removes only its fixed debug capture file. It does not clear app data. Do not reset another active QA session. Collection reads bounded data, checks target/build/window receipts and discards every parameter value before writing `events.checked.json`. Invalid parameter checks survive redaction. Raw device content/stderr is not retained. Artifacts are created with mode 0600 in a local ignored directory; review other QA media/logs before sharing.

## Reports and meaning

Outputs stay in the run's `analytics/` subdirectory: capability/reset/collection receipts, checked events, `report.json` and `report.md`. Do not reuse outputs. Rerun with a new QA run ID after changes; new collection requires a new reset and scenario replay.

- 0 PASS: declared app-side assertions passed with healthy evidence; offline PASS is explicitly synthetic.
- 1 FAIL: verified count, parameter, forbidden-event or ordering violation.
- 2 INCONCLUSIVE: missing/unhealthy capture, unapproved expectations, unverified provenance or capture policy.
- 3 INVALID_INPUT: invalid contract/CLI/output or reused files.

Keep UI, network and analytics outcomes visible separately. An analytics PASS does not establish UI correctness, HTTP delivery or Firebase/GA4 ingestion. Empty agent-device network logs are not analytics evidence. Use exploratory-QA cleanup for device sessions, logs, recordings and any proxy configuration. Do not send evidence externally without user authorization.
