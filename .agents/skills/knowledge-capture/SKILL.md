---
name: knowledge-capture
description: Records ADRs, post-mortems, and learnings after feature or bug resolution.
---

# Skill — Knowledge Capture

## Purpose
Record **only high-value institutional knowledge** that cannot be recovered from source code alone.
Source code is the source of truth for *what* the system does. This skill records *why* decisions were made, *what* traps exist, and *what* rules should be enforced permanently.

The article principle: "Every time you discover an agent has made a mistake, you take the time to engineer a solution so that it can never make that mistake again." (Mitchell Hashimoto)

---

## High-Value Filter — Apply Before Writing Anything

Before creating any document, ask: **"Would a skilled developer or agent lose significant time without this record?"**

| Document type | Write only if… |
|---|---|
| ADR | A deliberate architectural trade-off was made that is not obvious from the code |
| Past bug | The bug was non-obvious, hard to diagnose, systemic, or caused by a framework gotcha |
| Pitfall | A non-obvious anti-pattern is easy to stumble into again |
| Rule update | A coding constraint was followed that is not yet enforced by any existing rule |

**If the answer is "no" for every category → produce zero documents. That is the correct outcome.**

Do NOT record:
- Routine bugs (typos, simple null checks, obvious fixes)
- Decisions that are self-evident from reading the code
- Implementation details already visible in source
- Process steps or summaries that belong in `docs/current/`

---

## Load
- `docs/current/code_review_v<N>.md` (Code Review stage output)
- `docs/current/test_review_v<N>.md` (Test Review stage output)
- `docs/current/summary_v<N>.md` (full change history)

---

## Execute

### 1. Architecture decisions
**Qualifying question:** "Did this change require a deliberate architectural trade-off that is not obvious from reading the code?"

If yes → write an ADR in `docs/knowledge/architecture-decisions/` using that folder's README format.
If no → skip.

### 2. Past bugs
**Qualifying question:** "Would a skilled developer waste significant time diagnosing this same bug in the future without this record?"

If yes (non-obvious, hard-to-diagnose, systemic) → record in `docs/knowledge/past-bugs/<YYYY-MM-DD>-<slug>.md` using `harness/templates/regression-template.md`.
If no (routine typo, simple null-check, obvious fix) → skip.

### 3. Pitfalls
**Qualifying question:** "Would another developer or agent make the same mistake again without this knowledge?"

If yes → record in `docs/knowledge/pitfalls/<slug>.md`.
If no → skip.

### 4. Update rules if needed
**Qualifying question:** "Is there a constraint we followed in this change that should always be enforced but is not yet in any rule file?"

If yes → update the relevant `.agents/rules/<rule-file>.md`.
If no → skip.

### 5. Finalize docs/current/summary_v\<N\>.md
Update `docs/current/summary_v<N>.md` to mark all stages complete and record the final state:
```
## Change Summary — <name>

> *Ensure the Stage Progress table has all stages marked as ✅ Complete.*

## Knowledge Artifacts Produced
- <path> — <description>
(or "None — no high-value knowledge artifacts were warranted for this change.")
```

### 6. Mark Task Complete in Sliced Plan
If a sliced plan exists in `docs/current/progress.md`:
1. Find the task you just completed.
2. Update its progress status to ✅ Complete and set its completion date.

---

## Output

Zero or more of (zero is a valid and common outcome):
- `docs/knowledge/architecture-decisions/ADR-NNN-<title>.md`
- `docs/knowledge/past-bugs/<YYYY-MM-DD>-<slug>.md`
- `docs/knowledge/pitfalls/<slug>.md`
- Updated `.agents/rules/<rule-file>.md`
- Finalized `docs/current/summary_v<N>.md`
- Updated `docs/current/progress.md` (if a sliced plan is active)

---

## Done When

**This stage is complete when all of the following are true:**
- [ ] Every qualifying question was answered (even if every answer is "no — skip")
- [ ] Any qualifying ADR is recorded, or explicitly marked N/A
- [ ] Any qualifying bug record is written, or explicitly marked N/A
- [ ] Any qualifying pitfall is recorded, or explicitly marked N/A
- [ ] Any qualifying rule update is applied, or explicitly marked N/A
- [ ] `docs/current/summary_v<N>.md` is finalized with all stages marked ✅ Complete
- [ ] `docs/current/progress.md` updated to ✅ Complete (if a sliced plan is active)

**APPROVED →** Change is complete. Notify the user that the workflow pipeline is done.
