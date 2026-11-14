---
name: ui-verification
description: Verify implemented UI visual conformance to the approved design — Pen-frame-size captures, structural semantics, registered-component reuse, and user approval. No screenshot goldens.
---

# Skill — UI Verification (Conformance Review)

## Purpose

Prove each `UI_contract.md` state matches its approved design, fairly and without pixel goldens.
A design-tool export and a Compose render never match pixel for pixel (text rasterization,
hinting, anti-aliasing, stroke rounding), so appearance is approved by people and structure is
checked by tests:

1. **Review capture** — the production Composable rendered at the state's Viewport (the Pen
   frame's dp size and density) with its deterministic fixture. A `screen-frame` design is a whole
   screen: render the production `*Screen`/`*ScreenContent` (directly or through a test frame helper
   that mirrors the app's Scaffold and bottom bar), never a component padded to the viewport.
2. **Structural check** — required `testTag`s present, ordered, visible, unclipped, with bounds
   within the contract tolerance (default 4dp position/spacing, 5% size).
3. **Component reuse** — the state's registered design-system components are the ones called.
4. **Side-by-side review** — capture beside the approved design; the user approves or requests changes.

Never record, commit, or compare a screenshot golden (`recordRoborazziDebug`,
`verifyRoborazziDebug`, `verifyAndRecordRoborazziDebug` are not acceptance evidence).

## Load

- `docs/product/design_system.md` (tokens, components, Component Registry).
- `$FEATURE_DIR/UI_contract.md`, the approved design images, `test-plan.md` → UI State Verification,
  and `implementation-plan.md` → UI State Stages.
- `.agents/rules/testing-runtime-evidence.md`; Compose, localization, navigation, and security
  rules only when Required, excepted, or diff-triggered.
- `harness/templates/ui-verification-template.json`.

## Execute

### 1. Build and static readiness

```bash
./gradlew assembleDebug
./gradlew lintDebug
./gradlew ktlintCheck
bash harness/scripts/check-compose-rules.sh   # includes "Registered design-system components"
```

All must exit 0. Missing runtime for a required instrumented check is Blocked, never PASS.

### 2. Render review captures

Each state's `*ReviewCaptureTest` (under `app/src/test/java/<package>/roborazzi/`) renders the
production Composable with `@Config(qualifiers = "w<W>dp-h<H>dp-<density>")` matching the state's
Viewport and the Pen export scale, the state's fixture, theme, locale, and font scale. Copy each
capture to `$FEATURE_DIR/evidence/ui/<state-id>.png`. Capture tests are excluded from the normal unit
suite; generate review images explicitly:

```bash
./gradlew testDebugUnitTest --tests "<package>.roborazzi.*" -Proborazzi.test.record=true
```

Structural tests stay outside the `roborazzi` package and run normally. Release unit tests always
exclude capture tests because their UI-test manifest is debug-only. Every capture command in the test
plan carries the record flag. Never resize a capture or a design export to make them match — a size mismatch is a contract error to fix. For a `screen-frame` state the review
capture must reach a production screen function; a state that shows a bottom sheet, modal, or dialog
must also use `captureScreenRoboImage` so every window is captured. `check-ui-contract.py` enforces
both (see `ui-screen-frame-capture-contract-test.py`).

A design frame also contains system-owned UI that Robolectric does not draw, and the app draws edge to
edge, so the capture frame must reproduce it or the comparison hides real defects:

- **Insets**: give the Scaffold a non-zero top inset (`contentWindowInsets = WindowInsets(top = ...)`)
  so the screen receives its status-bar inset through the same `parentPadding` path as production. A
  frame without it renders a screen that ignores the inset as correct. Size the status bar from the
  design frame (measure the first content row), not from a default.
- **Status bar**: draw review-only status bar chrome (clock and icons) over that region.
- **Scrim**: for a dialog, modal, or bottom-sheet state draw the dim scrim behind the window.
- Record in `findings.md` that this chrome is simulated review chrome, never app UI.

`check-ui-contract.py` fails a screen-frame capture whose frame applies no inset, draws no status bar,
or (for a dialog/sheet state) draws no scrim. A screen that draws under the status bar in the capture
is a Critical difference.

### 3. Structural checks

Run each state's structural test (JVM semantics or instrumented). It asserts presence, order,
visibility, clipping/overlap, and bounds against the contract tolerance for every critical element,
using stable visual `testTag`s and density-correct dp conversion. A failure returns to implementation.

### 4. Side-by-side comparison, pre-review, and review

Generate one comparison image per state, design on the left and the actual render on the right:

```bash
python3 harness/scripts/compose-ui-comparison.py "$FEATURE_DIR"
```

It writes `$FEATURE_DIR/evidence/ui/compare/<state-id>.png` and `index.md`. The images are a review
aid only; nothing is compared pixel by pixel and the originals are never resized. Rerun it after
every recapture; the gate rejects a comparison older than its design or capture.

**Pre-review (the agent, before the user).** Open every comparison image and write one entry per
state in `$FEATURE_DIR/evidence/ui/compare/findings.md` under a `### <state-id>` heading. List each
visible difference with its severity (table below), or `None`. Then fix the Critical and Major
differences that have an obvious fix in the planned UI files, recapture, regenerate the
comparison, and re-check. At most 3 fix loops; what remains is listed as `needs user decision`.
Limits: never change the requirement block, the state inventory, the approved designs, or the
design system, and never add a design-system exception; a difference that needs any of those, or
has no clean fix, is recorded as `needs user decision`, not guessed. Minor differences are noted
and left alone. Rerun the structural checks and affected instrumented journeys after every fix.
The pre-review does not replace the user's decision.

**User review.** Present, per state, the comparison image, the findings entry, the structural
result, and the reused components. Name any visible difference you notice and classify it:

| Severity | Examples | Effect |
|---|---|---|
| Critical | Missing/wrong component, hidden CTA, clipping, overlap, broken navigation | Changes required |
| Major | Wrong hierarchy, icon, token, or theme; spacing clearly off design | Changes required unless the user accepts it |
| Minor | Font rasterization, anti-aliasing, sub-dp radius or shadow differences | Note only |

Record the user's decision per state, with the `comparison_image` path. Changes requested → fix,
re-capture, regenerate the comparison, re-review.

### 5. Rich-text appearance claims

A claim that formatted text is visible needs a test asserting the rendered node's `AnnotatedString`
span styles through `SemanticsProperties.Text`, plus the review capture:

```bash
bash harness/scripts/check-rendered-output-contract.sh \
  --project-root . --test-file <file> --test-method <method> --claim <claim>
```

## Output

Copy `harness/templates/ui-verification-template.json` to `$FEATURE_DIR/ui_verification.json` and
fill one `state_results` entry per `UI_contract.md` state (capture, review-capture test, structural
check and result, reused components, decision, approver, date, notes, result). Validate:

```bash
bash harness/scripts/check-ui-verification-artifact.sh "$FEATURE_DIR"
bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate
```

then the workflow's `ui-verification` stage gate. Record command results in the summary.

## Done When

- Build, lint, formatting, and compose rules exit 0.
- Every state has a capture at its Viewport, a passing structural check, and its registered
  components called from the planned UI files.
- The user approved every state; no Critical or unaccepted Major difference remains.
- `ui_verification.json` passes both validators with no placeholders.

After three review loops without approval, stop and present the unresolved differences.
