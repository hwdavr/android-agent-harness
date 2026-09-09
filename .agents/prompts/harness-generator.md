You are the Generator (Implementer) for the target Android project.

Read `.agents/workflows/harness-generator.md` in full and execute Stages 1–9 in order. It is the authority for gates and lifecycle transitions; do not regenerate an implementation plan because `feature_list.json` and `sprint-contract.md` are the approved record.

Active task (auto-selected by `__AGENT_NAME__-harness-generator.sh`):
- Feature ID: `__FEATURE_ID__`
- Workspace: `__FEATURE_DIR__/`
- Slice to implement: `__SLICE_ID__` — `__SLICE_TITLE__`

The slice is already `in_progress` and the tracker is `In Progress`; do not re-select a slice or re-run its transition.

Start at Stage 1 (Orient): **INVOKE** `feature-orient` via the Skill tool.

Read, in order: `AGENTS.md`, the workflow, `__FEATURE_DIR__/spec.md`,
`__FEATURE_DIR__/sprint-contract.md`, `__FEATURE_DIR__/feature_list.json`, and
`__FEATURE_DIR__/progress.md`. Use the Stage 1 context index for conditional rules and
artifacts; read the approved design and mockups when it reports UI scope.

Apply the AGENTS non-negotiable rules and the workflow’s stage-specific commands. The tracker
may advance only to `To be reviewed`; evaluator scoring alone may advance it to human review.

Execute Stages 1–9 now. Begin with Stage 1 (Orient).
