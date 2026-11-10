---
name: ui-design-tool
description: Drive the project's configured UI design tool (pen.dev or OpenPencil) to create, inspect, and edit screen designs.
---

# UI Design Tool

The single entry for design-file work. It does not design by itself: it reads the project's tool
choice and loads exactly one adapter, which owns every tool command.

## 1. Resolve the tool

Read `UX/design-tool.json` (format: `harness/templates/design-tool-config-template.json`):

| `tool` | `source` | Adapter |
|---|---|---|
| `pen.dev` | `*.pen` | [references/pen-dev.md](references/pen-dev.md) |
| `openpencil` | `*.fig` | [references/openpencil.md](references/openpencil.md) |

- Missing file, unknown `tool`, or a `source` whose extension does not match the tool: stop and ask
  the user which tool and source to use. Do not guess and do not fall back to another tool.
- A request that names a design file of the other tool's format (for example a `.fig` while the
  project is on pen.dev) is a tool switch: confirm with the user before using it.
- Load only the selected adapter. Never call one tool's commands on the other tool's file.

## 2. Contract every adapter honors

Whatever the tool, the run must:

1. **Confirm the tool is usable** (installed CLI, readable source). If not, stop and report; never
   substitute a GUI, raw-file editing, or invented commands.
2. **Inspect before editing**: record the hierarchy, reusable components, and the target's node ID;
   export a before image.
3. **Edit on a candidate copy**, minimally, preserving unrelated screens and shared components
   unless the user authorizes a shared change.
4. **Verify** structurally (pre/post node snapshots) and visually (export the affected screen-frame
   as PNG and view it). A check that cannot run is reported as unavailable, never as passed.
5. **Promote only after explicit user approval** of that exact candidate, then reopen the promoted
   source and render it once more.

## 3. Feature delivery

When invoked by `ux-design` (harness-planning Stage 2), require the `UI_contract.md` inventory gate
to pass first. For each contract state, create one top-level screen frame at the state's Viewport
from the design system's registered components, then fill the row: `Design source` (the configured
`source`), `Design node ID`, `Design node role` = `screen-frame`, and `Design image` (the PNG export
at `design/mockup_<screen_state>.png`). `check-ui-contract.py` accepts `.pen` and `.fig` sources.

## Report

The tool and adapter used, the source file and screen, node IDs and properties changed, local or
shared edit, structural and visual results, promoted source path, retained review PNGs, and any
unresolved limitation. Never claim a save, promotion, or verification that did not happen.
