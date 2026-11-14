<!-- Loaded by ui-design-tool when UX/design-tool.json selects "openpencil". -->

# OpenPencil adapter

Design source: a Figma-format `.fig` file. All commands come from the installed
[`open-pencil` skill](../../open-pencil/SKILL.md) and `openpencil --help`; treat those as
authoritative for this run and use only commands they confirm.

## Setup

1. Confirm the CLI: `openpencil --help`. If missing, stop and report that `@open-pencil/cli` (and
   `@open-pencil/mcp` for app mode) must be installed with `bun add -g`; do not install it unasked.
2. Use **headless mode** (pass the `.fig` path) for every read, edit, and export. Use app mode (no
   file argument; the running editor) only when the user asks to work in the open OpenPencil app.
3. Work on a candidate copy next to the source (for example `UX/<App>.candidate.fig`); the
   original stays untouched until approval.

## Inspect

```bash
openpencil info  <candidate.fig>
openpencil pages <candidate.fig>
openpencil tree  <candidate.fig> --depth 3
openpencil find  <candidate.fig> --type COMPONENT          # reusable components
openpencil node  <candidate.fig> --id <node-id>            # target details
openpencil export <candidate.fig> --node <node-id> -o <artifact-dir>/<screen>-before.png
```

Map the design system's Component Registry to the file's `COMPONENT` / `COMPONENT_SET` nodes and
build screens from instances of them.

## Edit

Make each change with `eval` and the Figma Plugin API, writing to the candidate:

```bash
openpencil eval <candidate.fig> -w -c '<minimal Figma Plugin API change>'
```

- Load every font a text node uses (`figma.loadFontAsync`) before changing its text or styling.
- Change one coherent thing at a time; re-read the node with `openpencil node --id` after each.
- Do not edit a main component unless the user authorizes a shared change; use instance overrides.

## Verify

- **Normalize first**: inserting any node makes `eval -w` re-lay out the whole page (a new page:
  the whole document), so stale stored geometry in the source (e.g. auto-width text stored wider
  than its characters) changes on the first structural edit. Before editing, copy the source,
  `eval -w` add a probe frame, `eval -w` remove it, and confirm a second pass reports
  `changed: false`. If `diff files <source.fig> <baseline.fig>` reports changes, list them as
  pre-existing source normalization, obtain user approval, and promote the baseline to the source
  as its own change before building the candidate. Do not try to "repair" these layers in the
  candidate with `resize` (the next write relays them out again) or by fixing text sizing.
- **Structural**: compare the (normalized) source and freshly reopened candidate using
  `openpencil diff files <source.fig> <candidate.fig> --json` and persisted source-GUID
  inventories captured from each document. Every pre-existing unrelated saved layer must retain
  its source GUID, name, type, and parent source GUID; the structural diff must show no changes
  to unrelated layers. Inspect each allowed change and ensure new nodes have the intended parent.
  Scene-graph IDs displayed by OpenPencil may be generated afresh on load and are not a substitute
  for persisted source GUIDs. Resolve the actual candidate screen node IDs after the fresh reopen,
  ensure they are unique and valid, and record those IDs in the UI contract. If persisted source
  GUIDs, the structural diff, or their interpretation cannot be obtained, fail the check rather
  than assuming preservation. `openpencil lint <candidate.fig> --json` must report no new findings
  in the edited frames.
- **Visual**: `openpencil export <candidate.fig> --node <frame-id> -o <png>`, then view the PNG.
  Export at scale 1 so the PNG matches the frame's dp size (the Viewport in `UI_contract.md`).
- Re-read the candidate in a fresh command (for example `openpencil info <candidate.fig>`) to prove
  it still opens.

## Extract layout

```bash
python3 harness/scripts/design_adapters/openpencil_layout.py --source <source.fig> --node <frame-id> \
  --out <feature>/design/mockup_<screen_state>.layout.json
```

Read-only; fails if the CLI is missing or the node is not a top-level frame. Text box widths of
auto-width text may be stale in the source (see Verify → Normalize first); use text size, line
height, gaps, and paddings.

## Promote after approval

Replace the `.fig` source with the approved candidate, export the final screen-frames once more to
`design/mockup_<screen_state>.png`, and delete only the run's own candidate and temporary files.

## Not yet verified for this project

`openpencil convert` from the app's existing `UX/NotesApp.pen` to `.fig` has not been tested. Before
switching the project to OpenPencil, convert a copy, compare its `tree` and exports with the pen.dev
screens, and record the result; do not overwrite the `.pen` source.
