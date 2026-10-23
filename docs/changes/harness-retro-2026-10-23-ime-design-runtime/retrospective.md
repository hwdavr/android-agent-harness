# IME design and production-boundary retrospective

## Incident and classification

Primary classification: `HARNESS_ENVIRONMENT`.

The existing Compose rule required a keyboard-visible design for every editable screen, but the
mechanical gate read only complex-feature `design.md` artifacts, skipped screens without a bottom
toolbar, and was not invoked by the ad-hoc UI contract or bug-fixing plan gates. The original
Sticker picker contract therefore listed All, Smileys, and unfocused no-results states only.

The first keyboard fix used a real software keyboard around directly mounted editor content. Its
GREEN result did not establish that the shipped Activity's window policy and imported-photo editor
layout worked. The bug-fixing gates required a production journey only for `NAV`, although IME
behavior depends on the production window even without a navigation change.

## Invariant

An editable input cannot pass planning without complete keyboard-closed and keyboard-open screen
designs, and an IME regression cannot pass with an instrumented fixture that replaces the shipped
Activity's content.

## Evidence

Application repository: `hwdavr/FunPhotoEditor` (incident artifacts remain in its local
`docs/current/` workspace).

- `docs/current/emoji-sticker-library/implementation_plan_v1.md:112`:
  “deterministic visual fixtures prefill query state and clear focus before capture.”
- `docs/current/emoji-sticker-library/UI_contract.md:25`: All, Smileys, and no-results states
  contain Search, with no keyboard-open state.
- `docs/current/spec_v23.md`, Reproduction Test: “mounts the production
  `DarkEditPhotoContent` with its real edge-to-edge root and Sticker Tool panel.” This is a
  Content fixture, not the shipped Activity and entry route.
- `docs/current/summary_v23.md`, Testing and Quality Results: post-install replay was skipped because the isolated T1/T2
  tests passed. The sufficiency of those tests was assumed.
- `docs/current/spec_v24.md`: the production activity used `adjust=pan`; after enabling resize,
  the production route still measured `panelBottom=2337`, `keyboardTop=1517`, `imeBottom=883`.
- `harness/scripts/check-keyboard-mockup-contract.sh`: the previous surface guard returned PASS
  for a text-input screen with no bottom toolbar.
- `harness/scripts/check-stage-artifacts.sh`: bug-fixing plan did not validate `UI_contract.md`;
  production-boundary checks during Testing were triggered only by `NAV`.

The application fix, device matrix, and current runtime assertions are outside this harness repair.

## Why the first delivery and first fix were insufficient

The feature inventory modeled query results but omitted focus/typing. Prefilling a query and
clearing focus stabilized the panel screenshot while excluding the state where Android takes
screen space. Approval of that inventory did not explicitly waive keyboard coverage; the harness
should have rejected the incomplete proposal before approval.

The first fix reproduced overlap in an isolated Content host, then interpreted GREEN in that
host as proof of the shipped editor. It did not establish the production soft-input mode or the
full entry route and parent layout. The post-install replay was skipped on that insufficient
basis. The later `adjust=pan` observation and second geometry RED showed the boundary mismatch.

The v23/v24 visual exports are panel-scoped: closed `430x420dp`, open `430x732dp` including a fixed
keyboard preview. They are not complete `430x932dp` editor designs. Passing those comparisons
proved the panel fixture, while the summaries overstated completeness of the screen design.
The repair rejects those historical contracts for missing IME coverage; it does not retroactively
declare their design inventories complete.

## Harness changes

- `.agents/rules/compose-rules.md` and `.agents/rules/testing-runtime-evidence.md` explicitly
  cover every editable screen, including toolbar-less screens, and distinguish full-screen IME
  design from component appearance and real production-window behavior.
- `.agents/workflows/create-ui-and-verify.md` and `.agents/workflows/bug-fixing.md` bind input
  inventories to full-window states and production Activity open/dismiss evidence. `NAV` being
  Not applicable no longer bypasses the IME boundary.
- `harness/templates/UI_contract-template.md` adds `IME State Coverage`; the test-plan template
  adds `IME Production Boundary` with future targets, exact command, and runner XML path.
- `harness/scripts/check-ui-contract.py` rejects omitted/unmapped states, panel crops, missing
  `system-ime`, missing input visibility, incomplete boundary declarations, wrong selected
  classes, and missing/skipped/failed runner cases.
- `harness/scripts/kotlin_ast_checker.py` adds `ime-boundary`, checking the selected method and
  reachable helpers for the production Activity/manifest, real insets, UI gesture, window bounds,
  and open/dismiss assertions. `setContent` replacement and generic test Activities are rejected.
- `harness/scripts/check-stage-artifacts.sh` invokes these checks at UI planning/verification
  and bug reproduction/planning/testing. The older complex-design gate now includes text-input
  screens without toolbars; its contradictory skill/CI wording is aligned.
- `.agents/gates/ci-checks.md` registers the new regression suite.

## Verification

Raw evidence is retained under this record's `evidence/` directory.

| Check | Result and one-line excerpt |
|---|---|
| Two new negative fixtures against `origin/main` (`cd9e2a7`) | Expected RED: **2 failures**, both old validators returned PASS. `evidence/initial-false-pass.log`: “unexpected PASS: PASS: design has no bottom-sheet surface or bottom toolbar.” |
| `bash harness/scripts/tests/ime-state-boundary-contract-test.sh` | PASS: **22 tests**. Includes omitted/cropped designs, generic/replaced Activity, unreachable/comment-only proof, stage wiring with `NAV` N/A, and unavailable/failed/skipped/wrong-class results. |
| Existing keyboard, UI-contract, bug-reproduction, UI-verification-artifact, rule-applicability, AST-checker, and gate-failure-stop contract suites | All seven PASS. `evidence/verification.log` records exact commands, output, and exit 0 for all eight selected suites including the new one. |
| Shell syntax and Python compile checks | PASS for changed scripts and regression fixture. Python cache output was directed to `/private/tmp` for the sandbox. |
| Historical Sticker contracts checked with the repaired validator | Expected rejection of both `docs/current/emoji-sticker-library/UI_contract.md` and `docs/current/UI_contract.md`: “editable text input requires ## IME State Coverage”. |
| `git diff --check` | PASS. |

Consumer-dependent legacy suites ran through a temporary host layout whose `harness`, `.agents`,
and `android-agent-harness` links point to this repair worktree. Its product docs are read-only
links to the existing application docs; no tracker or slice status changed. The AST suite used
the consuming application's existing `DOCUMENTED_DYNAMIC_TAGS_REGISTRY`.

Broader optional profile checks retain existing baseline failures:

`evidence/baseline-profile-checks.txt` records their diagnostics and unchanged baseline inputs.

- Instruction budget: **23,379 bytes**, limit 23,000. All three L1 inputs are byte-identical to
  `origin/main`; this repair adds no L1 text.
- Description routing: the unchanged context-management skill lacks `UI Request Routing`,
  which the existing routing contract expects. The same mismatch exists on `origin/main`.

No application source, Android build configuration, or Android runtime gate changed, so Android
build/unit/coverage/device suites were not rerun for this harness-only repair. ARTEMIS was not used.

## Routed items and remaining risk

- The current application's complete editor IME designs and corresponding new contract metadata
  remain a product UI-design follow-up. This retrospective preserves the approved product and
  application implementation; the stronger gate will fail until that design inventory is repaired.
- The existing instruction-budget/routing mismatches are separate harness issues and are recorded
  above rather than hidden or fixed by unrelated edits.
- The editable-control inventory must still be reconciled with the actual Composables. A validator
  can enforce declared inputs and recognizable text/search controls, but cannot infer every
  arbitrarily named custom input. Source checks and JUnit XML establish minimum structural proof;
  reviewers must assess route equivalence, geometry assertions, approved full-screen exports, and
  current build/runtime fingerprint receipts.
- The runtime source checker deliberately supports the project's Compose Activity boundary and
  real root-window inset approach. Alternative test frameworks require an explicit harness
  extension and contract fixtures, not a warning-only bypass.
