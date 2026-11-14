#!/usr/bin/env python3
"""Real-CLI test: the OpenPencil adapter extracts a tool-neutral layout from a `.fig` source."""

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ADAPTER = Path(__file__).resolve().parents[1] / "design_adapters/openpencil_layout.py"
PEN = {"version": "2.21", "children": [
    {"type": "frame", "id": "screen", "name": "Screen", "width": 200, "height": 300, "layout": "vertical",
     "gap": 12, "padding": 8, "children": [
         {"type": "text", "id": "title", "name": "Title", "content": "Hello", "fontSize": 24, "fontFamily": "Inter"},
         {"type": "frame", "id": "box", "name": "Box", "width": 50, "height": 40}]}]}


class OpenPencilLayoutTest(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(shutil.which("openpencil"), "OpenPencil CLI is required for live adapter evidence")
        self.temp = tempfile.TemporaryDirectory(prefix="design-layout-adapter-")
        self.root = Path(self.temp.name)
        pen = self.root / "source.pen"
        pen.write_text(json.dumps(PEN), encoding="utf-8")
        self.source = self.root / "source.fig"
        subprocess.run(["openpencil", "convert", str(pen), "-o", str(self.source)], check=True, capture_output=True)
        found = subprocess.run(["openpencil", "find", str(self.source), "--name", "Screen", "--json"],
                               text=True, capture_output=True, check=True).stdout
        self.screen = json.loads(found)[0]["id"] if found.lstrip().startswith("[") else "0:5"

    def tearDown(self):
        self.temp.cleanup()

    def extract(self, node, out="layout.json"):
        return subprocess.run([sys.executable, str(ADAPTER), "--source", str(self.source), "--node", node,
                               "--out", str(self.root / out)], text=True, capture_output=True)

    def test_extracts_frame_layout_text_and_hash(self):
        result = self.extract(self.screen)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        layout = json.loads((self.root / "layout.json").read_text())
        self.assertEqual((layout["version"], layout["tool"]), (1, "openpencil"))
        self.assertEqual(layout["source_sha256"], hashlib.sha256(self.source.read_bytes()).hexdigest())
        self.assertEqual((layout["frame"]["width"], layout["frame"]["height"]), (200, 300))
        nodes = {node["name"]: node for node in layout["nodes"]}
        self.assertEqual(nodes["Screen"]["layout"], {"mode": "VERTICAL", "gap": 12, "padding": [8, 8, 8, 8]})
        self.assertEqual((nodes["Title"]["x"], nodes["Title"]["y"]), (8, 8))
        self.assertEqual(nodes["Title"]["text"]["characters"], "Hello")
        self.assertEqual(nodes["Title"]["text"]["fontSize"], 24)
        # Child offsets accumulate: 8 padding + title height + 12 gap.
        self.assertEqual(nodes["Box"]["y"], 8 + nodes["Title"]["height"] + 12)

    def test_rejects_unknown_and_non_top_level_nodes(self):
        missing = self.extract("no-such-node")
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("node not found", missing.stdout + missing.stderr)
        self.extract(self.screen)
        child = json.loads((self.root / "layout.json").read_text())["nodes"][1]["id"]
        nested = self.extract(child, "child.json")
        self.assertNotEqual(nested.returncode, 0)
        self.assertIn("not a top-level screen frame", nested.stderr)
        self.assertFalse((self.root / "child.json").exists())

    def test_rejects_other_tool_source(self):
        pen = self.root / "other.pen"
        pen.write_text("x")
        result = subprocess.run([sys.executable, str(ADAPTER), "--source", str(pen), "--node", "0:1",
                                 "--out", str(self.root / "o.json")], text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be an existing .fig file", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
