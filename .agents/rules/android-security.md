# Android Security Code Rules

## Purpose and Scope

These rules define the mandatory security baseline for Android code that crosses a
trust boundary. Apply them whenever a change handles authentication or session
data, local sensitive data, `Intent`/`Bundle`/URI input, files, deep links,
exported components or IPC, networking/TLS, `WebView`, third-party SDKs, AI/model
input or output, rendering, or release/build security settings.

This is the conditional `SEC` row in the ten-row Rule Applicability matrix. When a
change touches one of the boundaries above, record `SEC: Required` and the relevant
evidence in the plan/review. When none apply, record `SEC: Not applicable — no
Android security boundary is changed`.

## Trust-Boundary Invariants

### 1. Treat external input as hostile

- Treat user text, backend responses, model output, `Intent` extras, deep-link
  parameters, `Bundle` values, navigation arguments, file metadata, and `content:`
  or remote URIs as untrusted.
- Validate type, size, encoding, scheme, authority, MIME type, and allowed values
  before use. Prefer bounded fields and explicit allow-lists over best-effort
  filtering.
- Reject malformed, blank, oversized, unknown, or ambiguous values and use a
  deterministic safe fallback. Do not turn validation failures into privileged
  navigation or data access.

### 2. Protect secrets and private content

- Never hardcode API keys, credentials, access/refresh/ID tokens, or signing
  material. Keep environment-specific values in approved configuration such as
  `local.properties` and `BuildConfig` without committing secrets.
- Never log, send to analytics, include in exception messages, or expose in UI
  diagnostics: credentials, tokens, full note content, prompts, model output,
  PII, or sensitive identifiers. Redact before telemetry or crash reporting.
- Store tokens and highly sensitive local data in encrypted storage where
  practical; clear in-memory and persisted session state on logout. Review
  backups, screenshots, notifications, clipboard, widgets, and previews for
  accidental disclosure.

### 3. Enforce network and transport security

- Production traffic must use HTTPS. Keep `usesCleartextTraffic="false"` and
  reject app-wide cleartext or TLS-verification bypasses.
- Any development or host-specific exception must be narrowly scoped, documented,
  approved, and excluded from release configuration. Never trust all certificates
  or hostnames in production.
- Validate and map remote payloads before domain/UI use; do not let a transport
  success imply authorization.

### 4. Keep WebView and rendered content least-privileged

- Avoid `WebView` unless required. For untrusted or inline content, disable
  JavaScript, DOM storage, file access, content access, and network loads unless
  a documented product requirement proves each setting necessary.
- Do not add JavaScript bridges for untrusted content, load arbitrary URLs, use a
  `file:///` base URL, or write untrusted model/user content directly to an HTML
  sink such as `innerHTML`.
- Mermaid or other diagram renderers must use strict security mode and sanitize or
  bound source text before rendering. Never use a loose security mode for
  untrusted diagrams.

### 5. Minimize Android component and IPC exposure

- Components are non-exported by default. An exported Activity, Service, Receiver,
  or Provider requires a clear product need, the narrowest permission model, and
  review of every incoming action, extra, URI, and caller.
- Validate incoming values before accessing data or entering privileged flows.
  Do not grant broad URI permissions or expose providers/intents for convenience.
- Request only the minimum manifest and runtime permissions and document why each
  permission is needed.

### 6. Constrain AI/model boundaries

- Bound every prompt field and clearly delimit untrusted user, note, backend, or
  file content before it reaches a model. Do not include secrets or unnecessary
  private content.
- Treat model responses as untrusted data. Accept only an exact, typed,
  allow-listed result; reject prose, markup, unknown values, blank values, and
  oversized output. Use a deterministic fallback and isolate requests so one
  request cannot influence another.
- Do not add an external model/service, upload private content, or expose model
  prompts without an explicit product and security review.

### 7. Harden release configuration and dependencies

- Release builds must not be debuggable and must not contain staging endpoints,
  inspectors, test hooks, or verbose sensitive logging. Review the merged release
  manifest/configuration rather than source defaults alone.
- Use R8/resource shrinking where the release policy requires it; keep rules must
  be minimal and justified. Obfuscation is not a substitute for access control.
- Review third-party SDK collection, permissions, transitive vulnerabilities, and
  update policy before adoption. Disable unnecessary identifiers and telemetry.

## Required Evidence and Enforcement

For a change marked `SEC: Required`:

1. Explain the affected trust boundary and the validation, least-privilege, and
   failure behavior in the implementation/review evidence.
2. Add unit/integration tests for validation, redaction, secure fallback, malformed
   URI/file/backend input, or authentication failures as applicable.
3. Add a real instrumented boundary test for platform behavior such as WebView,
   exported components, URI grants, permissions, or lifecycle/security state.
   JVM-only fakes are supplemental; an unavailable runtime/device/model/permission
   must fail loudly or remain blocked, never be recorded as a pass.
4. Run the canonical source gate from the project root:

   ```bash
   bash harness/scripts/check-full-source-rules.sh
   ```

   The bundle invokes `check-ai-security-rules.sh` and its negative-case contract
   test. The evaluator mechanically rejects app-wide cleartext, unsafe WebView or
   Mermaid settings, AI-input logging, and direct untrusted HTML sinks; it does not
   replace human review of storage, IPC, permissions, SDKs, or release settings.
5. Also run Android Lint, Detekt, Ktlint, and the applicable contract/gate checks.
   Do not suppress a finding, add a baseline, or broaden an exclusion to make a
   security check pass. Fix the root cause or document an explicitly approved
   false positive.

## Out of Scope

Backend-only controls (for example CSP, HSTS, cookie flags, server-side rate
limiting), formal compliance certification, and penetration testing require their
own owners and review. They do not waive these client-side rules.
