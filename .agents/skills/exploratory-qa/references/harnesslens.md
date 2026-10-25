# HarnessLens evidence in an Exploratory QA run

Read the installed HarnessLens skill and the pinned CLI's README before capture. The reporter and HarnessLens require Python 3.10+; check the interpreter, and use the pinned checkout's existing virtual environment when needed. Use an authorized debug app with state hooks at the real state owner and an analytics decorator at the real tracking boundary. Do not add application instrumentation while performing this harness workflow; route missing hooks to the app implementation workflow. Missing prerequisites remain INCONCLUSIVE. Use dogfood directly for UI-only exploration.

## Prepare the approved expectations

Save the generated scenario and all run artifacts under `.qa-artifacts/<run-id>/`. The directory label may differ from HarnessLens's native 32-character run ID. Keep the native ID in `harnesslens/run.json`. Record `app_id`, `target.device_id` (explicit serial/UDID) and `target.platform` in the scenario; do not use an implicit default device.

Add this shape to `expectations`, filling values from the selected approved requirements. The Home names illustrate the schema; do not copy their behavior into an unrelated feature:

```json
{
  "harnesslens": {
    "capture": "harnesslens/capture.ndjson",
    "state_checkpoints": [
      {
        "id": "home-edit",
        "ui_check_id": "home_edit_visible",
        "action": "Launch the app to Home Edit",
        "source": "approved requirements path and section",
        "capture": "harnesslens/checkpoints/home-edit.ndjson",
        "contract": "harnesslens/contracts/home-edit.json"
      }
    ],
    "analytics": {
      "source": "approved tracking requirements path and section",
      "contract": "harnesslens/contracts/analytics.json"
    }
  }
}
```

Every checkpoint must have a unique simple ID, an actual action and a declared `ui_check_id`. Cover each internal state whose correctness is in scope. Copy the approved source contract byte-for-byte into `harnesslens/contracts/` before actions; authored reusable originals stay in source control. List each source contract path and its SHA-256 in `generation.sources`. The reporter checks the source still matches that hash and that the run copy is byte-identical. A state contract requires non-empty `assertions`, each with `scope`, `field`, and `equals`, for example `{"schema_version":1,"assertions":[{"scope":"home","field":"screen_section","equals":"edit"}]}`. Use the analytics contract format documented by HarnessLens, including event counts, required parameter values, forbidden events and order when specified. Its `scenario` must equal this run's `scenario_id`. Never infer expectations from a successful capture or weaken them to fit actual output.

Create `harnesslens/run.json` with `run_id` from the actual start receipt, matching `app_id`, `device_id`, `platform`, `scenario_sha256` (SHA-256 of the final prepared scenario bytes), `contracts` (map of run-relative contract paths to their pre-action SHA-256 hashes), and `checkpoints` (map of checkpoint IDs to `{"after_sequence": N, "boundary_capture": "harnesslens/checkpoints/<id>-before.ndjson"}`). For the initial launch in a fresh armed run with no records, use 0 and omit `boundary_capture`. For every later action, export the pre-action capture to its own `*-before.ndjson` file; record the largest sequence in that exact file and its run-relative path. The reporter checks that each boundary file is a prefix of the final capture and its last sequence matches the manifest. Preserve the scenario and contract hashes; only add checkpoint boundaries during the run. Do not fabricate the manifest from expected output.

## Capture the same real journey

1. Select the actual app and device, inspect prerequisites and prepare the approved contracts. Set `QA_RUN_DIR=".qa-artifacts/<fresh-run>"`; create `$QA_RUN_DIR/harnesslens/contracts` and `$QA_RUN_DIR/harnesslens/checkpoints`.
2. Run `hlens capture start --platform "$PLATFORM" --app-id "$APP_ID" --device-id "$DEVICE_ID"` and retain its JSON stdout at `$QA_RUN_DIR/harnesslens/start.json`. Record its `run_id` as `LENS_RUN_ID` and in the manifest. Arm before launch/navigation; start alone does not prove recorder readiness.
3. Before each checkpoint action, export the current cumulative capture to `$QA_RUN_DIR/harnesslens/checkpoints/<checkpoint-id>-before.ndjson` (except the first action of a fresh run), then read its largest sequence and record both that value and file path in `run.json`. For later checkpoints the boundary must be at least the previous checkpoint's last sequence. Perform the declared action through dogfood/agent-device. Observe the UI and use `hlens state get`/`state await` with the same platform, app, device and `--run-id "$LENS_RUN_ID"` to inspect/await approved fields. Retain command failures and their actual output; a timeout must not be rewritten as a pass.
4. Export immediately after the checkpoint, before the next action: `hlens capture export --platform "$PLATFORM" --app-id "$APP_ID" --device-id "$DEVICE_ID" --run-id "$LENS_RUN_ID" --out "$QA_RUN_DIR/harnesslens/checkpoints/<checkpoint-id>.ndjson"`. Each file is a cumulative snapshot from the same run. A checkpoint requires a fresh state record for every asserted scope after its pre-action boundary. An unchanged cached value with no fresh emission cannot establish the post-action state; report the instrumentation gap.
5. Finish the scenario, stop capture, and export the full run to `$QA_RUN_DIR/harnesslens/capture.ndjson` using the same explicit IDs. Keep the app alive for the writer to settle. Stop has no durable drain guarantee; missing records are INCONCLUSIVE. Do not edit, splice, merge, or filter the raw checkpoint/full captures. If retrying, create a fresh run and retain the failed attempt.
6. Run Exploratory QA's reporter with the pinned HarnessLens source. In a consumer that vendors it at `tools/HarnessLens`, use `--harnesslens-root tools/HarnessLens`. Otherwise use the actual pinned checkout or a Python environment containing the installed `harnesslens` package. No automatic install is performed.

## Mechanical report gate

The reporter requires the manifest, scenario/contract hashes, native run identity, readiness and increasing sequences. It requires each checkpoint to be a prefix of the final capture and rejects paths escaping the run. It executes `python -m harnesslens state verify` once per checkpoint and `analytics verify` on the full run with `--run-id`. Generated reports and verifier logs go under `harnesslens/reports/state-<id>/` and `harnesslens/reports/analytics/`; `report.json` retains commands, exit codes, hashes and evidence paths. Old verifier output is removed before each invocation so a failed rerun cannot reuse a stale PASS.

A state mismatch on a fresh record is FAIL, even when another field is unavailable. Missing state/fields, stale checkpoint values, wrong-run data, zero analytics events, changed contracts, empty assertions, unavailable CLI or missing reports are INCONCLUSIVE. Analytics contract mismatches in a non-empty capture are FAIL. A known app failure still makes the aggregate FAIL if another check is inconclusive. Both outcomes block PASS. The Markdown report links expected/actual state details and analytics results alongside UI/network checks.

These are selected app-side observations. The manifest records the operator's selected target; the capture format itself does not attest the APK/device identity. Retain binary identity and UI evidence from the session. Sampled state is not a lossless transition history; use deterministic tests for transitions that cannot be observed reliably. Remote analytics delivery and backend persistence require their own evidence.
