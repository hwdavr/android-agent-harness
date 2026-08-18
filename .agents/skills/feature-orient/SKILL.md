---
name: feature-orient
description: Orients the agent with the current sprint contract and active task state.
---

# Skill — Feature Orient

## Purpose

Gather complete session, requirement, and git context, establishing a single source of truth for the active feature scope.

---

## Load
- `skills/spec-driven-development/SKILL.md`
- `rules/android-architecture.md`
- `rules/api-contract-rules.md`
- `rules/navigation-rules.md`
- `rules/testing-strategy.md`

---

## Execute

Before making any changes or planning code, gather complete session and git context:

1. **Validate and select `FEATURE_DIR` first**: run `bash harness/scripts/check-feature-lifecycle.sh`, then read the Harness Feature Tracker in `docs/product/product.md`. Continue an `In Progress` product workspace, or select the approved `Awaiting implementation approval` product workspace. Stop if validation fails; never infer lifecycle state by scanning directories or start a second feature while one is `In Progress`.
2. **Read `$FEATURE_DIR/spec.md`** for the full functional requirements (`FR-*`), acceptance criteria (`AC-*`), edge cases, and technical decisions. The Spec Coverage Matrix in the sprint contract references these IDs — reading the spec first provides the detailed context behind each reference.
3. **Read `$FEATURE_DIR/sprint-contract.md`** for scope, the Spec Coverage Matrix mapping requirements to user stories, acceptance test cases, and verification commands.
4. **Read `$FEATURE_DIR/evaluator-rubric.md`** when present for final quality evidence and issues that require follow-up.
5. **Read active logs** in `$FEATURE_DIR/progress.md` (or the session logs).
6. **Run recent git history analysis** (`git log -n 5 --oneline`).
7. **Review prior knowledge** in `docs/knowledge/`:
   - Scan `docs/knowledge/architecture-decisions/` for ADRs relevant to the feature area (e.g. navigation, scoping, data layer patterns).
   - Scan `docs/knowledge/past-bugs/` for bugs that affected the same area or similar functionality.
   - Scan `docs/knowledge/pitfalls/` for known gotchas that could impact implementation.
   - Record any relevant findings in the summary file's **Knowledge Artifacts** section so they are visible throughout the session.
8. **Select the next task & initialize summary**:
   - Review `$FEATURE_DIR/feature_list.json` and select the highest-priority incomplete task (status `not_started`). Do not work on multiple tasks in parallel.
   - Update its status in `$FEATURE_DIR/feature_list.json` to `in_progress`, update the tracker row to `In Progress`, and run `bash harness/scripts/check-feature-lifecycle.sh` again before continuing.
   - Generate `$FEATURE_DIR/summary_{feature_id}.md` (where `{feature_id}` is the selected task's ID) following the template below. Refer to the feature spec and sprint contract to document baseline goals, scope, and acceptance criteria. Include relevant findings from step 7.

**`summary_{feature_id}.md` Template:**
```markdown
# Change Summary — {name}

**Type**: feature / bugfix / api / refactor
**Started**: YYYY-MM-DD HH:MM
**Status**: In Progress / Complete

## Stage Progress

| Stage | Status | Timestamp | Notes |
|-------|--------|-----------|-------|
| Orient | | | |
| Setup | | | |
| Verify Baseline | | | |
| Implement | | | |
| Test | | | |
| Fix | | | |
| Update State | | | |
| Clean Exit | | | |

## Key Decisions
<major decisions made during this change>

## Knowledge Artifacts
<ADRs, past-bug entries, or pitfall entries produced>

## Open Items
<anything deferred or unresolved>
```
