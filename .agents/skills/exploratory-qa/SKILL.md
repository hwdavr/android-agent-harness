---
name: exploratory-qa
description: Execute approved mobile QA plans or explore feature risks with agent-device, HarnessLens and API fixtures.
---

# Exploratory QA

This extends the installed [dogfood skill](../dogfood/SKILL.md). Use it for app discovery, agent-device interaction, UI evidence, reproduction, and findings. Follow its installed CLI guidance instead of maintaining another device-action loop here.

## Invocation modes

The existing standalone scenario/capture/report workflow below remains available.
[feature-acceptance](../../workflows/feature-acceptance.md) invokes this skill after plan
approval in **approved-plan** mode to execute the reviewed cases. It invokes
**acceptance-support** mode separately for adaptive risk investigation. Keep planned
case results and exploratory findings separate, even though both use this skill.

### Artifact layout for plans with many cases

Follow the shared [artifact layout](references/artifact-layout.md) for suite/leaf paths,
run identity, provider sessions and report sections. Examples below use standalone paths;
substitute the selected execution leaf in a suite.

### Approved-plan execution mode

Accept the plan, approval record, bound input hashes, installed build/device/environment,
fixtures/replays, mock providers and suite directory. Read the complete plan and verify
the caller's [approval contract](../../workflows/feature-acceptance.md#generate-the-test-plan-and-request-review--stop).
Missing approval, changed inputs or conflicting instructions block affected planned execution.

1. Verify the approval hashes and installed build identity, then activate prepared QA
   fixtures/routing/captures under the [cleanup contract](#cleanup). Use the existing
   dogfood/agent-device tools and capture/report procedures below; do not add another
   driver. Execute the approved case order serially with isolated case/attempt evidence.
2. Verify each case's initial state and isolate QA data. For mocks, use
   [api-mocking's run/isolation procedure](../api-mocking/SKILL.md#run) between attempts.
3. Arm required captures before actions. Reuse a stable, reviewed `.ad` via
   `agent-device replay <path>` where appropriate; otherwise interact with fresh runtime
   selectors while keeping the approved actions, assertions and bounded waits unchanged.
   Screenshot-only evidence or replay exit 0 is insufficient to establish the outcome.
4. Assert every approved oracle and retain expected/actual observations: screenshots
   and accessibility, fresh HarnessLens state/analytics verifier output when required,
   mock receipts and authoritative staging backend observations. Use approved staging
   APIs/read-only queries with case-specific correlation IDs for backend checks.
   Internal state cannot substitute for rendered UI. Respect each collector's evidence limits.
5. Complete [API mock verification](../api-mocking/SKILL.md#run) and the approved
   post-timeout status enquiry/recovery assertions before exporting the attempt.
6. Record every attempt under `Planned acceptance` using the shared artifact contract:

   | Result | Meaning |
   |---|---|
   | PASS | Every approved assertion ran and matched with all required fresh evidence. |
   | FAIL | An observed assertion mismatch on a valid setup; classify its cause after reproduction. |
   | INCONCLUSIVE | Setup, automation, identity, oracle or required evidence cannot establish the result. |
   | SKIPPED | Deliberately not executed, with reason and owner/disposition; never counts as covered. |

7. Reproduce failures in fresh attempts with the same approved inputs and distinguish
   application defects from automation/environment failures. Keep the first failure and
   retries; a flaky pass cannot erase a failure. Invalid automation/environment proof is
   INCONCLUSIVE. Missing assertions, required evidence or unverified/unhit required mocks
   can never PASS. Keep independent cases running where safe.
   For an untestable real-server flow, return to the caller's
   [mock-flow replanning](../../workflows/feature-acceptance.md#mock-flow-replanning).
8. Return every case result and evidence link to the caller, including skipped and
   inconclusive cases. If using the existing structured reporter, preserve its manifest,
   contract and verification requirements; its aggregate verdict cannot replace per-case
   results. Complete [cleanup](#cleanup) even on failure. Run additional adaptive
   investigation separately in acceptance-support mode.

### Acceptance-support inputs

For adaptive investigation, accept feature scope, exploratory risk targets, planned acceptance coverage/results
summary and gaps, build/environment/device configuration, available mock providers, a
unique execution leaf and a bounded exploration budget. Set both time and action
limits and stop at the first limit, a safety boundary or an environment blocker; retain
partial evidence and the stop reason. Do not merely replay the planned acceptance list.
Use the caller-verified Android package/iOS bundle and installed build identity; example
package IDs in the standalone guidance are not defaults for either acceptance mode.

### Adaptive investigation in acceptance-support mode

1. Read approved behavior, known risks, recent changes, architecture/dependency hints,
   API failure modes and the supplied coverage summary. Start with an uncovered high-risk
   state or transition. Targets are hypotheses, not mandatory deterministic cases.
2. Observe the actual UI/accessibility tree, available HarnessLens state/analytics and
   network evidence. Choose the next action based on the current observation and risk:
   record observation → hypothesis → chosen action/reason → result/next question in the
   leaf's existing `dogfood-report.md`. Use fresh agent-device observations; code hints are not findings.
3. Consider boundary values, lifecycle/background/foreground, concurrent operations,
   retries, duplicated actions at different timing points, delayed/malformed/unexpected
   responses, restoration/recovery and cross-feature interference. Change one suspected
   cause at a time where practical. Repeat planned journeys only to investigate a failure.
4. Use [api-mocking](../api-mocking/SKILL.md) for approved selective faults, or the
   [mitmproxy provider](references/proxy.md). Use one response owner per route;
   their fallback behavior is not interchangeable. Verify injection through the provider.
5. Capture HarnessLens state and analytics when available, using approved contracts and
   the same app/device/actions. If required evidence is missing, preserve INCONCLUSIVE;
   useful UI investigation may continue. If optional instrumentation is unavailable,
   disclose the limitation. The existing structured reporter still requires its declared
   HarnessLens prerequisites and must not be weakened to obtain PASS. Its verdict is
   auxiliary investigation evidence, not the caller's planned acceptance verdict.
6. Keep planned ACs and expected results unchanged. Log newly observed paths separately;
   do not edit a hashed scenario/contract after capture. If a new fault or approved oracle
   requires another scenario, finish/export/verify and clean the current segment, then
   start a fresh linked run within the remaining budget. Risk targets with no independent
   oracle stay hypotheses; they are not required PASS/FAIL checks in `scenario.json`.
7. Reproduce suspected defects with controlled inputs and seek an independent expected
   behavior source (approved AC/contract or explicit product clarification). Distinguish
   `confirmed defect` (reproduced with established expectation), `suspected issue`
   (observed, not fully reproduced/attributed), and `unverified hypothesis` (not observed).
   Record environment/automation failures separately from application defects.

Return the shared artifact contract's `Exploratory findings` section with budget use/stop
reason and linked leaf evidence. Confirmed defects use the [bug-fixing handoff](#handoff-to-bug-fixing)
plus build/merged SHA, environment, business impact and relevant state/network evidence
(or its recorded absence). Suspected issues and hypotheses remain outside confirmed `findings`.

Include a `Regression candidates` subsection within `Exploratory findings` (or within
the existing standalone `dogfood-report.md`), listing only confirmed defects or explicitly
none: finding ID, established expected behavior/source, smallest reproducible setup/actions, proposed assertions, fixture
references and likely test layer. These are proposals, not newly implemented regression tests.
Do not claim AC coverage or an arbitrary state-space percentage from exploration. A PASS
from the existing reporter covers only its declared checks; findings inform the caller's
release risk assessment, and a confirmed critical defect blocks release promotion.

## Target and scenario

This is an ephemeral execution lane. Use `agent-device` to drive the installed app and
keep the whole run under `.qa-artifacts/<run-id>/`. Do not create permanent `androidTest`
classes, shared regression scenarios, app/test dependencies, journey-registry entries,
or CI changes just to execute the run. A confirmed finding can be handed to bug fixing
for separately scoped regression coverage.

Declare this in `scenario.json` before device actions:
`"execution": {"mode": "ephemeral", "driver": "agent-device", "regression_targets": [], "ci_required": false}`.
The reporter rejects a mixed regression/instrumented execution declaration and cannot
PASS without the execution intent. Review the source diff at cleanup to ensure the run
did not introduce permanent test or CI files; declarations alone do not prove device actions.

Accept a prebuilt APK or installed package; source code is optional. Use dogfood's target
discovery and project device-selection rules. Record package/version, device/OS, artifact
hash when available and requested scope; the checkout alone cannot identify a supplied app.

Generate `.qa-artifacts/<run-id>/scenario.json` for the selected feature. Read [scenario sources](references/scenario-sources.md) to derive checks from the matching workflow, discover code-only targets, and retain source hashes. The example illustrates the format, not the default journey for every run. Keep observations unset until runtime exploration.

Keep every generated scenario, manifest, contract snapshot, capture, verifier JSON, report, log and screenshot inside this run directory. Approved reusable contracts remain at their source-controlled paths; copy the selected contracts into the run and hash them before UI actions. Never put generated run JSON in `docs/`.

Before choosing a journey, inventory the feature's relevant entry points, including Home shortcuts/cards and in-context tool entries. Map each in-scope route to an `expectations.ui_checks` ID in `entry_points`; list future or otherwise out-of-scope routes in `excluded_entry_points` with a reason. The report validator returns `INCONCLUSIVE` when the inventory is absent, a route is unmapped, or route evidence is missing.

## Internal state and analytics — HarnessLens required

Invoke the installed [HarnessLens skill](../harnesslens/SKILL.md) and follow the complete
[capture/checkpoint/verification contract](references/harnesslens.md). That reference owns
expectations, manifests, readiness, fresh sequence boundaries and verifier commands.
The structured reporter requires its state/analytics proof even when a caller's case has
optional channels. Missing prerequisites remain INCONCLUSIVE; continue useful UI work
without turning that auxiliary reporter result into a PASS. Fresh observed mismatches
remain FAIL. Capture only the selected authorized app/device/actions.

The standalone [analytics-event-validator](../analytics-event-validator/SKILL.md) remains available for legacy captures. Its recorder and analytics-only parser do not replace this workflow's HarnessLens capture or internal state checks.

## Network mode

- No proxy: dogfood UI evidence plus HarnessLens state and analytics; no network interception is required.
- Capture: allowlisted HTTP metadata supplements dogfood evidence.
- Mock: serve named synthetic fixtures from the scenario's `apiMocks` or native WireMock mappings.

For mocks, obtain the API interaction inventory from [api-mocking](../api-mocking/SKILL.md#run).
Declare it in `expectations.mock_coverage`, linking each interaction to a
UI `check_id`, operation, method/path, API and contract source, and fixture ID. The reporter
marks missing or unlinked mock coverage `INCONCLUSIVE`. A routing-only probe must use
`mode: routing_only`, give a reason, and be reported explicitly as not covering feature API
behavior. A hit on an unrelated endpoint does not prove the feature's backend behavior.

For capture or mocks, read [proxy setup and fixtures](references/proxy.md). Check the trusted `mitmdump --version` and `python3 --version`; do not install software automatically. A listener does not prove APK routing or CA trust. Require an actual in-app receipt before setting `proxy_verified: true`. Record unavailable interception as blocked/inconclusive and continue relevant dogfood work. Do not bypass pinning or rebuild/change app security automatically.

Fixtures are external to the APK. Once interception works, edit fixtures and restart the proxy under a new run ID; re-trigger the request with the same APK. Retain APK/fixture hashes. Intentional HTTP errors are assessed against expected recovery UI.

## Explore and report

### Optional WireMock backend conditions

Use [api-mocking](../api-mocking/SKILL.md) for the backend lifecycle. This section owns
only the adapter-to-reporter interface.

Declare mapping names, fixture hashes and hit bounds under `expectations.wiremock` as
shown in the [usage guide](../api-mocking/references/usage.md). Set `wiremock_routing_verified`
only from the correlated app receipt. Add `--wiremock-url <server> --wiremock-session <run-id>`
to the report command below; it re-verifies live mappings through the adapter.

Use dogfood for the scoped journey. Start/mark logs when relevant, save their path while the session is active, and correlate findings with the proxy timeline. `agent-device network dump` parses app logs; empty output does not establish no traffic. Code testTags are selector hints until confirmed in fresh runtime snapshots.

Populate `observations.json` from `examples/observations.example.json` with actual checks, crash count, visited states, findings, and evidence paths. Update `harnesslens/run.json` with checkpoint sequence boundaries from that same live session. Record unreachable states and missing expectations/oracles. Exploration supplements the project's deterministic JVM and instrumented test gates and the ui-verification conformance review.

### Dogfood report reconciliation

When this run has a manual dogfood report, place it in the execution leaf as `dogfood-report.md`.
Reconcile its reportable observations into `observations.json.findings` before generating the
case report. Set `dogfood_report_reviewed: true` only after comparison; explicitly use an empty
findings list when there is nothing to promote. The reporter enforces this attestation, records
the source path/hash and structured findings, and links the detailed narrative instead of copying
raw Markdown. An unreviewed source keeps the case report INCONCLUSIVE. This is the sole report
reconciliation procedure; owning workflows link here.

Stop/export capture using the HarnessLens contract, keeping failed commands and partial
evidence. Run the reporter once with Python 3.10+, **before WireMock cleanup while its
mappings remain active**. Omit `--harnesslens-root` only when this interpreter has HarnessLens installed:

```bash
python3 .agents/skills/exploratory-qa/scripts/report.py \
  --run-dir .qa-artifacts/<run-id> \
  --scenario .qa-artifacts/<run-id>/scenario.json \
  --harnesslens-root /path/to/pinned/HarnessLens
```

Exit codes: 0 `PASS`, 1 `FAIL`, 2 `INCONCLUSIVE`/invalid input. PASS requires UI/network checks and all required HarnessLens state/analytics checks. Missing observations, omitted HarnessLens expectations or unexercised required mocks cannot pass; setup mismatches are labeled separately from app findings. Keep artifacts local and review/redact screenshots, logs, state values and URL paths before sharing. Capture only approved low-sensitivity fields; never tokens, user content, credentials or live HTTP bodies.

## Cleanup

Register finally/trap cleanup before changing resources and run it on every exit. Export
captures and report evidence before closing the app/session. Delegate backend restoration
to [api-mocking](../api-mocking/SKILL.md#run); stop owned logs/proxies/device sessions and
restore other changed device settings. Remove only isolated QA data through
approved staging procedures; never perform destructive production cleanup.
Check actual cleanup exit results and retain native receipts in the execution leaf;
record restoration in the suite's `Cleanup` section. Preserve partial evidence on interruption.
Redact credentials, tokens, PII, user content and payment details before sharing artifacts.

## Handoff to bug fixing

For each confirmed application finding, retain `id`, `title`, `severity`, `category`, `repro_steps`, `expected`,
`actual`, and non-empty local `evidence` paths in `observations.json`; the report generator carries them into
`report.json`. Keep package/version/device in the scenario target and record the APK hash when available.
Give the bug-fixing workflow the existing `report.json` path and selected finding ID. It can read and validate
that finding as its runtime reproduction without another QA session or another handoff document. Complete
only missing evidence before handing off. A QA finding does not establish a source-level root cause or a
post-fix pass; deterministic regression and later verification remain owned by bug fixing.
