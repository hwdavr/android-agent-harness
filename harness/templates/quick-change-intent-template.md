# Quick-Change Intent Template

Write `intent.md` at the root of `.scratch/<YYYY-MM-DD>-<change-id>/` for the
[`quick-change`](../../.agents/workflows/quick-change.md) lane. Keep it to one screen.
`harness/scripts/check-quick-change.sh` requires every heading below, `**Lane**: quick-change`,
a valid `**Kind**`, an Approved or Archived status, no unchecked entry-check box, and (behavior,
bug-fix) `RED:` and `GREEN:` runs under Tests. `archive-change.py` reads the `**Status**` line.

---

```markdown
# <change-id> — <short title>

**Lane**: quick-change
**Kind**: refactor / behavior / bug-fix / test-only
**Status**: Draft / Approved — <user, YYYY-MM-DD> / Archived — YYYY-MM-DD
**Input**: "<the user's request, verbatim>"

## Intent

<One to three sentences: what changes and why. bug-fix: root cause — triggered when <cond>, causing <behavior>.>

## Entry Check

- [x] Logic only (ViewModel/use case/mapper/domain/data logic); no `@Composable` changes
- [x] No new/changed screen, navigation, exposed UI state shape, Room entity/DAO/migration, DTO/API, permission, platform service, or analytics event
- [x] The kind's scenario rule holds
- [x] Bug fixes: a JVM unit test reproduces the defect (otherwise not applicable — tick)
- [x] At most 5 production Kotlin files change (test-only: none)

## Scenario Affected

<`<capability>.md#AC-###` (behavior: delta in `specs/<capability>.md`; bug-fix: violated scenario), or `None — refactor` / `None — test-only`>

## Files

- `<path>` — <what changes>

## Tests

- `<TestClass.testName>` — <scenario or preserved behavior it proves>
  - RED: <command → failing result> (behavior, bug-fix)
  - GREEN: <command → passing result>

## Result

<Filled after Stage 3: each gate command, exit code, and executed test count.>
```
