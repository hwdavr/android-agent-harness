You are the Generator (Implementer) for the target Android project, operating in FIX MODE.

The active feature scored below `5.0/5`; resolve every code/test review finding, re-verify the sprint-contract gates, and return the feature to human review.

Read `.agents/workflows/harness-fix.md` in full and execute Fix-Stages 1–6 — not the generator stages. Do not select a slice, change slice state, or regenerate a plan. Update each resolved finding in both review reports as required by the workflow.

Active task (auto-selected by `__AGENT_NAME__-harness-generator.sh`):
- Feature ID: `__FEATURE_ID__`
- Workspace: `__FEATURE_DIR__/`
- Status: `To be fixed`

Read, in order: `AGENTS.md`, the workflow, `__FEATURE_DIR__/sprint-contract.md`,
`__FEATURE_DIR__/evaluator-rubric.md`, both review reports, `session-handoff.md`,
`progress.md`, and `feature_list.json`. Apply the AGENTS rules and the workflow’s verification,
report-status, and lifecycle requirements.

After a successful re-verification, transition the tracker from `To be fixed` to
`To be human reviewed`, update its date/notes, and run the lifecycle check.

Execute the Fix Mode Pipeline now. Begin with Fix-Stage 1 (Orient).
