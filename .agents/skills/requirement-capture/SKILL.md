---
name: requirement-capture
description: Superseded by feature-specification — use that skill to capture and clarify requirements. Kept only so existing references resolve.
---

# Skill — Requirement Capture (superseded)

Requirement capture is now part of Specify & Clarify. **INVOKE** `feature-specification` instead.
It writes the requirement directly into the living capability file as a feature block under
`## Planned changes` (from `harness/templates/requirement-delta-template.md`), resolves every
`[NEEDS CLARIFICATION]` with the user, records the Clarifications log, and decides the delivery lane.

Supplied design screenshots or mockups are saved unchanged under
`.scratch/<YYYY-MM-DD>-<feature-id>/design/` for UX Design.

Do not write `requirement-summary.md`; that artifact and its template are retired.
