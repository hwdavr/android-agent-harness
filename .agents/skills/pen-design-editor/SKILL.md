---
name: pen-design-editor
description: Create, inspect, and precisely edit pen.dev .pen design files with the headless pen.dev CLI. Use for new pen designs, adding screens, targeted layout or style edits, visual inspection, and before/after comparison; not for Android implementation alone.
---

# Pen Design Editor

Use this skill whenever the requested design source of truth is a `.pen` file. Perform all
design reads and edits through the pen.dev CLI in **headless interactive mode**; never require
the pen.dev desktop app or IDE extension, and never edit `.pen` JSON directly.

Read [the headless CLI reference](references/headless-cli.md) before starting an editing
session. It deliberately routes to CLI-provided instructions rather than freezing API syntax in
this skill.

## Trigger and scope

Apply for requests to create or inspect a pen.dev design, add a screen, change a named screen or
element, show an updated screen, or compare a design before and after an edit. Do not use an
AI-prompt generation run for a targeted edit when a deterministic `execute` operation can do it.

First resolve the source file. Use an explicit path from the request; otherwise discover
repository designs with `rg --files -g '*.pen'`. If several candidates remain or the requested
screen/element has more than one plausible node, show the candidates with their node IDs and ask
the user to disambiguate. Never mutate based only on an ambiguous name.

## Required session setup

1. Confirm the installed CLI with `pen interactive --help`. If `pen` is missing, cannot
   authenticate, or cannot start headless mode, stop and explain the limitation; do not substitute
   a GUI, raw-file editing, or invented commands.
2. For an existing design, select an adjacent, new candidate output path. Start exactly in
   headless mode: `pen interactive --in <original.pen> --out <candidate.pen>`. For a new design,
   omit `--in`. Do not pass `--app`.
3. At the start of every interactive session, load the current guidance in this order:
   `read_skill()`, `read_skill({ path: "execute.md" })`, and
   `read_skill({ path: "pen-schema.md" })`, then call `get_app_state()`.
   Treat those responses and the installed help as authoritative for this run. Use only the tool
   names, operation forms, and parameter syntax they confirm.

## Discover and inspect before changing anything

Use the documented `execute` `Get` form to record the document hierarchy, top-level screens,
reusable components, design variables, and the candidate target's parent/children and node ID.
Capture the current target screen/component through the documented `TakeScreenshot` or `Export`
operation before editing, and keep the resulting image as the before artifact.

For a target inside a component instance, determine from the inspected hierarchy whether it is an
instance and whether the requested change is local. Use a documented instance override for a
local change when available. Do not edit the component origin or any other shared component unless
the user explicitly authorizes a global component change.

Determine the smallest edit scope and state it before execution:

- Update node properties for text, color, visibility, spacing, position, or sizing.
- Insert a child for a new control or content block.
- Replace a subtree only when a property update or insertion cannot express the requested change.
- Insert a new top-level screen without altering existing screens.

Reuse existing variables, styles, components, dimensions, naming conventions, and layout patterns.
For a new screen, inspect comparable existing screens first and match their dimensions and design
language. Give every new node a descriptive, stable name.

## Execute incrementally

Use the current `execute.md` syntax for `Insert`, `Update`, `Delete`, `Move`, `Copy`, or `Replace`.
Make one coherent, minimal change at a time and re-read the affected node with `Get` after each
mutation. Do not reconstruct an existing screen to make a local edit. Do not delete, replace, or
move unrelated screens or nodes.

Save only to the candidate path with the interactive shell's documented `save()` command. The
original remains untouched while validation runs. Track every path created during the run (candidate
`.pen` files, temporary exports, before/after screenshots, and preview files) so cleanup can be
explicit and limited to this run.

## Verify before saving the final file

Perform both checks; neither is optional.

**Visual check:** render the affected screen or component using the documented `TakeScreenshot`
or `Export` operation. Ensure there is a PNG at a predictable review path (for example,
`<artifact-dir>/<screen>-after.png`); the documented `pen --in <candidate.pen> --export <png>`
form may be used after saving the candidate if it is needed to retain the export. Open that PNG
with Codex's image-viewing capability. Compare it against the before image when present and check
alignment, spacing, typography, clipping, colors, and consistency with the request. If it is not
actually viewable, report visual verification as failed or unavailable, never as passed.

**Structural check:** compare the pre-edit and post-edit `Get` snapshots, not a serialization-only
text diff. Verify that every original top-level screen remains unless deletion was requested;
unrelated node IDs and properties are unchanged; shared components are unchanged unless expressly
authorized; and new nodes have the intended parent. Reopen the candidate in a fresh headless
session and render/export it to prove it can be read again. Treat benign serialization changes as
different from a design change, but investigate any changed node outside the planned scope.

If either check reveals a defect, correct only the affected area in a new candidate pass and repeat
both checks. If validation cannot pass, preserve the original and candidate for diagnosis and do
not report success.

## Finalize after approval and report

Do not replace the source or delete any run artifacts before the user explicitly approves the
validated design. Until approval, preserve both the original source and the validated candidate so
the user can review or request another revision.

After explicit design approval:

1. Confirm the candidate still passes the structural and visual checks and that the approval refers
   to this exact candidate and screenshot.
2. Replace the original `.pen` source with the validated candidate. Use a safe file operation only
   after confirming the candidate exists; do not edit the `.pen` JSON or create a Git commit.
3. Reopen the promoted original in a fresh headless session and render the final approved screen.
   If promotion or this final reopen fails, preserve the original and candidate paths and report
   failure rather than deleting anything.
4. Delete only the run-owned intermediate paths recorded during this session (candidate copies,
   temporary exports, previews, and before/after artifacts that are not the approved review asset).
   Never use a broad wildcard or remove user-provided assets, unrelated designs, or the original
   source. Keep the final approved screenshot required by the active workflow and the promoted
   `.pen` source.

The original is recoverable through version control; do not create a backup file unless the user
explicitly requests one. Do not change any later workflow stage or approval gate.

When this skill is invoked from an Android design workflow, also place the verified PNG at the
active `design/mockup_<screen>.png` location and update the required `design.md` to reference the
canonical `.pen` source, exported review image, design-system decisions, and any approved
exceptions. After approval, the canonical `.pen` source is the promoted original path; the PNG is
the retained review artifact.

Report the target `.pen` file and screen, exact node IDs and properties added or changed, whether
the edit was local or shared, structural and visual verification results, the promoted source
path, retained screenshot path, cleaned intermediate paths, and any unresolved limitation. Do not
claim a save, promotion, cleanup, or verification succeeded when it did not.
