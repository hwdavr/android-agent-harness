# UI Contract — <feature>

**Project design system**: `docs/product/design_system.md`
**Related spec**: `spec_v<N>.md`

## Phase 0 — Research Decisions

- Existing runtime screens, controls, and state transitions inspected: <paths and observations>
- Open design questions resolved: <decision and evidence>
- Content comparability decision: <which states can use identical fixtures>

## Phase 1 — Design & Contracts

The inventory below is the UI contract. Each row is a separately reviewable design and later a
separate implementation capture. It replaces a broad `design.md` for ad-hoc UI workflows.

## Screen States

List every visually distinct screen and interaction state from the spec and the current runtime. Give each state its own Pen frame and exported image. A supplied approved image may use `external` as its node ID. Use one deterministic runtime fixture and one plan stage per row. `exact` means visible content matches the fixture; `structural` requires a concrete content difference below.

| Screen | State ID | Design source | Design node ID | Design image | Runtime fixture | Comparison | Content difference | Plan stage |
|---|---|---|---|---|---|---|---|---|
| <screen> | <screen-state> | `../UI_design/<file>.pen` | <Pen node ID> | `design/mockup_<screen_state>.png` | <fixture ID> | exact / structural | None / <visible difference> | UI-01 |

## State Details

### UI-01 — <screen-state>

- Entry action and selected controls: <how to reach this state>
- Visible content and fixed fixture values: <text, image, selection, locale, theme>
- Visual anchors and icon identities: <named static elements and relationships>
- Design-system exception: None / <explicit user approval>
- Pen export check: <render viewed, icon identities checked, no question-mark placeholders>

## Planning Handoff

Copy every Plan stage ID into the implementation plan's `## UI State Stages` table. Implementation and verification are separate steps for each state. Generate missing Pen frames before asking for design approval. Compare each runtime capture only to its mapped state image; run pixel comparison only for `exact` content.

## Verification Quickstart

1. Run `bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify reference-design docs/current` or the active feature-delivery requirement-analysis gate.
2. After plan approval, capture each runtime fixture from an instrumented test and record a state result for each row.
3. Run the active UI verification stage gate and review each state result against its design image.
