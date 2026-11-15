# Spec Delta Template (Specify + Clarify)

Write one `specs/<capability>.md` in the change workspace for each capability file the change
touches in `docs/product/requirements/`. The living capability file stays untouched until the
change is delivered; `harness/scripts/archive-change.py` then merges the delta into it.

Writing rules:

- Use only these sections, each at most once: `## ADDED Requirements`, `## MODIFIED Requirements`,
  `## REMOVED Requirements`. Keep the headings exactly; tools parse them.
- `### Requirement: FR-### <Name>`; the first sentence uses SHALL and states one observable
  behavior (WHAT, never HOW). Every ADDED or MODIFIED requirement has at least one
  `#### Scenario: AC-### <name>` with **GIVEN** (optional) / **WHEN** / **THEN** / **AND** bullets;
  one scenario per outcome (happy path, fallback, error, boundary).
- **ADDED**: continue the capability file's `FR-###` and `AC-###` sequences. IDs are never reused.
- **MODIFIED**: same `FR-###` as the delivered requirement, with the complete new text and all its
  scenarios (it replaces the whole requirement). Keep the `AC-###` of scenarios that remain.
- **REMOVED**: the heading plus a `**Reason**:` line.
- MODIFIED and REMOVED need the living file in `capability-spec-template.md` format; convert it
  first (behavior-preserving) when it still uses a status table.
- A new capability: add `# <Capability title>` and `**User goal**: <one sentence>` at the top.
- Mark open decisions `[NEEDS CLARIFICATION: <question>]`; none may remain at approval.

---

```markdown
# <Capability title> — delta

## ADDED Requirements

### Requirement: FR-### <Name>
The app SHALL <one observable behavior>.

#### Scenario: AC-### <short name>
- **GIVEN** <precondition>
- **WHEN** <user action or event>
- **THEN** <observable outcome>

## MODIFIED Requirements

### Requirement: FR-### <Name>
The app SHALL <complete updated behavior>.

#### Scenario: AC-### <short name>
- **WHEN** <action>
- **THEN** <outcome>

## REMOVED Requirements

### Requirement: FR-### <Name>
**Reason**: <why it is retired, and what replaces it>
```
