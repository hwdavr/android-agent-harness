---
name: ux-design
description: Define UI_contract states, design them in the configured design tool from registered components, get approval.
---

# Skill — UX Design

## Purpose and entry

Run the separate UX stage after Specify & Clarify and before the implementation plan. Use the
feature block's Screen States and Navigation, supplied visual inputs, and the design system with its
Component Registry. UI_contract.md owns the UI
state inventory and behavior-to-reference mapping; the design-tool source file owns the actual visual design.
Do not generate a separate design.md.

## Artifact ownership

Do not create, version, or edit the requirement block or summary during visual iteration.
UX owns `UI_contract.md`, design-tool candidates, and review exports in `$FEATURE_DIR`.

Spacing, hierarchy, color, typography, icons, and copy preserving approved meaning stay within UX.
A behavior, scope, data, navigation, or required state-inventory change returns to Specify &
Clarify; reconcile only the affected block sections and contract rows. Record summary/progress
evidence at stage completion, approval, or blockers. Design approval does not authorize app code.

## Load

- The feature block (Screen States, Navigation) and supplied visual inputs
- `docs/product/design_system.md`, including its Component Registry
- `harness/templates/UI_contract-template.md`
- `harness/templates/visual-target-template.json` only when generating mockups with `visual-target-prompt.sh`
- `skills/ux-design/references/quick-reference.md` and `references/pro-rules.md` as needed
- `ui-design-tool` (it reads `UX/design-tool.json` and loads the pen.dev or OpenPencil adapter) after the inventory gate passes

## Execute

### 1. Define the contract before design

Create `UI_contract.md` from the template in `$FEATURE_DIR`.
Inspect relevant Compose screens/controls and the clarified requirements. Enumerate every required
screen/state before creating or editing design frames: loading, empty, ready, error, selected,
disabled, overlay, and keyboard variants where applicable.

For every row, settle its stable state ID, viewport, primary content, state-specific and persistent
controls, reused registered components (or `Pending`), deterministic runtime fixture, and plan
stage ID. The viewport is the design frame's logical dp size; the later review capture renders at it. Fill State Details
with entry/exit behavior, exact copy, interactions, accessibility, responsive constraints, visual
anchors, and explicit approved design-system exceptions. Keep design source, node ID, node role,
and image all `Pending` until that state's visual reference exists. These four fields and Reused
components are the only deferred fields; user behavior and keyboard coverage cannot be deferred.

Inventory every editable input in `## IME State Coverage`, including closed, open, and dismissed
states at the same full-window viewport. Declare resize/pan/overlay and the keyboard behavior:
`screen-no-toolbar`, `screen-toolbar-dismissed`, or `sheet-stays-open`. Show the focused field,
required controls, and real IME together; a bottom sheet remains open while typing and a screen's
bottom toolbar is dismissed. Use authentic keyboard assets for the target device/appearance.
When a real-IME state has no design (approved 2026-11-13), write `instrumented-only` in its open or dismissed
column; the IME Production Boundary test must then cover that input, and the closed state still needs a design.

Classify supplied images as approved references or defect evidence. Preserve approved inputs
unchanged and keep defect evidence separate. Existing approved references can fill completed rows.
Do not create an implementation screenshot baseline.

### 2. Validate the inventory before generating visuals

Run the calling workflow's pre-design gate:

- `bash harness/scripts/check-stage-artifacts.sh harness-planning ui-contract "$FEATURE_DIR"`

The gate checks complete state behavior, one-to-one spec/state mappings when supplied, unique
fixtures/stage IDs, viewports, controls, and IME coverage. It accepts `Pending` only for the four
design-reference fields and Reused components. Resolve missing states or product questions before design generation.
This gate does not approve a visual design or satisfy a planning/runtime gate.

When generating mockups, optionally derive a `visual-target.json` from this inventory (same state
IDs and viewports) and run `visual-target-prompt.sh --target <manifest> --state <state_id>` per state.
It is a generation aid only; nothing compares the implementation against it pixel for pixel.

### 3. Generate the design from the contract

Invoke `ui-design-tool` through the available skill mechanism with `UI_contract.md` as the
state-by-state input. If the Skill tool is unavailable, read the repository skill and record the
interface note once at the stage boundary. Follow its headless candidate, structural preservation,
fresh-reopen, and visual inspection requirements. Preserve the existing design unless the user
authorizes a change to it.

Create one complete top-level screen frame per contract row, using the declared viewport,
content, controls, and keyboard behavior. Build every state from design-tool component instances that
match the Component Registry. An element that matches no registry entry is either proposed as a new
shared component (registry entry approved with the design) or recorded as an approved exception.
Record each state's reused components in the contract. Update only that row's design source, node ID, node role,
and exported PNG after rendering and inspecting it. A control-only crop cannot replace a complete
screen reference. The design source (`.pen` or `.fig`) contains the actual visual design; the PNG is its review export.

Capture complete export logs. For pen.dev, run `bash harness/scripts/check-pen-export-log.sh <log>`; for OpenPencil, keep the export output and `openpencil lint --json` result.
Font/asset failures and missing glyphs fail the reference gate. Inspect alignment, clipping,
typography, icon identity, contrast, and required controls.


### 4. Gate, approve, and finalize

Run the caller's full UX gate after every reference is completed:

- `bash harness/scripts/check-stage-artifacts.sh harness-planning ux-design "$FEATURE_DIR"`

The full gate rejects pending references and components, verifies source/node/image mappings, and
checks every reused component against the Component Registry.

Sliced lane: present the contract and verified design exports for explicit design approval. Single
lane: continue to the implementation plan; the design is approved with the plans in one review. Visual feedback
updates the design and affected contract references within this stage. After approval, follow
the design-tool adapter's finalization contract and retain approved review images. Record stage evidence
once, then return to planning when implementation is requested.

## Output and completion

- `UI_contract.md` defines every UI state before design generation and links the clarified spec and design system.
- The actual design is retained in the canonical design-tool source file, with verified review PNGs mapped per state.
- Every editable input has complete IME coverage and explicit keyboard behavior.
- Every state names the registered components it reuses; new shared components are approved registry entries.
- Inventory and full UX gates pass at their respective phases; design approval precedes implementation.
