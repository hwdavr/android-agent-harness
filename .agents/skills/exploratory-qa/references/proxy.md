# Capture and response fixtures

The helper binds loopback and records only exact allowlisted hosts. Output contains method, host, sanitized path, status, duration and mock identity; no raw flows, live bodies, headers, cookies or query strings. Path redaction is best effort: paths, logs and screenshots still need review.

## Start

Use a unique run ID from the app root:

```bash
export QA_RUN_ROOT="$PWD/.qa-artifacts"
export QA_ALLOWED_HOSTS='api.your-test-host.example'
export QA_PROXY_PORT=8080
# Mock mode only; unset for capture-only mode.
export QA_MOCK_SCENARIO="$QA_RUN_ROOT/<run-id>/scenario.json"
bash .agents/skills/exploratory-qa/scripts/qa-proxy.sh start <run-id>
bash .agents/skills/exploratory-qa/scripts/qa-proxy.sh status <run-id>
```

For capture-only mode set `QA_SCENARIO_ID` to the scenario ID. Start refuses reused network logs. The child is detached and readiness is checked using its own PID receipt. Always check status; if a command runner reaps descendants, use a persistent terminal. Optional `QA_MITM_CONFIG_DIR` selects mitmproxy's private config; keep CA private keys outside retained/shared artifacts.

Device routing and CA trust are separate setup. Save prior Android proxy state and use only a dedicated authorized test device; emulator host access normally uses `10.0.2.2:<port>`. The helper refuses LAN listeners. Restore changes at teardown. Do not bypass pinning or disable TLS verification.

Apps targeting Android 24+ do not trust user-added CAs by default, and debuggable alone does not add trust. Inspect the packaged manifest and verify an actual in-app intercepted request. The current target-34 debug APK has no Network Security Configuration; HTTPS mocking is not established for it. Record unavailable interception as blocked/inconclusive. A curl helper test does not prove the Android boundary; neither does `agent-device network dump`, which depends on app logs.

## Fixtures

Reuse selected shared/feature-owned `apiMocks`, adding explicit host and stable rule `id`. This reserved-host example is a schema illustration, not an app API:

```json
{"scenario_id":"service-error","apiMocks":[{
  "id":"unavailable","host":"qa.example.test","method":"GET","path":"/items",
  "status":503,"response":{"error":"temporarily_unavailable"},"delay_ms":200,"min_hits":1
}]}
```

`response` is JSON fixture data. Alternatively, `body_file` relative to the scenario directory supplies malformed JSON/binary bytes; copy sanitized fixtures into that directory and retain original provenance. Exactly one body source is required. Optional `headers` contains synthetic response headers; content-length, transfer-encoding and connection headers are proxy-managed. Optional `query` is an exact string map; omit it to match any query on that host/method/path. Overlapping generic/query rules are rejected. Delay is bounded to 30,000ms.

Mock hosts must exactly equal the allowlist. Responses are synthesized in request hooks with lazy upstream connections. Unmatched mock-host requests receive a local setup error and an `unmatched_mock` receipt, never live fallback. Invalid/missing fixtures prevent startup. Stop, edit fixtures, and start a fresh run ID to change responses without rebuilding the APK. Re-trigger actual requests when app caching prevents traffic.

Metadata includes mocked status, rule ID, body fixture SHA-256 and scenario SHA-256. Required unused fixtures are inconclusive; unmatched traffic is a setup failure. Intentional 4xx/5xx must be allowed by any request expectations and checked against recovery UI. Synthetic HTTP 504 is distinct from a transport timeout.

## Finish

```bash
bash .agents/skills/exploratory-qa/scripts/qa-proxy.sh stop <run-id>
```

Use dogfood's log/session cleanup; save log paths before closing. Restore prior proxy/CA state and never export the CA private key. Synthetic body files are test inputs, not live captures.

Sources: [response hooks](https://docs.mitmproxy.org/stable/addons/examples/), [proxy options](https://docs.mitmproxy.org/stable/concepts/options/), [Android trust](https://developer.android.com/privacy-and-security/security-config).
