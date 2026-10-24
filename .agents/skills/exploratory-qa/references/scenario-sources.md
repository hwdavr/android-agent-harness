# Generate a scoped scenario

The agent writes run-specific JSON; the reporter evaluates it and never scans source or invents observations.

1. Resolve the requested feature, bug, APK, or diff. Prefer its approved spec/UI contract, then its test plan or sprint contract in `docs/current/` or its stable `.scratch/<feature>/` workspace. Check `Related spec`; the latest shared UI contract may belong to another feature.
2. Inventory the feature's relevant user-visible entry points before selecting a journey. Include Home shortcuts/cards and in-context tool entries, plus other documented routes such as notifications or deep links when relevant. Use the approved contract, a Home/runtime snapshot, journey registry, and action inventory as discovery sources. These sources are hints; runtime behavior is still the evidence.
3. Put every in-scope entry point in `entry_points` with its surface, action, expected destination/behavior, and a `check_id` present in `expectations.ui_checks`. Put only explicitly out-of-scope or future routes in `excluded_entry_points` with a reason. Do not silently omit unclear entry points; record the ambiguity and report missing intent.
4. Map selected Screen States, IME State Coverage, entry actions, controls, fixtures, and verification expectations to `states` and `expectations.ui_checks`. Retain state IDs/plan stages and bound the exploration budget. Ensure each in-scope entry point has a corresponding runtime check.
5. Use `docs/product/journey-registry.yaml`, relevant tests, UiState, navigation, handlers, and testTags for additional route/state hints. Code-only states belong in candidate `exploration_targets`, not approved expectations. Disclose missing intent.
6. Record `{path, sha256, section}` in `generation.sources` and binary identity in `target`. If source is absent or mismatched, use supplied acceptance criteria plus dogfood's runtime map.
7. Dogfood must verify real entry actions and runtime selectors. Test callbacks such as `onImageImported` are not device actions: use the real picker route. Compose tags may not be externally exposed. IME scenarios need a real keyboard; check current agent-device open options.

The generated scenario stays beside its report. Source inventory is not a runtime observation: start with empty observed checks, null crash count, and `proxy_verified: false`. Screenshots supplement existing instrumented/Roborazzi acceptance evidence.

## JSON fields

- `scenario_id`, `feature`, `app_id`, `environment`, `initial_state`, `max_steps`: scope.
- `target`: APK path/hash, package/version, device and installed-build identity when known.
- `generation.sources`: artifact provenance; initial `runtime_verified: false`.
- `states`: IDs, entry actions, expected outcome, check ID, source and plan stage.
- `entry_points`: one object per relevant in-scope route with unique `id`, `surface`, `action`, `expected`, and route-specific `check_id`; the check ID must appear in `expectations.ui_checks` and receive an actual runtime observation.
- `excluded_entry_points`: optional objects with unique `id` and a specific `reason`; excluded routes are disclosed but do not count as passing observations.
- `exploration_targets`: uncertain code-derived states without invented correctness claims.
- `expectations.ui_checks`: chosen check IDs; `no_unexpected_crash`: requires a recorded count.
- `expectations.requests`: optional method, host, path_glob, min_count, max_count, allowed_statuses, no_transport_errors. Paths are compared to sanitized metadata.
- `apiMocks`: optional feature/shared fixture data; see proxy reference. Do not invent endpoints to fill it.

A fixture defines input, not observed UI. Verify loading/error/empty states through dogfood. Do not infer network expectations from UI states alone.
The report validator marks a missing/empty entry-point inventory, an unmapped route, or a route without a true/false runtime observation as `INCONCLUSIVE`; a false route observation is `FAIL`. A scenario cannot PASS while any relevant route is unaccounted for or unobserved.
