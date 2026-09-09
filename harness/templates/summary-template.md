# Change Summary — <Slice or Feature Title>

**Type**: feature / bugfix / api / refactor
**Started**: YYYY-MM-DD HH:MM
**Status**: In Progress / Complete
**Feature ID**: <US-X / Task ID>
**Workspace**: `<active workspace>`

## Stage Progress

Insert exactly one table from `harness/templates/summary-profiles/<workflow>.md`. Do not load or
copy inactive workflow profiles. A stage is complete only when its concise evidence appears below.

## Context Provenance

- Canonical requirements and Rule Applicability: `<path and section>`
- Canonical execution metadata: `<feature_list path and slice ID, or N/A>`
- Source hashes at stage start: `<requirements hash>`; `<execution metadata hash>`
- Rule decisions: unchanged unless an approved canonical update is linked.

Do not copy Rule Applicability, acceptance criteria, user-story scope, or feature metadata here.

## Key Decisions

- <Execution decision not already captured in the approved artifact>

## Knowledge Artifacts

- `<path>` — <relevance, or `None`>

## Open Items

- <Unresolved item or `None — all acceptance criteria verified.`>

## Stage Evidence

For each completed stage, cite the artifact or evidence path and one concise result line. Keep
verbose command output in its referenced log/report.

### <Stage>

- Artifact or command: `<path or exact command>`
- Result: `exit <code>`; `<test count/coverage/other required signal>`
- Evidence receipt: `<path, or N/A for non-command evidence>`

Static-quality evidence must include `bash harness/scripts/check-full-source-rules.sh` against the
complete repository source tree.

## Observability & Execution Metrics

Keep one authoritative machine-readable metrics block. Prose may summarize exceptional failures
or retries but must not duplicate every stage value.

```json:metrics
{
  "slice_id": "<US-X or task-id>",
  "model": "<Model Name>",
  "total_duration_sec": 0,
  "files_read_count": 0,
  "files_modified_count": 0,
  "commands_executed": 0,
  "first_pass_command_rate": 0,
  "gate_retries_total": 0,
  "gate_failure_causes": [],
  "tokens_estimated": 0,
  "stages": {
    "<stage-id>": {"duration_sec": 0, "retries": 0, "commands": 0}
  }
}
```
