#!/usr/bin/env python3
"""Focused fixtures for capability docs and scratch migration failures."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

loader = importlib.util.spec_from_file_location("product_docs", Path(__file__).resolve().parents[1] / "check-product-docs.py")
module = importlib.util.module_from_spec(loader)
loader.loader.exec_module(module)


class ProductDocsContractTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.requirements = self.root / "docs/product/requirements"
        self.requirements.mkdir(parents=True)
        (self.requirements / "README.md").write_text("# Requirements\n")
        self.capability = self.requirements / "stickers.md"
        self.capability.write_text("# Stickers\n\n**Capability ID**: `stickers`\n\n## User goal\nDecorate photos.\n\n## Requirements\nPlace overlays.\n\n## Planned changes\nNone.\n\n## References\n[Index](../product.md)\n")
        self.index = self.root / "docs/product/product.md"
        self.index.write_text("# Product\n[Stickers](requirements/stickers.md)\n")

    def test_accepts_capability_and_scratch_links(self):
        workspace = self.root / ".scratch/2026-10-24-sticker-change"
        workspace.mkdir(parents=True)
        self.index.write_text(self.index.read_text() + "[Change](../../.scratch/2026-10-24-sticker-change/)\n")
        (workspace / "spec.md").write_text("# Change\n\n## Product Requirements\n[Stickers](docs/product/requirements/stickers.md)\n")
        self.assertEqual(module.check(self.root, workspace), 1)

    def test_accepts_audited_requirement_reconciliation_summary(self):
        summary = self.root / "docs/current/summary_v1.md"
        summary.parent.mkdir(parents=True)
        summary.write_text(
            "# Change Summary\n\n"
            "## Product Requirement Reconciliation\n\n"
            "| Capability file | Existing claim reviewed | Disposition | Current requirement location or retired status | Evidence / qualification |\n"
            "|---|---|---|---|---|\n"
            "| `docs/product/requirements/stickers.md` | Existing sticker picker behavior | Replace | Requirements table now describes picker behavior | Focused picker test passed and summary records the command. |\n"
        )
        self.assertEqual(module.check(self.root, summary=summary), 1)

    def test_reconciliation_requires_a_review_table(self):
        summary = self.root / "summary.md"
        summary.write_text("# Change Summary\n\n## Product Requirement Reconciliation\nNo claims reviewed.\n")
        with self.assertRaisesRegex(ValueError, "reconciliation table must use the required five columns"):
            module.check(self.root, summary=summary)

    def test_reconciliation_rejects_unsupported_disposition(self):
        summary = self.root / "summary.md"
        summary.write_text(
            "## Product Requirement Reconciliation\n\n"
            "| Capability file | Existing claim reviewed | Disposition | Current requirement location or retired status | Evidence / qualification |\n"
            "|---|---|---|---|---|\n"
            "| `docs/product/requirements/stickers.md` | Existing sticker picker behavior | Add section | Requirements table updated | Focused test passed and summary records the command. |\n"
        )
        with self.assertRaisesRegex(ValueError, "unsupported reconciliation disposition"):
            module.check(self.root, summary=summary)

    def test_reconciliation_rejects_unknown_capability(self):
        summary = self.root / "summary.md"
        summary.write_text(
            "## Product Requirement Reconciliation\n\n"
            "| Capability file | Existing claim reviewed | Disposition | Current requirement location or retired status | Evidence / qualification |\n"
            "|---|---|---|---|---|\n"
            "| `docs/product/requirements/unknown.md` | Existing requirement behavior | Retire | Removed from capability file | Summary links a verified retirement rationale here. |\n"
        )
        with self.assertRaisesRegex(ValueError, "unknown capability"):
            module.check(self.root, summary=summary)

    def test_reconciliation_rejects_replaced_claim_left_in_capability(self):
        summary = self.root / "summary.md"
        summary.write_text(
            "## Product Requirement Reconciliation\n\n"
            "| Capability file | Existing claim reviewed | Disposition | Current requirement location or retired status | Evidence / qualification |\n"
            "|---|---|---|---|---|\n"
            "| `docs/product/requirements/stickers.md` | Place overlays. | Replace | Requirements table now describes picker behavior | Focused picker test passed and summary records the command. |\n"
        )
        with self.assertRaisesRegex(ValueError, "stale claim marked Replace still appears"):
            module.check(self.root, summary=summary)

    def test_reconciliation_requires_retained_claim_to_remain(self):
        summary = self.root / "summary.md"
        summary.write_text(
            "## Product Requirement Reconciliation\n\n"
            "| Capability file | Existing claim reviewed | Disposition | Current requirement location or retired status | Evidence / qualification |\n"
            "|---|---|---|---|---|\n"
            "| `docs/product/requirements/stickers.md` | Old category sorting remains. | Retain | Requirements continues to describe sorting | Passing regression test confirms order remains unchanged. |\n"
        )
        with self.assertRaisesRegex(ValueError, "claim marked Retain is absent"):
            module.check(self.root, summary=summary)

    def test_rejects_dated_product_workspace(self):
        (self.root / "docs/product/2026-10-24-sticker-change").mkdir()
        with self.assertRaisesRegex(ValueError, "belong under .scratch"):
            module.check(self.root)

    def test_rejects_missing_requirements(self):
        self.capability.write_text(self.capability.read_text().replace("## Requirements", "## Other"))
        with self.assertRaisesRegex(ValueError, "Requirements section is required"):
            module.check(self.root)

    def test_rejects_filename_identity_mismatch(self):
        self.capability.write_text(self.capability.read_text().replace("`stickers`", "`drawing`"))
        with self.assertRaisesRegex(ValueError, "Capability ID"):
            module.check(self.root)

    def test_rejects_stale_delivery_link(self):
        self.index.write_text(self.index.read_text() + "[Old change](2026-10-24-sticker-change/)\n")
        with self.assertRaisesRegex(ValueError, "broken or external local link"):
            module.check(self.root)

    def test_rejects_unindexed_capability(self):
        self.index.write_text("# Product\n")
        with self.assertRaisesRegex(ValueError, "missing from the product index"):
            module.check(self.root)

    def test_new_change_requires_existing_capability(self):
        workspace = self.root / ".scratch/change"
        workspace.mkdir(parents=True)
        spec = workspace / "spec.md"
        spec.write_text("# Change\n")
        with self.assertRaisesRegex(ValueError, "Product Requirements section"):
            module.check(self.root, workspace)
        spec.write_text("## Product Requirements\n[Unknown](docs/product/requirements/unknown.md)\n")
        with self.assertRaisesRegex(ValueError, "unknown capability reference"):
            module.check(self.root, workspace)

    def test_rejects_shared_harness_workspace(self):
        workspace = self.root / "android-agent-harness/.scratch/change"
        workspace.mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, "shared harness"):
            module.check(self.root, workspace)


if __name__ == "__main__":
    unittest.main()
