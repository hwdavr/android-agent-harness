# Generate a scoped scenario

The agent writes run-specific JSON; the reporter evaluates it and never scans source or invents observations.

1. Resolve the requested feature, bug, APK, or diff. Prefer its approved spec/UI contract, then its test plan or sprint contract in `docs/current/` or its stable `.scratch/<feature>/` workspace. Check `Related spec`; the latest shared UI contract may belong to another feature.
2. Inventory the feature's relevant user-visible entry points before selecting a journey. Include Home shortcuts/cards and in-context tool entries, plus other documented routes such as notifications or deep links when relevant. Use the approved contract, a Home/runtime snapshot, journey registry, and action inventory as discovery sources. These sources are hints; runtime behavior is still the evidence.
3. Put every in-scope entry point in `entry_points` with its surface, action, expected destination/behavior, and a `check_id` present in `expectations.ui_checks`. Put only explicitly out-of-scope or future routes in `excluded_entry_points` with a reason. Do not silently omit unclear entry points; record the ambiguity and report missing intent.
4. Map selected Screen States, IME State Coverage, entry actions, controls, fixtures, and verification expectations to `states` and `expectations.ui_checks`. Retain state IDs/plan stages and bound the exploration budget. Ensure each in-scope entry point has a corresponding runtime check.
5. For mock mode, inventory the API interactions caused by each in-scope action. Trace UI action → ViewModel/use case → repository → service method/path, including autosave mutations and follow-up sync/list requests. Use source to discover the call path and payload shape, then use the API contract and approved shared/feature scenario as the response oracle. Never use a hit on a route probe as evidence that an unrelated feature API was mocked. Declare `expectations.mock_coverage` with `mode` (`feature_api` or `routing_only`), interaction ID, linked UI `check_id`, operation, method/path, source call site, contract/fixture source, and fixture IDs. The report rejects absent or unlinked inventories as `INCONCLUSIVE`; `routing_only` requires a reason and is explicitly not feature API coverage.
6. Use `docs/product/journey-registry.yaml`, relevant tests, UiState, navigation, handlers, and testTags for additional route/state hints. Code-only states belong in candidate `exploration_targets`, not approved expectations. Disclose missing intent.
7. Record `{path, sha256, section}` in `generation.sources` and binary identity in `target`. If source is absent or mismatched, use supplied acceptance criteria plus dogfood's runtime map.
8. Dogfood must verify real entry actions and runtime selectors. Test callbacks such as `onImageImported` are not device actions: use the real picker route. Compose tags may not be externally exposed. IME scenarios need a real keyboard; check current agent-device open options.
9. Derive internal state checkpoint contracts and analytics expectations from the same approved requirements using [HarnessLens](harnesslens.md). Discover exported scopes/fields from the installed build or source, but do not treat implementation values as expected behavior. Link each checkpoint to a real action and UI check; include all relevant initial/success/error/restoration states. Missing expected behavior or hooks is an evidence gap and prevents PASS.

The generated scenario stays beside its report. Source inventory is not a runtime observation: start with empty observed checks, null crash count, and `proxy_verified: false`. Screenshots supplement existing instrumented/Roborazzi acceptance evidence.

## JSON fields

- `execution`: required `{mode: ephemeral, driver: agent-device, regression_targets: [], ci_required: false}`.
  This declares temporary exploration; the reporter rejects permanent test targets or a CI requirement.
  Preserve actual action evidence and review source changes separately; this field is not an observation.

- `scenario_id`, `feature`, `app_id`, `environment`, `initial_state`, `max_steps`: scope.
- `target`: APK path/hash, package/version, device and installed-build identity when known.
- `generation.sources`: artifact provenance; initial `runtime_verified: false`.
- `states`: IDs, entry actions, expected outcome, check ID, source and plan stage.
- `entry_points`: one object per relevant in-scope route with unique `id`, `surface`, `action`, `expected`, and route-specific `check_id`; the check ID must appear in `expectations.ui_checks` and receive an actual runtime observation.
- `excluded_entry_points`: optional objects with unique `id` and a specific `reason`; excluded routes are disclosed but do not count as passing observations.
- `exploration_targets`: uncertain code-derived states without invented correctness claims.
- `expectations.ui_checks`: chosen check IDs; `no_unexpected_crash`: requires a recorded count.
- `expectations.mock_coverage`: required when `apiMocks` or `expectations.wiremock` is declared. Every fixture must link to a feature API interaction and UI check, or the whole mock scope must be explicitly `routing_only` with a reason.
- `expectations.harnesslens`: required full-run capture, non-empty `state_checkpoints` and an analytics contract; see [the schema and capture procedure](harnesslens.md). Generated contract snapshots belong in the run directory and are hashed before actions.
- `target.device_id`, `target.platform`, and `app_id`: explicit capture target, checked against `harnesslens/run.json`.
- `expectations.requests`: optional method, host, path_glob, min_count, max_count, allowed_statuses, no_transport_errors. Paths are compared to sanitized metadata.
- `apiMocks`: optional feature/shared fixture data; see proxy reference. Do not invent endpoints to fill it.

A fixture defines input, not observed UI. Verify loading/error/empty states through dogfood. Do not infer network expectations from UI states alone.
The report validator marks a missing/empty entry-point inventory, an unmapped route, or a route without a true/false runtime observation as `INCONCLUSIVE`; a false route observation is `FAIL`. A scenario cannot PASS while any relevant route is unaccounted for or unobserved.
