# Localization Rules — Enforcement Matrix

Rules from [`localization-rules.md`](../../.agents/rules/localization-rules.md), categorised by how each is enforced.

**Legend**

| Badge | Meaning |
|---|---|
| 🤖 **Scripted** | [`check-localization-rules.sh`](../scripts/check-localization-rules.sh) or Windows [`check-localization-rules.cmd`](../scripts/check-localization-rules.cmd) detects this automatically on every CI run |
| 🧠 **Evaluator** | AI code review can reliably identify this — pattern recognition, semantic understanding |
| 👁️ **Human** | Requires design judgement, visual inspection, or context that neither script nor AI can fully substitute |

A rule can carry more than one badge when layered enforcement is needed.

---

## Section 1 — String Resources Are Mandatory

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 1.1 | All user-visible text uses `stringResource()` — no raw string literals in `Text()` | 🤖 Scripted | Check 1: `\bText\s*\(\s*"` pattern match | |
| 1.2 | Composable parameters (`label=`, `title=`, `placeholder=`, `hint=`) use `stringResource()` | 🤖 Scripted | Check 2: `(label\|title\|placeholder\|hint)\s*=\s*"` | |
| 1.3 | Local UI label variables are not assigned raw string literals | 🤖 Scripted | Check 3: `val *Label/*Text/*Title/*Placeholder` = `"..."` | |

---

## Section 2 — Where to Define Strings

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 2.1 | All strings defined in `app/src/main/res/values/strings.xml` | 🧠 Evaluator | — | AI confirms no strings are defined in code-level constants or companion objects |

---

## Section 3 — Naming Convention

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 3.1 | String resource keys follow `<screen>_<component>_<type>` pattern | 🧠 Evaluator | — | AI reviews `strings.xml` additions at review time; naming intent cannot be reliably scripted |

---

## Section 4 — Plural Strings

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 4.1 | Count-dependent strings use `<plurals>` — not conditional string concatenation | 🧠 Evaluator | — | AI identifies `if (count == 1)` branches that format strings inline |
| 4.2 | Plural strings accessed via `pluralStringResource()` | 🧠 Evaluator | — | AI verifies the correct API is used at the call site |

---

## Section 5 — Dynamic Content

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 5.1 | Strings with runtime values use format arguments (`%s`, `%d`) in `strings.xml` | 🧠 Evaluator | — | AI reviews strings with dynamic parts to ensure format arguments are used, not string concatenation |
| 5.2 | Format arguments accessed via `stringResource(R.string.key, arg)` | 🧠 Evaluator | — | AI checks call sites for correct format-argument passing |

---

## Section 6 — Content Descriptions

| # | Rule | Enforcement | Script Check | Notes |
|---|------|-------------|-------------|-------|
| 6.1 | Non-text interactive elements (icons, image buttons) have `contentDescription = stringResource(...)` | 🤖 Scripted + 🧠 Evaluator | Check 4: `contentDescription\s*=\s*null` | Script catches explicit `null`; AI catches missing `contentDescription` entirely |
| 6.2 | `contentDescription` is never `null` on interactive icons | 🤖 Scripted | Check 4: `contentDescription\s*=\s*null` | |

---

## Enforcement Summary

| Category | Count | Rules |
|---|---|---|
| 🤖 Scripted only | 2 | 1.1, 1.2, 1.3, 6.2 |
| 🧠 Evaluator only | 7 | 2.1, 3.1, 4.1, 4.2, 5.1, 5.2 |
| 👁️ Human only | 0 | — |
| 🤖 + 🧠 Scripted + Evaluator | 1 | 6.1 |
| **Total rules** | **10** | |

> [!NOTE]
> No rule is **Human-only**. Every localization rule can be at least partially enforced by scripted regex or AI semantic review.  
> The naming convention (rule 3.1) and plural/format rules (4.x, 5.x) require AI review because they depend on understanding *intent* — a script cannot verify that a key name like `title` is wrong while `note_detail_title_label` is right without a full naming convention parser.

---

## Script Coverage Map

The [`check-localization-rules.sh`](../scripts/check-localization-rules.sh) script and Windows [`check-localization-rules.cmd`](../scripts/check-localization-rules.cmd) launcher currently cover:

| Script Check | Rules Covered |
|---|---|
| **Check 1** — `\bText\s*(\s*"` raw string literal in `Text()` | 1.1 |
| **Check 2** — `(label\|title\|placeholder\|hint)\s*=\s*"` in Composable params | 1.2 |
| **Check 3** — `val *Label/*Text/*Title/...` assigned a raw string | 1.3 |
| **Check 4** — `contentDescription\s*=\s*null` | 6.1 · 6.2 |
