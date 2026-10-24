# Android recorder capability and lifecycle

This skill verifies calls at an app analytics abstraction. It does not verify downstream Firebase/GA4 ingestion. Source search during adaptation found no tracker or Firebase Analytics dependency in FunPhotoEditor; the authorized API 33 debug app lacked `files/analytics-events.ndjson`. Recheck the selected build rather than assume the checkout matches an APK.

| Capability | Support / evidence |
|---|---|
| Host contracts/reports | Python 3.9+ stdlib; synthetic fixtures test helper behavior |
| Existing compatible Android debug recorder | ADB with explicit serial and accessible run-as sandbox |
| Current FunPhotoEditor build | No recorder discovered; live analytics INCONCLUSIVE |
| Non-debuggable/release APK | run-as normally unavailable; INCONCLUSIVE |
| iOS / provider ingestion | Outside this adaptation |

## Recorder protocol

A compatible recorder must already be installed in the selected debug build. Adding one is a separate approved implementation task. Keep file-writing and control hooks out of release variants; wrap the real provider and preserve forwarding. Fire product events from the existing presentation boundary according to the approved tracking design.

Write UTF-8 NDJSON to the fixed app-private path `files/analytics-events.ndjson`, with exactly one ready marker first, events in invocation order, and exactly one complete marker last:

```json
{"type":"capture_ready","version":1,"timestamp_ms":1761264000000}
{"type":"event","name":"sample_started","params":{"entry":"toolbar"},"timestamp_ms":1761264000001}
{"type":"capture_complete","version":1,"timestamp_ms":1761264000002,"event_count":1}
```

The names above are synthetic. Use epoch milliseconds from the device, nondecreasing timestamps, and an exact event count. The complete marker must follow an explicit writer flush barrier after the terminal UI state. No writes may follow completion. The agent must use the recorder's existing documented flush control; the helper does not install an IPC endpoint or synthesize a flush marker.

Source-sanitize with narrow low-sensitivity key/value allowlists. Do not record tokens, user identifiers, free text, prompts, photo paths or content. The host discards all parameter values before persistence, but this does not make recording unsafe data in the app sandbox acceptable.

The supplied package's starter recorder emits only capture_ready and events. It is intentionally not copied into this project: it has no completed-flush protocol, and this app has no real tracker to wrap.

## Sequence and receipts

1. Reuse the exploratory-QA scenario and selected binary/device. Run inspect. It checks installed APK hashes, package version, Android API, debug sandbox access and the initial marker without modifying app state.
2. For approved sources and a compatible recorder, run reset before launch. It pins the serial, stops only that app and deletes only the fixed NDJSON capture file. It creates `reset.json` after deletion; no app-data clear or settings/proxy changes occur.
3. Use exploratory-QA/dogfood for the real scenario, including requested recordings. Reach the terminal state and use the existing flush barrier.
4. Collect in the same run. It verifies unchanged target/build/scenario/contract, bounds stdout/time, requires fresh ready/completed markers, and writes checked boolean evidence plus `collection.json`. Raw NDJSON and device stderr never enter host artifacts.
5. Run the validator. Missing completion, changed build/source/receipt, failed collection, reused files, unsupported target or unavailable recorder cannot produce live PASS. A failed attempt requires a fresh run and reset/replay.
6. Preserve receipts and analytics reports alongside the parent QA report. Use exploratory-QA teardown; no helper here changes device proxy/CA settings or Firebase debug properties.

All commands require an explicit serial. List devices with adb and ask the user when selection is ambiguous, following project rules. Do not silently target another device. Command timeouts are 20 seconds; outputs are bounded in memory, input is capped at 3 MB. SDK/device capability failures remain visible as INCONCLUSIVE.
