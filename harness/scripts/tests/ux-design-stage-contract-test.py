#!/usr/bin/env python3
"""Contract-first UX planning: inventory before Pen, completed references before planning."""
import json
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
GATE = ROOT / "harness/scripts/check-stage-artifacts.sh"
CHECK = ROOT / "harness/scripts/check-ui-contract.py"


def run_gate(project, workflow, stage, artifacts, expected=None):
    result = subprocess.run(
        ["bash", str(GATE), workflow, stage, str(artifacts)],
        cwd=project, text=True, capture_output=True,
    )
    output = result.stdout + result.stderr
    if expected is None:
        assert result.returncode == 0, output
    else:
        assert result.returncode != 0, f"unexpected pass: {workflow}/{stage}"
        assert expected in output, output


with tempfile.TemporaryDirectory(prefix="ux-design-stage-") as temporary:
    project = Path(temporary)
    adhoc = project / "docs/current"
    feature = project / ".scratch/2026-10-25-feature"
    adhoc.mkdir(parents=True)
    feature.mkdir(parents=True)
    product = project / "docs/product"
    product.mkdir()
    (product / "design_system.md").write_text("# Design system\n")
    (product / "product.md").write_text(
        "<!-- HARNESS_TRACKER_START -->\n"
        "| ID | Feature | Workspace | Status | Updated | Notes |\n"
        "|---|---|---|---|---|---|\n"
        "| feature | Feature | [.scratch/2026-10-25-feature/](../../.scratch/2026-10-25-feature/) | Planning | 2026-10-25 | Fixture |\n"
        "<!-- HARNESS_TRACKER_END -->\n"
    )
    spec = "# Spec\n\n## Rule Applicability\n\n| Rule ID | Decision | Evidence |\n|---|---|---|\n"
    for rule in "ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC".split():
        spec += f"| {rule} | Required | fixture |\n"
    spec += (
        "\n## Screen States\n\n| Screen | State ID | Requirement | Acceptance Criteria |\n"
        "|---|---|---|---|\n| Editor | ready | FR-001 | AC-001 |\n"
    )
    (adhoc / "spec_v1.md").write_text(spec)
    (adhoc / "summary_v1.md").write_text("# Summary\n")
    (feature / "spec.md").write_text(spec)
    run_gate(project, "feature-delivery", "requirement-analysis", adhoc)
    run_gate(project, "harness-planning", "feature-specification", feature)

    contract = (
        "# UI Contract\nProject design system: `docs/product/design_system.md`\n\n## Screen States\n\n"
        "| Screen | State ID | Design source | Design node ID | Design node role | Design image | Viewport | Required regions | State controls | Runtime fixture | Comparison | Content difference | Plan stage |\n"
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
        "| Editor | ready | Pending | Pending | Pending | Pending | 430x932 | primary-content; state-controls; persistent-controls | Save button | ready-fixture | roborazzi | None | UI-01 |\n"
    )
    workflows = [("feature-delivery", adhoc), ("harness-planning", feature)]
    for workflow, artifacts in workflows:
        run_gate(project, workflow, "ui-contract", artifacts, "no file matching 'UI_contract.md'")
        (artifacts / "UI_contract.md").write_text(contract)
        # Inventory must pass before any Pen source, PNG, or design.md exists.
        run_gate(project, workflow, "ui-contract", artifacts)
        run_gate(project, workflow, "ux-design", artifacts, "pending design references")
        (artifacts / "UI_contract.md").write_text(contract.replace("| Editor | ready |", "| Editor | extra |"))
        run_gate(project, workflow, "ui-contract", artifacts, "UI contract states differ from spec")
        (artifacts / "UI_contract.md").write_text(contract.replace("| Save button |", "| Pending |"))
        run_gate(project, workflow, "ui-contract", artifacts, "unresolved state inventory")
        (artifacts / "UI_contract.md").write_text(contract)

    mixed_mode = subprocess.run(
        ["python3", str(CHECK), str(adhoc / "UI_contract.md"), "--inventory", "--plan", str(adhoc / "missing-plan.md")],
        text=True, capture_output=True,
    )
    assert mixed_mode.returncode != 0
    assert "--inventory cannot validate planning or runtime evidence" in mixed_mode.stdout + mixed_mode.stderr

    completed = contract.replace(
        "| Pending | Pending | Pending | Pending |",
        "| `design/source.pen` | ready-node | screen-frame | `design/mockup_ready.png` |",
    )
    for workflow, artifacts in workflows:
        (artifacts / "design").mkdir()
        (artifacts / "design/source.pen").write_text("opaque Pen fixture")
        (artifacts / "design/mockup_ready.png").write_bytes(
            b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 860, 1864)
        )
        (artifacts / "UI_contract.md").write_text(completed)
        run_gate(project, workflow, "ui-contract", artifacts)
    run_gate(project, "feature-delivery", "ux-design", adhoc)
    run_gate(project, "harness-planning", "ux-design", feature, "visual_evidence/visual-target.json")
    (feature / "visual_evidence").mkdir()
    manifest = {
        "version": 1, "target_id": "fixture", "appearance": "light", "device": "Pixel_6",
        "locale": "en-US", "logical_size_dp": {"width": 430, "height": 932},
        "states": {"ready": {"reference": "design/mockup_ready.png", "content_state": "Ready", "dynamic_regions": []}},
    }
    manifest_path = feature / "visual_evidence/visual-target.json"
    manifest_path.write_text(json.dumps(manifest))
    run_gate(project, "harness-planning", "ux-design", feature)
    manifest["states"]["other"] = manifest["states"].pop("ready")
    manifest_path.write_text(json.dumps(manifest))
    run_gate(project, "harness-planning", "ux-design", feature, "visual target states differ from UI contract")
    manifest["states"]["ready"] = manifest["states"].pop("other")
    manifest["states"]["ready"]["reference"] = "design/wrong.png"
    manifest_path.write_text(json.dumps(manifest))
    run_gate(project, "harness-planning", "ux-design", feature, "visual target reference differs from UI contract")
    manifest["states"]["ready"]["reference"] = "design/mockup_ready.png"
    manifest["logical_size_dp"]["width"] = 440
    manifest_path.write_text(json.dumps(manifest))
    run_gate(project, "harness-planning", "ux-design", feature, "visual target viewport differs from UI contract")
    manifest["logical_size_dp"]["width"] = 430
    manifest_path.write_text(json.dumps(manifest))
    (feature / "design/mockup_ready.png").unlink()
    run_gate(project, "harness-planning", "ux-design", feature, "missing or empty design PNG")

    # Downstream planning cannot bypass completed UX references.
    for name in ("implementation_plan_v1.md", "test_plan_v1.md"):
        (adhoc / name).write_text(
            "# Plan\nspec_v1.md#rule-applicability\n" +
            "".join(f"| {rule} | evidence |\n" for rule in "ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC".split())
        )
    (adhoc / "UI_contract.md").write_text(contract)
    run_gate(project, "feature-delivery", "implementation-plan", adhoc, "pending design references")
    (feature / "feature_list.json").write_text('{"features":[{"affects_ui":true}]}')
    (feature / "sprint-contract.md").write_text("# Contract\n")
    (feature / "progress.md").write_text("# Progress\n")
    (feature / "UI_contract.md").write_text(contract)
    run_gate(project, "harness-planning", "slice-planning", feature, "pending design references")
    assert (adhoc / "spec_v1.md").read_text() == spec
    assert (adhoc / "summary_v1.md").read_text() == "# Summary\n"
    assert (feature / "spec.md").read_text() == spec
    assert not list(project.rglob("design.md"))

    # Logic-only work does not acquire a UI-contract prerequisite.
    logic = spec.split("## Screen States")[0].replace("| SUI | Required |", "| SUI | Not applicable — no UI |")
    (adhoc / "spec_v1.md").write_text(logic)
    (feature / "spec.md").write_text(logic)
    for workflow, artifacts in workflows:
        (artifacts / "UI_contract.md").unlink()
        run_gate(project, workflow, "ui-contract", artifacts)
        run_gate(project, workflow, "ux-design", artifacts)

for workflow, requirements, planning in [
    ("feature-delivery", "Stage 1 — Requirement", "Stage 3 — Implementation Plan"),
    ("harness-planning", "Stage 1 — Clarify", "Stage 3 — Slice Planning"),
]:
    text = (ROOT / f".agents/workflows/{workflow}.md").read_text()
    assert text.index(requirements) < text.index("Stage 2 — UX Design") < text.index(planning)
    assert "ui-contract" in text
ux_skill = (ROOT / ".agents/skills/ux-design/SKILL.md").read_text()
assert "Do not create, version, or edit the spec or summary during visual iteration" in ux_skill
assert "contract before Pen" in ux_skill
assert "feature-design-template.md" not in ux_skill
assert "pen-design-editor" in ux_skill
spec_skill = (ROOT / ".agents/skills/feature-specification/SKILL.md").read_text()
assert "### 6. Generate Design" not in spec_skill
for skill in (ux_skill, spec_skill):
    description = next(line.removeprefix("description: ") for line in skill.splitlines() if line.startswith("description: "))
    assert 0 < len(description) <= 120, description
print("PASS: UI state inventory precedes Pen design; full UX and planning gates require completed references without design.md.")
