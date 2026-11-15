# Quick-Change Intent Template

Write `intent.md` at the root of `.scratch/<YYYY-MM-DD>-<change-id>/` for the
[`quick-change`](../../.agents/workflows/quick-change.md) lane. Keep it to one screen.
`harness/scripts/check-quick-change.sh` requires every heading below, `**Lane**: quick-change`,
an Approved or Archived status, and no unchecked entry-check box. `archive-change.py` reads the
`**Status**` line.

---

```markdown
# <change-id> — <short title>

**Lane**: quick-change
**Status**: Draft / Approved — <user, YYYY-MM-DD> / Archived — YYYY-MM-DD
**Input**: "<the user's request, verbatim>"

## Intent

<One to three sentences: what changes and why, in product terms.>

## Entry Check

- [x] Logic only in existing ViewModel/use case/mapper/domain classes; no `@Composable` changes
- [x] No new/changed screen, navigation, exposed UI state shape, persistence, API/DTO, permission, platform service, or analytics event
- [x] Behavior effect is none (refactor) or one existing scenario of one capability
- [x] Not a defect fix
- [x] At most 5 production Kotlin files change

## Scenario Affected

<`<capability>.md#AC-###` — delta in `specs/<capability>.md`, or `None — refactor`>

## Files

- `<path>` — <what changes>

## Tests

- `<TestClass.testName>` — <scenario or preserved behavior it proves>; RED: <command → failing result>, GREEN: <command → passing result>

## Result

<Filled after Stage 3: each gate command, exit code, and executed test count.>
```
