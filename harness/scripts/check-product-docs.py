#!/usr/bin/env python3
"""Validate capability documentation and the product/scratch ownership boundary."""

import argparse
from pathlib import Path
import re
import sys

RECONCILIATION_COLUMNS = [
    "Capability file",
    "Existing claim reviewed",
    "Disposition",
    "Current requirement location or retired status",
    "Evidence / qualification",
]
RECONCILIATION_DISPOSITIONS = {"Replace", "Retire", "Retain", "Confirm unchanged"}


def fail(message):
    raise ValueError(message)


def table_cells(line):
    return [cell.strip().strip("`") for cell in line.strip().strip("|").split("|")]


def normalize_claim(value):
    return re.sub(r"\s+", " ", value).strip().casefold()


def check_requirement_reconciliation(root, summary):
    summary_path = summary if summary.is_absolute() else root / summary
    summary_path = summary_path.resolve()
    if not summary_path.is_relative_to(root):
        fail("requirement reconciliation summary must belong to the consuming repository")
    if not summary_path.is_file():
        fail(f"missing requirement reconciliation summary: {summary_path}")

    text = summary_path.read_text()
    match = re.search(
        r"^## Product Requirement Reconciliation\s*\n(.*?)(?=^## |\Z)",
        text,
        re.M | re.S,
    )
    if not match:
        fail(f"{summary_path.name}: missing '## Product Requirement Reconciliation' section")

    table = [line for line in match.group(1).splitlines() if line.strip().startswith("|")]
    if len(table) < 3 or table_cells(table[0]) != RECONCILIATION_COLUMNS:
        fail(f"{summary_path.name}: reconciliation table must use the required five columns")

    requirements_dir = (root / "docs/product/requirements").resolve()
    seen_claims = set()
    valid_rows = 0
    for line in table[2:]:
        cells = table_cells(line)
        if len(cells) != len(RECONCILIATION_COLUMNS):
            fail(f"{summary_path.name}: malformed requirement reconciliation row")
        capability_ref, existing_claim, disposition, current_location, evidence = cells
        capability_path = (root / capability_ref).resolve()
        if (
            not capability_ref.startswith("docs/product/requirements/")
            or not capability_path.is_relative_to(requirements_dir)
            or not capability_path.is_file()
            or capability_path.name == "README.md"
        ):
            fail(f"{summary_path.name}: unknown capability in reconciliation table: {capability_ref}")
        if disposition not in RECONCILIATION_DISPOSITIONS:
            fail(
                f"{summary_path.name}: unsupported reconciliation disposition '{disposition}' "
                f"for {capability_ref}"
            )
        if len(existing_claim) < 8 or len(current_location) < 8 or len(evidence) < 12:
            fail(f"{summary_path.name}: each reconciliation row needs the prior claim, disposition, current location, and evidence/qualification")
        if disposition == "Confirm unchanged" and not re.search(r"\b(reason|because|confirmed)\b", evidence, re.I):
            fail(f"{summary_path.name}: Confirm unchanged requires its reason in Evidence / qualification")
        claim_key = (capability_ref, existing_claim.lower())
        if claim_key in seen_claims:
            fail(f"{summary_path.name}: duplicate prior claim in reconciliation table: {capability_ref}")
        seen_claims.add(claim_key)
        capability_text = re.sub(r"\s+", " ", capability_path.read_text()).casefold()
        prior_claim = normalize_claim(existing_claim)
        if disposition in {"Replace", "Retire"} and prior_claim in capability_text:
            fail(f"{summary_path.name}: stale claim marked {disposition} still appears in {capability_ref}: {existing_claim}")
        if disposition in {"Retain", "Confirm unchanged"} and prior_claim not in capability_text:
            fail(f"{summary_path.name}: claim marked {disposition} is absent from {capability_ref}: {existing_claim}")
        valid_rows += 1

    if valid_rows == 0:
        fail(f"{summary_path.name}: reconciliation table must contain at least one claim row")


def check(root, change_dir=None, summary=None):
    product = root / "docs/product"
    requirements = product / "requirements"
    index = product / "product.md"
    if not index.is_file() or not (requirements / "README.md").is_file():
        fail("product index and requirements/README.md are required")
    dated = [p.name for p in product.iterdir() if p.is_dir() and re.match(r"^\d{4}-\d{2}-\d{2}", p.name)]
    if dated:
        fail("dated change workspaces belong under .scratch/: " + ", ".join(dated))
    capabilities = sorted(p for p in requirements.glob("*.md") if p.name != "README.md")
    if not capabilities:
        fail("at least one capability requirement is required")
    index_text = index.read_text()
    for path in capabilities:
        text = path.read_text()
        identity = re.search(r"^\*\*Capability ID\*\*: `([a-z0-9]+(?:-[a-z0-9]+)*)`", text, re.M)
        if not identity or identity.group(1) != path.stem:
            fail(f"{path.name}: Capability ID must match the filename")
        for heading in ("User goal", "Requirements", "Planned changes", "References"):
            match = re.search(r"^## " + heading + r"\s*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
            if not match or not match.group(1).strip():
                fail(f"{path.name}: nonempty {heading} section is required")
        if f"requirements/{path.name}" not in index_text:
            fail(f"{path.name}: capability is missing from the product index")
    for path in [index, requirements / "README.md", *capabilities]:
        for raw in re.findall(r"\]\(([^)]+)\)", path.read_text()):
            target = raw.strip("<>").split("#", 1)[0]
            if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                continue
            if target.startswith(("docs/", ".scratch/")):
                resolved = (root / target).resolve()
            else:
                resolved = (path.parent / target).resolve()
            if not resolved.is_relative_to(root) or not resolved.exists():
                fail(f"{path.relative_to(root)}: broken or external local link: {target}")
    if summary:
        check_requirement_reconciliation(root, summary)
    if change_dir:
        workspace = (root / change_dir).resolve()
        if not workspace.is_relative_to(root):
            fail("change workspace must belong to the consuming repository")
        nested = root / "android-agent-harness"
        if workspace.is_relative_to(nested):
            fail("change workspace must not belong to the shared harness")
        spec = workspace / "spec.md"
        if not spec.is_file():
            versioned = sorted(
                (p for p in workspace.glob("spec_v*.md") if re.fullmatch(r"spec_v\d+\.md", p.name)),
                key=lambda p: int(re.search(r"_v(\d+)\.md$", p.name).group(1)),
            )
            if not versioned:
                fail("change workspace has no specification")
            spec = versioned[-1]
        text = spec.read_text()
        match = re.search(r"^## Product Requirements\s*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
        if not match:
            fail("new change specification requires a Product Requirements section")
        refs = re.findall(r"docs/product/requirements/([a-z0-9-]+\.md)", match.group(1))
        if not refs:
            fail("Product Requirements must reference an existing capability file")
        for ref in refs:
            if not (requirements / ref).is_file() or ref == "README.md":
                fail("unknown capability reference: " + ref)
    return len(capabilities)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--change-dir", type=Path)
    parser.add_argument("--summary", type=Path, help="Validate the affected-claim reconciliation table in a change summary")
    args = parser.parse_args()
    try:
        count = check(args.root.resolve(), args.change_dir, args.summary)
    except (ValueError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: {count} capability documents; product/scratch paths and references valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
