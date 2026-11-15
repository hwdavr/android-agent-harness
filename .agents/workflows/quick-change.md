---
description: Quick-change lane for a logic-only change, refactor, small logic bug fix, or test-only change; one short record, user go-ahead, unit tests, and a fresh diff-only review.
---

# Workflow: Quick Change

A proportionate lane for small presentation-, domain-, or data-logic work. It replaces
`harness-planning` + `single-lane-generator` + `feature-review`, or `bug-fixing`, only when the
entry check passes; it never replaces the direct UI lane.

Use `implementer` for stages 1–4 and a fresh `evaluator` for stage 5. If a fresh evaluator is
unavailable, keep the review pending; never self-review in its place.

Load only: root `AGENTS.md`, `.agents/rules/android-architecture.md`, the one affected living
capability file under `docs/product/requirements/` (behavior or bug-fix kinds), and the
`android-unit-test` skill. Do not load the router scope check, the Harness Feature Tracker,
`harness-planning`, `bug-fixing`, or the plan/test-plan templates.

```text
Record + Entry Check ⛔ → Implement → Gates → Fresh Review → Close
```

---

## Kinds

| `**Kind**` | Use for | Scenario Affected | `specs/` |
|---|---|---|---|
| `refactor` | Restructure without behavior change | `None — refactor` | none |
| `behavior` | Change or add one scenario under one existing requirement | `<capability>.md#AC-###` | one MODIFIED delta adding at most one new `AC-###` |
| `bug-fix` | Restore an already-specified scenario whose root cause is in logic code | violated `<capability>.md#AC-###` | none |
| `test-only` | Add or fix tests; no production code | `None — test-only` | none |

## Entry check

Every item must hold; otherwise stop and route to `harness-planning` (new or wider behavior)
or `bug-fixing` (any other defect):

- [ ] Logic only, in ViewModel, use case, mapper, domain, or data-layer logic classes; no
      `@Composable` file changes (appearance-only work uses `design-to-ui`).
- [ ] No new or changed screen, navigation, UI state shape exposed to Composables, Room
      entity/DAO/database/migration, DTO or Retrofit API, permission, platform service, or
      analytics event.
- [ ] The kind's scenario rule above holds (a new requirement or a second scenario is not a quick change).
- [ ] Bug fixes only: a JVM unit test reproduces the defect; bugs needing a device, UI,
      navigation, IME, lifecycle, or Exploratory QA reproduction use `bug-fixing`.
- [ ] At most 5 production Kotlin files under `src/main/` change (`test-only`: none).

`harness/scripts/check-quick-change.sh` enforces the mechanical items; the rest are judged here
and recorded. If any item fails later, stop, note the new route in the record, and hand off,
reusing `intent.md` as that workflow's intent or bug-context input.

---

## Stage 1 — Record and go-ahead ⛔

1. Create `.scratch/<YYYY-MM-DD>-<change-id>/intent.md` from
   [`quick-change-intent-template.md`](../../harness/templates/quick-change-intent-template.md).
2. `behavior`: add `specs/<capability>.md` with a single `## MODIFIED Requirements` entry
   ([`spec-delta-template.md`](../../harness/templates/spec-delta-template.md)): the full
   requirement with its existing scenarios plus the one changed or new scenario.
3. `bug-fix`: state the root cause (triggered when <cond>, causing <behavior>) under Intent.
4. Show the user the record. ⛔ STOP for go-ahead. Then set
   `**Status**: Approved — <user, YYYY-MM-DD>`. No tracker row is created.

Gate: `bash harness/scripts/check-quick-change.sh "$CHANGE_DIR"` exits 0.

## Stage 2 — Implement

- `behavior` / `bug-fix`: the changed or violated scenario's unit test fails first, then passes;
  record both runs under Tests (`RED:` and `GREEN:`).
- `refactor`: existing tests stay unchanged and pass before and after.
- `test-only`: new or fixed tests pass; no production file changes.
- Follow `rules/implementation-rules.md`: no stubs, TODOs, or no-op branches.

## Stage 3 — Gates

```bash
bash harness/scripts/check-quick-change.sh "$CHANGE_DIR"
bash harness/scripts/check-full-source-rules.sh
./gradlew testDebugUnitTest ktlintCheck detekt assembleDebug
```

Gate: every command exits 0 and the unit-test run has a non-zero executed count. Record commands,
exit codes, and counts under `## Result`.

## Stage 4 — Hand off for review

Give the evaluator only: `$CHANGE_DIR`, the base ref, and the diff
(`git diff <base>...HEAD` plus working-tree changes). Do not pass implementation reasoning.

## Stage 5 — Fresh review

A fresh `evaluator` that did not implement or test the change:

1. Reads `intent.md` (and `specs/` if present) and the diff only.
2. Re-checks the entry check and kind against the diff; any failure is blocking and reroutes.
3. Runs the `android-code-review` skill on the diff, and confirms an executed unit test covers the
   changed scenario, the restored scenario, or (refactor) unchanged behavior.
4. Writes `$CHANGE_DIR/review.md`: `**Verdict**: PASS` or `**Verdict**: FAIL`, `**Reviewer**:`, and
   findings with file:line. FAIL returns to Stage 2; the evaluator never fixes code.

## Stage 6 — Close

1. `behavior`: `python3 harness/scripts/archive-change.py "$CHANGE_DIR"` merges the delta and sets
   `intent.md` to `Archived`. Other kinds: set `**Status**: Archived — YYYY-MM-DD` by hand.
2. Gate: `bash harness/scripts/check-quick-change.sh "$CHANGE_DIR" --complete` exits 0.
3. No `docs/changes/` entry and no tracker transition are needed.

```text
Status: quick-change · <stage and result>
Done: <evidence>
Next: <user or agent> — <one action, or none>
```
