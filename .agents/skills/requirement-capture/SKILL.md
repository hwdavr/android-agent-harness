---
name: requirement-capture
description: Captures unambiguous product requirements and user goals from the user's prompt.
---

# Skill — Feature Requirement Capture

## Purpose

Capture a complete, unambiguous picture of the feature before any design or implementation work begins.
**Do not write any code. Do not design architecture. Do not slice tasks.**
This stage ends only when every open question has been answered by the user.

---

## Load
- `skills/spec-driven-development/SKILL.md`
- `harness/templates/requirement-summary-template.md`

---

## Execute

### 1. Read and Understand the Request

Read the user's feature request in full. Do not assume anything that is not explicitly stated.

### 2. Draft the Requirement Summary

Populate every section below. If a section cannot be filled from the available information, mark it with `⚠️ OPEN QUESTION` and add a numbered entry to the Open Questions section.

#### Sections to capture:

**Requirement Summary**
One paragraph. What is being built, end-to-end, in plain language.

**User Goal**
What does the user want to achieve? Write from the user's perspective.
_"As a [user type], I want to [action] so that [outcome]."_

**Expected Behavior**
A numbered list of concrete, observable behaviors. Each item should be independently testable.

**Business Rules**
Constraints imposed by business logic (e.g. "a note can only belong to one folder", "free users cannot create more than 10 notes").
If none, write: _None identified._

**Known Constraints**
Technical or platform constraints already known (e.g. "must support minSdk 24", "must not require network for offline mode").

**Non-Goals**
What is explicitly out of scope for this feature. Be specific.

**Explicit Assumptions**
Things assumed to be true that have not been confirmed. Each assumption is a risk — flag it.

**Open Questions**
Numbered list of questions that must be answered before implementation can begin.
Format each as:
```
Q1. <question>
   → Status: ⚠️ Unanswered / ✅ Answered: <answer>
```

---

### 3. Resolve All Open Questions

- Present the draft `requirement-summary.md` to the user.
- For each `⚠️ Unanswered` question, ask the user directly.
- Update the document with confirmed answers.
- **Do not advance to the next stage until every question is marked ✅ Answered.**

---

## Output

Write **`docs/current/requirement-summary.md`** following **`harness/templates/requirement-summary-template.md`** exactly.

**Save Design Screenshot**: If the user provides a design screenshot, mockup, or layout visual in their prompt, you **MUST** save the original design screenshot to **`docs/current/design/`** at this stage so that it is permanently preserved and can be referenced during Slice Planning and UI implementation.

---

## Done When — ⛔ MANDATORY STOP

**Present `requirement-summary.md` to the user and confirm:**

- [ ] Every section is filled — no `⚠️ OPEN QUESTION` or `⚠️ Unanswered` markers remain
- [ ] Original design screenshot saved to `docs/current/design/` (if UI changes are involved and mockup is provided)
- [ ] Expected behaviors are concrete and independently testable
- [ ] Non-goals are explicit (scope is bounded)
- [ ] All assumptions are listed and accepted by the user
- [ ] User has explicitly confirmed the document is correct

**Do not proceed to Slice Planning until the user approves this document.**

**APPROVED by user →** Return to the active workflow file and proceed to the Slice Planning stage.
