# UI Contract — <feature>

**Project design system**: `docs/product/design_system.md`
**Related spec**: feature block `<feature-id>` in `docs/product/requirements/<capability>.md`
**Reference status**: Inventory / Pen design in progress / Awaiting approval / Approved

## Research Decisions

- Existing runtime screens, controls, and transitions inspected: <paths and observations>
- Product questions resolved before design: <decisions or linked requirements>
- Editable input inventory: <stable tags and IME coverage, or confirmed no editable inputs>
- Design-system exceptions: None / <explicit user approval>
- Reused registered components: <from the design-system Component Registry, per state below>

## Screen States

Create and validate this inventory after requirements clarification and before Pen generation.
UI_contract.md is the UI state contract for both ad-hoc and complex workflows. The actual visual
design lives in the Pen file; no separate design.md is produced.

Define every screen/state, viewport, visible regions, named controls, reused registered components,
deterministic fixture, and plan stage. The Viewport is the Pen frame's logical size in dp; the
review capture is rendered at exactly that size and density. Loading, empty, error, selected, disabled, overlays, and keyboard
variants must be settled before generating visuals. Use globally unique State IDs for complex
runtime targets.

Set all four design-reference fields to `Pending` for a state whose Pen reference is not yet
created. The inventory gate allows only those fields to be deferred. As each Pen screen is
rendered and inspected, replace them with the canonical source, unique top-level node ID,
`screen-frame` role, and full-viewport PNG. A supplied approved image can use `external` and
`external-screen`. A control-only crop is not a full-screen reference.

**Reused components** lists the design-system Component Registry entries the state uses (taken from
the component instances in the Pen design), or `None — <reason>`. A design element that matches no
registry entry is either a new shared component (add it to the registry with approval) or an
approved exception. It may stay `Pending` only at the inventory gate.

| Screen | State ID | Design source | Design node ID | Design node role | Design image | Viewport | Required regions | State controls | Reused components | Runtime fixture | Plan stage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| <screen> | <screen-state> | Pending | Pending | Pending | Pending | 390x844 | primary-content; state-controls; persistent-controls | <named controls, selection/disabled status, toolbar or sheet when present> | `TopActionBar`, `NoteCard` | <fixture ID> | UI-01 |

## System Chrome

State the status bar height measured from the design frames (dp) and whether any state shows a dialog or
sheet that dims the screen. The review captures simulate both, apply the status-bar inset through the app
Scaffold, and label the chrome as review-only. Screens must consume the inset (`parentPadding`).

- Status bar height: <dp, measured from the first content row of the design frames>
- Dim scrim states: <state IDs, or None>

## IME State Coverage

Required for each editable input on an in-scope screen, including unchanged inputs. Omit this
section only after recording that no editable input exists. A Search button or read-only text
alone is not editable input.

Closed, open, and dismissed states use the same full-window viewport. Add `system-ime` to the
open state's Required regions. Dismissed may reuse closed when identical. Required visible tags
includes the focused input and all content/actions that must remain reachable above the IME.

A real-IME open or dismissed state without a design uses `instrumented-only` in its column. The IME
Production Boundary test must cover that input (approved 2026-11-13).

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

Copy every Plan stage ID into `### UI State Stages` in `implementation-plan.md` (with the same
reused components) and into `## UI State Verification` in `test-plan.md` (one review-capture method
and one structural-check method per state).

## Verification Quickstart

1. Before Pen: run the `ui-contract` stage gate (`--inventory` checks the state contract).
2. Generate/edit Pen frames from those rows using registered components, render and inspect them,
   then complete the reference fields and Reused components.
3. Run the `ux-design` gate (validates components against the registry) and obtain design approval.
4. After implementation: render each state at its Viewport, place it beside the approved design,
   run the structural checks, and record the user's approval in `ui_verification.json`. No
   screenshot golden is recorded or compared.
