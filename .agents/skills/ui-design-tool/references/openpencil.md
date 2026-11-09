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

- **Structural**: compare `openpencil tree` / `query` output before and after; every unrelated
  screen and node ID is unchanged and new nodes have the intended parent. `openpencil lint
  <candidate.fig> --json` must report no new findings in the edited frames.
- **Visual**: `openpencil export <candidate.fig> --node <frame-id> -o <png>`, then view the PNG.
  Export at scale 1 so the PNG matches the frame's dp size (the Viewport in `UI_contract.md`).
- Re-read the candidate in a fresh command (for example `openpencil info <candidate.fig>`) to prove
  it still opens.

## Promote after approval

Replace the `.fig` source with the approved candidate, export the final screen-frames once more to
`design/mockup_<screen_state>.png`, and delete only the run's own candidate and temporary files.

## Not yet verified for this project

`openpencil convert` from the app's existing `UX/NotesApp.pen` to `.fig` has not been tested. Before
switching the project to OpenPencil, convert a copy, compare its `tree` and exports with the pen.dev
screens, and record the result; do not overwrite the `.pen` source.
