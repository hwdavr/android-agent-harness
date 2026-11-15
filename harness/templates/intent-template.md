# Intent Template (Specify + Clarify)

Write `intent.md` at the root of the change workspace `.scratch/<YYYY-MM-DD>-<feature-id>/`. It
captures what is wanted, why, and under which constraints, in the originator's terms. Requirement
deltas live in `specs/<capability>.md` (`spec-delta-template.md`); stories, flow, and screen states
live in `design.md` (`design-template.md`). Approval covers `intent.md`, `design.md`, and every
file in `specs/`; `implementation-plan.md` records each SHA-256, so a later edit requires
re-approval. The `**Status**` line is excluded from the hash.

Writing rules:

- Describe WHAT and WHY, never HOW: no libraries, classes, files, or APIs.
- Cite requirements with their capability: `drawing.md#FR-008`.
- Mark each open product decision as `[NEEDS CLARIFICATION: <question>]` under Open Questions
  (at most three open at a time). Move each answer to Clarifications; an `Approved` intent has none open.
- A bug fix that restores already-specified behavior writes no intent; it cites the violated
  `FR-###`/`AC-###` in `implementation-plan.md`.

---

```markdown
# <feature-id> — <Feature title>

**Author**: <originator>
**Status**: Draft / Clarified / Approved — <user, YYYY-MM-DD> / Archived — YYYY-MM-DD
**Input**: "<the user's request, verbatim>"

## Problem

<What can't be done today, or what causes pain.>

## Proposed Outcome

- <What better looks like: one bullet per user-visible change. Mark **BREAKING** changes.>

**Success criteria**

- **SC-001**: <measurable, technology-agnostic outcome>

## Affected Users and Systems

- **Users**: <who is affected and how>
- **Systems**: <screens, modules, services, contracts, by name; no implementation>

| Capability | Delta file | Change |
|---|---|---|
| `<capability>` | `specs/<capability>.md` | ADDED FR-###; MODIFIED FR-### |

## Constraints

- <Platform, privacy, performance, design-system, or compatibility limits>

**Out of scope**

- <explicit non-goal>

**Assumptions**

| # | Assumption | Risk if wrong |
|---|---|---|
| A1 | <assumption> | <impact> |

## Open Questions

None.

## Clarifications

### Session YYYY-MM-DD

- Q: <question asked> → A: <answer> (updated `<capability>.md#FR-###`)

## Review Checklist

- [ ] No open questions remain here, in `design.md`, or in `specs/`.
- [ ] The capability table matches the files in `specs/`.
- [ ] Success criteria are measurable and technology-agnostic.
- [ ] Scope and assumptions are explicit; no implementation details.
```
