---
name: ux-design
description: Run the separate UX stage after requirements clarification, owning design artifacts and visual review.
---

# Skill — UX Design

## Purpose and entry

Turn clarified product requirements into an approved visual design before implementation planning
or slice planning. This is an individual workflow stage after Requirement & Impact Analysis
(`feature-delivery`) or Clarify & Specify (`harness-planning`).

Read the active spec and its required screen/state inventory. Resolve missing behavior, scope,
data, navigation, or state requirements through the requirements stage before designing them.
Reuse an existing clarified spec for design follow-ups; do not restart requirements analysis or
implementation planning for a visual edit within that contract.

## Artifact ownership

Do not create, version, or edit the spec or summary during visual iteration.
UX owns `design.md`, `UI_contract.md` when required by the caller, the visual-target manifest,
Pen candidates, and review exports. Reuse the same active artifact directory and delivery version.
Examples of visual iteration include spacing, layout, color, typography, icon choice, and copy
that preserves the approved meaning.

When feedback changes behavior, scope, data, navigation, or the required state inventory, return
to the requirements stage and update only the affected spec sections. Reconcile the design with
that changed contract and obtain the required approval again.

Update only the existing summary/progress stage row when the stage completes, approval is
received, or a blocker occurs. Link the design evidence there once; do not repeat the design
content, create a new summary version, or rewrite requirements after every Pen operation.
Design-only requests finish after approved design finalization; design approval does not authorize
application source changes.

## Load

- The active clarified spec and supplied visual inputs
- `docs/product/design_system.md`
- `harness/templates/feature-design-template.md`
- `harness/templates/UI_contract-template.md` for ad-hoc UI state mapping
- `harness/templates/visual-target-template.json` for complex-feature planning
- `skills/ux-design/references/quick-reference.md` and `references/pro-rules.md` as needed
- `pen-design-editor` and its current CLI guidance when a state needs a generated/edited Pen reference

## Execute

### 1. Establish the visual inputs

Classify supplied images as approved references or defect/current-state evidence. Preserve approved
images unchanged under the active `design/` directory; keep defect evidence separate. Reuse
approved references when they cover the required states. Invoke `pen-design-editor` only for
missing or changed visual references. The editable Pen source is canonical for generated designs;
PNG exports are review assets. Do not use a separate AI-image generator for UI mockups.

For an existing screen, inspect the relevant Compose screen/components and extract its controls,
semantic tokens, typography, stable tags, and states. Define the requested delta using the project
design system and existing component patterns. Record explicit user-approved exceptions or state
that there are none. Do not create or require an implementation screenshot baseline.

### 2. Write the design contract

Use `harness/templates/feature-design-template.md` for the active `design.md`. Link the spec
and `docs/product/design_system.md`. Cover each screen's purpose, entry/exit, hierarchy, components
and stable tags, state-specific content/actions, copy, accessibility, and responsive behavior.

For ad-hoc delivery, create/update `UI_contract.md` from its template. Match the spec's screen/state
inventory exactly. Map each state to a unique complete screen reference, viewport, required regions,
deterministic runtime fixture, comparison mode, and implementation plan stage ID. A control-only
crop cannot substitute for a complete screen.

For harness planning, create/update `visual_evidence/visual-target.json` before producing references.
It owns appearance, device, logical size, locale, content states, and dynamic-region handling.
For each state, run:

```bash
bash harness/scripts/visual-target-prompt.sh --target "$FEATURE_DIR/visual_evidence/visual-target.json" --state <content_state_id>
```

Use that exact target context in the Pen design, and record the generated reference's Pen source
and node ID. Define a deterministic Roborazzi comparison scope for each visual target: `screen`
when visible content matches, or `component` when the approved design isolates the changed surface.
The emulator preflight later consumes this same manifest.

### 3. Design, render, and review

Invoke `pen-design-editor` through the available skill mechanism and follow its headless candidate,
structural preservation, fresh-reopen, and visual inspection requirements. If the Skill tool is
unavailable, read the repository skill and record the interface note once at the stage boundary.
Keep every required screen/state covered, including loading, empty, error, disabled, and overlays.

Every editable surface requires distinct keyboard-closed and keyboard-visible designs at the same
full-window viewport. Show the focused field and required controls with the keyboard. A bottom
sheet stays open while typing; a screen bottom toolbar is dismissed while the keyboard is visible.
Use the authentic keyboard component for the declared device/appearance rather than inventing keys.

Capture complete Pen export logs and run `bash harness/scripts/check-pen-export-log.sh <log>`.
Font/asset failures or missing glyphs fail the design gate. Inspect every export for alignment,
clipping, icon identity, contrast, and readable content before presenting it.

### 4. Gate, approve, and finalize

Run the caller's independent UX gate:

- Ad-hoc feature delivery: `bash harness/scripts/check-stage-artifacts.sh feature-delivery ux-design docs/current`
- Complex planning: `bash harness/scripts/check-stage-artifacts.sh harness-planning ux-design "$FEATURE_DIR"`
- UI-update workflow: its `create-ui-and-verify reference-design` gate

Present the design and verified references, then wait for explicit design approval. Visual feedback
loops within this stage and changes only the owned design artifacts. After approval, follow the
Pen skill's finalization contract, honor the requested preservation/add-screen scope, and retain
the approved review images. Return to the calling workflow's planning stage when implementation
is requested.

## Output and completion

- `design.md` links the clarified spec, design system, decisions, references, and approved exceptions.
- Ad-hoc UI delivery has a complete `UI_contract.md` and one verified full-screen reference per state.
- Harness planning has a valid visual-target manifest and non-empty references for all named states.
- Keyboard states, stable tags, and comparison scopes are defined where applicable.
- The UX artifact gate passes and the user approves the design before downstream planning.
- Summary/progress evidence is recorded once at the stage boundary; visual revisions preserve the spec.
