---
name: design-to-ui
description: Align an existing Android screen's Compose UI to a user-named design frame (.fig/.pen) with no spec or plan. Appearance-only; keeps state, callbacks, navigation, and testTags.
---

# Design to UI

A thin orchestrator for the `android-ui-layer` direct lane when the target appearance is a design
frame the user names. It adds the design-source steps (resolve the frame, extract its layout, write
a minimal contract) and hands implementation and verification to the owning skills. It waives none
of their gates. Invoke each skill with the Skill tool when available; otherwise read its complete
`SKILL.md`, follow it, and record the missing interface once in the summary.

## 1. Entry check

Run the `android-ui-layer` direct-lane entry check. A frame the user names for an existing screen
counts as its approved design. Every item must hold:

- [ ] The screen exists. The design changes only layout, spacing, size, typography, color, icons,
      display copy, or the order of existing elements.
- [ ] No new or changed UI state, interaction, gesture, navigation, data, persistence, API,
      permission, dependency, or build configuration.
- [ ] Every value maps to a `docs/product/design_system.md` token, and every component is a
      registered component or a local composition of them. A new reusable component, a raw value,
      or a token change is a design-system exception: list it and get the user's explicit approval,
      or leave it out.
- [ ] Shared theme or component edits only when the user wants every consumer to change;
      otherwise keep the change local to the screen.

Report the result. If an item fails, name the boundary and route the behavior to `harness-planning`
(new behavior) or `bug-fixing` (defect). Offer the appearance-only subset; do it only if the user
agrees. Never add placeholder handlers.

## 2. Resolve the design (read-only)

- Use `ui-design-tool` to read `UX/design-tool.json` and load only its adapter. Never edit the
  design source in this skill.
- Locate the frame with the adapter's inspect commands (`tree`, `node`). The node must be the
  top-level screen frame, not a nested group, key, or instance (see
  `docs/changes/harness-retro-2026-11-14-design-source-of-truth`). Ask only when several frames match.
- Each frame for this screen is one state (default, sheet open, empty, ...). States without a frame
  are out of scope; say so.
- Report fonts or assets the project lacks. A substituted export is not authoritative.

## 3. Workspace and minimal contract

Create `WS=.scratch/<YYYY-MM-DD>-<screen>-design-sync/` (the direct-lane workspace) containing:

- `design/mockup_<screen>_<state>.png`: the adapter's frame export at scale 1 (frame dp size).
- `design/mockup_<screen>_<state>.layout.json`: the adapter's extraction script. OpenPencil:

  ```bash
  python3 harness/scripts/design_adapters/openpencil_layout.py --source <source.fig> \
    --node <frame-id> --out "$WS/design/mockup_<screen>_<state>.layout.json"
  ```

  pen.dev has no extractor yet: report the state as blocked. Never hand-author the layout or derive
  it from the PNG. Re-extract after any source change (the gate compares `source_sha256`).
- `UI_contract.md`: only `## Screen States` from `harness/templates/UI_contract-template.md`, all
  columns filled, `Plan stage` = `UI-1`, `UI-2`, ...
- `test-plan.md`: only `## UI State Verification` (Stage ID, review capture, structural check,
  command), naming the existing capture and structural tests for each stage.

Validate before implementation:

```bash
python3 harness/scripts/check-ui-contract.py "$WS/UI_contract.md" \
  --design-system docs/product/design_system.md --project-root .
```

## 4. Propose and get the go-ahead

Per state, list each difference as `layout.json value → current code value`, the files to change,
and any exception from step 1. Wait for the user's go-ahead (`android-ui-layer` requires it).

## 5. Implement

Invoke `android-ui-layer` and follow its direct-lane sections, Execute steps 3 (Composable) and 6
(strings), and the Done When items that apply to Composable and resource edits. Its ViewModel,
mapper, navigation, and analytics steps are out of scope; record UiState coverage as not applicable
(no state change).

- Take gaps, paddings, sizes, line heights, and icon identities from `layout.json`. Use the
  matching semantic token; where none is within the contract tolerance (4dp), it is an exception
  from step 1, not a raw value.
- Preserve testTags, semantics and content descriptions, enabled state, callbacks, and analytics.
- Edit only `ui/` Composables and UI resources (strings, drawables, fonts), plus theme tokens if an
  approved shared change. Use `stringResource()` and the localization rules.

## 6. Verify

Invoke `ui-verification` with `FEATURE_DIR=$WS`; the minimal contract and test plan stand in for
the planned artifacts. Run all of it: static checks, review captures into `$WS/evidence/ui/`,
structural checks, `compose-ui-comparison.py`, pre-review findings with at most 3 fix loops, user
approval per state, `ui_verification.json`, and both validators. Reuse existing capture and
structural tests; add a narrowly scoped one only when none covers the state. Also run
`git diff --check`. A missing build, runtime, or capture leaves verification incomplete: name the
blocker and never report the gate as passed.

## 7. Finish

Write a one-paragraph `$WS/summary.md`: design source and node IDs, files changed, checks and
results, the user's decision per state, approved exceptions, and remaining differences. No tracker
row. Run `code-quality-fix`, then report the same points in the chat.
