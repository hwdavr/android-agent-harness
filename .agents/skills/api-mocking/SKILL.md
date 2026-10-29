---
name: api-mocking
description: Control REST and GraphQL backend responses during Android or iOS QA using session-owned WireMock fixtures, passthrough, request verification, and cleanup. Use when a test needs backend conditions; keep device automation and analytics collection in their existing skills.
---

# API mocking

Use real backends by default. Choose this capability when approved test conditions need controlled responses. Python 3.9+ and a trusted WireMock 3 server are required; the adapter has no Python dependencies. No app rebuild is needed to change mappings after routing is established.

## Run

For temporary backend exploration, the execution intent is ephemeral: `agent-device`
drives the installed app through the existing dogfood/exploratory-qa lane. Keep native
WireMock fixtures and receipts in `.qa-artifacts/<run-id>/`; do not add WireMock to the
app/test APK, author a permanent instrumented test, or require CI setup for this run.
Only promote a journey into maintained regression coverage under a separately scoped
feature/bug change. WireMock controls backend responses; it does not drive device actions.

1. Inspect the selected app's network configuration and available server. Read [routing](references/routing.md) before changing device configuration. Use a dedicated server unless the app already sends a session header. A listener or curl response does not establish app routing.
2. Use the existing QA run ID as `--session`. Use `hlens mock` from the HarnessLens CLI; its [usage guide](references/usage.md) covers fixture matching, GraphQL, passthrough and troubleshooting. Set `HLS_WIREMOCK_JAR` in your shell profile to reuse a trusted local JAR path; `start --jar <trusted-jar>` can override it. If neither is set, `start` health-checks an existing server. Do not download/install WireMock as part of routine QA.
3. Select reviewed fixtures from `HarnessLens/examples/wiremock/` or the consuming feature. Apply native WireMock mapping JSON with `hlens mock apply`. The CLI namespaces scenarios, tags ownership, and health-checks before mutation. Use only synthetic fixture data.
4. Perform the actual journey through the existing device tools. Capture UI/state and analytics through their existing collectors. Use `hlens mock requests` and `hlens mock verify --name <mapping>` to confirm each required mapping was exercised. Do not send helper traffic during the app evidence window. Retain sanitized CLI output inside `.qa-artifacts/<run-id>/wiremock/` with fixture hashes and action/time context.
5. Verify and export evidence **before cleanup**. In a finally/trap path, `hlens mock reset` removes only this session's mappings and matched journal entries; restore the app URL, session header and any proxy/CA changes. Stop only a server started for this run. Unavailable routing/verification is INCONCLUSIVE; a healthy verification with insufficient hits is FAIL.

## Ownership and evidence

- Use one unique session per run; concurrent writers to the same session are unsupported. `--exclusive` declares a dedicated server. Shared servers require `--scope-header X-QA-Session` and app requests carrying that session ID. Metadata alone cannot isolate overlapping request matchers.
- `apply` upserts by session/name and clears prior hits for those mappings; it starts a fresh verification window. Apply an entire scenario bundle to restart its sequence. Different mapping names coexist: disable an earlier conflicting response before enabling another, or use explicit priorities. Lower numeric priority wins.
- Never invoke global WireMock reset, request deletion, scenario reset or recording. An interrupted/partially failed apply requires session cleanup. Existing unowned mappings are preserved; use a dedicated clean server if they could shadow the fixtures.
- Adapter output excludes live URLs, headers, bodies and arbitrary metadata. The WireMock server itself retains raw requests in memory: keep Admin API access private, use test accounts, bound its journal, and clean up. HTTPS uses normal certificate validation; `WIREMOCK_ADMIN_TOKEN` optionally supplies a bearer token to an existing gateway.
- WireMock proves backend request handling only. It cannot prove UI correctness, analytics emission or provider ingestion. Journal eviction can cause missing hits; bound journeys and verify promptly. Request counts cannot prove traffic absence outside the journal.

## Existing skill integration

[Exploratory QA](../exploratory-qa/SKILL.md) owns device actions, screenshots, HarnessLens and the combined report. It optionally calls this adapter and reruns WireMock verification in its reporter before cleanup. Keep its existing mitmproxy `apiMocks` format separate from native WireMock fixtures.

[Analytics event validator](../analytics-event-validator/SKILL.md) optionally prepares backend conditions with this adapter, then collects/validates events with its existing recorder. Required mock verification and analytics validation must both pass. Its live collector remains Android-specific; an iOS backend route does not add an iOS analytics collector.

Invoke `$api-mocking` in Codex or `/api-mocking` when installed in Claude Code's skills directory. When skill invocation is unavailable, read this entrypoint and call the HarnessLens CLI directly; the CLI is the single implementation. See [usage and tests](references/usage.md#discovery-and-validation).
