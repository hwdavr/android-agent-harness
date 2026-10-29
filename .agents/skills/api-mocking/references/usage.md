# Commands and fixtures

Use the installed `hlens` command and set `HLS_ROOT` to the HarnessLens checkout that contains the example fixtures. Examples use synthetic API shapes; adapt reviewed copies to the selected app's contract.

## Start, switch, verify, restore

Use the HarnessLens CLI (`hlens`) to connect to an existing WireMock 3 server or start one with Java 17+ and an already-downloaded standalone JAR. Tested baseline: WireMock **3.13.1**. Docker is optional; no SDK or Python package is required.

```bash
# Set this once in your shell profile to reuse your local JAR path.
export HLS_WIREMOCK_JAR="/path/to/wiremock-standalone-3.13.1.jar"

# Terminal 1: foreground; Ctrl-C stops only the child it created.
hlens mock --url http://127.0.0.1:8080 --session qa-20261028-01 --exclusive start
```

In the test runner terminal, use one helper for the same server/session. `--exclusive` means this instance is dedicated to this run. An explicit `--jar` overrides `HLS_WIREMOCK_JAR`; with neither set, `start` only health-checks an existing external server and returns. Global options precede the command.

```bash
umask 077
mkdir -p .qa-artifacts/qa-20261028-01/wiremock
HLS_ROOT=/path/to/HarnessLens
wm() {
  hlens mock --url http://127.0.0.1:8080 --session qa-20261028-01 --exclusive "$@"
}
# Install cleanup before apply; on failed setup it still attempts session removal.
trap 'wm reset > .qa-artifacts/qa-20261028-01/wiremock/cleanup.json' EXIT
wm start
wm apply "$HLS_ROOT/examples/wiremock/rest-query.json" \
  > .qa-artifacts/qa-20261028-01/wiremock/apply.json
wm list
# Perform actual app actions here. Do not use curl to manufacture app evidence.
wm requests > .qa-artifacts/qa-20261028-01/wiremock/requests.json
wm verify --name accounts-empty --min-hits 1 --max-hits 1 \
  > .qa-artifacts/qa-20261028-01/wiremock/verify.json
# Inspect exit status: 0 success, 1 expected-hit assertion failed, 2 setup/input error.
# A shell journey runner must propagate failures and check cleanup's exit status.
# Keep mappings active until any parent QA reporter has verified them.
wm disable --name accounts-empty
# Re-apply enables it again; previous hit evidence for applied names is cleared.
wm apply "$HLS_ROOT/examples/wiremock/rest-query.json"
wm reset
```

The shell trap is a fallback, not a passing cleanup receipt: inspect its exit status and JSON. Restore any device/app routing separately even on verification failure. Exiting a child shell does not stop an external WireMock server.

`apply` upserts a stable ID per session/name, retains the raw fixture SHA-256, and clears prior matched events for the applied mapping. `list`, `disable`, `requests`, `verify`, `reset` operate only on that session. `disable` removes one mapping and its hits; `reset` removes all session mappings, restores only their scenarios to Started and deletes only their matched events. No global reset endpoint is used. Applying a bundle is not transactional: after an interrupted/failed apply, run reset. Do not run concurrent commands with the same session.

## Matching and response changes

Native WireMock mappings avoid an extra fixture language. Each mapping needs a unique safe `name`, `request`, `response`; optional `priority`, `scenarioName`, `requiredScenarioState`, `newScenarioState`, body matchers and response transformers are passed through. A file is either one mapping or `{"mappings":[...]}`. Keep names stable when replacing a response at runtime; disable previous differently named overlapping mappings first. Lower priority numbers win; equal priorities use WireMock's newest matching stub.

| Fixture | Condition |
|---|---|
| `rest-query.json` | GET `/accounts` page 0 empty / page 1 last result |
| `rest-post.json` | POST `/payments`, JSON Content-Type, JSONPath amount=42, declined 422 |
| `graphql.json` | `/graphql`, operation and variables, named query without operationName, constrained anonymous query, dynamic variable response |
| `graphql-error.json` | Higher precedence Account(id=denied), HTTP 200 with data/null and GraphQL errors |
| `delayed.json` | Fixed 350ms latency |
| `retry.json` | 503 then 200 through a native scenario |
| `passthrough.json` | Lowest precedence catch-all to an explicitly selected backend |

For malformed JSON, set `response.body` to the desired malformed string instead of `jsonBody`. For empty HTTP responses use `status: 204` and omit the body. For authentication/authorization tests use 401/403 with the contract's headers/body; retain the app's existing auth interceptor and refresh behavior. A mocked API 401 can cause real token refresh traffic: keep the auth service real unless testing it is explicitly in scope.

Use `fixedDelayMilliseconds` above the configured client read timeout for timeout behavior. A slow response or synthetic 504 alone is not proof of a client timeout. Native `fault` options support transport faults. Reuse the scenario fields in `retry.json` for multi-step workflows; apply the full bundle to restart it. No server-wide delay/settings/scenario changes are needed.

GraphQL matches operationName and JSONPath variables, so many operations can share one URL. For clients omitting operationName, the example checks the named query text; its anonymous example restricts the root field. These are constrained regex examples, not GraphQL parsers. Persisted queries, GET GraphQL, aliases, multiple operations per document, batched requests, fragments or syntax-insensitive AST matching need explicit fixtures. Only consider WireMock's GraphQL extension when native request matching cannot reliably distinguish the actual payloads; do not install it by default. `toJson` escapes variables when rendering dynamic JSON; never inject unescaped user input into a template.

## Real backend fallback and shared servers

```bash
wm apply "$HLS_ROOT/examples/wiremock/passthrough.json" \
  --upstream https://authorized-staging-api.example.test
# Targeted mocks (priority 5 by default) override this priority-10000 fallback.
wm disable --name accounts-empty
# Matching traffic now goes to the backend while other selected mocks remain.
```

Without fallback, unmatched requests receive WireMock's 404. Fallback intentionally forwards real requests, including credentials and writes, to the specified authorized backend. Use a disposable test account and the correct origin/base path; verify authentication audience and host requirements. It is a reverse proxy, not a device-wide HTTP CONNECT proxy. Other domains remain on their existing real routes. Never point fallback back at WireMock; hostname aliases can also cause loops. Reset removes fallback too: restore the app's original base URL to return fully to normal backend behavior.

For shared servers replace `--exclusive` with `--scope-header X-QA-Session` and configure the debug app to send `X-QA-Session: <run-id>`. The adapter adds this matcher to every mapping, namespaces scenario names, and strips this header when proxying upstream. The server rejects mixing these adapter-owned sessions with an unscoped adapter session. Unowned/native mappings are preserved and can shadow tests; inspect the server or choose a separate instance. Session metadata is an isolation convention, not a security boundary against other Admin API users. Use separate servers if the app cannot provide a scope header.

External URLs support HTTPS with normal system trust and optional `WIREMOCK_ADMIN_TOKEN` bearer authentication through a gateway. No TLS bypass or secrets in URLs. Keep the Admin API private; its journal contains raw request content even though adapter output does not. Local mode binds loopback, disables request logging and bounds the in-memory journal to 1000 entries. It never records response fixtures from live traffic. External server privacy/retention policy is the operator's responsibility.

## Mock coverage inventory

Before applying fixtures for a feature flow, trace the request path from the user action through
the app's service and repository, including successful mutation responses and follow-up syncs.
Use code to identify method/path and payload construction; derive expected request/response
behavior from the OpenAPI contract and approved shared/feature scenario. Do not make production
calls to harvest response data. Fixture bodies must remain synthetic, and request body matchers
should assert the feature payload when it matters.

When a scenario declares `apiMocks` or `expectations.wiremock`, require an
`expectations.mock_coverage` inventory. Each `fixture_ids` entry is an `apiMocks[].id` or a
WireMock mapping `name`. Link it to the UI check that triggers the interaction and retain both
the app call-site and contract/fixture source:

```json
{
  "mode": "feature_api",
  "interactions": [{
    "id": "table-content-save",
    "check_id": "table_persisted",
    "operation": "updateNoteContent",
    "method": "PATCH",
    "path": "/v1/notes/{itemID}/content",
    "api_source": "app/src/main/java/.../NotesApiService.kt#updateNoteContent",
    "contract_source": "sharedContracts/test-scenarios/note_update_content_001.json#/apiMocks/0",
    "fixture_ids": ["table-note-save"]
  }]
}
```

If mocks only prove that the app reaches the local server, use `mode: routing_only`, provide a
reason, and state that this does not cover the feature API behavior. The exploratory-QA reporter
marks absent or unlinked inventories `INCONCLUSIVE`, and names routing-only coverage separately
from feature API coverage.

## Exploratory QA integration

Use the run ID for the session. Add this to the run scenario's `expectations`, using the actual SHA-256 from apply output. The list is independent of existing mitmproxy `apiMocks` and `expectations.requests`.

```json
{"wiremock":[{"name":"accounts-empty","min_hits":1,"max_hits":1,"fixture_sha256":"<actual-64-character-sha256>"}]}
```

Record a real app request correlated to the journey before setting `observations.wiremock_routing_verified: true`. Save screenshots/state via dogfood and HarnessLens. Then run the existing reporter before cleanup:

```bash
python3 .agents/skills/exploratory-qa/scripts/report.py \
  --run-dir .qa-artifacts/qa-20261028-01 \
  --scenario .qa-artifacts/qa-20261028-01/scenario.json \
  --harnesslens-root /path/to/pinned/HarnessLens \
  --wiremock-url http://127.0.0.1:8080 --wiremock-session qa-20261028-01
```

The reporter calls the HarnessLens WireMock module and stores sanitized `wiremock_verifications` in report.json. It checks session equals the run directory, fixture hash, active mapping and hit bounds. Missing routing/server/mapping is INCONCLUSIVE; a healthy unused fixture is FAIL. Existing HarnessLens/UI/network checks still apply. No WireMock expectations means no CLI import or server requirement.

For analytics-event-validator, select the backend condition from the approved event requirements, apply, use the existing capture/reset/flush/collect/validate commands, and verify every required mapping before cleanup. Retain the analytics verdict and WireMock verdict separately; neither proves the other. Do not replace or intercept the analytics collector. When the parent is exploratory-QA, share its actions and run and defer cleanup to its reporter.

## Troubleshooting

- No hits: confirm app base URL, actual request shape, cache invalidation, scope header, priority and fixture hash. Trigger a new request using real UI. A healthy unused mapping fails verification; do not substitute helper requests.
- Setup HTTP 422: validate native mapping syntax against the server's Admin API schema. Error bodies are deliberately not printed because they can echo secrets. Diagnose using sanitized synthetic fixtures on a private server.
- Proxy errors: check upstream origin, base path, DNS, normal TLS trust and auth requirements; do not change enterprise security controls. Do not proxy requests to the listener itself.
- GraphQL mismatch: inspect a sanitized synthetic payload and distinguish transport errors from HTTP-200 GraphQL errors; check omitted operationName, variable types and query syntax. Do not retain real bodies as artifacts.
- Missing earlier hits: the journal may have evicted them or apply cleared the window. Start a fresh bounded run. Requests from before apply or after cleanup cannot prove the declared run.
- Interrupted run: reset using the same server/session, restore routing, stop the owned foreground server. Reset is idempotent. A failed cleanup is a setup issue, never a pass.

## Discovery and validation

This skill is the workflow guide; the adapter implementation lives in HarnessLens `cli/harnesslens/wiremock.py`. Codex discovers this skill through the consuming app's `.agents` symlink. Claude Code can load this skill and invoke the same `hlens mock` CLI; keep one adapter implementation.

```bash
cd /path/to/HarnessLens
python3 -m unittest discover -s tests -p test_wiremock_cli.py -v
WIREMOCK_JAR=/path/to/wiremock-standalone-3.13.1.jar \
  python3 -m unittest discover -s tests -p test_wiremock_integration.py -v
```

The unit suite uses only Python's standard library. The optional integration test launches a real WireMock process; it proves the server boundary, not Android/iOS routing or analytics collection.

Primary references: [Admin API](https://wiremock.org/docs/standalone/administration/), [matching](https://wiremock.org/docs/request-matching/), [templating](https://wiremock.org/docs/response-templating/), [proxying](https://wiremock.org/docs/proxying/), [verification](https://wiremock.org/docs/verifying/), [scenarios](https://wiremock.org/docs/stateful-behaviour/), [GraphQL extension](https://wiremock.org/docs/solutions/graphql/).
