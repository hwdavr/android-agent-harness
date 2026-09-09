---
name: ui-verification
description: Verify Android UI visually and interactively against approved design and runtime evidence.
---

# Skill — UI Verification

## Purpose

Verify implemented UI against the approved design and design system after implementation. Keep
deterministic structure and runtime evidence binding; use perceptual and AI comparison for scoped
design judgment. The report schema exists only in
`harness/templates/ui-verification-template.json`.

## Load

- `docs/product/design_system.md` and the approved feature design/reference assets.
- The active spec, implementation/test plan or selected sprint-contract rows, and execution flags.
- `.agents/rules/testing-runtime-evidence.md`.
- Only Required, excepted, or diff-triggered Compose, localization, navigation, and security rules.
- `harness/templates/ui-verification-template.json`.

## Execute

### Phase 0 — Build and runtime readiness

```bash
./gradlew assembleDebug
./gradlew lintDebug
./gradlew ktlintCheck
ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest
```

All applicable commands must exit 0. Prefer an emulator and use a physical device only when no
emulator is connected. Missing required runtime evidence is `Blocked`/`Revise`, never passing.

Visual captures must be created inside the active test after `waitForIdle()` using
`UiAutomation.takeScreenshot()` or `captureToImage()`, saved under `/sdcard/Download/`, and pulled
with `adb pull`. Post-test CLI screencaps are invalid.

For evidence-backed reports, `design_anchors` and `runtime_evidence` are a pair. Expected geometry
lives only in `design_anchors.json`; captured bounds live only in `ui_frames.json`. Version 2+
PASS reports also declare each applicable visual-risk role, its runtime-backed visual `testTag`,
producing method, and concrete assertion. A touch target does not prove the smaller visible shape.

### Phase 1 — Normalize

Record reference/runtime resolution and density, common logical dp space, aspect ratio, system-bar
cropping or masks, orientation, theme, font scale, and locale. Differences must be corrected or
declared before comparison.

### Phase 2 — Scope

Derive the area of interest from approved requirements and changed files. Fully verify changed
regions. For unchanged regions, prove presence, visibility, no clipping/overlap, and no unintended
layout shift. A new screen or full redesign uses the full screen as its scope.

### Phase 3 — Decompose

Map the scoped surface into named logical regions that correspond to design components. Record
region bounds in dp; do not invent arbitrary rectangles solely to improve a comparison score.

### Phase 4 — Structural verification

For each critical element, verify existence, position, size, alignment, spacing, visibility,
clipping, overlap, and cross-state invariance. Use design-approved tolerances; defaults are 4dp for
position/spacing and 5% for size unless the design declares stricter values.

Use Compose semantic bounds from stable visual `testTag`s and density-derived dp conversion.
`uiautomator` is a fallback only when semantics cannot expose the element. The artifact validator
computes expected/actual deltas; do not self-report PASS values that are not source-fed.

### Phase 5 — Mask dynamic content

Mask only runtime-variable content such as user text, identifiers, timestamps, balances, chart
data, dynamic images, or counts. Preserve container bounds, layout, static labels, icons, borders,
and background treatment. Record every mask and rationale.

### Phase 6 — Perceptual comparison

```bash
bash harness/scripts/compare-visual-evidence.sh \
  --reference <approved-reference> \
  --actual <runtime-capture> \
  --diff-output <diff-overlay> \
  --crop-insets

bash harness/scripts/compare-visual-evidence.sh --feature "$FEATURE_DIR" --crop-insets
```

- Golden comparisons are binding at similarity >= 0.95 with zero high-severity defects.
- Approved mockup comparisons are informational and support semantic design review.
- Reference-anchor geometry remains the binding structural proof.
- `reference-map.json` resolves explicit references/masks; `null` declares anchor-only evidence.
- Missing, ambiguous, dangling, or stale references fail as `NO_REFERENCE`.
- Promote every approved non-anchor-only capture to its golden baseline.
- Preserve the report, actual capture, and neon-magenta diff overlay.

Evaluate composition, visual weight, palette, boundaries, icon identity, and typography hierarchy.
A score cannot override a hidden CTA, clipping, overlap, or missing component.

### Phase 7 — Classify defects

| Severity | Examples | Verdict effect |
|---|---|---|
| Critical | Missing/wrong screen or component, inaccessible CTA, unreadable clipping, unusable overlap, overflow, broken navigation | FAIL |
| Major | Dimensions beyond tolerance, spacing deviation over 8dp, layout shift, wrong hierarchy/icon/theme/token | FAIL unless explicitly accepted |
| Minor | Small within-tolerance spacing, anti-aliasing, subtle same-hue variance, small radius/shadow difference | PASS with warning |

Record region, severity, evidence, suggested fix, and resolution status for every finding.

### Phase 8 — AI visual evaluation

Evaluate the normalized reference and runtime image only within the declared scope. Return
structured findings for component order, alignment, relative spacing, typography, clipping,
overlap, missing/extra elements, icon/assets, and visual balance. Record regression results for
out-of-scope regions. Do not substitute a vague whole-screen similarity judgment.

## Conditional rendered-output proof

For rich-text or inline-formatting appearance claims, the named test must capture plain and
formatted Compose nodes and assert an explicit pixel difference. Model marks, text content,
toolbar state, and screenshot existence are supplemental. Run:

```bash
bash harness/scripts/check-rendered-output-contract.sh \
  --project-root . --test-file <file> --test-method <method> --claim <claim>
```

## Output

Copy `harness/templates/ui-verification-template.json`, replace every placeholder, and write the
active workflow's `ui_verification.json`. Validate it with:

```bash
bash harness/scripts/check-ui-verification-artifact.sh <ui_verification.json>
bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate
```

Do not reproduce or maintain the JSON schema in this skill. Update the active summary with concise
command results and referenced evidence paths.

## Done When

- Applicable build, lint, formatting, and instrumented commands exit 0.
- Normalization, scope, regions, masks, and out-of-scope regressions are recorded.
- Every critical element has source-fed bounds evidence within its approved tolerance.
- Every required visual role has a runtime-backed visual tag and concrete assertion.
- Required captures, anchors, references/goldens, comparisons, and rendered-output checks pass.
- No Critical or unresolved Major finding remains.
- The canonical JSON artifact passes its validator with no placeholders or contradictory results.

On failure, return to UI implementation, fix the root cause, and rerun only invalidated evidence.
After the workflow's retry cap, stop and present the unresolved deviation with its evidence.
