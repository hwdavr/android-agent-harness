---
description: Deliver an Android feature end-to-end through approved implementation, testing, and quality gates.
---

# Workflow: Feature Delivery

Read and follow [Product documentation flow](../rules/product-documentation.md). Load affected living capability requirements before scoping or reviewing this change. Dated complex-change contracts and evidence belong under `.scratch/`.

## When to use
- Use this workflow when you are acting as the **Generator** (Implementer) agent.
- Implementing a new feature
- Enhancing an existing feature
- Integrating a backend or API change

This workflow is for production-grade delivery — not quick prototyping.

---

## Core Principle

Do not jump directly into coding.
**The Implementation Plan must be approved before any code is written.**
**Every stage's skill must be invoked via the Skill tool — reading the SKILL.md manually is not a substitute.**
**Memory of prior approval does not bypass stages. Source of truth is on-disk artifacts in `docs/current/`. If an artifact is missing, re-run the stage via its skill.**

Pipeline: Clarify Requirements & Impact → UX Design → [Design Approval] → Plan → [Implementation Approval] → Implementation → Testing → Code Quality Fix → Product Document Update → Install App To Device

Use one active `v<N>` for the delivery. UX iterations update `UI_contract.md`, the
Pen candidate, and review exports. Keep the clarified spec stable unless behavior, scope, data,
navigation, or the required state inventory changes. Update the summary only at stage boundaries,
approval, or a blocker; do not create a spec/summary version for each visual revision.

---

## Stage Execution

### Stage 1 — Requirement & Impact Analysis
The specification must include the complete ten-row Rule Applicability matrix, and the
stage gate must reject missing or unsupported decisions.
**INVOKE** the `requirement-analysis` skill via the Skill tool (name: `requirement-analysis`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Clarify behavior, scope, data, navigation, edge cases, and the required screen/state inventory.
Resolve material product questions before UX begins. Preserve supplied images as inputs; visual
layout and exported references belong to Stage 2.

Output: `docs/current/spec_v<N>.md` and one `docs/current/summary_v<N>.md` with Context Provenance
and requirement-stage evidence. The summary links the spec's canonical Rule Applicability matrix.
Gate: requirements clear, impacted files identified, API classified, UiState/navigation behavior
defined. Run `bash harness/scripts/check-stage-artifacts.sh feature-delivery requirement-analysis`.
This gate requires no design document, Pen export, or UI contract.

---

### Stage 2 — UX Design ⛔ STOP FOR DESIGN APPROVAL
For UI scope, **INVOKE** `ux-design` through the available skill mechanism. If the Skill tool is
unavailable, read its repository `SKILL.md` and record that once in stage evidence.
Input: the clarified `spec_v<N>.md`, supplied visual inputs, and the project design system.
Logic-only scope records this stage N/A and proceeds to Stage 3.

First create `docs/current/UI_contract.md` from the clarified requirements. Define every UI state,
viewport, content/control inventory, fixture, and IME behavior before generating any Pen design.
Only the four design-reference fields may be `Pending`. Run
`bash harness/scripts/check-stage-artifacts.sh feature-delivery ui-contract` and resolve all
inventory gaps before invoking `pen-design-editor` with this contract as its input.

The actual visual design lives in the Pen file. Populate each contract row with its verified Pen
node and PNG as the design is rendered and inspected. No separate design.md is produced.
The editable Pen source and exports follow the Pen skill's validation/finalization contract.

Gate: `bash harness/scripts/check-stage-artifacts.sh feature-delivery ux-design` must exit 0.
Present the design and verified references and wait for explicit design approval. Iterate within
this stage for visual feedback. Return to Stage 1 only for a product requirement change; then
update the affected spec sections and revalidate the design. Record the summary row at stage
completion/approval, not on every edit. Design approval does not authorize implementation.

---

### Stage 3 — Implementation Plan ⛔ STOP
The implementation and test plans must link the canonical Rule Applicability record
and identify evidence for each `Required` row.
**INVOKE** the `implementation-plan` skill via the Skill tool (name: `implementation-plan`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: `docs/current/implementation_plan_v<N>.md` created; `docs/current/test_plan_v<N>.md` created; `docs/current/summary_v<N>.md` updated.
For UI changes, include a `## UI State Stages` table in the implementation plan with one implementation and verification step for each Plan stage ID in `UI_contract.md`.
Gate: Run `bash harness/scripts/check-stage-artifacts.sh feature-delivery implementation-plan` — must exit 0. **STOP — present plan to user. Do not proceed until user explicitly approves.**

---

### Stage 4 — Implementation (Data + Domain + UI)
**INVOKE** the `android-implementation` skill via the Skill tool (name: `android-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Feature delivery is implementation-first: implement the approved plan before the Testing stage.

Output: All required source files across Data, Domain, UI, or test-infrastructure layers created or modified;
`docs/current/summary_v<N>.md` updated with Implementation stage marked complete. Test-infrastructure changes must
keep fixture state in the test target and leave production ViewModels/repositories unaware of fixture selection.
Gate: `./gradlew assembleDebug` passes, all layer rules are satisfied, and UI changes conform to `docs/product/design_system.md` plus any explicit approved exception in `docs/current/UI_contract.md`.

---

### Stage 5 — Testing
**INVOKE** the `android-testing` skill via the Skill tool (name: `android-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Create or complete the approved tests against the implementation and verify them GREEN. Do not
introduce a separate feature-level RED/TDD stage.

Output: Unit tests, integration tests, loopback-boundary tests when required, and shared JSON scenarios created or
updated; `docs/current/summary_v<N>.md` updated with selected test commands, executed counts, and request-receipt evidence.
Gate: every related test selected by `android-testing` passes with a non-zero executed count; required instrumented boundaries pass on the declared runtime. Record the executed tests and any blocked required runtime in `docs/current/summary_v<N>.md`, then run `bash harness/scripts/check-stage-artifacts.sh feature-delivery testing docs/current`. Run `bash harness/scripts/check-journey-registry.sh --validate` and use `--run-one <journey-id>` for each affected registered journey. Repository-wide coverage is checked in Code Quality Fix and the full JVM suite in CI. For any claim that rich text or an inline formatting mark is visibly rendered, run `bash harness/scripts/check-rendered-output-contract.sh` for the named `*RoborazziTest` method and require `captureRoboImage()` against the approved Pen export; state-only marks and device screenshots are supplemental evidence.

---

### Stage 6 — Code Quality Fix
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Output: All violations resolved; `docs/current/summary_v<N>.md` updated with code quality results.
Gate: `ktlintCheck`, `detekt`, `lintDebug`, and all custom check scripts exit with code 0.

---

### Stage 7 — Product Document Update
Read the full affected capability files and compare their existing requirements and Planned changes with the approved delta, current implementation, and actual verification. Edit stale claims in place: replace obsolete current behavior and retire old IDs/counts/destinations; do not leave the old claim beside a new `Proposed v<N>` subsection. Keep only genuinely undelivered behavior or incomplete acceptance in Planned changes, and mark implemented-but-unverified behavior as blocked. Update the product index only where its navigation summary is stale; never change lifecycle status to imply acceptance.

In `docs/current/summary_v<N>.md`, add a `## Product Requirement Reconciliation` table with one row for each affected prior claim and these columns: `Capability file`, `Existing claim reviewed`, `Disposition`, `Current requirement location or retired status`, and `Evidence / qualification`. Quote an exact, concise prior excerpt. Use only `Replace`, `Retire`, `Retain`, or `Confirm unchanged`; cite evidence or the exact blocked condition. The checker rejects replaced/retired excerpts still present in the capability file and retained/unchanged excerpts that are missing. This review table supplements the in-place capability edits; it is not a substitute for them.

Record execution metrics in the summary and run:

```bash
python3 harness/scripts/check-product-docs.py --change-dir docs/current --summary docs/current/summary_v<N>.md
bash harness/scripts/check-feature-lifecycle.sh
bash harness/scripts/check-harness-metrics.sh --validate docs/current/summary_v<N>.md
```

Output: the same capability files contain current product intent and evidence references; the summary cites reconciliation and metrics evidence.
Gate: all commands exit 0 and review confirms the requirements match verified behavior.

---

### Stage 8 — Install App To Device
Install the completed debug build when the feature affects UI, requires instrumented/platform
verification, or the user explicitly requests installation. Otherwise record an explicit
non-runtime N/A.

**Actions**:
1. Install the app to every connected device and emulator:
    ```bash
    ./gradlew installDebug
    ```
2. Record the install command, connected device IDs, and exit status in `docs/current/summary_v<N>.md`.

Output: Debug app installed on every connected device and emulator.
Gate: when required, installation exits 0; failure or no connected device is blocked. Otherwise
the feature-specific N/A rationale completes the stage.

---

## Rollback Routes

| Failure | Return to |
|---------|-----------|
| Requirement or behavior change | Requirement & Impact Analysis |
| Visual design feedback | UX Design |
| Plan-only feedback | Implementation Plan |
| Compilation error | Implementation (Data + Domain + UI) |
| Selected test failure | Testing (fix implementation if needed, then re-test) |
| CI suite failure or coverage gap | Testing (fix implementation or add related tests, then rerun the failed gate) |
| Quality check violation | Code Quality Fix (fix root cause, re-run checks) |
| Install failure or missing connected device | Install App To Device |

---

## Human-in-the-Loop Confirmation Points

1. **After Requirement & Impact Analysis** — resolve material product questions before UX begins.
2. **After UX Design** — user approves the design and references for UI scope.
3. **After Implementation Plan** — user approves implementation plan *(mandatory always)*.
