#!/usr/bin/env python3
"""compose-ui-comparison.py builds one design-versus-render image per state and never alters the originals."""

import hashlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # the script itself needs Pillow; fail loudly rather than skip
    raise SystemExit("FAIL: ui-comparison-contract-test.py needs Pillow (python3 -m pip install pillow)")

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "harness/scripts/compose-ui-comparison.py"
HEADER = ("| Screen | State ID | Design source | Design node ID | Design node role | Design image | Viewport | "
          "Required regions | State controls | Reused components | Runtime fixture | Plan stage |")


class ComparisonTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ui-comparison-")
        self.feature = Path(self.temp.name)
        (self.feature / "design").mkdir()
        (self.feature / "evidence/ui").mkdir(parents=True)
        rows = [HEADER, "|" + "---|" * 12]
        for index, state in enumerate(("open", "closed"), 1):
            rows.append(
                f"| Share | {state} | design/source.pen | {state}-node | screen-frame | design/mockup_{state}.png | "
                f"390x844 | primary-content; state-controls; persistent-controls | Search field | "
                f"None — fixture screen | {state}-fixture | UI-0{index} |")
        (self.feature / "UI_contract.md").write_text(
            "# UI contract\n\n## Screen States\n\n" + "\n".join(rows) + "\n")
        for state in ("open", "closed"):
            Image.new("RGB", (780, 1688), (250, 250, 255)).save(self.feature / f"design/mockup_{state}.png")
            Image.new("RGB", (780, 1688), (240, 250, 240)).save(self.feature / f"evidence/ui/{state}.png")

    def tearDown(self):
        self.temp.cleanup()

    def run_script(self):
        return subprocess.run([sys.executable, str(SCRIPT), str(self.feature)], text=True, capture_output=True)

    @staticmethod
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def test_composes_one_labelled_pair_per_state_and_an_index(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        compare = self.feature / "evidence/ui/compare"
        for state in ("open", "closed"):
            with Image.open(compare / f"{state}.png") as image:
                self.assertGreater(image.width, 2 * 780)
                self.assertGreater(image.height, 1688)
        index = (compare / "index.md").read_text()
        self.assertIn("evidence/ui/compare/open.png", index)
        self.assertIn("UI-02", index)

    def test_originals_are_never_modified(self):
        paths = [self.feature / "design/mockup_open.png", self.feature / "evidence/ui/open.png"]
        before = [self.digest(path) for path in paths]
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(before, [self.digest(path) for path in paths])

    def test_missing_capture_fails(self):
        (self.feature / "evidence/ui/closed.png").unlink()
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing review capture for closed", result.stderr)

    def test_mismatched_aspect_ratio_fails_instead_of_resizing(self):
        Image.new("RGB", (780, 780), (240, 250, 240)).save(self.feature / "evidence/ui/open.png")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("different aspect ratios", result.stderr)
        self.assertFalse((self.feature / "evidence/ui/compare/open.png").exists())


if __name__ == "__main__":
    unittest.main()
