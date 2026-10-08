---
name: ux-design
description: Design Android Compose UI and produce design.md plus mockups when none are supplied.
---

# Skill — UX Design (Android / Jetpack Compose / Material 3)

## Purpose

Turn user requirements and feature specifications into a complete, state-of-the-art UI/UX design document (`design.md`) and high-fidelity visual mockup images (`design/mockup_<screen_name>.png`) tailored for Android applications using Jetpack Compose and Material Design 3 (M3).

> **Conditional Usage Rule**:
> - **If user-provided screenshot/mockup exists**: Save the image(s) to `design/`, populate `design.md` referencing those images, and **do NOT generate AI mockup images**.
> - **If NO user-provided screenshot/mockup exists**: Follow this skill to apply the project design system, write `design.md`, and generate visual mockup images using `generate_image` for each screen.

---

## Load

- `docs/product/design_system.md` — mandatory project-wide visual source of truth; load before making any visual decision
- `docs/product/reference_components/` — authentic emulator-captured reference components (e.g. software keyboards) organized by device name
- `skills/ux-design/references/quick-reference.md` — 10 priority categories for Android/Compose UX rules
- `skills/ux-design/references/pro-rules.md` — Pre-delivery polish checklist & app interface standards
- `harness/templates/feature-design-template.md` — Standard structure for `design.md`
- `harness/templates/visual-target-template.json` — Canonical target/state manifest shape shared by mockup generation and runtime capture

---

## Execute

### 1. Analyze Feature & Apply The Project Design System

> **Update vs. New Screen Rule**:
> - **If the screen is an update of an existing feature**: Read the existing Compose source for that screen and its components first. Extract the current layout, component inventory, semantic tokens, typography, `testTag` IDs, and visual states directly from the code. Preserve those constraints while describing the approved delta in the canonical Pen design. Record the Pen source and node ID in `visual_evidence/visual-target.json`; the exported Pen frame is the only image reference used for Roborazzi verification. Do not create or require an implementation screenshot baseline.
> - **If the screen is net-new**: Proceed to design from the project design system as described below.

Read `docs/product/design_system.md`, inspect the relevant existing Compose screen/components, and extract from the user request and `spec.md`:
- **Product Domain**: Target Application Domain / Productivity / Utility
- **Visual Style**: Use the applicable app-shell or editor mode defined by the project design system. Do not select a new style from generic trends.
- **Color Palette (Existing Semantic Tokens)**:
  - Primary / OnPrimary
  - Secondary / OnSecondary
  - Surface / OnSurface / SurfaceContainer
  - Accent / Highlights (Tailored HSL / Harmonious hex)
- **Typography Hierarchy**: Reuse the typography and component-specific sizes in the project design system; use M3 roles only where it leaves the mapping open.
- **Component Inventory**: Reuse established top bars, bottom toolbars, buttons, sliders, rails, overlays, sheets, and picker patterns before defining a new component.

If the user request or supplied mockup conflicts with `docs/product/design_system.md`, record the exact user-approved exception in `design.md`. If no explicit exception exists, the project design system wins. Never invent an exception silently.

### 2. Formulate `design.md`

Write `design.md` using `harness/templates/feature-design-template.md` in the active feature directory (`$FEATURE_DIR/design.md` for harness, `docs/current/design.md` for ad-hoc).

At the top of `design.md`, link `docs/product/design_system.md`. For each screen, identify the semantic tokens and existing component patterns it uses, plus any explicit approved exceptions.

Ensure each screen block includes:
- Purpose & UX Principles
- Entry and Exit points
- Information Architecture & Region layout
- Component Inventory (with required states and `testTag` IDs)
- Visual States (Loading, Empty, Content, Error)
- Interaction Rules & Gestures
- Copy Requirements
- Accessibility (dynamic text, min touch targets 48x48dp, contentDescription)
- Responsive & Configuration Behavior

### 3. Visual Mockup Generation (When No User Mockup Provided)

Before generating any mockup, create or load the feature's canonical
`visual_evidence/visual-target.json`. It is the single source of truth for the
appearance, concrete device, logical size, locale, and named content states.
For each state, run
`bash harness/scripts/visual-target-prompt.sh --target "$FEATURE_DIR/visual_evidence/visual-target.json" --state <content_state_id>` and use its output as the target context for `generate_image`. Do not restate those values from memory or create a second mockup-only configuration; the emulator preflight must consume this same manifest with `prepare-visual-runtime.sh --target`.

For **each screen** defined in `design.md`:
1. Formulate a rich prompt for `generate_image` describing an Android app screen running Jetpack Compose Material 3. Begin with the mandatory mockup prompt baseline from `docs/product/design_system.md` and include the exact relevant hex/alpha values, typography, component sizes, shapes, and visual-state rules:
   - High-fidelity Android mobile app UI mockup of `<Screen Name>`
   - Use the project-defined app-shell or editor mode and its existing semantic accent; do not invent vibrant/purple/glassmorphism treatments
   - Include only the top bars, content regions, toolbars, controls, and component families required by the approved feature design
   - Crisp rendering, UI component detail, no device frame
2. **Keyboard-Visible Mockup Protocol**: When generating a keyboard-visible state (`mockup_<screen_name>_keyboard.png`):
   - Retrieve the authentic emulator keyboard component from `docs/product/reference_components/<device>/keyboard_<appearance>.png` matching the declared target `device` and `appearance`.
   - Do NOT allow generative models to hallucinate synthetic keyboard keys. Composite or align the real emulator keyboard component at its exact native bounds.
3. Call `generate_image` tool with `ImageName: mockup_<screen_name>`
4. Move/save the generated image artifact to `<active_design_dir>/mockup_<screen_name>.png`
5. Reference the image in the **Design Assets** section of `design.md`:
   ```markdown
   ### Design Assets
   - **Generated mockup**: `design/mockup_<screen_name>.png` — AI-generated visual mockup reflecting this screen's layout, components, and visual states.
   - **Keyboard-visible mockup**: `design/mockup_<screen_name>_keyboard.png` — Visual mockup incorporating the emulator keyboard reference component from `docs/product/reference_components/<device>/keyboard_<appearance>.png`.
   ```

---

## Output

- Active `design.md` file
- Visual mockup images under `<active_design_dir>/` (either user-provided or generated `mockup_*.png`)

---

## Done When

- [ ] `design.md` exists with all sections filled according to `feature-design-template.md`.
- [ ] `design.md` links to `docs/product/design_system.md` and lists any explicit approved exceptions (or states that there are none).
- [ ] Every generated mockup prompt uses exact applicable design-system tokens and introduces no unexplained colors or component families.
- [ ] Visual mockup images exist under `design/` for every screen described in `design.md`.
- [ ] Design Assets section in `design.md` correctly references all mockup files.
- [ ] All interactive elements have defined stable `testTag` identifiers in the component inventory.
