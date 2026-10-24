# Generate a scoped scenario

The agent writes run-specific JSON; the reporter evaluates it and never scans source or invents observations.

1. Resolve the requested feature, bug, APK, or diff. Prefer its approved spec/UI contract, then its test plan or sprint contract in `docs/current/` or its stable `.scratch/<feature>/` workspace. Check `Related spec`; the latest shared UI contract may belong to another feature.
2. Map selected Screen States, IME State Coverage, entry actions, controls, fixtures, and verification expectations to `states` and `expectations.ui_checks`. Retain state IDs/plan stages and bound the exploration budget.
3. Use `docs/product/journey-registry.yaml`, relevant tests, UiState, navigation, handlers, and testTags for additional route/state hints. Code-only states belong in candidate `exploration_targets`, not approved expectations. Disclose missing intent.
4. Record `{path, sha256, section}` in `generation.sources` and binary identity in `target`. If source is absent or mismatched, use supplied acceptance criteria plus dogfood's runtime map.
5. Dogfood must verify real entry actions and runtime selectors. Test callbacks such as `onImageImported` are not device actions: use the real picker route. Compose tags may not be externally exposed. IME scenarios need a real keyboard; check current agent-device open options.

The generated scenario stays beside its report. Source inventory is not a runtime observation: start with empty observed checks, null crash count, and `proxy_verified: false`. Screenshots supplement existing instrumented/Roborazzi acceptance evidence.

## JSON fields

- `scenario_id`, `feature`, `app_id`, `environment`, `initial_state`, `max_steps`: scope.
- `target`: APK path/hash, package/version, device and installed-build identity when known.
- `generation.sources`: artifact provenance; initial `runtime_verified: false`.
- `states`: IDs, entry actions, expected outcome, check ID, source and plan stage.
- `exploration_targets`: uncertain code-derived states without invented correctness claims.
- `expectations.ui_checks`: chosen check IDs; `no_unexpected_crash`: requires a recorded count.
- `expectations.requests`: optional method, host, path_glob, min_count, max_count, allowed_statuses, no_transport_errors. Paths are compared to sanitized metadata.
- `apiMocks`: optional feature/shared fixture data; see proxy reference. Do not invent endpoints to fill it.

A fixture defines input, not observed UI. Verify loading/error/empty states through dogfood. Do not infer network expectations from UI states alone.
