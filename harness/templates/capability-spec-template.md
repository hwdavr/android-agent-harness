# Capability Spec Template

Use this format for every living capability file in `docs/product/requirements/<capability>.md`.
Adapted from OpenSpec main specs: the file states only delivered, verified behavior as testable
requirements with scenarios. Planned work lives in the change, never beside delivered behavior.

Writing rules:

- One file per stable product capability. The filename stem is the Capability ID.
- Each `### Requirement:` heading is `FR-### <Name>`. IDs are scoped to the file, never reused;
  a retired requirement is deleted, not renumbered.
- The first sentence uses SHALL and states one observable behavior (WHAT, never HOW): no
  classes, libraries, files, APIs, or test tags.
- Every requirement has at least one `#### Scenario:` headed `AC-### <name>`, written as
  **GIVEN** (optional) / **WHEN** / **THEN** / **AND** (optional) bullets. Scenarios are the
  acceptance tests that `test-plan.md` maps to evidence. Cover rejected and edge cases too.
- Behavior owned by another capability is cited (`[layers.md](layers.md#FR-###)`), not restated.
- Keep the headings exactly; tools parse `### Requirement:` and `#### Scenario:` to merge deltas.
- No `## Planned changes` section: undelivered scope lives in a change's `specs/` delta until
  `archive-change.py` merges it here.

---

```markdown
# <Capability title>

**Capability ID**: `<capability>`
**Updated**: YYYY-MM-DD

## User goal

<Why this capability exists, in one or two sentences.>

## Requirements

### Requirement: FR-001 <Name>
The app SHALL <one observable behavior>.

#### Scenario: AC-001 <short name>
- **GIVEN** <precondition>
- **WHEN** <user action or event>
- **THEN** <observable outcome>
- **AND** <additional outcome>

## References

- [Product index and lifecycle tracker](../product.md)
- [<change-id>](<../../../.scratch/<YYYY-MM-DD>-<change-id>/>) — change that delivered or last changed this capability.
```
