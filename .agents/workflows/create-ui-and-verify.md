---
description: Implement or update the Android UI to match a provided screenshot or an approved mockup.
---

# Workflow: Create UI and Verify

## When to use
Use this workflow when:
- Implementing a new screen from a design screenshot or generated mockup
- Updating an existing screen to match a revised design

---

## Stages

### Stage 0 — Reference Design Gate
Before implementation, classify every supplied image as either an approved design reference or
defect evidence. A screenshot showing the current/wrong behavior is evidence only and is not a
design reference.

- **Approved reference provided:** Save the image to `docs/current/design/` and use it as the
  original design reference. Do not invoke `ux-design` for this task.
- **Defect evidence provided, or no approved reference:** Save defect evidence separately under
  `docs/current/evidence/`, then **INVOKE** the `ux-design` skill via the Skill tool (name:
  `ux-design`). The skill must read `docs/product/design_system.md`, create the feature design
  specification and mockup(s) under `docs/current/`, and record any deliberate exceptions to the
  design system. Do not begin UI implementation until the generated mockup and design decisions
  are approved by the user.
- **Reference path unavailable:** Stop and ask the user to attach the missing screenshot again;
  do not substitute an inferred design.

The active plan must cite the approved design reference/mockup path and keep defect evidence
separate. A generated mockup becomes the Stage 2 design reference only after user approval.

### Stage 1 — UI Implementation
**INVOKE** the `android-ui-layer` skill via the Skill tool (name: `android-ui-layer`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Read `docs/product/design_system.md`, then implement the UI changes using the approved reference
from Stage 0. If the reference intentionally differs from the project design system, record the
explicit user-approved exception in `docs/current/design.md`; otherwise reuse the project tokens
and component patterns.

### Stage 2 — UI Verification ↩️ Loop
**INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Compare the implemented UI against the approved generated mockup or original design screenshot
in `docs/current/design/`, never against defect evidence in `docs/current/evidence/`, and against
`docs/product/design_system.md`. Any deviation from either source must be an explicit approved
exception.

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
