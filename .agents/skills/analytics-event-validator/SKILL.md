---
name: analytics-event-validator
description: Independently validate app-side analytics events against approved tracking requirements and produce analytics reports. Use for missing or duplicate events, parameter checks, and event sequence verification with a compatible Android debug recorder or supplied captures. Exploratory-QA can optionally invoke this skill.
---

# Analytics event validator

Run independently for analytics-only verification. Produce an analytics report plus supporting checked events and provenance receipts. General app logs, network dumps, screenshots and video are opt-in only. This skill does not require exploratory-QA or dogfood.

## Requirements and scenario

Select the feature's approved analytics tracking specification, explicit analytics requirements in its approved spec/test plan, or exact expectations approved by the user. Read [contracts](references/contracts.md) to create the event contract and retain hashed source sections.

Source call sites are discovery hints; actual events are observations. Neither defines the expected contract automatically. When requirements are missing, draft expectations for review and report the gap. Approval metadata records human authorization; it does not grant it.

Create a fresh `.qa-artifacts/<run-id>/scenario.json` with the contract's `scenario_id` and the actual `app_id`. Describe only the actions needed to trigger the declared events, using requirements, an existing workflow/replay, and source hints. This minimal run file is sufficient; no broader QA report or observations file is required.

```json
{"scenario_id":"<contract-scenario-id>","app_id":"com.example.funphotoeditor"}
```

At the original FunPhotoEditor adaptation, no analytics tracker/provider or approved tracking spec had been discovered. The app now has a `FirebaseAnalyticsTracker`, a source event catalog, and living requirements in `docs/product/requirements/analytics-tracking.md`; the planned click-tracking scope there is not implementation authorization. Firebase App Distribution is unrelated. A compatible recorder was not found in the installed API 33 debug app during that adaptation. Recheck the selected build; adding instrumentation or rebuilding an APK requires a separate implementation scope.

## Capture and validate

When an approved event contract requires a controlled backend condition, optionally use [api-mocking](../api-mocking/SKILL.md). Follow its [usage and cleanup guide](../api-mocking/references/usage.md); without skill-to-skill invocation call `hlens mock --session <run-id> --exclusive <command>` against a dedicated server. Reuse the selected run/device and existing user interaction; record the condition, reviewed fixture hash and required mapping names in this run's `wiremock/` evidence. Real backend mode remains the default.

Apply the fixture before arming the existing capture and performing its trigger action. Collect and validate actual events through the existing recorder below; then verify each required mapping with the adapter before removing it. Keep the separate WireMock verification JSON alongside the analytics report. A WireMock hit establishes only the backend condition: it never counts as an analytics event. Required backend verification failure or unavailable routing blocks overall journey completion even if analytics alone passes. Always reset temporary session mappings and restore routing in a finally/trap path. When invoked by exploratory-QA, let that parent verify/report before its shared cleanup. Backend routing supports iOS, but this skill's live collector remains Android-specific; use a compatible supplied capture for other platforms and retain its evidence limitations.

Read [Android capture](references/android-capture.md). Python 3.9+ and ADB are required for live collection; the helpers use only the standard library. Supplied captures can be validated offline without ADB or device interaction. Follow project device-selection rules and pin the chosen serial.

For live collection, inspect the existing build:

```bash
python3 .agents/skills/analytics-event-validator/scripts/capture.py inspect \
  --run-dir .qa-artifacts/<run-id> --serial <selected-serial>
```

Inspect is read-only and writes `analytics/capability.json`. Missing/non-debuggable app, absent recorder, or unsupported protocol is INCONCLUSIVE. A healthy capture requires initialization and a completed flush marker. The supplied starter recorder's ready-only stream needs adaptation before live use.

For an approved contract and already-compatible debug build:

```bash
python3 .agents/skills/analytics-event-validator/scripts/capture.py reset \
  --run-dir .qa-artifacts/<run-id> --serial <selected-serial> \
  --contract .qa-artifacts/<run-id>/analytics/contract.json
# Perform the declared analytics-trigger actions using an existing workflow/replay
# or the installed agent-device CLI. Check its local help for exact syntax.
# Invoke the existing recorder's documented flush barrier before collection.
python3 .agents/skills/analytics-event-validator/scripts/capture.py collect \
  --run-dir .qa-artifacts/<run-id> --serial <selected-serial> \
  --contract .qa-artifacts/<run-id>/analytics/contract.json
python3 .agents/skills/analytics-event-validator/scripts/validate.py \
  --run-dir .qa-artifacts/<run-id> \
  --contract .qa-artifacts/<run-id>/analytics/contract.json
```

Reset stops only the selected package and removes only its fixed debug capture file; it does not clear app data. Avoid resetting another active session. Collection checks the target/build/window receipts and discards every parameter value before writing `events.checked.json`. Invalid parameter checks survive redaction. Artifacts use mode 0600 in a local ignored directory; raw device content/stderr is not retained.

## Report and cleanup

Return `analytics/report.md` and its analytics verdict to the user. Keep `report.json`, checked events and receipts as supporting evidence. Use a fresh run after changes or a failed collection; never reuse old output as current evidence.

- 0 PASS: declared app-side assertions passed with healthy evidence; offline PASS is explicitly synthetic.
- 1 FAIL: verified count, parameter, forbidden-event or ordering violation.
- 2 INCONCLUSIVE: missing/unhealthy capture, unapproved expectations, unverified provenance or capture policy.
- 3 INVALID_INPUT: invalid contract/CLI/output or reused files.

An analytics PASS establishes app-side contract compliance within the declared scenario. It does not establish provider ingestion. Close only device sessions opened for this run; preserve the analytics evidence locally. No external evidence sharing is implied.

## Optional use from exploratory-QA

[Exploratory-QA](../exploratory-qa/SKILL.md) may invoke this validator when analytics checks are in scope. In that case reuse its scenario ID, selected APK/device and existing UI actions; store analytics evidence in the same run's `analytics/` directory. Coordinate reset before the shared scenario, then flush/collect once after the relevant actions. The parent workflow owns shared sessions, media, logs/proxy settings and cleanup.

The broader QA writeup includes the analytics verdict and a link to its report alongside UI/network results. If required analytics checks fail or remain inconclusive, overall QA completion must reflect that. Standalone invocation produces only the analytics result.
