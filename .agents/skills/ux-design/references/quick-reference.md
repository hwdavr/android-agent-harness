# Quick Reference — Android/Compose/Material 3 UX Rules (10 Categories)

This document provides a categorized set of Android & Jetpack Compose UI/UX rules and design intelligence for quick scanning and application during feature design and review.

---

## 1. Accessibility (CRITICAL)

- `color-contrast`: Minimum 4.5:1 ratio for body text, 3:1 for large text/icons against background (WCAG AA / Material Design 3).
- `content-description`: Every non-decorative icon and image must provide a localized `contentDescription = stringResource(...)` or `null` if decorative.
- `touch-target-size`: Minimum 48×48dp interactive component size (`Modifier.minimumInteractiveComponentSize()`).
- `dynamic-type`: Support system font scaling without text clipping; use `TextOverflow.Ellipsis` or scrollable containers.
- `keyboard-focus`: Provide visible focus indication for TV / desktop / hardware keyboard navigation.
- `screen-reader-traversal`: Use `Modifier.semantics(mergeDescendants = true)` on composite components for clean talkback reading order.
- `color-not-only`: Never convey state or error solely by color — always combine with icons, text labels, or shapes.

---

## 2. Touch & Interaction (CRITICAL)

- `press-feedback`: Provide immediate visual press feedback within 100ms (Material Ripple via `Modifier.clickable`).
- `gesture-conflicts`: Avoid horizontal swipe gestures that conflict with Android system back-swipe or tab pagers.
- `loading-states`: Disable controls during async operations; display `CircularProgressIndicator` or linear shimmer loaders.
- `destructive-actions`: Irreversible actions (delete, discard changes) must display a confirmation `AlertDialog` or modal sheet.
- `safe-area-awareness`: Respect system bars, notch, and gesture navigation bar using `WindowInsets.systemBars` padding.

---

## 3. Performance (HIGH)

- `lazy-list-virtualization`: Use `LazyColumn` / `LazyRow` / `LazyVerticalGrid` for dynamic content; specify stable `key` parameters.
- `remember-derived-state`: Wrap expensive dynamic calculations or scroll state listeners in `remember` and `derivedStateOf`.
- `bitmap-memory`: Scale, crop, or downsample bitmaps off the main thread; recycle unused bitmap memory.
- `avoid-recomposition`: Mark data models as `@Immutable` or `@Stable`; extract stateless leaf Composables.

---

## 4. Style Selection (HIGH)

- `material3-tokens`: Use `MaterialTheme.colorScheme` and `MaterialTheme.typography` tokens — no raw hex codes or inline font sizes in Composables.
- `sleek-dark-mode`: Dark theme for editor/focused context — high-contrast surfaces (`SurfaceContainerHigh`), neutral dark background (`#121212` / `#1E1E1E`), bright accent pop (primary color).

---

## 8. Forms & Controls (MEDIUM)

- `field-labels`: Always show visible field labels or floating `OutlinedTextField` labels — never rely solely on placeholders.
- `inline-errors`: Display validation error text below the input field in `error` color with an warning icon.
- `active-slider`: Numerical/range sliders must display live numerical values/percentages above or beside the thumb during drag.

---

## 9. Navigation Patterns (HIGH)

- `predictable-back`: Back button and system back gesture must predictably pop the stack or close active sheet/dialog.
- `bottom-bar-limit`: Limit main navigation bottom bar to 3–5 items maximum with visible icons and labels.
- `deep-linking`: Navigation routes must accept primitive/serializable parameters for state restoration.

---

## 10. Visual Verification (LOW)

- `state-completeness`: Design and verify all 4 core visual states for every screen: Loading, Content, Empty, and Error.
- `mockup-alignment`: Actual implementation in Compose must visually match the design mockup in hierarchy, copy, and layout.
