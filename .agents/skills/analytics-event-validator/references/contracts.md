# Tracking requirements and contract

Use an approved analytics tracking spec, explicit analytics requirements in the feature spec/test plan, or a recorded direct user approval of exact expectations. Save direct expectations in a local artifact so their hash can be retained. Inspect implementation call sites only for candidates and route hints. If no authoritative source exists, keep approval status draft and request review; do not learn the expected event stream from the output under test.

The example contract and two NDJSON fixtures are synthetic host-tool demonstrations. They define no FunPhotoEditor analytics requirements. They are not an event catalogue for Scene Swap or another shipped feature.

## Contract schema, version 1

See [contract.example.json](../examples/contract.example.json). Only the declared fields are accepted.

- `schema_version`: integer 1; `scenario_id`: same ID as this run's scenario.json; a minimal standalone run or an existing exploratory-QA run both work.
- `approval`: `status` is draft, example, or approved; `reference` records the actual human decision or synthetic purpose. Setting a string is not human approval.
- `sources`: each has local `path`, SHA-256 `sha256`, and `section`. Approved contracts require at least one source. Live runs verify the files relative to `--source-root` (default project root); absolute supplied paths also work.
- `expected_events`: a nonempty bounded list of unique event names, `count` and optional `params`.
- Counts use `exact`, or `min`/`max`, with nonnegative integer bounds. Bool is not int. Zero-count assertions are valid only with a healthy initialized/completed capture.
- Parameter rules declare `type` (string, integer, number, boolean, null), optional `required` (default true), `equals`, `one_of`, and string-only `matches`. Equality distinguishes bool/int and integer/float; number type also accepts integers. Arrays, objects, nonfinite numbers, strings over 256 characters, and integers beyond exact JSON-number range are unsupported captures.
- Regex uses full-match semantics and a bounded subset: literals/classes/anchors and at most one simple finite repetition, maximum 128. Groups, alternatives, backreferences, lookarounds and unbounded repeats are rejected. Prefer finite enums.
- `forbidden_events`: unique event names, disjoint from expected names.
- `order`: an ordered subsequence in file order, allowing intervening events and repeated expected names when counts permit.
- `allow_unexpected`: default true for SDK/background events. Unknown event names become `__unexpected__`; their parameter values are discarded and never asserted. A closed app-owned recorder can set false. Extra parameter keys on an expected event make capture policy INCONCLUSIVE; a verified assertion failure remains FAIL.

Names use ASCII letters followed by letters/digits/underscores, up to 64 characters. Limits: 100 expected events, 50 rules per event, 20,000 captured events, 256 KB contract and 3 MB raw/checked input. Duplicate JSON keys and unknown schema fields are rejected.

## Offline demonstration

Create a fresh ignored standalone run with this minimal synthetic `scenario.json`:

```json
{"scenario_id":"synthetic_editor_flow","app_id":"com.example.funphotoeditor"}
```

Then run from the project root:

```bash
python3 .agents/skills/analytics-event-validator/scripts/validate.py \
  --run-dir .qa-artifacts/<fresh-demo-run> \
  --contract .agents/skills/analytics-event-validator/examples/contract.example.json \
  --offline --capture .agents/skills/analytics-event-validator/examples/events.pass.example.ndjson
```

Use another fresh run for the fail fixture or missing-file case. Expected exits are 0, 1 and 2 respectively. Offline results always say they are not live app evidence; a draft contract remains INCONCLUSIVE. All parameter values are discarded even when valid.

## Evidence integrity

Collector output is a JSON stream of checks tied to the exact contract hash, not raw analytics data. Reset/collection receipts bind scenario hash, selected device, package version, installed base/split APK hashes, device time window, raw input hash and checked capture hash. Validation checks these receipts and the approved source hashes. Files are local reproducibility evidence, not signed/attested proof against a malicious host. Do not relabel or manually reconstruct collector receipts.
