#!/usr/bin/env python3
"""Contract-first UX: the UI state inventory precedes Pen design, completed references and
registered components precede planning, and UX never edits the approved requirement block."""
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[3]
GATE = ROOT / "harness/scripts/check-stage-artifacts.sh"
RULES = ("ARCH", "IMPL", "TEST", "SUI", "L10N", "NAV", "API", "OBS", "ANL", "SEC")


def run_gate(project, stage, workspace, expected=None):
    result = subprocess.run(["bash", str(GATE), "harness-planning", stage, str(workspace)], cwd=project,
                            env={**os.environ, "HARNESS_PROJECT_ROOT": str(project)}, text=True, capture_output=True)
    output = result.stdout + result.stderr
    if expected is None:
        assert result.returncode == 0, output
    else:
        assert result.returncode != 0, f"unexpected pass: {stage}\n{output}"
        assert expected in output, output
    return output


def png(path, width, height):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + b"\xff\xff\xff" * width for _ in range(height))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


BLOCK = """<!-- feature: editor-save -->
### editor-save — Save from the editor

**Status**: Approved — user, 2026-11-09

#### Requirements

##### FR-001 — Save button (New)

Users MUST be able to save from the editor.

**Acceptance criteria**

- **AC-001**: Given an edited note, when Save is tapped, then the note is persisted.
SCREEN_STATES<!-- /feature: editor-save -->
"""
SCREEN_STATES = """
#### Screen States

| Screen | State ID | Requirement | Acceptance Criteria |
|---|---|---|---|
| Editor | ready | FR-001 | AC-001 |
"""
HEADER = ("| Screen | State ID | Design source | Design node ID | Design node role | Design image | Viewport | "
          "Required regions | State controls | Reused components | Runtime fixture | Plan stage |\n|" + "---|" * 12 + "\n")


def contract(design, components="`SaveButton`", state="ready"):
    return ("# UI Contract\n\nProject design system: `docs/product/design_system.md`\n\n## Screen States\n\n" + HEADER +
            f"| Editor | {state} | {design} | 430x932 | primary-content; state-controls; persistent-controls | "
            f"Save button enabled | {components} | ready-fixture | UI-01 |\n")


with tempfile.TemporaryDirectory(prefix="ux-design-stage-") as temporary:
    project = Path(temporary)
    workspace = project / ".scratch/2026-11-09-editor-save"
    (workspace / "design").mkdir(parents=True)
    (project / "docs/product/requirements").mkdir(parents=True)
    requirement = project / "docs/product/requirements/editor.md"
    requirement.write_text("# Editor\n\n## Planned changes\n\n" + BLOCK.replace("SCREEN_STATES", SCREEN_STATES))
    (project / "docs/product/design_system.md").write_text(
        "# Design System\n\n### Component Registry\n\n"
        "| Component | Pen component | Composable | Required testTag | Wraps Material |\n|---|---|---|---|---|\n"
        "| SaveButton | comp/save | ui/components/SaveButton.kt | save_button | Button |\n")
    (project / "docs/product/product.md").write_text(
        "<!-- HARNESS_TRACKER_START -->\n| ID | Feature | Workspace | Status | Updated | Notes |\n|---|---|---|---|---|---|\n"
        "| editor-save | Save | [.scratch/2026-11-09-editor-save/](../../.scratch/2026-11-09-editor-save/) | Planning | 2026-11-09 | ui |\n"
        "<!-- HARNESS_TRACKER_END -->\n")
    (workspace / "summary.md").write_text("# Summary\n")
    run_gate(project, "specify", workspace)
    approved_block = requirement.read_text()

    # Inventory before Pen: references may be Pending, components may be Pending.
    pending = "Pending | Pending | Pending | Pending"
    (workspace / "UI_contract.md").write_text(contract(pending, components="Pending"))
    run_gate(project, "ui-contract", workspace)
    run_gate(project, "ux-design", workspace, "has unresolved state inventory: Reused components")
    (workspace / "UI_contract.md").write_text(contract(pending))
    run_gate(project, "ux-design", workspace, "has pending design references")
    (workspace / "UI_contract.md").write_text(contract(pending, components="Pending", state="saved"))
    run_gate(project, "ui-contract", workspace, "UI contract states differ from spec")

    # Pen design complete: registered components required.
    (workspace / "design/editor.pen").write_text("Pen fixture")
    png(workspace / "design/editor-ready.png", 430, 932)
    complete = "design/editor.pen | ready-frame | screen-frame | design/editor-ready.png"
    (workspace / "UI_contract.md").write_text(contract(complete, components="`FancyButton`"))
    run_gate(project, "ux-design", workspace, "reuses unregistered components ['FancyButton']")
    (workspace / "UI_contract.md").write_text(contract(complete))
    run_gate(project, "ux-design", workspace)
    (workspace / "design/editor-ready.png").unlink()
    run_gate(project, "ux-design", workspace, "missing or empty design PNG")
    png(workspace / "design/editor-ready.png", 430, 932)

    # UX never rewrites the approved requirement block.
    assert requirement.read_text() == approved_block

    # Logic-only scope: UX stages are N/A.
    requirement.write_text("# Editor\n\n## Planned changes\n\n" + BLOCK.replace("SCREEN_STATES", ""))
    (workspace / "UI_contract.md").unlink()
    assert "N/A" in run_gate(project, "ui-contract", workspace)
    assert "N/A" in run_gate(project, "ux-design", workspace)

print("PASS: UX stages gate the inventory, completed Pen references, and registered components.")
