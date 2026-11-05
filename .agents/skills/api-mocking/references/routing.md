# Routing apps to WireMock

Fixtures are server-side. After an app points at WireMock, applying/replacing/disabling fixtures requires no app rebuild. Preserve the original URL, proxy, trust and session-header settings and restore them after the run. Backend interception must be established by a real in-app receipt, not server health or host-side curl.

## Inspect the installed target first

Routing is app- and build-specific. Inspect the current target instead of treating an old
repository snapshot or the example below as proof of the installed build's capabilities.

1. Record the selected device, package/bundle ID, installed version, debuggable status and
   installed artifact identity where available. When the user authorizes an existing
   installed build, use it for local QA and record any unavailable source/CI provenance.
   Do not rebuild or reinstall merely to create a routing prerequisite. Local QA results
   do not establish post-merge or release provenance when that identity is unavailable.
2. Inspect the app's current base URL construction, request interceptors, debug target
   picker and route persistence. Verify an existing runtime route in the installed UI.
   A checkout containing a picker does not prove that the installed artifact has it.
3. Inspect main/debug manifests and the packaged or merged network-security configuration.
   Record whether the selected HTTP/HTTPS origin is permitted, including any certificate
   trust or pinning constraints. Debuggable alone does not establish cleartext permission
   or test-CA trust. Do not weaken TLS or release policy to make routing work.
4. Prefer the existing runtime route when available. Use a build-time override only when
   the installed target has no supported runtime route and a different build is separately
   authorized. A missing route is an explicit affected-case evidence gap; it does not
   authorize an application change, implicit rebuild, or a passing routing claim.
5. Before changing routing, create `wiremock/routing-preflight.md` in the run leaf with the
   required fields below. After the app action, add its request proof and the restoration
   result. A server listener, health check or host-side curl cannot prove app routing.

| Required field | Evidence to retain |
|---|---|
| `installed_artifact` | Device, package/version/debuggable status, installed artifact hash or explicit limitation; no substitution of checkout HEAD for installed identity. |
| `routing_control` | Current source/config paths, installed UI control and observed selection, target origin, route lifetime, dedicated-server/session isolation. |
| `network_security` | Main/debug/packaged configuration and target-specific HTTP/HTTPS allowance, trust and pinning limits. |
| `app_request_receipt` | Mapping name/hash and app-originated method/path hit correlated with the triggering UI action; pending until the action actually runs. |
| `restore` | Original app target, proxy/trust/header and ADB reverse state, owned changes, cleanup commands and verified restoration result. |

## NotesTakingApp debug routing example

The current source provides the following route. Verify it in the selected installed
artifact before using it; these source facts are not device evidence:

- `app/build.gradle.kts` configures `BuildConfig.API_BASE_URL` from local.properties, then
  environment, then the default URL. `AppModule.kt` installs
  `RuntimeApiBaseUrlInterceptor` alongside the existing auth interceptor/authenticator.
- In debug builds, tap `settings_debug_api_routing_trigger` seven times within three
  seconds in Settings. Select the visible “Localhost, localhost:8080” option, then “Done”
  (source tags `debug_api_target_localhost` and `debug_api_routing_done`). Use the fresh
  installed snapshot's selectors: Compose dialog windows may expose labels without their
  test tags even when Activity controls expose tags as IDs. The fixed localhost endpoint is `http://localhost:8080/`;
  new requests preserve their path/query while their scheme, host and port change.
  The choice is process-local and takes effect without a client rebuild or process restart.
- `app/src/debug/AndroidManifest.xml` supplies
  `@xml/debug_localhost_network_security_config`, whose domain policy permits cleartext
  only for `localhost`; the main manifest retains its cleartext restriction. This does
  not establish trust for unrelated HTTPS certificates or origins.
- For a host-side WireMock listener, use serial-pinned
  `adb -s <serial> reverse tcp:8080 tcp:8080` so the Android localhost target reaches the
  host. Inspect existing reverse rules first and preserve them. `10.0.2.2` is not the
  target selected by this fixed localhost picker.
- The picker does not supply a session-header control. Use a dedicated WireMock server
  unless the installed app independently supports and demonstrably sends a session header.
- Restore the visible “Production, Configured API URL” option (source tag
  `debug_api_target_production`) and dismiss the picker during cleanup. “Production”
  means the build-configured API URL: verify its actual authorized environment before real
  requests or passthrough writes. A process restart resets the choice, so recheck it after
  interruptions. Export/verify mocks before removing only this run's reverse rule/session.

If the installed target lacks this route, record that mismatch and keep affected mocked
cases INCONCLUSIVE. Do not infer an iOS route from this Android example.

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
