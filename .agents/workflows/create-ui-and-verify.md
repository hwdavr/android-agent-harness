---
description: Implement or update Android UI from a provided screenshot or approved mockup, then verify it.
---

# Workflow: Create UI and Verify

## When to use
Use this workflow when:
- Implementing a new screen from a design screenshot or generated mockup
- Updating an existing screen to match a revised design

## Triage: Small UI Patch

Do not use this workflow for a small, localized UI-only adjustment to one existing
presentation surface. Invoke `android-ui-layer` directly for Compose layout or
styling, design-system tokens, accessibility presentation, or a focused existing
component change when no API, persistence, domain, ViewModel behavior, navigation,
or new user journey change is required.

---

## Stages

Before implementation, read the approved Rule Applicability matrix for the change.
Carry every decision into the implementation plan, verification evidence, and review;
the UI rules are required only when their triggers are present.

### Stage 0 — Reference Design Gate
Before implementation, classify every supplied image as either an approved design reference or
defect evidence. A screenshot showing the current/wrong behavior is evidence only and is not a
design reference.

- **Approved reference provided:** Save the image to `docs/current/design/` and use it as the
  original design reference for the state it depicts. Preserve that image unchanged. If the state
  inventory contains states with no approved reference, invoke `pen-design-editor` only to design
  and export those missing states.
- **Defect evidence provided, or no approved reference:** Save defect evidence separately under
  `docs/current/evidence/`, then **INVOKE** the `pen-design-editor` skill via the Skill tool (name:
  `pen-design-editor`). The skill must read `docs/product/design_system.md`, use the canonical
  `.pen` design source to create every visually distinct screen/state, export a verified PNG for
  each state under `docs/current/design/`, and record deliberate exceptions to the design system
  in `docs/current/UI_contract.md`. Do not begin UI implementation until all exported states and
  design decisions are approved by the user.
- **Reference path unavailable:** Stop and ask the user to attach the missing screenshot again;
  do not substitute an inferred design.

Create `docs/current/UI_contract.md` from `harness/templates/UI_contract-template.md`. Enumerate
each visible screen/state from requirements and the current runtime, including selected subtools,
overlays, empty/error states, and keyboard states when applicable. Give each state one distinct
Pen node and export, or identify the supplied approved image as an external reference. Record the
deterministic runtime fixture, comparison mode, and unique plan stage ID. Render and inspect every
Pen export, including icon identity and missing-glyph placeholders. Then run:

```bash
bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify reference-design docs/current
```

The active plan must cite the approved state references and keep defect evidence separate. A
generated mockup becomes the Stage 2 design reference only after user approval.
After approval, promote the validated `.pen` source in place and delete only the run-owned
intermediate design outputs according to `pen-design-editor`; retain the approved review PNG and
continue through implementation and verification.

### Stage 0b — Per-State Implementation Plan ⛔ STOP

Create `docs/current/implementation_plan_v<N>.md` with a `## UI State Stages` table. Give every
Plan stage ID in `UI_contract.md` its own implementation and verification steps. Run:

```bash
bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify implementation-plan docs/current
```

Present the plan and wait for the user's approval before writing application code.

### Stage 1 — UI Implementation
**INVOKE** the `android-ui-layer` skill via the Skill tool (name: `android-ui-layer`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Read `docs/product/design_system.md`, then implement the UI changes using the approved reference
from Stage 0. If the reference intentionally differs from the project design system, record the
explicit user-approved exception in `docs/current/UI_contract.md`; otherwise reuse the project tokens
and component patterns.

### Stage 2 — UI Verification ↩️ Loop
**INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Compare the implemented UI against the approved generated mockup or original design screenshot
in `docs/current/design/`, never against defect evidence in `docs/current/evidence/`, and against
`docs/product/design_system.md`. When the approved reference is a `.pen` design, export the named
frame to PNG. Run `./gradlew app:verifyRoborazziDebug` only when its visible content matches the
runtime fixture. For different content, verify structural anchors and static visual components,
and record that full-screen pixel parity was not evaluated. Do not record an implementation golden.
Any deviation from either source must be an explicit approved exception.

Before recording a PASS, create `docs/current/ui_verification.json` using the `ui-verification`
skill's required report schema and run:

```bash
bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify ui-verification docs/current
```

For every design-critical spatial relationship—such as edges that meet a border, center alignment,
overlay anchoring, spacing, or a compact visual inside a larger touch target—the report must link
the approved reference and actual screenshot to a bounds-based instrumented assertion. Name the
visual bounds `testTag` (not only the outer touch target) and record the measured relation and
tolerance. A broad screenshot with a statement such as “matches design” is not sufficient proof
of placement.

For version 2+ evidence-backed reports, declare a `visual_contract` with the visual-risk roles
present in the changed surface (for example `icon_identity`, `layout_relationship`, and
`action_presence`). Each role must name a runtime-backed `testTag`, the producing instrumented
test method, and the concrete visual assertion being proved. A button's existence or 48dp
touch-target frame is not proof of its visible icon, label treatment, relative placement, or
presence of a secondary action.

**Loop rule — if verification FAILS:**
- Return to **Stage 1 — UI Implementation** to fix the implementation.
- Re-run **Stage 2 — UI Verification** after each fix.
- **Maximum 3 loops total.**
- If still failing after 3 loops, stop and surface the deviation to the user with the screenshot attached.

**PASS →** the UI verification artifact gate above exits 0; then proceed to Stage 3 — Code + Test Review.

### Stage 3 — Code Quality Fix ⛔ STOP
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Run the code-quality-fix stage to verify complete baseline correctness.

Gate:
- All conditions in `skills/code-quality-fix/SKILL.md` pass
- **⛔ STOP — present results to user. Do not proceed until user explicitly approves.**

## Best Practices
- **Handling Long Content**: For scrollable screens or bottom sheets, ensure the UI handles scrolling properly. In tests, use `performScrollToNode()` to find off-screen elements.
- **Bottom Sheets**: Use `skipPartiallyExpanded = true` for bottom sheets with significant content to improve immediate visibility and test reliability.
- **Duplicate Text**: When multiple nodes share the same text, use `onAllNodesWithText()[index]` to avoid ambiguity in assertions.
