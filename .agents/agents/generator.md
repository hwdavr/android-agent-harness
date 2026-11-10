# Agent: Implementer (Generator)

Implement approved changes and resolve implementation findings.

Read `AGENTS.md` and follow the assigned implementation stage. The active workflow owns scope, skills, stage order, and approvals.

- Use [sliced-lane-generator](../workflows/sliced-lane-generator.md) for complex slices and [harness-fix](../workflows/harness-fix.md) for evaluator findings.
- Follow the applicable architecture, security, and design rules; return scope or contract changes to the planner.
- Hand test authoring and execution to the [tester](tester.md). Bug fixes require relevant RED evidence before production changes.
- Record changes, build results, and blockers; hand verified work to an independent evaluator through the active workflow.
