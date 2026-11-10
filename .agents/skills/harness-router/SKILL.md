---
name: harness-router
description: Route work in this Android notes project to its existing harness workflow or direct skill. Use for fixes, enhancements, UI changes, requirements, reviews, QA, regression checks, harness maintenance, or requests to resume work or choose the next step. Apply the consuming project's AGENTS.md and on-disk approval evidence; leave stage execution to the selected workflow. Skip unrelated general questions.
---

# Harness Router

Identify the user's outcome, select the existing project entry point, and continue at
the first incomplete stage supported by evidence. Keep routing thin: workflows own
stage order, role assignments, gates, approval stops, and completion criteria.

## Resolve project context

- Resolve every path below from the consuming application's repository root.
  `.agents/` and `harness/` may point into the shared `.harness/` submodule; this
  does not move application documentation into that submodule.
- Read the root `AGENTS.md`, `.agents/rules/android-architecture.md`, and
  `.agents/rules/testing-strategy.md` once per session. The consuming project's
  explicit routing instructions take precedence over a shared harness index.
- Use the conversation and affected living capability requirements under
  `docs/product/requirements/` to understand intent. Follow
  `.agents/rules/product-documentation.md` for requirement changes.
- For new features, enhancements, or changed scope, complete the scope check below
  before choosing between the direct UI lane, Feature Delivery, and Bug Fixing. A clearly worded outcome alone is
  insufficient. A routing decision does not grant implementation or acceptance approval.

## Check for a continuation

When the request resumes earlier work or asks what comes next, inspect the Harness Feature
Tracker in `docs/product/product.md`. Follow the workspace linked by the tracker, then inspect
its `summary.md`, `implementation-plan.md` (lane and Status), and — sliced lane —
`feature_list.json`, `tasks.md`, slice summaries, and review reports.
Load only the candidate work needed to identify the target.

- Continue the work clearly identified by the request and evidence. Ask which target
  the user means only when several candidates remain plausible.
- Before selecting tracked work, run
  `bash harness/scripts/check-feature-lifecycle.sh`. Failure blocks selection;
  report the inconsistency and use the harness-maintenance route for diagnosis.
- Use recorded status and approvals, rather than folder location, timestamps, or
  the mere existence of an artifact. `Blocked` means inspect the recorded blocker.
  Pending approvals or human review remain pending until their owning workflow's
  conditions are met. `Complete` is not authorization for another implementation.
- A clearly new request can proceed independently of unrelated open work. Preserve
  existing edits and evidence; do not replace an earlier workspace or summary.

## Clarify feature scope before classifying

For a new feature, enhancement, or scope change, establish these facts before
choosing Feature Delivery or Harness Planning. For unchanged approved work, reuse
the recorded scope rather than repeating discovery.

| Scope fact | Establish from the request, conversation, and focused repository inspection |
|---|---|
| Outcome and boundaries | What must the user be able to do end to end? What is excluded? |
| Journeys and states | Which existing or new flows and important states change? |
| Data and external dependencies | Does this affect persistence, migration, APIs, sync, permissions, or platform services? |
| Delivery dependencies | Is this one cohesive change, or does it need ordered, independently deliverable behaviors? |
| Verification | What observable result proves success, and which test/runtime boundaries are involved? |

Mark each fact as known with its source or unresolved. Inspect the relevant
requirements and code for technical facts; ask the user about product choices.
Do not ask the user to estimate file counts, architecture, or technical complexity.

If an unresolved fact could change the route, ask one to three focused questions
and wait for answers before final classification. Ask further questions only if the
answers expose another decision that affects routing. Tailor questions to the
request, for example: "Should this search only notes stored on this device, or also
server notes and attachments?" Explain briefly why that distinction affects scope.
Do not silently turn a missing answer into a small-feature assumption.

While awaiting answers, continue relevant read-only investigation. Report
"Route: undecided — scope clarification" and name the missing decision. Do not
create a feature workspace, transition the tracker, or launch delivery on a guessed
classification. If the user wants help defining the scope, select exploration or
Feature Delivery's Specify & Clarify stage explicitly for that purpose; it resolves the unknowns.

After the scope check, choose using the evidence:

| Route | Evidence supporting the choice |
|---|---|
| Direct UI lane: `android-ui-layer` | Appearance only (spacing, color, icon, copy wording, reorder, design-system alignment) on an existing screen; no new state, interaction, navigation, data, or API; an approved design or the design system already defines the target. |
| Feature Delivery | Any new or changed behavior. Its Specify stage fixes the lane: one deliverable change → single lane; two or more independently deliverable stories → sliced lane (harness generator). The router does not pre-decide the lane. |
| Bug Fixing | Observed behavior contradicts an existing requirement or expectation. |

Do not classify by prompt length, requirement counts, an assumed one-session
duration, or the user's word "small" alone. A new screen or API is a signal to
investigate, not an automatic size decision. State the selected route, the concrete
scope evidence supporting it, and relevant exclusions. If all facts are already
established, proceed without a redundant clarification or route-confirmation pause.
Workflow-level specification still follows; this check only chooses its owner.

## Select the entry point

Use an explicitly requested workflow when it fits the task and its prerequisites.
For ongoing work, keep its owning workflow unless the scope or recorded lifecycle
requires a handoff. Apply the root `AGENTS.md` if this map becomes stale.

| Intent | Workflow or direct skill to read in full |
|---|---|
| App bug, crash, regression, or unexpected behavior | `.agents/workflows/bug-fixing.md` |
| New feature or bounded enhancement | `.agents/workflows/harness-planning.md` |
| Appearance-only adjustment to an existing screen that passes the direct-lane entry check | `.agents/skills/android-ui-layer/SKILL.md` (direct lane; ends with the `ui-verification` conformance review) |
| UI implementation from a screenshot/mockup, or any UI change with new states or behavior | `.agents/workflows/harness-planning.md` (the mockup is the UX Design input) |
| Large feature with independently deliverable stories | `.agents/workflows/harness-planning.md` (Specify selects the sliced lane) |
| Implement an approved single-lane feature | `.agents/workflows/single-lane-generator.md` |
| Implement the next slice of an approved sliced-lane feature | `.agents/workflows/sliced-lane-generator.md` |
| Resolve sliced-lane evaluator findings; tracker status `To be fixed` | `.agents/workflows/harness-fix.md` |
| Independent review of a single-lane change | `.agents/workflows/feature-review.md` |
| Independent review of an implemented sliced-lane slice | `.agents/workflows/harness-evaluation.md` |
| Plan and execute post-merge feature acceptance | `.agents/workflows/feature-acceptance.md` |
| Explore an installed mobile app or run temporary QA scenarios/captures | `.agents/skills/exploratory-qa/SKILL.md`; use `.agents/skills/dogfood/SKILL.md` for UI-only exploration |
| Harness instructions, gates, templates, fixtures, or evidence repair | `.agents/skills/harness-retrospective/SKILL.md` |
| Product documentation or requirements edits without implementation | `.agents/skills/documentation-and-adrs/SKILL.md` and `.agents/rules/product-documentation.md`; return to the owning planning stage if an approved change contract is affected |
| Run existing checks without changing source | Use the named checks from `AGENTS.md` or the active contract; for static-analysis checks consult `.agents/skills/android-code-quality-checks/SKILL.md` |
| Explore an idea or compare options before committing to delivery | Clarify the outcome and discuss options; start Feature Delivery only when the user wants to proceed |

Treat "small" as a scope estimate, not permission to bypass an approval or gate.
Use the scope check above for the route; the lane is decided at Specify.

Distinguish app defects from desired behavior changes. A QA failure stays a finding
until fixing it is within the user's scope. Read-only checks and ephemeral QA do not
authorize source repairs or new maintained regression suites. Formal acceptance
retains its own test-plan approval; a generic request to test the app is not acceptance.

## Hand off and execute

Announce the outcome and selected entry point in one sentence, then continue without
an additional route-confirmation pause. Read the selected workflow or direct skill
in full before writing source. Invoke its current-stage skills through the exposed
skill mechanism; if unavailable, read their complete repository `SKILL.md` files
and record the unavailable interface in the stage evidence, as `AGENTS.md` permits.

Use the existing evidence locations rather than introducing a second status system:

| Evidence | Location |
|---|---|
| Living capability behavior | `docs/product/requirements/<capability>.md` |
| Lifecycle of every feature and bug fix, and workspace links | `docs/product/product.md` |
| Specification (feature block) | `## Planned changes` in the capability file |
| Plans, slices, reviews, summaries, and evidence | Tracker-linked `.scratch/<YYYY-MM-DD>-<feature-id>/` |
| Temporary QA captures, fixtures, reports, and cleanup | `.qa-artifacts/<run-id>/` |
| Delivered-change audit and reusable knowledge | `docs/changes/` and `docs/knowledge/` |

Resume only from valid evidence. Missing or stale prerequisites return to their
owning stage. Implementation requires the approved `implementation-plan.md` and
`test-plan.md` (Status Approved, block SHA-256 recorded); the sliced lane adds the approved
`tasks.md` and `feature_list.json`, without a duplicate plan. The direct UI lane requires
its entry check and the user's go-ahead. Keep required stage gates,
runtime boundaries, and independent review non-passing when their prerequisites
are unavailable. The router does not create substitute approvals or evidence.

After sliced-lane slice selection, generate the context index as required by `AGENTS.md`:
`bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"`.
Load stage-specific rules progressively; reconcile all ten Rule Applicability rows
in requirements, planning, and review through their existing template and skills.

## Re-route when evidence changes

If investigation changes scope, explain the new entry point and carry forward valid
artifacts. Revalidate affected contracts and approvals through their owning stages.
Do not reset the workflow because a gate failed, or shrink the route to bypass it.
`To be fixed` goes to `harness-fix`, rather than starting another generator slice.
When checks reveal a defect, report it and enter bug fixing only within authorized scope.

For instruction-file changes, present the exact protected file list and proposed
changes before editing, and obtain the approval required by `AGENTS.md`. Report
instruction conflicts and repair their authoritative sources through the prescribed
PR process; routing is not permission to rewrite rules automatically.

At a stage handoff, approval stop, blocker, or completion, finish with a brief status
and one concrete next action. Name the responsible party and the artifact or command:

```text
Status: <workflow/direct skill> · <current stage and result>
Done: <completed work supported by evidence>
Next: <user or agent> — <one action, or none when complete>
```

When no user decision is needed and work remains, continue working. Do not end the
turn solely to announce a route or ask permission already recorded for that scope.
