# Pre-Delivery UX Polish Checklist — Android App Interface

Load this checklist during final visual inspection or UX polish pass of Android Compose UI.

---

## Icons & Visual Assets

| Rule | Standard | Avoid | Why It Matters |
|------|----------|-------|----------------|
| **Vector Icons Only** | Use Material Symbols, `ImageVector`, or SVG drawables. | Emojis (🎨 ⚙️ 🚀) or raster PNG icons for system controls. | Vector icons scale crisp on high-DPI displays, adapt to dark mode, and match theme tokens. |
| **Consistent Stroke/Style** | Use unified icon weight/fill style across toolbars (e.g. outlined by default, filled when selected). | Mixing filled and outline icons randomly within the same toolbar. | Maintains cohesive visual language. |
| **Touch Target Margin** | Expand touch bounds to minimum 48×48dp (`Modifier.minimumInteractiveComponentSize()`). | Tiny 24×24dp tap targets with no padding around them. | Prevents missed taps and user frustration on mobile screens. |
| **Icon Alignment** | Vertically align icons to text baseline with consistent 8dp gap. | Off-center icons or misaligned text-icon pairings. | Prevents subtle visual imbalance. |

---

## Interactive Controls & Touch Feedback

| Rule | Do | Don't |
|------|----|-------|
| **Tap Feedback** | Provide immediate visual press response (Material Ripple, opacity change) within 100ms. | Static buttons that show no response when pressed. |
| **Disabled State Clarity** | Use reduced opacity (e.g. `0.38f`) and set `enabled = false` on clickable modifiers. | Tappable-looking controls that silently ignore user touches. |
| **System Bar Insets** | Apply `WindowInsets.safeDrawing` or `statusBarsPadding()` / `navigationBarsPadding()`. | UI controls clipped behind status bar, camera notch, or gesture bar. |
| **Slider Affordance** | Show active value badge while dragging range/numerical sliders (font size, margin, intensity). | Invisible value sliders where users must guess current level. |
| **Dialog Confirmation** | Prompt user before discarding unsaved note edits or deleting items. | Abrupt screen dismissal with accidental data loss. |

---

## Screen States & Polish

| State | Checklist Item |
|-------|----------------|
| **Loading** | Shimmer animation or `CircularProgressIndicator` centered; non-blocking elements disabled. |
| **Content** | Primary document/note content dominates view; controls anchored in ergonomic reach zone. |
| **Empty** | Helpful illustration/icon + clear prompt copy + CTA button (e.g., "Create a New Note"). |
| **Error** | Human-readable message + Retry CTA button + WARN/ERROR log captured. |
