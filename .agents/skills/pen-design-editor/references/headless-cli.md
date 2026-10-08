# pen.dev headless CLI reference

Use this reference for a pen.dev editing task. The installed CLI and its `read_skill` content are
the live authority; this file records the stable operating contract without copying a versioned
CLI manual.

## Current sources

- Official CLI documentation: <https://docs.pen.dev/for-developers/pen-cli>
- Local command help: `pen interactive --help`
- Current in-session editing guidance: `read_skill()`, then
  `read_skill({ path: "execute.md" })` and `read_skill({ path: "pen-schema.md" })`

The official CLI documentation describes `execute`, `get_app_state`, and `read_skill` as the
default headless tools. It also documents `get_style`; tool availability can differ by CLI version
or app-connected mode, so enumerate and use only the tools the current headless session exposes.

## Start a safe headless session

For an existing source, start with distinct input and output paths:

```text
pen interactive --in input.pen --out candidate.pen
```

For a new document:

```text
pen interactive --out candidate.pen
```

Do not add `--app`; that connects to a GUI application and is outside this skill. Within the shell,
load the three dynamic instruction resources before selecting an `execute` operation. The official
workflow shows `save()` writing the active document to the declared output file.

## API discipline

`execute.md` is the authority for the exact input language, node references, query forms, response
shape, screenshot paths, and export options. It currently documents design operations including
`Get`, `Insert`, `Update`, `Delete`, `Move`, `Copy`, `Replace`, `TakeScreenshot`, and `Export`.
Copy the required syntax from that live document; do not infer fields, enum values, or parameter
names from this reference.

Use `pen-schema.md` to validate constructible node types and properties. Use `get_app_state()` for
document metadata and selection context, not as a substitute for hierarchy inspection. Save only
after the planned operation and its local inspection have succeeded.

## Persistent visual artifacts

For an exported final PNG, the current CLI documentation supports:

```text
pen --in candidate.pen --export review.png
```

Confirm that the expected file exists because an export error can be reported without a nonzero
process exit. View the PNG before recording visual verification. Prefer `execute` rendering for
in-session inspection and retain the exported PNG as the review artifact.

## Failure boundaries

If the CLI is absent, unauthenticated, fails to load the document, or its live instructions do not
support the planned operation, preserve the original file and report the failure. Never fall back
to modifying the `.pen` JSON or to app-connected interactive mode.
