---
description: Quick-change lane for a small logic-only ViewModel or domain change or refactor; one short record, user go-ahead, unit tests, and a fresh diff-only review.
---

# Workflow: Quick Change

A proportionate lane for small presentation- or domain-logic changes. It replaces
`harness-planning` + `single-lane-generator` + `feature-review` only when the entry check
passes; it never replaces `bug-fixing` or the direct UI lane.

Use `implementer` for stages 1–4 and a fresh `evaluator` for stage 5. If a fresh evaluator is
unavailable, keep the review pending; never self-review in its place.

Load only: root `AGENTS.md`, `.agents/rules/android-architecture.md`, the one affected living
capability file under `docs/product/requirements/` (when behavior changes), and the
`android-unit-test` skill. Do not load the router scope check, the Harness Feature Tracker,
`harness-planning`, or the plan/test-plan templates.

```text
Record + Entry Check ⛔ → Implement (RED→GREEN) → Gates → Fresh Review → Close
```

---

## Entry check

Every item must hold; otherwise stop and route to `harness-planning` (new or wider behavior)
or `bug-fixing` (behavior contradicts an existing requirement):

- [ ] Logic only, in existing ViewModel, use case, mapper, or domain classes; no `@Composable`
      file changes (appearance-only work uses `design-to-ui`).
- [ ] No new or changed screen, navigation, UI state shape exposed to Composables, persistence or
      migration, API/DTO, permission, platform service, or analytics event.
- [ ] Behavior effect is either **none** (refactor) or a change to **one** existing
      `AC-###` scenario of **one** capability.
- [ ] Not a defect fix (defects keep `bug-fixing`'s reproduction step).
- [ ] At most 5 production Kotlin files under `src/main/` change.

`harness/scripts/check-quick-change.sh` enforces the mechanical items; the rest are judged here
and recorded. If any item fails later during implementation, stop, set the record's lane note to
the new route, and hand off to that workflow, reusing `intent.md` as its intent input.

---

## Stage 1 — Record and go-ahead ⛔

1. Create `.scratch/<YYYY-MM-DD>-<change-id>/intent.md` from
   [`quick-change-intent-template.md`](../../harness/templates/quick-change-intent-template.md).
2. Behavior change: add `specs/<capability>.md` with a single `## MODIFIED Requirements` entry
   ([`spec-delta-template.md`](../../harness/templates/spec-delta-template.md)) carrying the one
   changed scenario. Refactor: no `specs/` folder; write `None — refactor` under Scenario Affected.
3. Show the user the record (entry check, intent, scenario, files, tests). ⛔ STOP for go-ahead.
4. On go-ahead set `**Status**: Approved — <user, YYYY-MM-DD>`. No tracker row is created.

Gate: `bash harness/scripts/check-quick-change.sh "$CHANGE_DIR"` exits 0.

## Stage 2 — Implement

- Behavior change: write or update the unit test for the changed scenario first and observe it
  fail (RED), then implement until it passes (GREEN). Record both runs under Tests.
- Refactor: existing tests stay unchanged and must pass before and after.
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
2. Re-checks the entry check against the diff; any failure is blocking and reroutes the change.
3. Runs the `android-code-review` skill on the diff, and confirms the changed scenario (or, for a
   refactor, unchanged behavior) is covered by an executed unit test.
4. Writes `$CHANGE_DIR/review.md`: `**Verdict**: PASS` or `**Verdict**: FAIL`, the reviewer, and
   findings with file:line. FAIL returns to Stage 2; the evaluator never fixes code.

## Stage 6 — Close

1. Behavior change: `python3 harness/scripts/archive-change.py "$CHANGE_DIR"` merges the delta into
   the living capability file and sets `intent.md` to `Archived`. Refactor: set
   `**Status**: Archived — YYYY-MM-DD` by hand.
2. Gate: `bash harness/scripts/check-quick-change.sh "$CHANGE_DIR" --complete` exits 0.
3. No `docs/changes/` entry and no tracker transition are needed.

```text
Status: quick-change · <stage and result>
Done: <evidence>
Next: <user or agent> — <one action, or none>
```
