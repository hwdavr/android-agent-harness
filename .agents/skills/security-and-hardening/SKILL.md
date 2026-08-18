---
name: security-and-hardening
description: Hardens Android code against security and privacy risks. Use when handling authentication tokens, local storage, deep links, WebView, file or content URIs, exported components, IPC, network communication, or third-party SDKs. Use when building features that process untrusted input, store sensitive data on-device, or integrate with backend APIs and external services.
---

# Security and Hardening

## Overview

Security-first development practices for Android applications. Treat every external input as untrusted, every token as sensitive, every exported surface as a security boundary, and every persisted secret as a liability. Security is not a later review step. It constrains storage, networking, manifest design, SDK integrations, and UI behavior from the start.

## When to Use

- Handling auth tokens, refresh tokens, or user sessions
- Storing sensitive data locally
- Adding deep links, app links, or exported components
- Working with `Intent`, `Bundle`, `SavedStateHandle`, URI input, or navigation args from outside the current process
- Opening files, attachments, camera/gallery results, or `content://` URIs
- Adding or modifying `WebView`
- Integrating third-party SDKs, analytics, crash reporters, or external APIs
- Handling PII, financial data, or regulated data
- Making build, manifest, or network security configuration changes

## Android Security Boundaries

### Always Do

- Validate all external input from `Intent`, deep link, URI, `Bundle`, backend payload, and file metadata
- Store tokens and sensitive local data using encrypted storage where practical
- Use HTTPS for production traffic and block cleartext by default
- Keep Android components non-exported unless there is a clear product need
- Apply least privilege for runtime and manifest permissions
- Redact tokens, secrets, and sensitive identifiers from logs and crash reports
- Review manifest, Network Security Config, and build-type changes for security impact
- Keep dependencies and SDKs updated and review known vulnerabilities before release

### Ask First

- Adding a new exported Activity, Service, Receiver, or Provider
- Adding or changing authentication/session flows
- Storing new categories of sensitive local data
- Adding `WebView`, JavaScript bridges, or arbitrary URL loading
- Relaxing TLS validation, enabling cleartext traffic, or adding trust exceptions
- Adding certificate pinning
- Introducing new third-party SDKs that collect user/device data
- Expanding background sync, foreground services, or privileged device access

### Never Do

- Never hardcode API keys, client secrets, tokens, or credentials in source
- Never log passwords, access tokens, refresh tokens, session secrets, or full PII
- Never trust client checks as authorization
- Never set components exported by default for convenience
- Never disable TLS verification in production
- Never allow app-wide cleartext traffic for convenience
- Never use unrestricted `WebView` settings against untrusted content
- Never assume file extension or MIME declaration is trustworthy without validation

## Core Threat Areas

### 1. Input Validation at Android Boundaries

- Validate IDs, enum values, route params, and user-entered fields before use
- Validate all `Intent` extras and deep-link params before navigation or data fetch
- Treat backend responses as untrusted until parsed and mapped
- Constrain URI schemes, authorities, MIME types, and file sizes

### 2. Local Data Protection

- Use encrypted storage for tokens and highly sensitive data
- Avoid plaintext storage in `SharedPreferences`, Room, or files unless risk is explicitly accepted
- Clear sensitive state on logout
- Review whether local data should be excluded from backup/restore
- Avoid placing secrets in clipboard, notifications, widgets, or screenshots unless explicitly required

### 3. Auth and Session Handling

- Keep tokens out of logs, exceptions, analytics, and navigation args
- Clear both in-memory and persisted auth state on logout
- Treat refresh-token handling as sensitive infrastructure
- Fail closed when auth state is missing, malformed, or expired

### 4. Exported Components and IPC

- Default to `android:exported="false"`
- Validate all incoming extras, actions, and URIs on exported entry points
- Use the narrowest permission model possible for IPC
- Avoid unintentionally exposing data via Providers, Receivers, or implicit intents

### 5. Deep Links and Navigation

- Treat every deep-link parameter as hostile
- Validate destination eligibility before entering privileged flows
- Do not navigate directly into sensitive screens without auth and state checks
- Ensure malformed or partial deep links fail safely

### 6. Network Hardening

- Use HTTPS only for production endpoints
- Use Network Security Config intentionally rather than broad defaults
- Validate backend payloads before domain/UI mapping
- Be explicit about retry and fallback behavior on auth and transport failures

### 7. WebView Safety

- Avoid `WebView` unless it is genuinely needed
- Disable JavaScript unless required
- Never add a JavaScript interface to untrusted content
- Restrict file access and mixed content
- Do not load arbitrary user-provided URLs without allowlisting

### 8. File and URI Handling

- Use `ContentResolver` and scoped access patterns
- Validate MIME type, size, and expected source before processing
- Request and grant the narrowest URI permissions possible
- Treat attachment parsing and preview rendering as untrusted-input paths

### 9. Third-Party SDK Data Minimization

- Review what data the SDK collects, stores, and transmits
- Disable unnecessary identifiers, auto-capture, or verbose logging where possible
- Do not send auth tokens or sensitive note content to SDKs unless explicitly required and approved

## Android Release Hardening

### Obfuscation and Shrinking

Use for release builds that ship sensitive business logic, anti-abuse checks, or auth-adjacent behavior.

- Enable R8 for release builds where appropriate
- Shrink unused code and resources when safe
- Add only the keep rules required by serialization, DI, reflection, and SDK integrations
- Verify obfuscation does not break Retrofit, Moshi, Kotlinx Serialization, Hilt, Room, or navigation
- Do not treat obfuscation as a primary security boundary

Checks:
- Release build uses `isMinifyEnabled = true` where the app policy expects it
- Release build uses `isShrinkResources = true` when compatible
- Keep rules are minimal and reviewed, not copied wholesale

### TLS and Certificate Pinning

Use selectively for high-sensitivity traffic or environments with explicit MITM-resistance requirements.

- Enforce HTTPS for production traffic
- Add certificate pinning only with an agreed certificate rotation plan
- Prefer designs that support backup pins and controlled migration
- Document the expected failure behavior before shipping pinning
- Do not add pinning casually; broken pinning creates production outages

Checks:
- Only justified production hosts are pinned
- Rotation and backup-pin strategy exists
- Pin failure UX and recovery behavior are reviewed

### Debuggable and Build Variant Configuration

Release builds must not expose debug behavior.

- Ensure release builds are not debuggable
- Keep debug-only tooling, mock endpoints, inspectors, and verbose logging out of release variants
- Gate dev menus and test hooks behind debug-only build flags
- Verify final merged manifest and release config, not just source defaults

Checks:
- Release variant is not debuggable
- No debug interceptors or inspectors are bundled in release
- No staging or localhost endpoint can ship in production

### Cleartext / Plain HTTP Enforcement

Plain HTTP should be blocked unless there is a narrow, approved exception.

- Set `usesCleartextTraffic="false"` by default
- Use Network Security Config for tightly scoped exceptions only
- Never allow app-wide cleartext just to support a convenience endpoint
- Review SDKs, image loaders, and file fetchers for accidental HTTP usage

Checks:
- Production traffic uses HTTPS only
- Any cleartext exception is host-specific and documented
- `WebView` behavior does not silently reintroduce insecure transport

## Review Checklist

- What are the new trust boundaries in this change
- Does any new input cross process, network, file, or URI boundaries
- Is any sensitive data stored locally, and if so, is the storage appropriate
- Did this change add any exported manifest surface
- Could this change leak data through logs, screenshots, clipboard, notifications, backups, or SDKs
- Are permissions minimal
- Does release configuration differ safely from debug
- Is cleartext blocked and TLS behavior appropriate
- Is pinning justified operationally if added

## Testing Expectations

- Add unit tests for validation, sanitization, and secure fallback logic
- Add integration tests for malformed backend payloads, auth failures, and URI/file edge cases where practical
- Review manifest and release-build security settings when changing exported surfaces, permissions, TLS, or cleartext policy
- For logout or credential changes, verify sensitive state is cleared from memory and disk-backed storage

## What This Skill Is Not For

- Backend-only concerns like CORS, CSP, HSTS, cookie flags, SQL injection, or server-side rate limiting
- Payment-industry or platform-compliance audits that require formal legal/compliance review

