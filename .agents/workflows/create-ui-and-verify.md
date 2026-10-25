---
description: Implement or update Android UI from a provided screenshot or approved mockup, then verify it.
---

# Workflow: Create UI and Verify

Read and follow [Product documentation flow](../rules/product-documentation.md). Load affected living capability requirements before scoping or reviewing this change. Dated complex-change contracts and evidence belong under `.scratch/`.

## When to use
Use this workflow when:
- Implementing a new screen from a design screenshot or generated mockup
- Updating any existing user-visible screen, component, state, layout, style, or interaction
- Making a single UI-only adjustment to an existing component

## No Direct UI-Change Lane

There is no direct implementation path for a user-visible UI request, regardless of
its size. A one-component styling, layout, selected-state, overlay, or interaction
change must use this workflow and receive an approved implementation plan before
application source is modified. Use `bug-fixing` instead only when the request reports
unexpected behavior, a regression, or a defect that needs RED reproduction.

For a small change, keep the state inventory and plan proportionate: reuse an existing
approved reference when it covers the target state, add only the changed state(s), and
declare one focused Roborazzi verification target. The smaller evidence set does not
remove the plan, approval, or visual-verification gates.

---

## Stages

Before implementation, read the approved Rule Applicability matrix for the change.
Carry every decision into the implementation plan, verification evidence, and review;
the UI rules are required only when their triggers are present.

### Stage 0 — Reference Design Gate
This is the separate UX design stage. Clarify behavior and the required state inventory first;
reuse the active clarified spec when one exists. Apply `ux-design`'s artifact ownership contract:
visual iterations update design artifacts, and summary evidence is recorded at stage boundaries,
approval, or blockers. Do not regenerate a spec, summary, or implementation plan for each Pen edit.
Behavior/scope changes return to requirements clarification before design resumes.

Create `UI_contract.md` before generating Pen screens. Run
`bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify ui-contract docs/current` to
validate the complete state and IME inventory with only design-reference fields marked `Pending`.
Then generate Pen frames from those rows and fill their node/export mappings. The actual design
is in the Pen file; no separate design.md is required.

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

Complete the reference fields in the `UI_contract.md` prepared before Pen generation. Its inventory enumerates
each visible screen/state from requirements and the current runtime, including selected subtools,
overlays, empty/error states, and keyboard states for every editable input. Inventory each input's
stable tag in `## IME State Coverage` and bind it to keyboard-closed, keyboard-open, and dismissed
states. Dismissal may reuse the closed design when identical. Closed/open designs use the same
full window viewport; the open state's Required regions includes `system-ime`. Show the focused
input, required actions, content, persistent controls, and keyboard together. A panel crop or a
prefilled query with focus cleared does not cover the keyboard-open screen. Component Roborazzi
comparisons supplement the full screen design and production IME boundary. An unchanged input
still requires these states when its containing screen is in scope. Give each state one distinct
top-level screen frame and full-viewport export, or identify the supplied approved image as an
external-screen reference. Each export must visibly include primary content, all state-specific
controls, and persistent interactive surfaces; a control-only or component crop is invalid.
Record the deterministic runtime fixture, comparison mode, and unique plan stage ID.
Render and inspect every Pen export, including icon identity and missing-glyph placeholders. Capture
the complete headless CLI output for each export and run the fail-closed diagnostic before treating
the PNG as an approved reference:

```bash
bash harness/scripts/check-pen-export-log.sh <pen-export-log>
```

Any `Failed to load font family`, `AssetFetchError`, missing-font, or placeholder-glyph diagnostic
is a failed reference-design gate. Do not use or approve that PNG; restore the missing font/icon
asset or the required network/cache prerequisite, re-export, and inspect the PNG again. A zero exit
from the Pen CLI alone is not evidence that glyphs rendered correctly.

Then run:

```bash
bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify reference-design docs/current
```

The active plan must cite the approved state references and keep defect evidence separate. The
canonical `.pen` source and its approved PNG export remain the Stage 2 design reference; generated
mockups are secondary review artifacts and never replace the Pen source.
After approval, promote the validated `.pen` source in place and delete only the run-owned
intermediate design outputs according to `pen-design-editor`; retain the approved review PNG and
continue through implementation and verification.

### Stage 0b — Per-State Implementation Plan ⛔ STOP

Create `docs/current/implementation_plan_v<N>.md` with a `## UI State Stages` table. Give every
Plan stage ID in `UI_contract.md` its own implementation and verification steps. Each row must
declare one unique future JVM `*RoborazziTest.kt#method`, cite its approved design image, and name
the method-scoped `./gradlew app:verifyRoborazziDebug --tests "<package>.<Class>.<method>"`
command. The test source may be created during implementation, but the plan gate rejects a state
without this binding. For editable inputs, also create the test plan's `## IME Production Boundary`
table with the shipped Activity, open/dismiss instrumented methods, class-scoped command, and
planned JUnit XML path. The verification gate rejects Content-only tests and unavailable/skipped
results. Run:

```bash
bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify implementation-plan docs/current
```

Present the plan and wait for the user's approval before writing application code.

### Stage 1 — UI Implementation
**INVOKE** the `android-ui-layer` skill via the Skill tool (name: `android-ui-layer`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

If the current environment does not expose the Skill tool, load the repository skill directly,
record the unavailable invocation interface in the stage evidence, and continue its executable
requirements. Do not treat the missing invocation interface as a reason to defer a named Gradle
gate or verification command.

Read `docs/product/design_system.md`, then implement the UI changes using the approved reference
from Stage 0. If the reference intentionally differs from the project design system, record the
explicit user-approved exception in `docs/current/UI_contract.md`; otherwise reuse the project tokens
and component patterns.

### Stage 2 — UI Verification ↩️ Loop
**INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

If the current environment does not expose the Skill tool, load the repository skill directly,
record the unavailable invocation interface in the verification evidence, and run the declared
Roborazzi command. A missing invocation interface makes the stage `Blocked` only when the
executable verification command itself cannot run or its required evidence is unavailable.

Compare the implemented UI against the canonical `.pen` design source and its approved PNG export
in `docs/current/design/`, never against defect evidence in `docs/current/evidence/`, and against
`docs/product/design_system.md`. Generated mockups may be retained as review artifacts, but they
are not the visual source of truth. Export the named Pen screen or static component to PNG, capturing
the complete CLI output. Run `bash harness/scripts/check-pen-export-log.sh <pen-export-log>` before
normalizing the PNG and then run `./gradlew app:verifyRoborazziDebug` for every visual state; use a component-scoped export
when surrounding screen content differs. Do not record an implementation golden.
Any deviation from either source must be an explicit approved exception.

Before recording a PASS, create `docs/current/ui_verification.json` using the `ui-verification`
skill's required report schema and run:

```bash
bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify ui-verification docs/current
```

For every design-critical spatial relationship—such as edges that meet a border, center alignment,
overlay anchoring, spacing, or a compact visual inside a larger touch target—the report must link
the approved reference to the Roborazzi compare/actual artifacts and a bounds-based assertion from
the named JVM test. Name the visual bounds `testTag` (not only the outer touch target) and record
the measured relation and tolerance. An instrumented device screenshot or a broad statement such
as “matches design” is not visual-comparison proof.

For version 2+ evidence-backed reports, declare a `visual_contract` with the visual-risk roles
present in the changed surface (for example `icon_identity`, `layout_relationship`, and
`action_presence`). Each role must name a runtime-backed `testTag`, the producing `*RoborazziTest`
method, and the concrete visual assertion being proved. A button's existence or 48dp
touch-target frame is not proof of its visible icon, label treatment, relative placement, or
presence of a secondary action.

**Loop rule — if verification FAILS:**
- Return to **Stage 1 — UI Implementation** to fix the implementation.
- Re-run **Stage 2 — UI Verification** after each fix.
- **Maximum 3 loops total.**
- If still failing after 3 loops, stop and surface the deviation to the user with the Roborazzi compare/actual artifacts attached.

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

## Product Requirements Reconciliation

Before closing this change, reconcile affected living capability requirements with verified behavior and link evidence. For an already-correct bug contract, record `Confirmed unchanged` with a reason. Preserve undelivered scope and pending review. Run `python3 harness/scripts/check-product-docs.py` and the lifecycle validator; for new change specs also use `--change-dir <active-workspace>`. Relocation never renews approvals or runtime evidence.
