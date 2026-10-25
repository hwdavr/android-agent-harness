---
name: feature-specification
description: Clarify product requirements and write an approved spec before the separate UX design stage.
---

# Skill — Feature Specification

Follow `.agents/rules/product-documentation.md`. Read affected `docs/product/requirements/<capability>.md` files and update those same files for behavior changes. Keep dated change contracts/evidence in `.scratch/`. New specs include `## Product Requirements` with capability links, changed requirements, and approval-time SHA-256 hashes. Completion reconciles verified behavior or records `Confirmed unchanged` for an already-correct bug contract.

## Purpose

Turn a general feature request into approved source artifacts:

- `docs/current/spec.md` — **always produced by ad-hoc workflows**
- `$FEATURE_DIR/spec.md` — the requirements output when invoked by `harness-planning`

The later UX Design stage defines `UI_contract.md` before creating Pen sources, visual-target manifests, and review
exports. This skill captures behavior and the required screen/state inventory without generating
visual designs or invoking `ux-design`/`pen-design-editor` inside requirements clarification.

This skill replaces both `screen-specification` and `requirement-capture`. It adapts its depth based on the task type:

| Task Type | `spec.md` | Later UX Design | Screen-specific spec sections |
|-----------|-----------|-----------------|-------------------------------|
| New screen or major UI flow | Full | Required | Include |
| Enhancement to existing screen | Full | Required if UI changes | Changed behavior/states only |
| Pure logic/behavior change | Full | N/A | Skip |

Do not plan implementation slices. Do not write code. Do not invent missing product decisions.
This skill ends only when every material question has been answered by the user and all artifacts contain no unresolved assumptions or open questions.

---

## Load

- `rules/android-architecture.md` (skip if already loaded this session — L1 is session-scoped)
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read
- `harness/templates/rule-applicability-template.md` as the conditional-rule trigger catalog
- Load the mapped conditional rule only after its row is `Required`, excepted, or
  newly triggered by inspected scope. For UI scope this includes
  `docs/product/design_system.md`, `rules/compose-rules.md`, and
  `rules/localization-rules.md`; the Compose keyboard/IME section applies to text input.
- `harness/templates/feature-spec-template.md`

---

## Execute

### 1. Capture The Raw Request

Read the user's request exactly as stated. Preserve concrete inputs as source-of-truth anchors, including:

- Named screens, tabs, entry points, and destinations
- User roles or audiences
- Provided screenshots, sketches, or mockups
- Required copy, labels, or product terminology
- Explicit non-goals

If the user provides a screenshot, mockup, or visual reference, save it unchanged under the active
artifact directory's `design/` folder and reference it from `spec.md` as an input for UX Design.
In `harness-planning`, the active artifact directory is `$FEATURE_DIR`.

### 2. Classify The Task Type

Before asking questions, determine the task type:

- **New screen**: No existing screen serves this purpose. Requires full `spec.md` and later UX Design.
- **Enhancement**: Adds or modifies behavior on an existing screen. Requires `spec.md` only (screen-specific sections only for changed parts).
- **Logic-only**: No UI changes. Requires `spec.md` only (skip all screen-specific sections).

State the classification to the user and confirm before proceeding.

#### Rule applicability decision

Before asking product questions, copy the complete matrix from
`harness/templates/rule-applicability-template.md` and decide every row. Use only
`Required`, `Not applicable — <feature-specific reason>`, or
`Exception — approved by <user/date>`. Record the trigger and evidence for required
rows. Assess analytics and observability explicitly; they do not require new events or
logs when their triggers are absent.

### 3. Ask Clarifying Questions In Chat

Ask targeted questions before writing the artifacts. Prefer 3–7 questions per round.
Questions must be concrete and answerable, not broad prompts like "anything else?"

**Surface assumptions first** — state what you are assuming about the request before asking about behavior; every assumption is a question until the user confirms it.

**Always cover:**
1. **User and goal**: who uses the feature, what they are trying to complete, and what success means.
2. **Expected behavior**: concrete, observable behaviors — each independently testable.
3. **Business rules**: constraints imposed by business logic.
4. **Scope boundaries**: what is explicitly out of scope for this version.

**Cover if new screen or enhancement with UI changes:**
5. **Entry and exit**: how the user reaches the screen/feature, what back/close/submit actions do, and where success/failure navigates.
6. **Core content**: exact data, sections, controls, copy, and required empty/loading/error states.
7. **Interactions**: taps, selection, editing, gestures, validation, confirmation, destructive actions, and disabled states.
8. **State and persistence**: local-only state, saved state, backend/API expectations, offline behavior, and configuration-change behavior.
9. **Visual inputs and constraints**: capture supplied references and product constraints for the
   later UX Design stage; settle layout, density, and styling during that separate stage.
10. **Accessibility and testing**: content descriptions, focus order, dynamic text, test tags, and verifiable acceptance criteria.

If an answer creates a new ambiguity, ask a follow-up. Continue until the requirement can be written without assumptions.

### 4. Zero-Ambiguity Gate

Before writing any artifacts, verify:

- [ ] Every material product decision is answered by the user.
- [ ] No unresolved assumptions are needed to describe the intended behavior.
- [ ] Scope boundaries and non-goals are explicit.
- [ ] Every user-visible state has a defined behavior (if UI is involved).
- [ ] Every destructive or irreversible action has a defined confirmation/recovery behavior.
- [ ] The user has confirmed the clarified scope is correct.
- [ ] Every rule-applicability row has a supported decision, rationale, and planned evidence.

If any item fails, ask more questions and do not write the artifacts yet.

### 5. Write the active `spec.md`

Use `harness/templates/feature-spec-template.md`.

The spec file must always describe:
- Objective and user goal
- Scope (in scope / out of scope)
- **Technical spec** (libraries & dependencies, key technical decisions, external APIs/services, platform constraints)
- Functional requirements with stable IDs
- Acceptance criteria with stable IDs
- Data and persistence requirements
- Edge cases and error states
- Explicit assumptions
- Open questions (all must be ✅ Answered)
- Verification expectations
- The complete **Rule Applicability** matrix, copied from the canonical template; this specification is the canonical record for downstream plans and reviews

**Outcome decomposition (one AC per named outcome):** Each functional requirement decomposes into acceptance criteria covering every distinct behavior its text promises — the happy path plus each fallback, error, boundary, and persistence/compatibility outcome. A single AC per FR is valid only when the FR names exactly one outcome. In particular, a requirement that promises *backward/forward compatibility* or *graceful fallback for missing/unknown input* must include a dedicated AC for each fallback path — a clean round-trip AC alone does not cover it.

**Conditional sections** (include only for new screen or enhancement with UI changes):
- Screen States table
- Navigation section
- Traceability to the later `UI_contract.md`

Do not include an "Open Questions" section with unresolved items. If there are unresolved items, return to Step 3 instead.

Update `spec.md` when a clarified answer changes behavior, scope, data, navigation, or the required
state inventory. Visual revisions stay in the later UX Design stage and do not rewrite the spec.

## Output

- Ad-hoc callers: `docs/current/spec.md` (use the active workflow's versioned name when required).
- Harness planning: `$FEATURE_DIR/spec.md`.
- Preserved user-supplied inputs, when present, referenced from the spec.

The spec owns product behavior, acceptance criteria, the complete Rule Applicability matrix,
and the required state inventory. The next UX Design stage owns visual artifacts.

## Done When — ⛔ MANDATORY STOP

- [ ] The spec contains every required section and no unresolved material product questions.
- [ ] Every rule has an explicit applicability decision, rationale, and planned evidence.
- [ ] UI scope has a behavioral screen/state inventory ready for UX Design.
- [ ] Supplied inputs are preserved and referenced.
- [ ] The user has approved the clarified specification.

**APPROVED by user →** Return to the active workflow: UX Design for UI scope, otherwise Slice Planning.
