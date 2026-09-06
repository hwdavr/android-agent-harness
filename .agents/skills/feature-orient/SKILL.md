---
name: feature-orient
description: Orients the agent with the current sprint contract and active task state.
---

# Skill — Feature Orient

## Purpose

Gather complete session, requirement, and git context, establishing a single source of truth for the active feature scope.

---

## Load

At a new session, load L1: `rules/android-architecture.md`,
`rules/implementation-rules.md`, and `rules/testing-strategy.md`.

After selecting the slice, run `bash harness/scripts/print-context-index.sh
--feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"`. Load a conditional rule only
when the generated index lists it as `Required` or an approved exception. Load
`docs/product/design_system.md`, `design.md`, and mockups only when `affects_ui` is
true. The index is derived from the approved contract; it does not replace it.

---

## Execute

This is a gated spec-driven workflow: `$FEATURE_DIR/spec.md` (Phase 1: Specify) and `$FEATURE_DIR/sprint-contract.md` (Phase 2: Plan) are already user-approved. Orient to them — never re-open approved requirements or re-plan the sprint contract. The sprint contract's acceptance tests and gates are the plan's verification checkpoints; the active slice's `acceptance_test_ids` and `verification` commands are where this session proves completion.

Before making any changes or planning code, gather complete session and git context:

1. **Validate and select `FEATURE_DIR` first**: run `bash harness/scripts/check-feature-lifecycle.sh`, then read the Harness Feature Tracker in `docs/product/product.md`. Continue an `In Progress` product workspace, or select the approved `Awaiting implementation approval` product workspace. Stop if validation fails; never infer lifecycle state by scanning directories or start a second feature while one is `In Progress`.
2. **Select the slice, then generate the context index**: read the selected slice in `$FEATURE_DIR/feature_list.json`, run `bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"`, and retain its source hashes. Read only the `FR-*` / `AC-*` rows mapped to that slice, the selected user-story section, and the matching acceptance rows in `$FEATURE_DIR/spec.md` and `$FEATURE_DIR/sprint-contract.md`.
3. **Read `$FEATURE_DIR/evaluator-rubric.md`** only when it names unresolved findings for the selected slice.
4. **Read active logs**: start with the latest relevant entry in `$FEATURE_DIR/progress.md` (or session logs); expand only when it names an unresolved dependency or blocker.
5. **Run recent git history analysis** (`git log -n 5 --oneline`).
6. **Review prior knowledge** in `docs/knowledge/`:
   - Search titles and metadata for the selected feature area, affected components, and required-rule IDs first.
   - Open only matching ADRs, past bugs, and pitfalls; do not preload entire knowledge directories.
   - Record any relevant findings in the summary file's **Knowledge Artifacts** section so they are visible throughout the session.
7. **Select the next task & initialize summary**:
   - Review `$FEATURE_DIR/feature_list.json` and select the highest-priority incomplete task (status `not_started`). Do not work on multiple tasks in parallel.
   - Update its status in `$FEATURE_DIR/feature_list.json` to `in_progress`, update the tracker row to `In Progress`, and run `bash harness/scripts/check-feature-lifecycle.sh` again before continuing.
   - Generate `$FEATURE_DIR/summary_{feature_id}.md` from `harness/templates/summary-template.md`. Its **Context Provenance** section must cite the approved `sprint-contract.md`, `feature_list.json`, the selected slice, and the generated index hashes. Do not repeat the Rule Applicability matrix, scope, acceptance criteria, or feature-list metadata.
