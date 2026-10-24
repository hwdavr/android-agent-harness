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
