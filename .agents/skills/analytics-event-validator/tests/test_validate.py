import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import validate as v


def stream(events=None):
    if events is None:
        events = [("sample_started", {"entry": "toolbar"}), ("sample_completed", {"duration_ms": 42})]
    rows = [{"type": "capture_ready", "version": 1, "timestamp_ms": 1000}]
    rows += [{"type": "event", "name": name, "params": params, "timestamp_ms": 1001 + index}
             for index, (name, params) in enumerate(events)]
    rows += [{"type": "capture_complete", "version": 1, "timestamp_ms": 1001 + len(events),
              "event_count": len(events)}]
    return b"".join(v.json_bytes(row).replace(b"\n", b"") + b"\n" for row in rows)


class ValidatorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.run_dir = Path(self.temp.name)
        self.contract = json.loads((ROOT / "examples/contract.example.json").read_text())
        self.path = self.run_dir / "contract.json"
        self.capture = self.run_dir / "input.ndjson"
        self.capture.write_bytes(stream())
        (self.run_dir / "scenario.json").write_text(json.dumps({
            "scenario_id": "synthetic_editor_flow", "app_id": "com.example.funphotoeditor"}))

    def save(self):
        self.path.write_bytes(v.json_bytes(self.contract))
        return v.load_contract(self.path)

    def evaluate(self, events=None):
        contract = self.save()
        return v.evaluate(contract, v.check_raw(stream(events), contract), "offline")

    def cli(self, *extra):
        return subprocess.run([sys.executable, str(ROOT / "scripts/validate.py"),
                               "--run-dir", str(self.run_dir), "--contract", str(self.path), *extra],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)

    def test_healthy_fixture_passes_and_values_are_discarded(self):
        result = self.evaluate()
        self.assertEqual("PASS", result["status"])
        self.assertEqual(2, result["event_count"])
        self.assertNotIn("toolbar", json.dumps(result))
        self.assertTrue(any("Offline" in item for item in result["limitations"]))

    def test_missing_and_duplicate_event_fail_count(self):
        for events in ([("sample_started", {"entry": "home"})],
                       [("sample_started", {"entry": "home"})] * 2 + [("sample_completed", {"duration_ms": 1})]):
            with self.subTest(events=events):
                result = self.evaluate(events)
                self.assertEqual("FAIL", result["status"])
                self.assertTrue(any(item["id"].startswith("count:") and item["status"] == "FAIL"
                                    for item in result["checks"]))

    def test_zero_and_ranged_counts(self):
        self.contract["expected_events"] = [{"name": "sample_started", "count": {"exact": 0}}]
        self.contract["order"] = []
        self.assertEqual("PASS", self.evaluate([])["status"])
        self.contract["expected_events"][0]["count"] = {"min": 1, "max": 2}
        self.assertEqual("FAIL", self.evaluate([])["status"])
        self.assertEqual("PASS", self.evaluate([("sample_started", {})])["status"])

    def test_required_and_optional_parameters(self):
        events = [("sample_started", {}), ("sample_completed", {"duration_ms": 1})]
        self.assertEqual("FAIL", self.evaluate(events)["status"])
        self.contract["expected_events"][0]["params"]["entry"]["required"] = False
        self.assertEqual("PASS", self.evaluate(events)["status"])

    def test_bool_does_not_satisfy_integer(self):
        result = self.evaluate([("sample_started", {"entry": "home"}), ("sample_completed", {"duration_ms": True})])
        self.assertEqual("FAIL", result["status"])
        self.assertEqual("FAIL", next(item["status"] for item in result["checks"]
                                      if item["id"] == "param:sample_completed.duration_ms"))

    def test_scalar_and_enum_semantics(self):
        self.assertFalse(v.equivalent(1, True))
        self.assertFalse(v.equivalent(1, 1.0))
        self.assertTrue(v.param_ok(1, {"type": "number"}))
        self.assertTrue(v.param_ok(None, {"type": "null"}))
        self.assertFalse(v.param_ok("other", {"type": "string", "one_of": ["home"]}))

    def test_forbidden_and_unexpected_policy(self):
        base = [("sample_started", {"entry": "home"}), ("sample_completed", {"duration_ms": 1})]
        self.assertEqual("FAIL", self.evaluate(base + [("sample_failed", {})])["status"])
        result = self.evaluate(base + [("background_signal", {"secret": "DO_NOT_RETAIN"})])
        self.assertEqual("PASS", result["status"])
        self.assertEqual(v.UNKNOWN, result["timeline"][-1])
        self.assertNotIn("DO_NOT_RETAIN", json.dumps(result))
        self.contract["allow_unexpected"] = False
        self.assertEqual("FAIL", self.evaluate(base + [("background_signal", {})])["status"])

    def test_wrong_and_repeated_order(self):
        reverse = [("sample_completed", {"duration_ms": 1}), ("sample_started", {"entry": "home"})]
        self.assertEqual("FAIL", self.evaluate(reverse)["status"])
        self.contract["order"] = ["sample_started", "sample_completed", "sample_started"]
        self.contract["expected_events"][0]["count"] = {"exact": 2}
        self.assertEqual("PASS", self.evaluate([reverse[1], reverse[0], reverse[1]])["status"])

    def test_invalid_contracts_rejected(self):
        variants = []
        for key, value in [("schema_version", True), ("allow_unexpected", []), ("unknown", 1)]:
            item = copy.deepcopy(self.contract)
            item[key] = value
            variants.append(item)
        for count in ({"exact": True}, {"min": 4, "max": 1}, {"exact": 1, "min": 1}):
            item = copy.deepcopy(self.contract)
            item["expected_events"][0]["count"] = count
            variants.append(item)
        for rule in ({"type": []}, {"type": "integer", "equals": True},
                     {"type": "string", "matches": "(a+)+$"}, {"type": "string", "matches": "["},
                     {"type": "string", "one_of": [1]}):
            item = copy.deepcopy(self.contract)
            item["expected_events"][0]["params"]["entry"] = rule
            variants.append(item)
        for item in variants:
            with self.subTest(item=item):
                self.path.write_bytes(v.json_bytes(item))
                with self.assertRaises(ValueError):
                    v.load_contract(self.path)

    def test_safe_bounded_pattern(self):
        v.safe_pattern("[a-z]{1,20}")
        self.assertTrue(v.param_ok("home", {"type": "string", "matches": "[a-z]{1,20}"}))
        for pattern in ("a+", "(a|b)", "a{1,20}b{1,20}", "(?=a)"):
            with self.assertRaises(ValueError):
                v.safe_pattern(pattern)

    def test_duplicate_json_keys_rejected(self):
        with self.assertRaises(ValueError):
            v.decode(b'{"key":1,"key":2}')

    def test_unhealthy_streams_are_inconclusive(self):
        contract = self.save()
        rows = [json.loads(line) for line in stream().splitlines()]
        variants = [b"", b"\xff", b'{"type":', stream()[:-30], b'{"x":NaN}',
                    stream([("sample_started", {"entry": {"secret": "x"}})]),
                    b'{}']
        variants += [b"\n".join(json.dumps(item).encode() for item in sequence)
                     for sequence in (rows[1:], rows[:-1], [rows[0], rows[0], *rows[1:]])]
        for data in variants:
            with self.subTest(data=data[:40]):
                with self.assertRaises(v.CaptureIssue):
                    v.check_raw(data, contract)
        with self.assertRaises(v.CaptureIssue):
            v.check_raw(stream(), contract, earliest=1001)
        with self.assertRaises(v.CaptureIssue):
            v.check_raw(stream(), contract, latest=1002)

    def test_sensitive_invalid_value_remains_failure_after_redaction(self):
        secret = "sensitive_fixture_email"
        raw = stream([("sample_started", {"entry": secret}), ("sample_completed", {"duration_ms": 1})])
        checked = v.check_raw(raw, self.save())
        self.assertNotIn(secret, json.dumps(checked))
        result = v.evaluate(self.contract, checked, "live")
        self.assertEqual("FAIL", result["status"])
        self.assertNotIn(secret, v.render(result))

    def test_extra_expected_event_parameters_are_not_silent_pass(self):
        result = self.evaluate([("sample_started", {"entry": "home", "email": "PRIVATE"}),
                                ("sample_completed", {"duration_ms": 1})])
        self.assertEqual("INCONCLUSIVE", result["status"])
        self.assertNotIn("PRIVATE", json.dumps(result))

    def test_cli_exit_reports_and_parent_isolation(self):
        self.save()
        (self.run_dir / "report.md").write_text("parent evidence")
        result = self.cli("--offline", "--capture", str(self.capture))
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("parent evidence", (self.run_dir / "report.md").read_text())
        report = json.loads((self.run_dir / "analytics/report.json").read_text())
        self.assertEqual("offline", report["mode"])
        self.assertEqual(v.digest(self.path.read_bytes()), report["provenance"]["contract_sha256"])
        self.assertEqual(0o600, (self.run_dir / "analytics/report.json").stat().st_mode & 0o777)
        self.assertEqual(3, self.cli("--offline", "--capture", str(self.capture)).returncode)

    def test_cli_fail_fixture(self):
        self.save()
        result = self.cli("--offline", "--capture", str(ROOT / "examples/events.fail.example.ndjson"))
        self.assertEqual(1, result.returncode, result.stderr)

    def test_cli_missing_capture_and_draft(self):
        self.save()
        self.assertEqual(2, self.cli("--offline", "--capture", str(self.run_dir / "missing")).returncode)

    def test_cli_draft_cannot_pass(self):
        self.contract["approval"]["status"] = "draft"
        self.save()
        self.assertEqual(2, self.cli("--offline", "--capture", str(self.capture)).returncode)

    def test_cli_example_cannot_be_live(self):
        self.save()
        self.assertEqual(2, self.cli().returncode)

    def test_cli_invalid_contract_and_output_error(self):
        self.path.write_text("{}")
        self.assertEqual(3, self.cli("--offline", "--capture", str(self.capture)).returncode)
        self.save()
        (self.run_dir / "analytics").write_text("not a directory")
        self.assertEqual(3, self.cli("--offline", "--capture", str(self.capture)).returncode)

    def test_oversized_and_nonfinite_inputs(self):
        self.capture.write_bytes(b"x" * (v.MAX_BYTES + 1))
        with self.assertRaises(ValueError):
            v.bounded(self.capture)
        with self.assertRaises(ValueError):
            v.decode(b'{"number":Infinity}')
        contract = self.save()
        with self.assertRaises(v.CaptureIssue):
            v.check_raw(b"x" * (v.MAX_BYTES + 1), contract)


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.run_dir = Path(self.temp.name)
        self.directory = self.run_dir / "analytics"
        self.directory.mkdir()
        (self.run_dir / "scenario.json").write_text(json.dumps({
            "scenario_id": "synthetic_editor_flow", "app_id": "com.example.funphotoeditor"}))
        self.source = self.run_dir / "tracking.md"
        self.source.write_text("Approved synthetic test tracking")
        self.contract = json.loads((ROOT / "examples/contract.example.json").read_text())
        self.contract["approval"] = {"status": "approved", "reference": "Synthetic test owner"}
        self.contract["sources"] = [{"path": "tracking.md", "sha256": v.digest(self.source.read_bytes()), "section": "all"}]
        self.contract_path = self.run_dir / "contract.json"
        self.contract_path.write_bytes(v.json_bytes(self.contract))
        self.hash = v.digest(self.contract_path.read_bytes())
        self.ctx = v.context(self.run_dir)
        self.checked = v.check_raw(stream(), self.contract)
        self.checked["contract_sha256"] = self.hash
        self.identity = {"serial": "test-serial", "package": self.ctx["package"], "api": 33,
                         "version_code": 1, "apk_sha256": ["a" * 64]}
        self.reset = {**self.ctx, "schema_version": 1, "status": "RESET", "identity": self.identity,
                      "contract_sha256": self.hash, "started_ms": 1000}
        self.receipt = {**self.ctx, "schema_version": 1, "status": "COLLECTED", "identity": copy.deepcopy(self.identity),
                        "contract_sha256": self.hash, "collected_ms": 1999,
                        "raw_sha256": v.digest(stream()), "raw_bytes": len(stream())}

    def write(self):
        reset = v.json_bytes(self.reset)
        data = v.json_bytes(self.checked)
        self.receipt.update(reset_sha256=v.digest(reset), capture_sha256=v.digest(data))
        (self.directory / "reset.json").write_bytes(reset)
        (self.directory / "events.checked.json").write_bytes(data)
        (self.directory / "collection.json").write_bytes(v.json_bytes(self.receipt))

    def read(self):
        return v.live_capture(self.run_dir, self.contract, self.ctx, self.hash, self.run_dir)

    def test_matching_live_provenance(self):
        self.write()
        self.assertEqual("PASS", v.evaluate(self.contract, self.read(), "live")["status"])

    def test_mismatch_scenario_target_build_contract_and_time(self):
        for key, value in (("scenario_id", "other"), ("package", "com.example.wrong"),
                           ("scenario_sha256", "b" * 64), ("schema_version", True), ("raw_bytes", -1),
                           ("contract_sha256", "b" * 64),
                           ("identity", {**self.identity, "serial": "another"}),
                           ("collected_ms", 1001)):
            with self.subTest(key=key):
                original = copy.deepcopy(self.receipt)
                self.receipt[key] = value
                self.write()
                with self.assertRaises(v.CaptureIssue):
                    self.read()
                self.receipt = original

    def test_capture_hash_and_source_change(self):
        self.write()
        (self.directory / "events.checked.json").write_text("{}")
        with self.assertRaises(v.CaptureIssue):
            self.read()
        self.write()
        self.source.write_text("Changed requirements")
        with self.assertRaises(v.CaptureIssue):
            self.read()

    def test_collection_failure_invalidates_prior_capture(self):
        self.write()
        (self.directory / "collection-error.json").write_text("{}")
        with self.assertRaises(v.CaptureIssue):
            self.read()

    def test_reset_receipt_hash_cannot_be_changed(self):
        self.write()
        self.receipt["reset_sha256"] = "b" * 64
        (self.directory / "collection.json").write_bytes(v.json_bytes(self.receipt))
        with self.assertRaises(v.CaptureIssue):
            self.read()

    def test_invalid_target_metadata_cannot_pass_matching_receipts(self):
        for key, val in (("api", True), ("serial", "-unsafe"), ("apk_sha256", ["bad"])):
            with self.subTest(key=key):
                old = self.identity[key]
                self.identity[key] = val
                self.receipt["identity"] = copy.deepcopy(self.identity)
                self.write()
                with self.assertRaises(v.CaptureIssue):
                    self.read()
                self.identity[key] = old

    def test_unknown_checked_fields_cannot_hide_raw_values(self):
        self.checked["events"][0]["secret"] = "private"
        self.write()
        with self.assertRaises(v.CaptureIssue):
            self.read()


if __name__ == "__main__":
    unittest.main()
