# UI Contract — <feature>

**Project design system**: `docs/product/design_system.md`
**Related spec**: `spec_v<N>.md` / `spec.md` (use the active workflow's path)
**Reference status**: Inventory / Pen design in progress / Awaiting approval / Approved

## Research Decisions

- Existing runtime screens, controls, and transitions inspected: <paths and observations>
- Product questions resolved before design: <decisions or linked requirements>
- Editable input inventory: <stable tags and IME coverage, or confirmed no editable inputs>
- Design-system exceptions: None / <explicit user approval>
- Roborazzi scope: <screen or approved component; exact content within that scope>

## Screen States

Create and validate this inventory after requirements clarification and before Pen generation.
UI_contract.md is the UI state contract for both ad-hoc and complex workflows. The actual visual
design lives in the Pen file; no separate design.md is produced.

Define every screen/state, viewport, visible regions, named controls, deterministic fixture,
comparison, and plan stage. Loading, empty, error, selected, disabled, overlays, and keyboard
variants must be settled before generating visuals. Use globally unique State IDs for complex
runtime targets.

Set all four design-reference fields to `Pending` for a state whose Pen reference is not yet
created. The inventory gate allows only those fields to be deferred. As each Pen screen is
rendered and inspected, replace them with the canonical source, unique top-level node ID,
`screen-frame` role, and full-viewport PNG. A supplied approved image can use `external` and
`external-screen`. A control-only crop is not a full-screen reference.

| Screen | State ID | Design source | Design node ID | Design node role | Design image | Viewport | Required regions | State controls | Runtime fixture | Comparison | Content difference | Plan stage |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| <screen> | <screen-state> | Pending | Pending | Pending | Pending | 430x932 | primary-content; state-controls; persistent-controls | <named controls, selection/disabled status, toolbar or sheet when present> | <fixture ID> | roborazzi | None / <approved content scope> | UI-01 |

## IME State Coverage

Required for each editable input on an in-scope screen, including unchanged inputs. Omit this
section only after recording that no editable input exists. A Search button or read-only text
alone is not editable input.

Closed, open, and dismissed states use the same full-window viewport. Add `system-ime` to the
open state's Required regions. Dismissed may reuse closed when identical. Required visible tags
includes the focused input and all content/actions that must remain reachable above the IME.

Keyboard behavior is exactly one of:
- `screen-no-toolbar`: screen input with no bottom toolbar.
- `screen-toolbar-dismissed`: screen bottom toolbar is dismissed while the keyboard is visible.
- `sheet-stays-open`: the modal bottom sheet remains open while typing; it covers the screen toolbar.

| Screen | Input tag | Window viewport | Keyboard closed state | Keyboard open state | Dismissed state | Layout policy | Keyboard behavior | Required visible tags |
|---|---|---|---|---|---|---|---|---|
| <screen> | <input testTag> | 430x932 | <closed ID> | <open ID> | <closed or dismissed ID> | resize / pan / overlay | screen-no-toolbar / screen-toolbar-dismissed / sheet-stays-open | <input tag; submit tag; results tag> |

## State Details

### UI-01 — <screen-state>

- Requirements: <FR/AC references in the clarified spec>
- Entry/exit and selected controls: <actions and navigation boundaries>
- Primary content and deterministic values: <image, canvas, list, document, or other content>
- State controls: <buttons, menus, labels, selection, disabled/validation/error behavior>
- Persistent controls: <navigation, actions, or toolbars and their states>
- Exact copy and interactions: <labels and observable effects>
- Accessibility/responsive behavior: <focus order, descriptions, touch targets, text size, constraints>
- Visual anchors and icon identities: <relationships to verify against the Pen design>
- Design-system exception: None / <explicit approval>
- Pen export check: Pending / <render viewed, icon identities checked, no missing glyphs>

## Planning Handoff

For ad-hoc delivery, copy every Plan stage ID into `## UI State Stages` in the implementation plan,
with one unique planned Roborazzi method and its method-scoped verify command per state.

For complex planning, derive `visual_evidence/visual-target.json` from this contract. Mirror its
State IDs, viewports, and design-image paths exactly. Bind each runtime content state and approved
reference to the sprint contract's visual rows. The manifest adds device/locale/dynamic-region
metadata; it does not define another state inventory.

## Verification Quickstart

1. Before Pen: run the active workflow's `ui-contract` stage gate (`--inventory` checks the state contract).
2. Generate/edit Pen frames from those rows, render and inspect them, then complete the reference fields.
3. Run the full `ux-design` or UI-update `reference-design` gate and obtain design approval.
4. After implementation approval, verify deterministic runtime states against the approved Pen exports.
