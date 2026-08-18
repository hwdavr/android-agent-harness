---
name: ui-verification
description: Verifies Android UI screens visually and interactively using an 8-phase structured pipeline — normalize, scope, decompose, structural check, mask, perceptual compare, classify, AI evaluate.
---

# Skill — UI Verification

## Purpose
Verify that the implemented UI renders correctly and matches the design specified in `spec_v<N>.md`.
This stage runs after implementation is complete and before (or as part of) the code review.

**Core principle**: separate deterministic structural checks from perceptual/AI-judged visual
evaluation. Most real UI bugs are structural (missing element, wrong spacing, clipped text) and
can be caught deterministically. Reserve visual comparison for layout composition, color harmony,
and design-system compliance.

Use the cheapest reliable check first — build and static analysis → instrumented UI tests →
structural verification → scoped visual evaluation.

---

## Load
- `docs/product/design_system.md` — project-wide visual and component baseline
- `rules/android-architecture.md` — ensure no layer violations (UI importing data classes, etc.)
- `docs/current/spec_v<N>.md` — UiState design and visual specification from the Requirement, Impact & Design Analysis stage
- `docs/current/design/` — **original design screenshots** provided by the user in the Requirement, Impact & Design Analysis stage (e.g. `design.png`)
- `docs/current/implementation_plan_v<N>.md` — list of changed Composables and **scope of UI changes**

---

## Execute

### Phase 0 — Build and static checks
```bash
./gradlew assembleDebug
./gradlew lintDebug
./gradlew ktlintCheck
```
All must pass before proceeding to visual steps.

### Phase 0a — Instrumented UI test verification
Run existing instrumented tests for any changed screen (target an emulator first, e.g. using
`ANDROID_SERIAL=emulator-5554`, and fall back to a connected physical device only if no emulator
is present):
```bash
ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest
```

For each changed Composable, verify:
- [ ] Loading state renders correctly
- [ ] Success / content state renders correctly
- [ ] Empty state renders correctly (if applicable)
- [ ] Error state renders correctly (if applicable)
- [ ] CTAs are visible and correctly enabled/disabled
- [ ] Navigation triggers work as expected

---

### Phase 1 — Normalize screenshots

Before comparing anything, make the mockup and actual screenshot comparable.

**What to normalize:**

| Property | Normalization |
|----------|--------------|
| Screen resolution | Map both to the same logical dp-equivalent coordinate space (e.g. 390 × 844 dp) |
| Device aspect ratio | Identify and document aspect ratio of both reference and runtime device |
| Status bar | Crop or mask system status bar from both images |
| Navigation bar | Crop or mask system navigation bar (gesture bar / 3-button) |
| Safe areas / insets | Account for display cutouts and system insets |
| Orientation | Confirm both are in the same orientation; rotate if needed |
| Theme | Confirm both are in the same theme mode (light/dark); note if different |
| Font scale | Confirm both use the same font scale (default 1.0); note if different |
| Locale | Confirm both use the same locale; note if different |

**Example — do NOT compare directly:**
```
Figma mockup:   390 × 844
Runtime:       1080 × 2400
```

Map both to the same logical coordinate space:
```
Logical space: 390 × 844 dp-equivalent
```

**Record in the report:**
- Source resolution and density of reference
- Source resolution and density of runtime device
- Logical coordinate space used for comparison
- Any properties that differ between reference and runtime (theme, font scale, locale)

---

### Phase 2 — Scope-aware area selection

Derive the **area of interest** from the spec, design, and implementation plan.

**When the feature modifies only part of the screen** (e.g. "add emoji picker below toolbar",
"redesign the balance card", "update bottom CTA"):
- Identify the specific region(s) of the screen that the change affects
- Set those regions as the **area of interest** for full verification (Phases 3–8)
- All other regions receive only a **lightweight regression check**:
  - [ ] Region exists and is visible
  - [ ] Region is not clipped or overlapping
  - [ ] No layout shift compared to before the change
- This prevents false failures from unrelated regions and focuses agent effort on the actual change

**When the spec describes a new screen or full-screen redesign:**
- The area of interest is the entire screen
- All regions are fully verified

**Record in the report:**
- Declared area of interest with rationale (which spec/plan section drives it)
- List of regions receiving full verification
- List of regions receiving regression-only checks
- Regression check results for out-of-scope regions

---

### Phase 3 — Region decomposition

Within the area of interest, break the content into named logical regions derived from the spec's
component hierarchy.

**Example:**
```
┌────────────────────────────┐
│ header                     │
├────────────────────────────┤
│ balance_card               │
│ $128.50                    │
├────────────────────────────┤
│ usage_chart                │
│                            │
├────────────────────────────┤
│ transaction_list           │
│ ...                        │
├────────────────────────────┤
│ bottom_cta                 │
└────────────────────────────┘
```

Regions should map to logical components from the spec, not arbitrary pixel rectangles.

**Record in the report:** table of region names with their approximate bounds in dp.

---

### Phase 4 — Structural verification

For each critical element within each in-scope region, verify deterministic structural properties.

**Properties to check:**

| Property | Description |
|----------|-------------|
| `exists` | Element is present in the semantic tree |
| `position` | Element's x/y coordinates in dp |
| `size` | Element's width/height in dp |
| `alignment` | Element's alignment relative to parent or siblings |
| `spacing` | Gaps between adjacent elements in dp |
| `visibility` | Element is visible (not hidden, not zero-sized) |
| `clipping` | Content is not clipped or overflowing its bounds |
| `overlap` | Element does not unintentionally overlap siblings |
| `cross_state_invariance` | Element position/size remains unchanged across interactive focus/selection transitions (zero layout shift) |

**Default tolerances:**

```yaml
position_tolerance_dp: 4
size_tolerance_percent: 5
spacing_tolerance_dp: 4
```

You do not need exact equality — use tolerances to account for rounding, density differences,
and minor rendering variations.

**Example structural check:**
```
Pay button:
  Expected:
    x = 24–366 dp
    height ≈ 48 dp
    bottom margin ≈ 24 dp

  Actual:
    x = 24–366 dp
    height = 48 dp
    bottom margin = 6 dp

  Result: FAIL
    bottom spacing differs significantly (expected ~24dp, got 6dp)
```

**How to measure:**

Use Compose semantics bounds when available:
- Give the rendered element a stable `testTag`
- Use `fetchSemanticsNode().boundsInRoot` and density-derived dp conversion
- When the visual shape differs from the interactive target (e.g. a small icon inside a 48dp
  touch target), give the visual shape its own `testTag` and measure that

Use `adb shell uiautomator dump` as a fallback for elements without semantic tags.

**Record in the report:** table of element measurements vs expected values, with tolerances and
PASS/FAIL per element.

---

### Phase 5 — Mask dynamic content

Before visual comparison, identify and mask regions containing runtime-variable data.

**Mask areas containing:**
- Customer names and user-generated text
- Account numbers and IDs
- Timestamps, dates, and clocks
- Balances and monetary values
- Chart/graph data points
- Dynamic images and avatars
- Notification badges and counts
- Random or session-specific identifiers

**What to compare after masking:**
- Container bounds and shape
- Layout structure and alignment
- Label text (static labels, not dynamic values)
- Icon presence and position
- Background color and borders

**Example:**
```yaml
ignore_regions:
  - balance_value     # "$128.50" — runtime variable
  - account_number    # "****1234" — user-specific
  - chart_data        # plotted line — data-dependent
  - timestamp         # "2 hours ago" — time-dependent
```

**Record in the report:** list of masked regions with rationale.

---

### Phase 6 — Perceptual comparison

Compare visual composition rather than exact pixel values. Traditional pixel diff is too sensitive
and fails due to:
- Font anti-aliasing differences
- GPU rendering variations
- Different OS versions
- Subpixel placement
- Shadow rendering
- Image compression artifacts
- Status bar differences (even after normalization)

**What to evaluate (per in-scope region):**
- Shape and contour similarity
- Layout composition and visual weight distribution
- Color distribution and palette adherence
- Edge structure and element boundaries
- Typography hierarchy (relative sizes, weights, not exact rendering)

**Conceptual thresholds:**
```yaml
overall_similarity: 0.95       # minimum for full-screen pass
critical_component: 0.98       # minimum for critical UI elements (CTAs, headers)
```

These thresholds guide judgment — they are not computed metrics from a pixel-diff tool.
The agent uses visual reasoning to assess whether the runtime output is perceptually equivalent
to the reference within these confidence levels.

**Important:** score alone does not determine PASS/FAIL. A 0.93 similarity with only minor
anti-aliasing differences is a PASS. A 0.97 similarity where the CTA button is partially hidden
is a FAIL. Use defect classification (Phase 7) to make the final call.

**Record in the report:** per-region perceptual assessment with confidence level and notes.

---

### Phase 7 — Defect classification

Classify every finding from Phases 4–6 into severity tiers. This prevents agents from endlessly
fixing meaningless pixel differences.

#### Critical → FAIL
- Button or CTA hidden or inaccessible
- Text clipped or unreadable
- Elements overlap making content unusable
- Wrong screen rendered
- Missing required component
- Layout overflowing screen bounds
- Navigation element missing or broken

#### Major → usually FAIL
- Wrong component dimensions (beyond tolerance)
- Large spacing deviation (>8dp from reference)
- Layout shift or positional jumping during focus, selection, or interactive state transitions
- Wrong typography hierarchy (e.g. body used where heading expected)
- Incorrect icon or asset
- Wrong theme applied
- Color significantly different from design system token

#### Minor → WARN
- 1–2dp shadow or elevation difference
- Small spacing deviation (within 4dp but noticeable)
- Anti-aliasing or font rendering differences
- Subtle color variance within the same hue
- Minor border radius difference

**Verdict rules:**
- Any Critical finding → **FAIL**
- Any unresolved Major finding → **FAIL** (unless explicitly accepted by reviewer)
- Minor findings only → **PASS with WARNs**

**Record in the report:** table of findings with region, severity, description, and suggested fix.

---

### Phase 8 — AI visual evaluation

With the reference mockup, runtime screenshot, and all context from prior phases, perform a
structured visual evaluation.

**Evaluation inputs:**
1. Reference mockup (normalized, from Phase 1)
2. Runtime screenshot (normalized, from Phase 1)
3. Declared area of interest (from Phase 2)
4. Acceptance criteria (from spec)
5. Masked/ignored regions (from Phase 5)

**Evaluation axes — evaluate within the area of interest:**
- Component hierarchy — are all expected components present in the right order?
- Alignment — are elements aligned as specified?
- Relative spacing — are gaps between elements proportional to the reference?
- Typography hierarchy — do headings, body, captions follow the right visual weight?
- Clipping — is any content cut off?
- Overlap — do any elements unintentionally overlap?
- Missing/extra elements — anything present that shouldn't be, or absent that should be?
- Icons and assets — correct icons used, correct size, correct color?
- Visual balance — does the overall composition feel balanced and intentional?

**Do NOT ask vaguely:** "Does this look the same?"

**Do ask specifically:** evaluate each axis above and return structured findings.

**Expected output format:**
```json
{
  "status": "PASS | FAIL",
  "area_of_interest": "bottom toolbar + emoji picker",
  "issues": [
    {
      "region": "bottom_cta",
      "severity": "critical",
      "issue": "CTA is partially hidden behind navigation bar",
      "suggestion": "Apply navigationBarsPadding()"
    },
    {
      "region": "balance_card",
      "severity": "minor",
      "issue": "Vertical padding appears approximately 4dp larger than reference"
    }
  ],
  "regression_checks": {
    "header": "PASS — exists, visible, no layout shift",
    "transaction_list": "PASS — exists, visible, no layout shift"
  }
}
```

**Record in the report:** the full structured evaluation result.

---

## Checklist — what to verify

### Deterministic (must all pass)
- [ ] Build succeeds with no crash (`assembleDebug`)
- [ ] Static checks pass (`lintDebug`, `ktlintCheck`)
- [ ] Instrumented UI tests pass (if present)
- [ ] Screenshots normalized to common dp coordinate space
- [ ] Area of interest declared and documented
- [ ] In-scope regions identified and listed
- [ ] Out-of-scope regions regression-checked (exists, visible, no shift)
- [ ] Cross-state positional invariance verified for interactive overlays/handles (zero host layout shift)
- [ ] All text strings match the design (`spec_v<N>.md`)
- [ ] Structural properties verified within tolerance for all critical elements
- [ ] Dynamic content regions identified and masked
- [ ] No Critical defects found
- [ ] No unresolved Major defects

### Judged (agent visual assessment)
- [ ] Perceptual similarity within acceptable range per in-scope region
- [ ] AI visual evaluation completed with structured findings
- [ ] Actual screenshot conforms to `docs/product/design_system.md` except for explicitly
      documented approved exceptions
- [ ] Loading / empty / error / success states all render correctly
- [ ] Long content handled correctly (scrolling verified)
- [ ] Bottom sheets with long content use `skipPartiallyExpanded = true` for reliable accessibility
- [ ] Navigation destination or back-stack behavior matches design

---

## Output

Produce `docs/current/ui_verification.json` from
`harness/templates/ui-verification-template.json`. The output is a single JSON document:
```json
{
  "version": "<N>",
  "reference_design": "design/<approved_mockup_or_screenshot>.png",

  "build_and_static_checks": {
    "assembleDebug": "PASS / FAIL",
    "lintDebug": "PASS / FAIL",
    "ktlintCheck": "PASS / FAIL"
  },

  "instrumented_tests": {
    "passed": "<N>",
    "total": "<N>"
  },

  "normalization": {
    "reference_resolution": "<e.g. 390×844>",
    "reference_density": "<e.g. 2x>",
    "runtime_resolution": "<e.g. 1080×2400>",
    "runtime_density": "<e.g. 2.75x>",
    "logical_space": "<e.g. 390×844 dp>",
    "theme": { "reference": "light", "runtime": "light", "match": true },
    "font_scale": { "reference": 1.0, "runtime": 1.0, "match": true },
    "locale": { "reference": "en-US", "runtime": "en-US", "match": true }
  },

  "scope": {
    "type": "partial / full-screen",
    "area_of_interest": "<description>",
    "rationale": "<which spec/plan section drives this scope>",
    "in_scope_regions": ["<region_name>"],
    "out_of_scope_regions": ["<region_name>"]
  },

  "regression_checks": [
    {
      "region": "<out-of-scope region>",
      "exists": true,
      "not_clipped": true,
      "no_layout_shift": true,
      "result": "PASS / FAIL"
    }
  ],

  "region_decomposition": [
    {
      "region": "<region_name>",
      "bounds_dp": { "x_start": 0, "x_end": 390, "y_start": 0, "y_end": 56 }
    }
  ],

  "structural_verification": {
    "tolerances": {
      "position_dp": 4,
      "size_percent": 5,
      "spacing_dp": 4
    },
    "checks": [
      {
        "region": "<region>",
        "element": "<element>",
        "property": "<property>",
        "expected": "<value>",
        "actual": "<value>",
        "within_tolerance": true,
        "result": "PASS / FAIL"
      }
    ]
  },

  "dynamic_content_masking": [
    {
      "region": "<region>",
      "rationale": "<why masked>"
    }
  ],

  "perceptual_comparison": [
    {
      "region": "<region>",
      "confidence": "high / medium / low",
      "notes": "<observations>"
    }
  ],

  "defect_classification": [
    {
      "id": 1,
      "region": "<region>",
      "severity": "critical / major / minor",
      "description": "<description>",
      "suggested_fix": "<suggestion>",
      "status": "open / fixed"
    }
  ],

  "ai_visual_evaluation": {
    "status": "PASS / FAIL",
    "area_of_interest": "<description>",
    "issues": [
      {
        "region": "<region>",
        "severity": "critical / major / minor",
        "issue": "<description>",
        "suggestion": "<fix>"
      }
    ],
    "regression_summary": {
      "<out-of-scope region>": "PASS — exists, visible, no layout shift"
    }
  },

  "design_deviations": [],

  "verdict": {
    "result": "PASS / FAIL",
    "reason": "<reason if fail>",
    "critical_findings": 0,
    "major_findings_unresolved": 0,
    "minor_findings_warnings": 0
  }
}
```

Update `docs/current/summary_v<N>.md`: mark UI Verification stage complete.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**
- [ ] `assembleDebug` — exit code 0
- [ ] `lintDebug` and `ktlintCheck` — exit code 0
- [ ] Instrumented UI tests pass (if present): `./gradlew connectedDebugAndroidTest`
- [ ] Screenshots normalized and logical coordinate space documented
- [ ] Area of interest declared with rationale
- [ ] Out-of-scope regions regression-checked (exists, visible, no layout shift)
- [ ] In-scope regions decomposed and listed
- [ ] Structural properties verified within tolerance for all critical in-scope elements
- [ ] Dynamic content masked and documented
- [ ] All text strings verified against design — no unresolved mismatches
- [ ] Perceptual comparison completed for all in-scope regions
- [ ] Defect classification applied — zero Critical, zero unresolved Major
- [ ] AI visual evaluation completed with structured per-region findings
- [ ] Actual screenshot compared against the original or approved generated reference
- [ ] All UiState variants (loading, success, empty, error) confirmed rendering correctly
- [ ] `docs/current/ui_verification.json` exists with verdict filled in
- [ ] `bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify ui-verification docs/current` exits 0

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.

**REVISION REQUIRED →**
- Build failure → fix compilation error in the UI implementation stage
- Critical/Major defect → fix in the UI implementation stage, re-run from Phase 0
- Text mismatch → fix hardcoded strings or string resource values, re-run verification
- State rendering issue → return to UI implementation stage and fix ViewModel or Composable
- Structural failure → fix spacing/sizing/alignment in the Composable, re-run from Phase 4

**Iteration cap:** 2 rounds. If a layout issue cannot be resolved through structural verification
and code fixes alone, surface it to the user with the screenshot, structural measurements, and
defect classification attached.
