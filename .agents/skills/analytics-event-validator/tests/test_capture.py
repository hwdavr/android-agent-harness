import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import capture as c
import validate as v

FAKE_ADB = r'''
import json, os, sys
from pathlib import Path
state_path = Path(os.environ["ANALYTICS_FAKE_STATE"])
state = json.loads(state_path.read_text())
with (state_path.parent / "commands.jsonl").open("a") as out:
    out.write(json.dumps(sys.argv[1:]) + "\n")
args = sys.argv[1:]
if args[:2] != ["-s", "test-serial"]:
    sys.exit(1)
args = args[2:]
if state.get("fail"):
    print("SENSITIVE_STDERR", file=sys.stderr)
    sys.exit(1)
if args == ["get-state"]:
    print("device")
elif args[:3] == ["shell", "pm", "path"]:
    print("package:/data/app/base.apk")
elif args[:2] == ["shell", "sha256sum"]:
    print(state.get("hash", "a"*64) + "  /data/app/base.apk")
elif args[:3] == ["shell", "dumpsys", "package"]:
    print("versionCode=1 minSdk=24")
elif args[:2] == ["shell", "getprop"]:
    print("33")
elif args == ["shell", "date", "+%s"]:
    print("1")
elif args[:3] == ["shell", "am", "force-stop"]:
    pass
elif len(args) > 3 and args[:2] in (["shell", "run-as"], ["exec-out", "run-as"]):
    operation = args[3:]
    if operation == ["id"]:
        print("uid=10000")
    elif operation[:2] == ["test", "-f"]:
        sys.exit(0 if state.get("present") else 1)
    elif operation[:2] == ["rm", "-f"]:
        state["present"] = False
        state["raw"] = ""
        state_path.write_text(json.dumps(state))
    elif operation[:2] == ["head", "-c"]:
        if not state.get("present"):
            sys.exit(1)
        sys.stdout.buffer.write(state["raw"].encode()[:int(operation[2])])
    else:
        sys.exit(1)
else:
    sys.exit(1)
'''


class CollectorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.run_dir = self.root / "run"
        self.run_dir.mkdir()
        (self.run_dir / "scenario.json").write_text(json.dumps({
            "scenario_id": "synthetic_editor_flow", "app_id": "com.example.funphotoeditor"}))
        self.contract = json.loads((ROOT / "examples/contract.example.json").read_text())
        (self.root / "tracking.md").write_text("Approved synthetic tracking")
        self.contract["approval"] = {"status": "approved", "reference": "Synthetic fixture"}
        self.contract["sources"] = [{"path": "tracking.md", "section": "all",
                                    "sha256": v.digest((self.root / "tracking.md").read_bytes())}]
        self.contract_path = self.root / "contract.json"
        self.contract_path.write_bytes(v.json_bytes(self.contract))
        self.raw = (ROOT / "examples/events.pass.example.ndjson").read_text()
        self.state_path = self.root / "state.json"
        self.state = {"present": True, "raw": self.raw}
        self.save_state()
        bindir = self.root / "bin"
        bindir.mkdir()
        executable = bindir / "adb"
        executable.write_text("#!" + sys.executable + "\n" + FAKE_ADB)
        executable.chmod(0o700)
        environment = patch.dict(os.environ, {"PATH": str(bindir) + os.pathsep + os.environ["PATH"],
                                              "ANALYTICS_FAKE_STATE": str(self.state_path)})
        environment.start()
        self.addCleanup(environment.stop)

    def save_state(self):
        self.state_path.write_text(json.dumps(self.state))

    def action(self, action):
        return c.execute(action, self.run_dir, "test-serial", self.contract_path, self.root)

    def emit_after_reset(self):
        self.state = json.loads(self.state_path.read_text())
        self.state.update(present=True, raw=self.raw)
        self.save_state()

    def test_inspect_is_read_only(self):
        self.assertEqual(0, self.action("inspect"))
        self.assertEqual(self.state, json.loads(self.state_path.read_text()))
        receipt = json.loads((self.run_dir / "analytics/capability.json").read_text())
        self.assertEqual("AVAILABLE", receipt["status"])
        commands = (self.root / "commands.jsonl").read_text()
        self.assertNotIn("force-stop", commands)
        self.assertNotIn('"rm"', commands)

    def test_reset_collect_live_validation_and_fixed_target(self):
        self.assertEqual(0, self.action("reset"))
        self.assertFalse(json.loads(self.state_path.read_text())["present"])
        self.emit_after_reset()
        self.assertEqual(0, self.action("collect"))
        ctx = v.context(self.run_dir)
        checked = v.live_capture(self.run_dir, self.contract, ctx,
                                 v.digest(self.contract_path.read_bytes()), self.root)
        self.assertEqual("PASS", v.evaluate(self.contract, checked, "live")["status"])
        commands = [json.loads(line) for line in (self.root / "commands.jsonl").read_text().splitlines()]
        self.assertTrue(all(command[:2] == ["-s", "test-serial"] for command in commands))
        self.assertIn(["-s", "test-serial", "shell", "run-as", "com.example.funphotoeditor",
                       "rm", "-f", c.REMOTE_FILE], commands)
        self.assertFalse(any("clear" in command for command in commands))

    def test_invalid_target_before_any_command(self):
        for serial in ("", "-e", "device;echo", "../test"):
            with self.assertRaises(ValueError):
                c.Android(serial, "com.example.app")
        with self.assertRaises(ValueError):
            c.Android("test-serial", "com.example.app;bad")
        self.assertFalse((self.root / "commands.jsonl").exists())

    def test_missing_recorder_is_inconclusive(self):
        self.state["present"] = False
        self.save_state()
        self.assertEqual(2, self.action("inspect"))
        self.assertEqual("INCONCLUSIVE", json.loads((self.run_dir / "analytics/capability.json").read_text())["status"])

    def test_device_failure_does_not_leak_stderr(self):
        self.state["fail"] = True
        self.save_state()
        self.assertEqual(2, self.action("inspect"))
        self.assertNotIn("SENSITIVE_STDERR", (self.run_dir / "analytics/capability.json").read_text())

    def test_reset_requires_actual_source_approval(self):
        self.contract["approval"]["status"] = "draft"
        self.contract_path.write_bytes(v.json_bytes(self.contract))
        self.assertEqual(2, self.action("reset"))
        self.assertFalse((self.root / "commands.jsonl").exists())

    def test_changed_build_after_reset_cannot_collect(self):
        self.assertEqual(0, self.action("reset"))
        self.emit_after_reset()
        self.state["hash"] = "b" * 64
        self.save_state()
        self.assertEqual(2, self.action("collect"))
        self.assertFalse((self.run_dir / "analytics/events.checked.json").exists())

    def test_wrong_reset_receipt_and_unflushed_stream(self):
        self.assertEqual(0, self.action("reset"))
        self.emit_after_reset()
        self.state["raw"] = self.raw.rsplit("\n", 2)[0] + "\n"
        self.save_state()
        self.assertEqual(2, self.action("collect"))
        self.assertTrue((self.run_dir / "analytics/collection-error.json").is_file())
        self.assertFalse((self.run_dir / "analytics/collection.json").exists())

    def test_oversized_stream_cannot_persist(self):
        self.assertEqual(0, self.action("reset"))
        self.emit_after_reset()
        self.state["raw"] = "x" * (v.MAX_BYTES + 1)
        self.save_state()
        self.assertEqual(2, self.action("collect"))
        self.assertFalse((self.run_dir / "analytics/events.checked.json").exists())

    def test_reused_collection_invalidates_old_evidence(self):
        self.assertEqual(0, self.action("reset"))
        self.emit_after_reset()
        self.assertEqual(0, self.action("collect"))
        with self.assertRaises(ValueError):
            self.action("collect")
        with self.assertRaises(v.CaptureIssue):
            v.live_capture(self.run_dir, self.contract, v.context(self.run_dir),
                           v.digest(self.contract_path.read_bytes()), self.root)

    def test_sensitive_invalid_value_has_no_retained_value(self):
        self.assertEqual(0, self.action("reset"))
        self.emit_after_reset()
        self.state["raw"] = self.raw.replace("toolbar", "SENSITIVE_FIXTURE")
        self.save_state()
        self.assertEqual(0, self.action("collect"))
        capture = (self.run_dir / "analytics/events.checked.json").read_text()
        self.assertNotIn("SENSITIVE_FIXTURE", capture)
        self.assertEqual(0o600, (self.run_dir / "analytics/events.checked.json").stat().st_mode & 0o777)
        self.assertEqual("FAIL", v.evaluate(self.contract, json.loads(capture), "live")["status"])

    def test_command_timeout_and_stdout_limit(self):
        with self.assertRaises(v.CaptureIssue):
            c.command([sys.executable, "-c", "import time; time.sleep(2)"], timeout=0.05)
        with self.assertRaises(v.CaptureIssue):
            c.command([sys.executable, "-c", "print('x'*4096)"], limit=32)

    def test_public_cli_requires_serial_and_reports_capability(self):
        base = [sys.executable, str(ROOT / "scripts/capture.py"), "inspect", "--run-dir", str(self.run_dir)]
        result = subprocess.run(base, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        self.assertEqual(2, result.returncode)
        self.assertFalse((self.run_dir / "analytics").exists())
        result = subprocess.run(base + ["--serial", "test-serial"],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_output_symlink_is_rejected(self):
        (self.run_dir / "analytics").symlink_to(self.root / "elsewhere")
        with self.assertRaises(ValueError):
            self.action("inspect")


if __name__ == "__main__":
    unittest.main()
