# Requirement Delta Template (Specify + Clarify)

Use this template in the **Specify** stage of every lane that changes product behavior.
Paste the block below under `## Planned changes` of each affected living capability file in
`docs/product/requirements/<capability>.md`. The living file is the specification; the
dated feature workspace holds only the plan, tasks, test plan, slice contract, and evidence.

Writing guidelines (how to fill in this block; coding rules apply later, through the implementation plan's Rule Applicability):

- One block per feature per capability file. Use the same `<feature-id>` as the Harness
  Feature Tracker row and the `.scratch/<YYYY-MM-DD>-<feature-id>/` workspace.
- Keep the opening and closing markers exactly. The analyze gate hashes the text between them;
  `implementation-plan.md` records that SHA-256 at approval, so any later edit requires re-approval.
- IDs are scoped to the capability file and never reused: continue the file's `FR-###`,
  `AC-###`, and `SC-###` sequences. Cite them elsewhere as `<capability>.md#FR-###`.
- Each requirement declares its relation to delivered behavior: `New`, `Changes FR-###`, or
  `Retires FR-###`. Delivered requirements stay untouched under `## Requirements` until the
  Product Document Update stage reconciles them in place.
- Describe WHAT and WHY, never HOW. No libraries, classes, files, or APIs — those belong in
  `implementation-plan.md`.
- Mark every unresolved product decision inline as `[NEEDS CLARIFICATION: <question>]`
  (at most three open at a time). Resolve each in the Clarifications log; an `Approved`
  block must contain none.
- Bug fixes that restore already-specified behavior do not add a block; they cite the
  violated `FR-###`/`AC-###` in `implementation-plan.md`.

---

```markdown
<!-- feature: <feature-id> -->
### <feature-id> — <Feature title>

**Workspace**: `.scratch/<YYYY-MM-DD>-<feature-id>/`
**Created**: YYYY-MM-DD
**Status**: Draft / Clarified / Approved — <user, YYYY-MM-DD>
**Input**: "<the user's request, verbatim>"

#### User Scenarios *(sliced lane only — omit for a single-lane change)*

**Lane rule**: ask whether the change splits into two or more independently deliverable,
independently testable stories. If yes, write them here and the feature takes the `sliced` lane
(one generator/evaluator cycle per story). If no, omit this section entirely and the feature takes
the `single` lane (one pass, one approval). Never split or merge stories to steer the lane.
Story IDs become the `feature_list.json` slice IDs and the `tasks.md` phases.

##### US-1 — <Brief title> (Priority: P1)

<The user journey in plain language.>

**Why this priority**: <value and reason for its rank>
**Independent Test**: <how this story alone is verified and what value it delivers>
**Requirements**: FR-###, FR-###

##### US-2 — <Brief title> (Priority: P2)

<…>

**Why this priority**: <…>
**Independent Test**: <…>
**Requirements**: FR-###

#### Requirements *(mandatory)*

##### FR-### — <Requirement title> (New / Changes FR-### / Retires FR-###)

<System MUST … / Users MUST be able to … — one testable behavior.>

**Acceptance criteria**

- **AC-###**: Given <state>, when <action>, then <observable result>.
- **AC-###**: Given <fallback/error/boundary state>, when <action>, then <observable result>.

A requirement that promises several outcomes (happy path, fallback, error, boundary,
compatibility) needs one `AC-###` per outcome.

##### FR-### — <Requirement title> (New)

<System MUST … [NEEDS CLARIFICATION: retention period not specified]>

**Acceptance criteria**

- **AC-###**: Given <…>, when <…>, then <…>.

#### Key Entities *(include when data is involved)*

- **<Entity>**: <what it represents, key attributes, relationships — no storage details>

#### Edge Cases

- <boundary or error condition> → <required behavior and the AC-### that covers it>

#### Screen States *(include when the change has UI; remove otherwise)*

List every visually distinct screen and state. `UI_contract.md` uses the same pairs and adds
the registered design-system components each state reuses.

| Screen | State ID | Requirement | Acceptance Criteria |
|---|---|---|---|
| <screen> | <screen-state> | FR-### | AC-### |

#### Navigation *(include when a route, destination, or back stack changes)*

- **Entry**: <route or source screen>
- **Back/cancel**: <exact behavior>
- **Success**: <destination or state>
- **Error recovery**: <destination or state>

#### Success Criteria *(mandatory)*

Measurable, technology-agnostic outcomes.

- **SC-###**: <e.g. "A user can invite a collaborator in under 30 seconds">

#### Out of Scope

- <explicit non-goal>

#### Assumptions

| # | Assumption | Risk if wrong |
|---|---|---|
| A1 | <assumption> | <impact> |

#### Clarifications

##### Session YYYY-MM-DD

- Q: <question asked> → A: <answer> (updated FR-###/AC-###)

#### Review & Acceptance Checklist

- [ ] No `[NEEDS CLARIFICATION]` markers remain.
- [ ] Every requirement is testable and unambiguous; every outcome has its own `AC-###`.
- [ ] Sliced lane only: every user story is independently testable and lists its requirements.
- [ ] Success criteria are measurable and technology-agnostic.
- [ ] Scope boundaries and assumptions are explicit.
- [ ] No implementation details (libraries, classes, files, APIs).
- [ ] `Changes`/`Retires` relations name the affected delivered `FR-###`.
<!-- /feature: <feature-id> -->
```
