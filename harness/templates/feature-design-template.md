# Feature Design — <Feature Name>

**Date**: YYYY-MM-DD
**Status**: Draft / Final
**Source request**: <short reference to the user request>
**Related spec**: `spec.md`
**Project design system**: `docs/product/design_system.md`
**Approved design-system exceptions**: None / <explicit user-approved exception and rationale>

---

## Conditional Keyboard-Visible Mockup Contract

If any screen contains a bottom sheet with a textbox, text field, search field, or other text-input control, define a separate keyboard-visible visual state. Explain how the sheet changes while the keyboard is shown, and reference a distinct non-empty image such as `design/mockup_<screen_name>_keyboard.png` in addition to the base mockup. The keyboard-visible mockup is required even when the keyboard changes only the sheet height or available content region.

---

## Screens Covered

<!-- List every screen or major UI surface this design document covers. -->
<!-- Remove this table and rename the title to "Screen Design — <Screen Name>" when only one screen is involved. -->

| # | Screen / Surface | Status |
|---|-----------------|--------|
| 1 | <Screen Name> | New / Updated |
| 2 | <Screen Name> | New / Updated |

---

<!-- ═══════════════════════════════════════════════════════════
     REPEAT THIS BLOCK FOR EACH SCREEN.
     Replace N with the screen number and <Screen Name> accordingly.
     ═══════════════════════════════════════════════════════════ -->

## Screen 1 — <Screen Name>

### Purpose

<What this screen helps the user accomplish and why it exists.>

### UX Principles

- <principle that guides layout and behavior>
- <principle that guides interaction or density>

### Entry And Exit

- **Entry points**: <where this screen is opened from>
- **Primary success exit**: <where the user goes after success>
- **Cancel/back behavior**: <exact behavior>
- **Failure exit or recovery**: <exact behavior>

### Information Architecture

Describe the screen from top to bottom.

1. **<Region name>**: <content and purpose>
2. **<Region name>**: <content and purpose>
3. **<Region name>**: <content and purpose>

### Component Inventory

| Component | Purpose | Required States | Test Tag |
|-----------|---------|-----------------|----------|
| <component> | <purpose> | <default/loading/selected/disabled/error/etc.> | `<tag>` |

### Reference Anchor Contract

List each visual relationship in the approved reference that must be measured rather than judged
only by a broad screenshot. When the visible shape is smaller than its touch target, assign a
separate visual-bounds tag to the shape.

| Reference relationship | Visual bounds node(s) | Required runtime measurement |
|------------------------|-----------------------|------------------------------|
| <for example, pill bottom meets table top border> | `<visual_tag>`, `<anchor_tag>` | `<visualBounds>.bottom == <anchorBounds>.top ± <tolerance>dp` |

### Visual States

| State | User Sees | User Can Do |
|-------|-----------|-------------|
| Loading | <visual behavior> | <allowed actions> |
| Empty | <visual behavior> | <allowed actions> |
| Content | <visual behavior> | <allowed actions> |
| Error | <visual behavior> | <allowed actions> |

### Interaction Rules

- **Primary action**: <trigger and result>
- **Secondary actions**: <trigger and result>
- **Validation**: <inline errors, blocking rules, disabled states>
- **Destructive actions**: <confirmation and recovery behavior>
- **Gestures**: <supported gestures and non-gesture alternatives>

### Copy Requirements

| Element | Copy |
|---------|------|
| Title | <exact text> |
| Primary action | <exact text> |
| Empty state | <exact text> |
| Error state | <exact text> |

### Accessibility

- <content descriptions, roles, focus order, dynamic type, contrast, minimum touch target>

### Responsive And Configuration Behavior

- <portrait/landscape/tablet behavior>
- <configuration-change survival expectations>

### Design Assets

- **Mockup image**: `design/mockup_<screen_name>.png` (or user-provided screenshot/mockup path in `design/`) — Visual mockup reflecting this screen's layout, components, and visual states.
- **Keyboard-visible mockup**: `design/mockup_<screen_name>_keyboard.png` when this screen has a bottom-sheet text input; otherwise state `Not applicable`.
- <paths to any additional reference screenshots/assets, or "None">

### Out Of Scope For This Design

- <explicit non-goal>

---

<!-- ═══════════════════════════════════════════════════════════
     SCREEN 2 — copy the block above and paste it here
     ═══════════════════════════════════════════════════════════ -->

## Screen 2 — <Screen Name>

### Purpose

<What this screen helps the user accomplish and why it exists.>

### UX Principles

- <principle that guides layout and behavior>

### Entry And Exit

- **Entry points**: <where this screen is opened from>
- **Primary success exit**: <where the user goes after success>
- **Cancel/back behavior**: <exact behavior>
- **Failure exit or recovery**: <exact behavior>

### Information Architecture

1. **<Region name>**: <content and purpose>
2. **<Region name>**: <content and purpose>

### Component Inventory

| Component | Purpose | Required States | Test Tag |
|-----------|---------|-----------------|----------|
| <component> | <purpose> | <default/loading/selected/disabled/error/etc.> | `<tag>` |

### Reference Anchor Contract

List each visual relationship in the approved reference that must be measured rather than judged
only by a broad screenshot. When the visible shape is smaller than its touch target, assign a
separate visual-bounds tag to the shape.

| Reference relationship | Visual bounds node(s) | Required runtime measurement |
|------------------------|-----------------------|------------------------------|
| <for example, pill bottom meets table top border> | `<visual_tag>`, `<anchor_tag>` | `<visualBounds>.bottom == <anchorBounds>.top ± <tolerance>dp` |

### Visual States

| State | User Sees | User Can Do |
|-------|-----------|-------------|
| Loading | <visual behavior> | <allowed actions> |
| Content | <visual behavior> | <allowed actions> |
| Error | <visual behavior> | <allowed actions> |

### Interaction Rules

- **Primary action**: <trigger and result>
- **Validation**: <inline errors, blocking rules, disabled states>
- **Destructive actions**: <confirmation and recovery behavior>

### Copy Requirements

| Element | Copy |
|---------|------|
| Title | <exact text> |
| Primary action | <exact text> |

### Accessibility

- <content descriptions, roles, focus order, dynamic type, contrast, minimum touch target>

### Responsive And Configuration Behavior

- <portrait/landscape/tablet behavior>

### Design Assets

- **Mockup image**: `design/mockup_<screen_name>.png` (or user-provided screenshot/mockup path in `design/`) — Visual mockup reflecting this screen's layout, components, and visual states.
- **Keyboard-visible mockup**: `design/mockup_<screen_name>_keyboard.png` when this screen has a bottom-sheet text input; otherwise state `Not applicable`.
- <paths to any additional reference screenshots/assets, or "None">

### Out Of Scope For This Design

- <explicit non-goal>

---

<!-- Add more Screen N blocks as needed -->
