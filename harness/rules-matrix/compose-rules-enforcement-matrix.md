# Compose Rules — Enforcement Matrix

Rules from [`compose-rules.md`](../../.agents/rules/compose-rules.md), categorised by how each is enforced.

**Legend**

| Badge | Meaning |
|---|---|
| 🤖 **Scripted** | The shared Kotlin AST checker, invoked by [`check-compose-rules.sh`](../scripts/check-compose-rules.sh) or [`check-localization-rules.sh`](../scripts/check-localization-rules.sh), detects this automatically on every CI run |
| 🧠 **Evaluator** | AI code review can reliably identify this — pattern recognition, semantic understanding |
| 👁️ **Human** | Requires design judgement, visual inspection, or context that neither script nor AI can fully substitute |

A rule can carry more than one badge when layered enforcement is needed.

---

## Section 1 — Composable Responsibilities

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 1.1 | Composable receives `UiState` + callbacks as parameters | 🧠 Evaluator | — | AI reviews parameter signatures for data/callback split |
| 1.2 | Composable only renders state — no derived computation | 🧠 Evaluator | — | Requires semantic understanding of what counts as "transformation" |
| 1.3 | Callbacks called on interaction — Composable never calls ViewModel directly | 🤖 Scripted + 🧠 Evaluator | AST visitor: `hiltViewModel()` / `viewModel()` call nodes inside `*Content` | Script catches direct calls; AI catches subtler patterns |
| 1.4 | No use case or repository calls inside Composable | 🤖 Scripted + 🧠 Evaluator | AST visitor: repository/use-case/data-source call nodes in `@Composable` bodies | AI validates semantic edge cases |
| 1.5 | No business logic or data transformation inside Composable | 🧠 Evaluator | — | Too semantic for a script; AI checks for sorting, filtering, formatting inside composable bodies |
| 1.6 | No hardcoded strings — must use `stringResource()` | 🤖 Scripted | `check-localization-rules.sh` / `.cmd` AST visitors for calls, named arguments, and UI properties | Moved to localization script — compose script no longer owns this |
| 1.7 | No hardcoded colors — must use `LocalAppColors.current.<token>` | 🤖 Scripted | AST visitor: `Color(0x...)` and named `Color.*` references | `AppColors.kt` is excluded from the check |

---

## Section 2 — Stateless / Stateful Split Pattern

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 2.1 | Every screen must have a stateful wrapper (`*Screen`) and a stateless content composable (`*Content`) | 🧠 Evaluator | — | AI checks naming convention and that the pair exists |
| 2.2 | Stateful wrapper is the only place that calls `hiltViewModel()` / `collectAsStateWithLifecycle()` | 🤖 Scripted + 🧠 Evaluator | AST visitor: ViewModel call nodes in `*Content` | AI verifies `collectAsState` is not in content either |
| 2.3 | UI tests target `*Content`, not `*Screen` | 🧠 Evaluator | — | Checked during test review — not detectable in production source |

---

## Section 3 — Test Tags

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 3.1 | All interactive elements have `Modifier.testTag(...)` | 🤖 Scripted + 🧠 Evaluator | AST visitor: interactive call nodes in files without a `testTag` call node | The file-level invariant remains a conservative heuristic; AI audits individual elements |
| 3.2 | Key content containers have `testTag` (note card, list items, empty/error states, loading indicators, navigation) | 🧠 Evaluator | — | Requires understanding of "key" — AI applies the rule contextually |
| 3.3 | testTag names are descriptive and stable (no `"btn"`, no `"button_${id}"`) | 🤖 Scripted + 🧠 Evaluator | AST visitor: interpolated/concatenated/derived tag expressions plus registry-backed documentation | Script rejects every unregistered dynamic expression; AI flags non-descriptive static names like `"btn"` |

---

## Section 4 — String Resources

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 4.1 | All user-visible text uses `stringResource()` | 🤖 Scripted | `check-localization-rules.sh` / `.cmd` AST visitors for calls, named arguments, and UI properties | Owned by localization script |
| 4.2 | String resource keys follow `<screen>_<element>_<type>` naming convention | 🧠 Evaluator | — | Naming convention; AI verifies format at review time |

---

## Section 5 — Colors

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 5.1 | No `Color(0x...)` literals outside `AppColors.kt` | 🤖 Scripted | AST visitor: hexadecimal `Color` call nodes | |
| 5.2 | No named `Color.*` constants (`Color.Red`, `Color.White`, etc.) outside `AppColors.kt` | 🤖 Scripted | AST visitor: named `Color` reference nodes | |
| 5.3 | All colors accessed via `LocalAppColors.current.<token>` | 🧠 Evaluator | — | Script catches the negative (hardcoded); AI verifies the positive (token usage) |
| 5.4 | Color named by semantic purpose, not by value (`textSecondary` not `gray`) | 🧠 Evaluator | — | Naming intent requires human/AI judgement |
| 5.5 | New color added to **both** `LightAppColors` and `DarkAppColors` | 🧠 Evaluator | — | No reliable symmetry checker exists yet; evaluator verifies semantic pairing in the changed color models. |

---

## Section 6 — Component Extraction

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 6.1 | Reused UI structures extracted to `components/` | 👁️ Human + 🧠 Evaluator | — | Recognising structural duplication across screens requires visual/design context |
| 6.2 | Components with their own state or complexity extracted | 🧠 Evaluator | — | AI reviews for components that have grown too complex |
| 6.3 | One visual responsibility per component | 👁️ Human + 🧠 Evaluator | — | "Visual responsibility" is a design judgement call |

---

## Section 7 — State Hoisting

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 7.1 | State hoisted to the lowest common ancestor that needs it | 👁️ Human + 🧠 Evaluator | — | Requires understanding of full component tree — design judgement |
| 7.2 | State not hoisted higher than necessary | 👁️ Human + 🧠 Evaluator | — | Same — context-dependent |
| 7.3 | Avoid `remember` in `*Content` composables (keep them stateless for testability) | 🧠 Evaluator | — | AI checks for `remember {}` calls in `*Content` functions |

---

## Section 8 — Performance

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 8.1 | Use `LazyColumn` instead of `Column` + `forEach` for lists | 🤖 Scripted | AST visitor: `.forEach()` call nodes nested in a `Column` call node | |
| 8.2 | Pass stable types as parameters to avoid unnecessary recompositions | 🧠 Evaluator | — | AI checks for `List<>`, `Map<>`, lambdas created inline that destabilise composition |
| 8.3 | Use `key()` in lazy lists when items have stable IDs | 🧠 Evaluator | — | AI verifies that `items()` / `itemsIndexed()` calls use a key lambda |
| 8.4 | Avoid creating lambdas inside the composable body — pass as parameters | 🧠 Evaluator | — | Script was too noisy (false positives on delegation); AI applies intent-level review |

---

## Section 9 — Keyboard / IME Behavior

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 9.1 | When screen content (or a bottom sheet) has text input, the bottom toolbar must dismiss while the keyboard/IME is visible (never behind the keyboard; use `imePadding()` + `WindowInsets.isImeVisible`) | 👁️ Human + 🧠 Evaluator | — | Runtime/visual behavior — verified during runtime verification (does the bar dismiss?) and code review (insets + `isImeVisible` handling); script heuristics are too noisy |
| 9.2 | Tapping text input inside a bottom sheet must not dismiss the sheet — it stays open above the keyboard (only scrim tap / swipe-down / close action dismisses) | 👁️ Human + 🧠 Evaluator | — | Runtime/visual behavior — verified during runtime verification (does the sheet stay open when its field is focused?) and code review (`onDismissRequest` + `imePadding()` handling) |

---

## Enforcement Summary

| Category | Count | Rules |
|---|---|---|
| 🤖 Scripted only | 4 | 1.7, 5.1, 5.2, 8.1 |
| 🧠 Evaluator only | 15 | 1.1, 1.2, 1.5, 2.1, 2.3, 3.2, 4.2, 5.3, 5.4, 5.5, 6.2, 7.3, 8.2, 8.3, 8.4 |
| 👁️ Human only | 0 | — |
| 🤖 + 🧠 Scripted + Evaluator | 5 | 1.3, 1.4, 2.2, 3.1, 3.3 |
| 👁️ + 🧠 Human + Evaluator | 6 | 6.1, 6.3, 7.1, 7.2, 9.1, 9.2 |
| 🤖 Scripted (via localization script) | 2 | 1.6, 4.1 |
| **Total rules** | **32** | |

> [!NOTE]
> No rule is **Human-only**. Every rule can be at least partially enforced by AI review. Rules marked 👁️ Human still benefit from human design review as a final sanity check — the AI coverage alone is not considered sufficient confidence.

---

## Script Coverage Map

All Kotlin checks below are implemented as visitors over the shared structural AST
(`harness/scripts/kotlin_ast_checker.py`). Comments, string/character literals, and
unrelated nested text are not treated as Kotlin code.

The [`check-compose-rules.sh`](../scripts/check-compose-rules.sh) script currently covers:

| AST visitor | Rules Covered |
|---|---|
| Color call/reference nodes outside `AppColors.kt` | 1.7 · 5.1 · 5.2 |
| Interactive call nodes in files without a `testTag` call node | 3.1 |
| `hiltViewModel()` / `viewModel()` call nodes in `*Content` composables | 1.3 · 2.2 |
| Repository/use-case/data-source call nodes inside `@Composable` | 1.4 |
| Dynamic testTag expression nodes match documented registry entries | 3.3 |
| `.forEach()` call nodes nested in `Column` call nodes | 8.1 |

> [!NOTE]
> String-resource checks (rules 1.6 · 4.1) are now owned by [`check-localization-rules.sh`](../scripts/check-localization-rules.sh). See the [Localization Rules Enforcement Matrix](localization-rules-enforcement-matrix.md) for details.
