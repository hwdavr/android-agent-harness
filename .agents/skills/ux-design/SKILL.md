---
name: ux-design
description: Define UI_contract states before Pen design, then validate and approve the completed visual references.
---

# Skill — UX Design

## Purpose and entry

Run the separate UX stage after requirements clarification and before implementation or slice
planning. Use the active clarified spec and supplied visual inputs. UI_contract.md owns the UI
state inventory and behavior-to-reference mapping; the Pen file owns the actual visual design.
Do not generate a separate design.md.

## Artifact ownership

Do not create, version, or edit the spec or summary during visual iteration.
UX owns `UI_contract.md`, Pen candidates, and review exports. The runtime visual-target manifest
for complex features is derived from the contract's state IDs, viewports, and reference paths.
Reuse the same artifact directory and delivery version.

Spacing, hierarchy, color, typography, icons, and copy preserving approved meaning stay within UX.
A behavior, scope, data, navigation, or required state-inventory change returns to requirements
clarification; reconcile only the affected spec sections and contract rows. Record summary/progress
evidence at stage completion, approval, or blockers. Design approval does not authorize app code.

## Load

- The clarified spec and supplied visual inputs
- `docs/product/design_system.md`
- `harness/templates/UI_contract-template.md`
- `harness/templates/visual-target-template.json` for complex runtime target metadata
- `skills/ux-design/references/quick-reference.md` and `references/pro-rules.md` as needed
- `pen-design-editor` and its current CLI guidance after the inventory gate passes

## Execute

### 1. Define the contract before Pen

Create `UI_contract.md` from the template in the active ad-hoc or complex-feature workspace.
Inspect relevant Compose screens/controls and the clarified requirements. Enumerate every required
screen/state before creating or editing Pen frames: loading, empty, ready, error, selected,
disabled, overlay, and keyboard variants where applicable.

For every row, settle its stable state ID, viewport, primary content, state-specific and persistent
controls, deterministic runtime fixture, comparison mode, and plan stage ID. Fill State Details
with entry/exit behavior, exact copy, interactions, accessibility, responsive constraints, visual
anchors, and explicit approved design-system exceptions. Keep design source, node ID, node role,
and image all `Pending` until that state's visual reference exists. These four fields are the
only deferred fields; user behavior and keyboard coverage cannot be deferred.

Inventory every editable input in `## IME State Coverage`, including closed, open, and dismissed
states at the same full-window viewport. Declare resize/pan/overlay and the keyboard behavior:
`screen-no-toolbar`, `screen-toolbar-dismissed`, or `sheet-stays-open`. Show the focused field,
required controls, and real IME together; a bottom sheet remains open while typing and a screen's
bottom toolbar is dismissed. Use authentic keyboard assets for the target device/appearance.

Classify supplied images as approved references or defect evidence. Preserve approved inputs
unchanged and keep defect evidence separate. Existing approved references can fill completed rows.
Do not create an implementation screenshot baseline.

### 2. Validate the inventory before generating visuals

Run the calling workflow's pre-design gate:

- `bash harness/scripts/check-stage-artifacts.sh feature-delivery ui-contract docs/current`
- `bash harness/scripts/check-stage-artifacts.sh harness-planning ui-contract "$FEATURE_DIR"`
- `bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify ui-contract docs/current`

The gate checks complete state behavior, one-to-one spec/state mappings when supplied, unique
fixtures/stage IDs, viewports, controls, and IME coverage. It accepts `Pending` only for the four
design-reference fields. Resolve missing states or product questions before Pen generation.
This gate does not approve a visual design or satisfy a planning/runtime gate.

For complex features, derive runtime target metadata from this inventory before Pen work:
use the same state IDs and viewports, add appearance/device/locale/dynamic-region handling, and
choose the planned export paths. Run `visual-target-prompt.sh --target <manifest> --state <state_id>`
for each target so Pen generation and later runtime capture consume identical target values.

### 3. Generate Pen design from the contract

Invoke `pen-design-editor` through the available skill mechanism with `UI_contract.md` as the
state-by-state input. If the Skill tool is unavailable, read the repository skill and record the
interface note once at the stage boundary. Follow its headless candidate, structural preservation,
fresh-reopen, and visual inspection requirements. Preserve the existing design unless the user
authorizes a change to it.

Create one complete top-level screen frame per contract row, using the declared viewport,
content, controls, and keyboard behavior. Update only that row's Pen source, node ID, node role,
and exported PNG after rendering and inspecting it. A control-only crop cannot replace a complete
screen reference. The Pen source contains the actual visual design; the PNG is its review export.

Capture complete export logs and run `bash harness/scripts/check-pen-export-log.sh <log>`.
Font/asset failures and missing glyphs fail the reference gate. Inspect alignment, clipping,
typography, icon identity, contrast, and required controls.

For complex features, reconcile `visual_evidence/visual-target.json` with the completed contract:
its state IDs, viewports, and actual exported PNG paths must match exactly. Keep Roborazzi content
exact within the approved screen/component scope.

### 4. Gate, approve, and finalize

Run the caller's full UX gate after every reference is completed:

- `bash harness/scripts/check-stage-artifacts.sh feature-delivery ux-design docs/current`
- `bash harness/scripts/check-stage-artifacts.sh harness-planning ux-design "$FEATURE_DIR"`
- UI-update workflow: its `create-ui-and-verify reference-design` gate

The full gate rejects pending references and verifies source/node/image mappings. The complex
gate also checks that runtime target states, viewports, and PNG paths mirror UI_contract.md.

Present the contract and verified Pen exports for explicit design approval. Visual feedback
updates the Pen design and affected contract references within this stage. After approval, follow
the Pen skill's finalization contract and retain approved review images. Record stage evidence
once, then return to planning when implementation is requested.

## Output and completion

- `UI_contract.md` defines every UI state before Pen generation and links the clarified spec and design system.
- The actual design is retained in the canonical Pen file, with verified review PNGs mapped per state.
- Every editable input has complete IME coverage and explicit keyboard behavior.
- Complex runtime metadata is derived from and matches the same contract.
- Inventory and full UX gates pass at their respective phases; design approval precedes downstream planning.
