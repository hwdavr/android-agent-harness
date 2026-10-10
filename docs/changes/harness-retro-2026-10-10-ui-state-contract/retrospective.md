# Per-state UI contract retrospective

## Incident

The Transform toolbar request exposed a planning gap: `docs/current/spec_v10.md` named Crop, Rotate, Flip, Perspective, and Reset interactions, but `docs/current/design.md` and `design/mockup_crop_edit_photo_v10.png` supplied only one Crop frame. The `create-ui-and-verify` reference-design stage had no artifact gate. A minimal empty fixture reproduced the false pass:

```text
$ bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify reference-design <empty-dir>
SKIP: create-ui-and-verify has no doc-artifact gate for 'reference-design'.
Stage 'create-ui-and-verify/reference-design' artifacts present.
exit 0
```

Affected stages: ad-hoc UI reference design, feature-delivery requirement analysis and implementation planning, and UI verification.

## Classification and invariant

Primary classification: `WORKFLOW_GAP`. No authoritative ad-hoc workflow required an exhaustive state inventory or bound each state to a design frame, fixture, plan step, and later runtime capture.

Invariant: **Every declared UI screen/state pair must have one unique design reference, runtime fixture, comparison mode, and plan stage before implementation begins.**

## Harness repair

- `.agents/workflows/create-ui-and-verify.md`: “Create `docs/current/UI_contract.md` from `harness/templates/UI_contract-template.md`” and run the new reference-design and implementation-plan gates. Missing states are designed in Pen and every export is visually inspected for icons and missing glyphs.
- `.agents/workflows/feature-delivery.md`: “Declare every visually distinct screen/state in the spec's `## Screen States` table.” The ad-hoc UI artifact is `UI_contract.md` instead of a broad `design.md`.
- `.agents/skills/requirement-analysis/SKILL.md`, `.agents/skills/implementation-plan/SKILL.md`, `.agents/skills/pen-design-editor/SKILL.md`, and `.agents/skills/ui-verification/SKILL.md`: carry the state inventory through design, planning, export, and verification. Complex-feature `design.md` remains under its existing workflow.
- `harness/templates/UI_contract-template.md`: records research decisions, separate state rows, Pen node IDs, PNGs, fixtures, comparison modes, and verification handoff. `harness/templates/spec-template.md`, `harness/templates/requirement-summary-template.md`, `harness/templates/implementation-plan-template.md`, and `harness/templates/ui-verification-template.json` add matching state tables/results.
- `harness/scripts/check-ui-contract.py`: “PASS: 2 UI state(s) have unique design, fixture, comparison, and plan mappings.” It rejects missing assets, reused nodes/images/fixtures, spec/plan omissions, and missing runtime state results. `harness/scripts/check-stage-artifacts.sh` calls it at the applicable stages.
- `harness/scripts/tests/ui-contract-contract-test.sh`: the old empty-directory false pass is now an expected failure, with additional duplicate, missing-export, missing-spec-state, missing-plan-stage, and missing-verification-state fixtures. Existing UI verification fixture was updated for the new gate.

The contract follows Spec Kit's research then design/contracts progression and adds a per-state verification quickstart; it does not change application requirements.

## Verification

| Command | Result |
|---|---|
| `bash harness/scripts/tests/ui-contract-contract-test.sh` | Exit 0; negative fixtures rejected. |
| `bash harness/scripts/tests/ui-verification-artifact-contract-test.sh` | Exit 0; stage gate accepts a mapped runtime state. |
| `bash harness/scripts/tests/visual-comparison-contract-test.sh` | Exit 0; existing exact/structural comparison contract preserved. |
| `bash -n harness/scripts/check-stage-artifacts.sh harness/scripts/tests/ui-contract-contract-test.sh harness/scripts/tests/ui-verification-artifact-contract-test.sh` | Exit 0. |
| `PYTHONPYCACHEPREFIX=/tmp/ui-contract-pycache python3 -m py_compile harness/scripts/check-ui-contract.py` | Exit 0. |
| `git diff --check` | Exit 0. |

`rule-applicability-contract-test.sh` stops before its fixtures because this checkout has no `.harness/AGENTS.md`; supplying that file temporarily reaches its next existing precondition failure: root `AGENTS.md` does not contain `rule-applicability-template.md`. These are separate harness fixture drift issues and are not counted as passing evidence here.

No app source, Pen design, product specification, lifecycle tracker, or feature authorization changed. Android build, lint, coverage, and device tests were not relevant to this harness-only repair.

## Routed items and remaining risk

- The actual Transform Pen document still needs separate missing states and inspected exports. This retrospective only makes their absence fail the design gate.
- The validator confirms declared Pen node IDs and nonempty exports, but cannot prove a node exists or an icon rendered correctly. The Pen editor skill requires reopening and viewing each export; that visual check remains a required human-readable evidence step.
- The existing rule-applicability test's `.harness/AGENTS.md` precondition and root `AGENTS.md` text expectation need a separate fixture repair.
