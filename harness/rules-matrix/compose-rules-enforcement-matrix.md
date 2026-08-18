# Compose Rules — Enforcement Matrix

Rules from [`compose-rules.md`](../../.agents/rules/compose-rules.md), categorised by how each is enforced.

**Legend**

| Badge | Meaning |
|---|---|
| 🤖 **Scripted** | [`check-compose-rules.sh`](../scripts/check-compose-rules.sh) or [`check-localization-rules.sh`](../scripts/check-localization-rules.sh) detects this automatically on every CI run |
| 🧠 **Evaluator** | AI code review can reliably identify this — pattern recognition, semantic understanding |
| 👁️ **Human** | Requires design judgement, visual inspection, or context that neither script nor AI can fully substitute |

A rule can carry more than one badge when layered enforcement is needed.

---

## Section 1 — Composable Responsibilities

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 1.1 | Composable receives `UiState` + callbacks as parameters | 🧠 Evaluator | — | AI reviews parameter signatures for data/callback split |
| 1.2 | Composable only renders state — no derived computation | 🧠 Evaluator | — | Requires semantic understanding of what counts as "transformation" |
| 1.3 | Callbacks called on interaction — Composable never calls ViewModel directly | 🤖 Scripted + 🧠 Evaluator | Check 4: `hiltViewModel()` / `viewModel()` inside `*Content` | Script catches direct hiltViewModel calls; AI catches subtler patterns |
| 1.4 | No use case or repository calls inside Composable | 🤖 Scripted + 🧠 Evaluator | Check 5: `Repository`/`UseCase`/`DataSource` pattern match | Script is heuristic; AI validates edge cases |
| 1.5 | No business logic or data transformation inside Composable | 🧠 Evaluator | — | Too semantic for a script; AI checks for sorting, filtering, formatting inside composable bodies |
| 1.6 | No hardcoded strings — must use `stringResource()` | 🤖 Scripted | `check-localization-rules.sh` / `.cmd` Checks 1–3 | Moved to localization script — compose script no longer owns this |
| 1.7 | No hardcoded colors — must use `LocalAppColors.current.<token>` | 🤖 Scripted | Check 2: `Color(0x...)` and named `Color.*` constants | `AppColors.kt` is excluded from the check |

---

## Section 2 — Stateless / Stateful Split Pattern

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 2.1 | Every screen must have a stateful wrapper (`*Screen`) and a stateless content composable (`*Content`) | 🧠 Evaluator | — | AI checks naming convention and that the pair exists |
| 2.2 | Stateful wrapper is the only place that calls `hiltViewModel()` / `collectAsStateWithLifecycle()` | 🤖 Scripted + 🧠 Evaluator | Check 4 | Script catches `hiltViewModel` in `*Content`; AI verifies `collectAsState` is not in content either |
| 2.3 | UI tests target `*Content`, not `*Screen` | 🧠 Evaluator | — | Checked during test review — not detectable in production source |

---

## Section 3 — Test Tags

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 3.1 | All interactive elements have `Modifier.testTag(...)` | 🤖 Scripted + 🧠 Evaluator | Check 3: files with interactive elements but no testTag | Script is file-level heuristic; AI audits at element level |
| 3.2 | Key content containers have `testTag` (note card, list items, empty/error states, loading indicators, navigation) | 🧠 Evaluator | — | Requires understanding of "key" — AI applies the rule contextually |
| 3.3 | testTag names are descriptive and stable (no `"btn"`, no `"button_${id}"`) | 🤖 Scripted + 🧠 Evaluator | Check 6: string interpolation in testTag | Script flags interpolation; AI flags non-descriptive names like `"btn"` |

---

## Section 4 — String Resources

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 4.1 | All user-visible text uses `stringResource()` | 🤖 Scripted | `check-localization-rules.sh` / `.cmd` Checks 1–3 | Owned by localization script |
| 4.2 | String resource keys follow `<screen>_<element>_<type>` naming convention | 🧠 Evaluator | — | Naming convention; AI verifies format at review time |

---

## Section 5 — Colors

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 5.1 | No `Color(0x...)` literals outside `AppColors.kt` | 🤖 Scripted | Check 2a | |
| 5.2 | No named `Color.*` constants (`Color.Red`, `Color.White`, etc.) outside `AppColors.kt` | 🤖 Scripted | Check 2b | |
| 5.3 | All colors accessed via `LocalAppColors.current.<token>` | 🧠 Evaluator | — | Script catches the negative (hardcoded); AI verifies the positive (token usage) |
| 5.4 | Color named by semantic purpose, not by value (`textSecondary` not `gray`) | 🧠 Evaluator | — | Naming intent requires human/AI judgement |
| 5.5 | New color added to **both** `LightAppColors` and `DarkAppColors` | 🤖 Scripted + 🧠 Evaluator | Verify both entries exist with grep | Script can check symmetry; AI confirms semantic pairing makes sense |

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
| 8.1 | Use `LazyColumn` instead of `Column` + `forEach` for lists | 🤖 Scripted | Check 7: `Column { ... .forEach {` | |
| 8.2 | Pass stable types as parameters to avoid unnecessary recompositions | 🧠 Evaluator | — | AI checks for `List<>`, `Map<>`, lambdas created inline that destabilise composition |
| 8.3 | Use `key()` in lazy lists when items have stable IDs | 🧠 Evaluator | — | AI verifies that `items()` / `itemsIndexed()` calls use a key lambda |
| 8.4 | Avoid creating lambdas inside the composable body — pass as parameters | 🧠 Evaluator | — | Script was too noisy (false positives on delegation); AI applies intent-level review |

---

## Enforcement Summary

| Category | Count | Rules |
|---|---|---|
| 🤖 Scripted only | 4 | 1.7, 5.1, 5.2, 8.1 |
| 🧠 Evaluator only | 12 | 1.2, 1.5, 2.1, 2.3, 3.2, 4.2, 5.3, 5.4, 6.2, 7.3, 8.2, 8.3 |
| 👁️ Human only | 0 | — |
| 🤖 + 🧠 Scripted + Evaluator | 6 | 1.3, 1.4, 2.2, 3.1, 3.3, 8.4 |
| 👁️ + 🧠 Human + Evaluator | 5 | 5.5, 6.1, 6.3, 7.1, 7.2 |
| 🤖 Scripted (via localization script) | 2 | 1.6, 4.1 |
| **Total rules** | **29** | |

> [!NOTE]
> No rule is **Human-only**. Every rule can be at least partially enforced by AI review. Rules marked 👁️ Human still benefit from human design review as a final sanity check — the AI coverage alone is not considered sufficient confidence.

---

## Script Coverage Map

The [`check-compose-rules.sh`](../scripts/check-compose-rules.sh) script currently covers:

| Script Check | Rules Covered |
|---|---|
| **Check 1** — `Color(0x...)` outside `AppColors.kt` | 1.7 · 5.1 |
| **Check 2** — Named `Color.*` constants outside `AppColors.kt` | 1.7 · 5.2 |
| **Check 3** — Files with interactive elements but no `testTag` | 3.1 |
| **Check 4** — `hiltViewModel()` / `viewModel()` in `*Content` composables | 1.3 · 2.2 |
| **Check 5** — `Repository`/`UseCase`/`DataSource` call inside `@Composable` | 1.4 |
| **Check 6** — String interpolation in `testTag` values | 3.3 |
| **Check 7** — `Column { ... .forEach {` pattern | 8.1 |

> [!NOTE]
> String-resource checks (rules 1.6 · 4.1) are now owned by [`check-localization-rules.sh`](../scripts/check-localization-rules.sh). See the [Localization Rules Enforcement Matrix](localization-rules-enforcement-matrix.md) for details.
