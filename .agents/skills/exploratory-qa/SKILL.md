---
name: exploratory-qa
description: Verify an Android APK or installed app with workflow-derived scenarios, HarnessLens internal state and analytics contracts, optional mitmproxy fixtures, and evidence reports. Use dogfood directly for UI-only exploration.
---

# Exploratory QA

This extends the installed [dogfood skill](../dogfood/SKILL.md). Use it for app discovery, agent-device interaction, UI evidence, reproduction, and findings. Follow its installed CLI guidance instead of maintaining another device-action loop here.

## Target and scenario

Accept a prebuilt APK or installed package; source code is optional. Record package/version, device/OS, APK SHA-256 when available, and requested scope. Follow project device-selection rules. The local app ID is `com.example.funphotoeditor`; do not assume the checkout matches a supplied APK.

Generate `.qa-artifacts/<run-id>/scenario.json` for the selected feature. Read [scenario sources](references/scenario-sources.md) to derive checks from the matching workflow, discover code-only targets, and retain source hashes. The example illustrates the format, not the default journey for every run. Keep observations unset until runtime exploration.

Keep every generated scenario, manifest, contract snapshot, capture, verifier JSON, report, log and screenshot inside this run directory. Approved reusable contracts remain at their source-controlled paths; copy the selected contracts into the run and hash them before UI actions. Never put generated run JSON in `docs/`.

Before choosing a journey, inventory the feature's relevant entry points, including Home shortcuts/cards and in-context tool entries. Map each in-scope route to an `expectations.ui_checks` ID in `entry_points`; list future or otherwise out-of-scope routes in `excluded_entry_points` with a reason. The report validator returns `INCONCLUSIVE` when the inventory is absent, a route is unmapped, or route evidence is missing.

## Internal state and analytics — HarnessLens required

Invoke the installed [HarnessLens skill](../harnesslens/SKILL.md) and follow [capture, checkpoints and contract verification](references/harnesslens.md). Use the same installed app, selected device and real dogfood actions for UI, internal state and analytics evidence. Confirm the selected state hooks and analytics decorator exist in the debug build; absent instrumentation, missing approved expectations or an unavailable CLI is `INCONCLUSIVE`, with the prerequisite recorded. Continue useful UI exploration while preserving that incomplete verdict.

Before acting, declare `expectations.harnesslens`: a full-run capture, at least one state checkpoint linked to a UI check and action, and the approved analytics contract. Derive expected scope/field/value assertions from approved requirements; source code can reveal exported fields but cannot supply the correctness oracle. Cover the relevant initial, success, error and restored states declared by the scenario. Record unknown or unexported fields as evidence gaps.

Arm capture before launching/navigating. At each checkpoint, record the pre-action sequence boundary, perform its actual action, wait for the expected state within a bounded timeout, and export a separate snapshot before the next action. The reporter requires fresh state after that boundary and verifies each snapshot against its own contract. A correct final screen cannot substitute for an earlier checkpoint. Keep the full capture for analytics counts, parameters, forbidden events and order.

The reporter reruns the real HarnessLens verifiers against captured evidence; it ignores manually supplied PASS flags. A fresh observed mismatch is `FAIL`; absent/stale state, zero analytics events, changed contracts or mixed runs are `INCONCLUSIVE`. Analytics contract mismatches in a non-empty capture are `FAIL`. Both outcomes block overall PASS. Include expected and actual state values through the linked state reports. A sampled state history cannot establish every transient transition, and app-side analytics cannot prove Firebase ingestion.

The standalone [analytics-event-validator](../analytics-event-validator/SKILL.md) remains available for legacy captures. Its recorder and analytics-only parser do not replace this workflow's HarnessLens capture or internal state checks.

## Network mode

- No proxy: dogfood UI evidence plus HarnessLens state and analytics; no network interception is required.
- Capture: allowlisted HTTP metadata supplements dogfood evidence.
- Mock: serve named synthetic fixtures from the scenario's `apiMocks`.

For capture or mocks, read [proxy setup and fixtures](references/proxy.md). Check the trusted `mitmdump --version` and `python3 --version`; do not install software automatically. A listener does not prove APK routing or CA trust. Require an actual in-app receipt before setting `proxy_verified: true`. Record unavailable interception as blocked/inconclusive and continue relevant dogfood work. Do not bypass pinning or rebuild/change app security automatically.

Fixtures are external to the APK. Once interception works, edit fixtures and restart the proxy under a new run ID; re-trigger the request with the same APK. Retain APK/fixture hashes. Intentional HTTP errors are assessed against expected recovery UI.

## Explore and report

Use dogfood for the scoped journey. Start/mark logs when relevant, save their path while the session is active, and correlate findings with the proxy timeline. `agent-device network dump` parses app logs; empty output does not establish no traffic. Code testTags are selector hints until confirmed in fresh runtime snapshots.

Populate `observations.json` from `examples/observations.example.json` with actual checks, crash count, visited states, findings, and evidence paths. Update `harnesslens/run.json` with checkpoint sequence boundaries from that same live session. Keep dogfood's detailed findings as `dogfood-report.md` so the structured report does not overwrite them. Record unreachable states and missing expectations/oracles. Exploration supplements the project's deterministic Android and Roborazzi gates.

Stop and export HarnessLens capture before closing the app/session; retain failed commands and partial evidence. Stop proxy/logs and restore any device proxy/CA changes made. Then run with Python 3.10+ (omit `--harnesslens-root` only when this Python environment already has HarnessLens installed):

```bash
python3 .agents/skills/exploratory-qa/scripts/report.py \
  --run-dir .qa-artifacts/<run-id> \
  --scenario .qa-artifacts/<run-id>/scenario.json \
  --harnesslens-root /path/to/pinned/HarnessLens
```

Exit codes: 0 `PASS`, 1 `FAIL`, 2 `INCONCLUSIVE`/invalid input. PASS requires UI/network checks and all required HarnessLens state/analytics checks. Missing observations, omitted HarnessLens expectations or unexercised required mocks cannot pass; setup mismatches are labeled separately from app findings. Keep artifacts local and review/redact screenshots, logs, state values and URL paths before sharing. Capture only approved low-sensitivity fields; never tokens, user content, credentials or live HTTP bodies.

## Handoff to bug fixing

For each confirmed application finding, retain `id`, `title`, `severity`, `category`, `repro_steps`, `expected`,
`actual`, and non-empty local `evidence` paths in `observations.json`; the report generator carries them into
`report.json`. Keep package/version/device in the scenario target and record the APK hash when available.
Give the bug-fixing workflow the existing `report.json` path and selected finding ID. It can read and validate
that finding as its runtime reproduction without another QA session or another handoff document. Complete
only missing evidence before handing off. A QA finding does not establish a source-level root cause or a
post-fix pass; deterministic regression and later verification remain owned by bug fixing.
