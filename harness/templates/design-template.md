# Design Template (Specify + Clarify)

Write `design.md` at the root of the change workspace, for every lane. It owns the product design
of the change: the lane, user stories, flow, screen-state list, and product decisions. Technical
design (structure, data model, API, risks) belongs in `implementation-plan.md`; visual design
belongs in the design-tool source; `UI_contract.md` details each screen state listed here.

Writing rules:

- No implementation details: no classes, files, libraries, or storage.
- Cite requirements with their capability: `drawing.md#FR-008`.
- **Lane rule**: write user stories only when the change splits into two or more independently
  deliverable, independently testable stories; that is the `sliced` lane (one generator/evaluator
  cycle per story). Otherwise omit User Scenarios; that is the `single` lane. Never split or merge
  stories to steer the lane. Story IDs become the `feature_list.json` slice IDs and `tasks.md` phases.
- Remove sections marked *(include when …)* that do not apply. Keep Lane and Product Decisions.

---

```markdown
# <feature-id> — Design

**Lane**: single / sliced

## User Scenarios *(sliced lane only)*

### US-1 — <Brief title> (Priority: P1)

<The user journey in plain language.>

**Why this priority**: <value and reason for its rank>
**Independent Test**: <how this story alone is verified and what value it delivers>
**Requirements**: <capability>.md#FR-###, <capability>.md#FR-###

## Key Entities *(include when data is involved)*

- **<Entity>**: <what it represents, key attributes, relationships>

## User Flow and Navigation *(include when a route, destination, or back stack changes)*

- **Entry**: <route or source screen>
- **Back/cancel**: <exact behavior>
- **Success**: <destination or state>
- **Error recovery**: <destination or state>

## Screen States *(include when the change has UI)*

Every visually distinct screen and state. `UI_contract.md` uses the same pairs.

| Screen | State ID | Requirement | Acceptance Criteria |
|---|---|---|---|
| <screen> | <screen-state> | FR-### | AC-### |

## Product Decisions

| Decision | Chosen | Alternatives considered | Reason |
|---|---|---|---|
| <decision> | <choice> | <rejected options> | <why> |

## Review Checklist

- [ ] The lane matches the stories (none = single; two or more independent = sliced).
- [ ] Sliced lane: every story lists its requirements, and every ADDED/MODIFIED requirement belongs to a story.
- [ ] Every UI state the requirements imply is listed under Screen States.
- [ ] No implementation details.
```
