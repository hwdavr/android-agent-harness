# Editable inputs require an IME design and a production window test

The Sticker picker incident exposed two independent evidence gaps. Its original visual inventory
covered All, Smileys, and no-results with focus cleared, so typing was never designed. The first
fix passed with directly mounted editor Content while the shipped Activity still used a different
window policy and parent layout.

The keyboard is a screen state whenever the containing surface has editable input. Preserve the
full window viewport in closed/open designs and show the focused input, required actions,
content, persistent surfaces, and IME together. A panel above a static keyboard image proves only
that fixture's composition. It does not show what the full editor must do or how Android resizes it.

IME geometry belongs to the production Activity boundary even without a navigation change. The
primary instrumented test must use the shipped manifest and content, wait for real root-window
IME insets, assert window-coordinate control bounds, dismiss, and prove restoration. Replacing
the Activity content or checking `adjustResize` alone is supplemental evidence.

Use the `IME State Coverage` and `IME Production Boundary` template tables. Their stage gates
reject omitted states and insufficient runtime proof. Source structure and runner XML are minimum
checks; reviewing equivalence with the observed entry route and keeping current fingerprint
receipts remain necessary. Clearing focus to stabilize a visual comparison must not remove the
keyboard-open acceptance state.

Incident and verified regression fixtures:
`docs/changes/harness-retro-2026-10-23-ime-design-runtime/retrospective.md`.
