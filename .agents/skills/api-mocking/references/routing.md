# Routing apps to WireMock

Fixtures are server-side. After an app points at WireMock, applying/replacing/disabling fixtures requires no app rebuild. Preserve the original URL, proxy, trust and session-header settings and restore them after the run. Backend interception must be established by a real in-app receipt, not server health or host-side curl.

## Inspected NotesTakingApp baseline

- `app/build.gradle.kts` reads `API_BASE_URL` from local.properties, then environment, then `https://api.example.com/`; it writes `BuildConfig.API_BASE_URL` at build time. A local.properties value takes precedence over an environment override.
- `app/src/main/java/com/example/notesapp/di/AppModule.kt` creates singleton Retrofit from that constant and keeps the existing AuthInterceptor/TokenAuthenticator. No runtime URL override was found.
- `app/src/main/AndroidManifest.xml` disallows cleartext HTTP. The debug manifest adds a test activity and has no debug Network Security Configuration. Debuggable alone does not establish HTTPS test-CA trust.
- No iOS target/configuration was found in this checkout. No device routing or iOS analytics collector is claimed as verified by this skill's host tests.

The smallest one-time setup is a debug build with `API_BASE_URL` pointing to a trusted HTTPS WireMock gateway. Set the value through the existing local.properties/environment mechanism; confirm the packaged build and launch it through the existing device skill. Subsequent mapping changes are immediate. Preserve the original value and build after the test if a different artifact is needed. Do not change production networking/security for this harness task.

If runtime switching is required, propose a separate, small debug-only change at the existing Retrofit/OkHttp construction point: a validated debug preference for a test origin and, only if shared servers are needed, a debug session-header setting. Recreate the client or restart the process when the preference changes; keep release wiring on BuildConfig and preserve auth behavior. No such app change is implemented here. Debug cleartext/CA changes also require a separately authorized app scope; prefer a trusted HTTPS endpoint where practical.

## Platform capability matrix

| Target | Route from app | One-time prerequisites | Evidence status |
|---|---|---|---|
| Android standard emulator | `10.0.2.2:<port>` reaches host; or `adb -s <serial> reverse tcp:8080 tcp:8080` then device loopback | Existing debug URL override/build; HTTP must be explicitly permitted only in debug, or use trusted HTTPS | Documented; not device-tested |
| iOS simulator | Host `127.0.0.1:<port>` for a local listener | Existing debug base URL setting; HTTPS trust or narrowly scoped debug ATS exception | Documented; no iOS target here |
| Android USB device | Serial-pinned ADB reverse, device loopback URL | Debug URL selection and valid TLS/debug-only HTTP configuration | Documented; not device-tested |
| iOS physical device | Reachable host LAN DNS/IP or private HTTPS gateway; device localhost is the device | Existing debug URL setting, trusted certificate, authorized network and local network permission if applicable | Documented; not device-tested |
| Android LAN device | Reachable host LAN DNS/IP or private HTTPS gateway | Same URL/TLS constraints; host firewall permits only the test device | Documented; not device-tested |
| Adapter + real server | Host loopback and local reverse-proxy upstream | Python 3.9+, Java 17+, trusted WireMock JAR | Covered by real server integration tests |

Local adapter startup intentionally binds loopback. For physical-device LAN access, use an already configured private server/gateway and connect with `start` without `--jar`. A WireMock listener exposes Admin API on the same port; firewall/reverse-proxy rules must restrict admin access while allowing app traffic. Do not expose an unauthenticated WireMock port to a public network. ADB reverse is per serial; remove only the reverse rule added for this run.

## HTTPS, auth and restoration

Use certificates trusted by the test app and valid for its configured hostname. If the app already pins certificates, use an authorized debug configuration or report the missing prerequisite. Never disable verification, bypass pinning, add a release trust override or modify managed-device security. WireMock's standalone HTTPS options or an existing private TLS gateway can terminate TLS. Forward-proxy settings alone cannot rewrite a hardcoded HTTPS base URL into this reverse-proxy server.

Keep the existing auth/network stack. Passthrough forwards Authorization and cookies; use an authorized test backend/account and check token audience/host constraints. Other services (Auth0, analytics, bookmark URLs) keep their real routes unless separately scoped. The scope header is synthetic and is removed from proxy upstream requests by the adapter.

At teardown, verify/export first, reset session-owned mappings, restore the original debug URL/header, restore any prior device proxy/CA settings, remove only this run's reverse rule and close only owned sessions/listeners. Retain sanitized evidence locally. A failed or unavailable platform setup is INCONCLUSIVE, not proof that app behavior passed.

Sources: [Android emulator networking](https://developer.android.com/studio/run/emulator-networking), [Android Network Security Configuration](https://developer.android.com/privacy-and-security/security-config), [Apple ATS](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity), [WireMock HTTPS](https://wiremock.org/docs/https/).
