---
name: api-mocking
description: Control REST and GraphQL backend responses during Android or iOS QA with session-owned WireMock fixtures, passthrough, verification, and cleanup. Device automation and analytics stay in their skills.
---

# API mocking

Use real backends by default. Choose this capability when approved test conditions need controlled responses. Python 3.9+ and a trusted WireMock 3 server are required; the adapter has no Python dependencies. No app rebuild is needed to change mappings after routing is established.

## Run

The caller owns the journey and approval; this skill controls backend responses.
Use exploratory-qa's [execution scope](../exploratory-qa/SKILL.md#target-and-scenario)
and [artifact layout](../exploratory-qa/references/artifact-layout.md) for temporary runs.

1. Inspect the selected app's network configuration and available server. Read [routing](references/routing.md) before changing device configuration. Use a dedicated server unless the app already sends a session header.
2. Use the caller's execution run ID as `--session` and the existing `hlens mock` adapter. Follow the [usage guide](references/usage.md) for trusted JAR configuration, commands, passthrough, matching and timeouts. Do not download/install WireMock during routine QA.
3. Trace each in-scope user action through the UI/use case/repository to its actual method/path, including autosave and follow-up reads. Use approved API contracts/scenarios for synthetic response shapes; code supplies call-path hints. Never harvest production responses. Check [local side effects](#local-state-side-effects) before applying fixtures.
4. Select reviewed fixtures from `HarnessLens/examples/wiremock/` or the consuming feature and apply native mappings with `hlens mock apply`. Keep mitmproxy's `apiMocks` format separate. Supply exploratory-qa's [mock coverage declaration](../exploratory-qa/SKILL.md#network-mode) when that skill is the caller. The adapter namespaces scenarios, tags ownership and health-checks before mutation.
5. Have the caller trigger the app actions, then use `hlens mock requests` and `hlens mock verify --name <mapping>` for every required mapping's fixture hash and hit bounds. A listener, configured rule or helper request cannot prove app injection; send no helper traffic during the evidence window. Retain sanitized receipts under the execution leaf's `wiremock/` directory with action/time context. Confirm timeout injection using the usage guide's client-timeout boundary, not an HTTP 504 alone.
6. Verify and export evidence **before cleanup**. In a finally/trap path, `hlens mock reset` removes only this session's mappings and matched journal entries; restore the app URL, session header and any proxy/CA changes. Stop only a server started for this run. Unavailable routing/verification is INCONCLUSIVE; a healthy verification with insufficient hits is FAIL.

## Ownership and evidence

- Use one unique session per run; concurrent writers to the same session are unsupported. `--exclusive` declares a dedicated server. Shared servers require `--scope-header X-QA-Session` and app requests carrying that session ID. Metadata alone cannot isolate overlapping request matchers.
- `apply` upserts by session/name and clears prior hits for those mappings; it starts a fresh verification window. Apply an entire scenario bundle to restart its sequence. Different mapping names coexist: disable an earlier conflicting response before enabling another, or use explicit priorities. Lower numeric priority wins.
- Never invoke global WireMock reset, request deletion, scenario reset or recording. An interrupted/partially failed apply requires session cleanup. Existing unowned mappings are preserved; use a dedicated clean server if they could shadow the fixtures.
- Adapter output excludes live URLs, headers, bodies and arbitrary metadata. The WireMock server itself retains raw requests in memory: keep Admin API access private, use test accounts, bound its journal, and clean up. HTTPS uses normal certificate validation; `WIREMOCK_ADMIN_TOKEN` optionally supplies a bearer token to an existing gateway.
- WireMock proves app-side request handling against synthetic responses. It cannot prove UI correctness, analytics emission/ingestion, real-server persistence/authorization, cross-account behavior or external state. Keep unsupported backend assertions INCONCLUSIVE. Journal eviction can lose hits; bound journeys and verify promptly. Counts cannot prove absence outside the journal.

## Mock continuation when real fixtures are unavailable

For feature acceptance, follow the workflow's [mock-flow replanning](../../workflows/feature-acceptance.md#mock-flow-replanning).

## Local state side effects

Trace local side effects before applying a fixture. Treat a mock request that causes
`ItemsSyncCoordinator.syncAll()` or another Room clear/rebuild as a local state replacement,
even when its HTTP method is GET. If it can remove existing shared-note cache, require an
isolated account/device or the user's explicit approval for that bounded replacement and
the restoration path. Never bypass that approval boundary through a helper or hidden fixture.

## Existing skill integration

[Exploratory QA](../exploratory-qa/SKILL.md) owns device actions, screenshots, HarnessLens and the combined report. Its reporter reruns this adapter's verification before cleanup.

[Analytics event validator](../analytics-event-validator/SKILL.md) optionally prepares backend conditions with this adapter, then collects/validates events with its existing recorder. Required mock verification and analytics validation must both pass. Its live collector remains Android-specific; an iOS backend route does not add an iOS analytics collector.

Invoke `$api-mocking` in Codex or `/api-mocking` when installed in Claude Code's skills directory. When skill invocation is unavailable, read this entrypoint and call the HarnessLens CLI directly; the CLI is the single implementation. See [usage and tests](references/usage.md#discovery-and-validation).
