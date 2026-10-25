---
name: exploratory-qa
description: Verify an Android APK or installed app with workflow-derived scenarios, correlated logs, optional mitmproxy fixtures, and evidence reports. Use for QA needing network control or structured scenario results; use dogfood directly for UI-only exploration.
---

# Exploratory QA

This extends the installed [dogfood skill](../dogfood/SKILL.md). Use it for app discovery, agent-device interaction, UI evidence, reproduction, and findings. Follow its installed CLI guidance instead of maintaining another device-action loop here.

## Target and scenario

Accept a prebuilt APK or installed package; source code is optional. Record package/version, device/OS, APK SHA-256 when available, and requested scope. Follow project device-selection rules. The local app ID is `com.example.funphotoeditor`; do not assume the checkout matches a supplied APK.

Generate `.qa-artifacts/<run-id>/scenario.json` for the selected feature. Read [scenario sources](references/scenario-sources.md) to derive checks from the matching workflow, discover code-only targets, and retain source hashes. The example illustrates the format, not the default journey for every run. Keep observations unset until runtime exploration.

Before choosing a journey, inventory the feature's relevant entry points, including Home shortcuts/cards and in-context tool entries. Map each in-scope route to an `expectations.ui_checks` ID in `entry_points`; list future or otherwise out-of-scope routes in `excluded_entry_points` with a reason. The report validator returns `INCONCLUSIVE` when the inventory is absent, a route is unmapped, or route evidence is missing.

## Analytics checks

When analytics checks are requested or declared in the selected tracking requirements, invoke the standalone [analytics-event-validator](../analytics-event-validator/SKILL.md). Share this run's scenario ID, selected APK/device and existing UI actions; coordinate analytics reset before those actions and flush/collect afterward. Keep analytics evidence in `analytics/`; no additional logs or video are required by the validator. This exploratory-QA workflow owns shared sessions and cleanup. Include the analytics verdict and report link in the overall QA writeup alongside UI/network results. Required analytics failures or inconclusive results prevent claiming overall QA completion.

## Network mode

- UI/log-only: use dogfood; no proxy is required.
- Capture: allowlisted HTTP metadata supplements dogfood evidence.
- Mock: serve named synthetic fixtures from the scenario's `apiMocks`.

For capture or mocks, read [proxy setup and fixtures](references/proxy.md). Check the trusted `mitmdump --version` and `python3 --version`; do not install software automatically. A listener does not prove APK routing or CA trust. Require an actual in-app receipt before setting `proxy_verified: true`. Record unavailable interception as blocked/inconclusive and continue relevant dogfood work. Do not bypass pinning or rebuild/change app security automatically.

Fixtures are external to the APK. Once interception works, edit fixtures and restart the proxy under a new run ID; re-trigger the request with the same APK. Retain APK/fixture hashes. Intentional HTTP errors are assessed against expected recovery UI.

## Explore and report

Use dogfood for the scoped journey. Start/mark logs when relevant, save their path while the session is active, and correlate findings with the proxy timeline. `agent-device network dump` parses app logs; empty output does not establish no traffic. Code testTags are selector hints until confirmed in fresh runtime snapshots.

Populate `observations.json` from `examples/observations.example.json` with actual checks, crash count, visited states, findings, and evidence paths. Keep dogfood's detailed findings as `dogfood-report.md` so the structured report does not overwrite them. Record unreachable states and missing expectations/oracles. Exploration supplements the project's deterministic Android and Roborazzi gates.

Stop proxy/logs and close dogfood's session; restore any device proxy/CA changes made. Then run:

```bash
python3 .agents/skills/exploratory-qa/scripts/report.py \
  --run-dir .qa-artifacts/<run-id> \
  --scenario .qa-artifacts/<run-id>/scenario.json
```

Exit codes: 0 `PASS`, 1 `FAIL`, 2 `INCONCLUSIVE`/invalid input. PASS covers declared checks with submitted evidence. Missing observations or unexercised required mocks cannot pass; setup mismatches are labeled separately from app findings. Keep artifacts local and review/redact screenshots, logs, and URL paths before sharing. Helpers do not persist live bodies, headers, credentials, or raw proxy flows.

## Handoff to bug fixing

For each confirmed application finding, retain `id`, `title`, `severity`, `category`, `repro_steps`, `expected`,
`actual`, and non-empty local `evidence` paths in `observations.json`; the report generator carries them into
`report.json`. Keep package/version/device in the scenario target and record the APK hash when available.
Give the bug-fixing workflow the existing `report.json` path and selected finding ID. It can read and validate
that finding as its runtime reproduction without another QA session or another handoff document. Complete
only missing evidence before handing off. A QA finding does not establish a source-level root cause or a
post-fix pass; deterministic regression and later verification remain owned by bug fixing.
