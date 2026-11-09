---
name: ui-verification
description: Verify implemented UI against the approved design through a conformance review — review captures at the Pen frame size, structural semantics checks, registered-component reuse, and user approval. No screenshot goldens.
---

# Skill — UI Verification (Conformance Review)

## Purpose

Prove each `UI_contract.md` state matches its approved design, fairly and without pixel goldens.
A design-tool export and a Compose render never match pixel for pixel (text rasterization,
hinting, anti-aliasing, stroke rounding), so appearance is approved by people and structure is
checked by tests:

1. **Review capture** — the production Composable rendered at the state's Viewport (the Pen
   frame's dp size and density) with its deterministic fixture.
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

Each state's `*ReviewCaptureTest` (under `app/src/test/java/<package>/review/`) renders the
production Composable with `@Config(qualifiers = "w<W>dp-h<H>dp-<density>")` matching the state's
Viewport and the Pen export scale, the state's fixture, theme, locale, and font scale. Copy each
capture to `$FEATURE_DIR/evidence/ui/<state-id>.png`. Never resize a capture or a design export to
make them match — a size mismatch is a contract error to fix.

### 3. Structural checks

Run each state's structural test (JVM semantics or instrumented). It asserts presence, order,
visibility, clipping/overlap, and bounds against the contract tolerance for every critical element,
using stable visual `testTag`s and density-correct dp conversion. A failure returns to implementation.

### 4. Side-by-side review

Present, per state, the approved design image and the review capture together, plus the structural
result and reused components. Name any visible difference you notice and classify it:

| Severity | Examples | Effect |
|---|---|---|
| Critical | Missing/wrong component, hidden CTA, clipping, overlap, broken navigation | Changes required |
| Major | Wrong hierarchy, icon, token, or theme; spacing clearly off design | Changes required unless the user accepts it |
| Minor | Font rasterization, anti-aliasing, sub-dp radius or shadow differences | Note only |

Record the user's decision per state. Changes requested → fix, re-capture, re-review.

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
