#!/usr/bin/env python3
"""Contract and real OpenPencil tests for the preservation checker."""

import copy
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check-openpencil-preservation.py"
spec = importlib.util.spec_from_file_location("preservation", CHECKER)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
HEADER = "@@ /Page/Added added to #0:1 at 1"
BASE = [{"id": "0:2", "guid": "1:2", "name": "Original", "type": "FRAME", "parent": "1:1"}]
BODY = HEADER + "\n+<Frame name=\"Added\" />"
DIFF = {"changed": True, "pages": [{"name": "Page", "status": "changed", "diff": BODY}], "diff": BODY}
SNAPSHOT = ('JSON.stringify([...figma.graph.nodes.values()].filter(n=>n.source.id).map(n=>'
            '({id:n.id,guid:n.source.id,name:n.name,type:n.type,'
            'parent:n.parentId?figma.graph.getNode(n.parentId)?.source.id:null})))')


class PreservationTest(unittest.TestCase):
    def test_addition_and_transient_id_change(self):
        after = copy.deepcopy(BASE)
        after[0]["id"] = "0:77"
        self.assertEqual(checker.check(BASE, after, DIFF, [HEADER]), (1, 1))

    def test_missing_original(self):
        with self.assertRaisesRegex(ValueError, "missing original GUID"):
            checker.check(BASE, [{"guid": "1:3", "name": "Other", "type": "FRAME", "parent": None}], DIFF, [HEADER])

    def test_identity_changes(self):
        for key, value in (("name", "Changed"), ("type", "RECTANGLE"), ("parent", "1:9")):
            with self.subTest(key=key):
                after = copy.deepcopy(BASE)
                after[0][key] = value
                with self.assertRaisesRegex(ValueError, "original identity changed"):
                    checker.check(BASE, after, DIFF, [HEADER])

    def test_unapproved_appearance_edit(self):
        altered = copy.deepcopy(DIFF)
        altered["diff"] += "\n@@ /Page/Original\n-old\n+new"
        altered["pages"][0]["diff"] = altered["diff"]
        with self.assertRaisesRegex(ValueError, "unexpected or missing diff hunks"):
            checker.check(BASE, BASE, altered, [HEADER])

    def test_invalid_evidence(self):
        with self.assertRaisesRegex(ValueError, "duplicate GUID"):
            checker.check(BASE + BASE, BASE, DIFF, [HEADER])
        with self.assertRaisesRegex(ValueError, "nonempty array"):
            checker.check([], BASE, DIFF, [HEADER])
        with self.assertRaisesRegex(ValueError, "nonempty body"):
            checker.check(BASE, BASE, {"changed": True, "pages": DIFF["pages"], "diff": ""}, [HEADER])
        with self.assertRaisesRegex(ValueError, "cannot read"):
            checker.read_json("/path/that/does/not/exist")

    def test_unexpected_or_missing_addition(self):
        with self.assertRaisesRegex(ValueError, "unexpected or missing diff hunks"):
            checker.check(BASE, BASE, DIFF, ["@@ /Page/Other added to #0:1 at 1"])


class LiveOpenPencilTest(unittest.TestCase):
    def test_real_addition_edit_and_deletion(self):
        self.assertIsNotNone(shutil.which("openpencil"), "OpenPencil CLI is required for live evidence")
        with tempfile.TemporaryDirectory(prefix="openpencil-preservation-") as directory:
            root = Path(directory)
            pen = root / "minimal.pen"
            pen.write_text(json.dumps({"version": "2.21", "children": [
                {"type": "frame", "id": "original", "name": "Original", "width": 100, "height": 100}
            ]}), encoding="utf-8")
            original = root / "original.fig"

            def run(*args, expected=0):
                result = subprocess.run(args, text=True, capture_output=True, timeout=60, check=False)
                self.assertEqual(result.returncode, expected, f"{args}: {result.stderr}\n{result.stdout}")
                return result.stdout

            run("openpencil", "convert", str(pen), "-o", str(original))
            before = json.loads(json.loads(run("openpencil", "eval", str(original), "-c", SNAPSHOT).strip()))
            self.assertTrue(before, "live source must have persisted GUIDs")
            candidate = root / "candidate.fig"
            shutil.copyfile(original, candidate)
            run("openpencil", "eval", str(candidate), "-w", "-c",
                'let n=figma.createRectangle();n.name="Added"')
            after = json.loads(json.loads(run("openpencil", "eval", str(candidate), "-c", SNAPSHOT).strip()))
            diff = json.loads(run("openpencil", "diff", "files", str(original), str(candidate), "--json", expected=1))
            allow = [x for x in diff["diff"].splitlines() if x.startswith("@@ ")]
            self.assertEqual(len(allow), 1)
            self.assertIn("Added", allow[0])
            checker.check(before, after, diff, allow)

            for operation in ('n.resize(80,80)', 'n.remove()'):
                altered = root / ("edit.fig" if "resize" in operation else "delete.fig")
                shutil.copyfile(candidate, altered)
                run("openpencil", "eval", str(altered), "-w", "-c",
                    f'let n=figma.currentPage.findOne(n=>n.name==="Original");{operation}')
                bad_after = json.loads(json.loads(run("openpencil", "eval", str(altered), "-c", SNAPSHOT).strip()))
                bad_diff = json.loads(run("openpencil", "diff", "files", str(original), str(altered), "--json", expected=1))
                with self.subTest(operation=operation), self.assertRaises(ValueError):
                    checker.check(before, bad_after, bad_diff, allow)


if __name__ == "__main__":
    unittest.main(verbosity=2)
