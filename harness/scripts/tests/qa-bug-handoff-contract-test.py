#!/usr/bin/env python3
"""Contract fixtures for importing an existing Exploratory QA finding."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HARNESS_ROOT = Path(__file__).resolve().parents[3]
STAGE_GATE = HARNESS_ROOT / "harness/scripts/check-stage-artifacts.sh"
CONTEXT_READER = HARNESS_ROOT / "harness/scripts/read-qa-bug-context.py"


class QaBugHandoffContractTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="qa-bug-handoff-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.docs = self.root / "docs/current"
        self.run = self.root / ".qa-artifacts/qa-run"
        self.docs.mkdir(parents=True)
        (self.run / "evidence").mkdir(parents=True)
        (self.run / "evidence/observation.txt").write_text("Observed empty picker after photo selection.\n")
        target = {"package": "example.app", "version": "1.0-debug", "device": "Emulator API 33"}
        self.scenario = {"scenario_id": "qa-run", "target": target}
        self.finding = {
            "id": "F-001", "title": "Picker stays empty", "severity": "medium",
            "category": "functional", "affected_flow": "Home > photo > editor",
            "repro_steps": ["Open Home", "Select a photo", "Wait for the picker"],
            "expected": "The picker contains items", "actual": "The picker is empty",
            "evidence": ["evidence/observation.txt"],
        }
        self.report = {
            "scenario": "qa-run", "status": "FAIL", "target": target,
            "findings": [self.finding], "generation": {"sources": []},
        }
        self.scenario["generation"] = self.report["generation"]
        self.write_run()
        self.spec = self.docs / "spec_v1.md"
        self.spec.write_text(
            "# Bug context\n\n## Exploratory QA Handoff\n\n"
            "- Report: `.qa-artifacts/qa-run/report.json`\n- Finding: `F-001`\n\n"
            "## Rule Applicability\n\n| Rule ID | Decision |\n|---|---|\n" +
            "".join("| %s | Not applicable — fixture only |\n" % rule
                    for rule in ("ARCH", "IMPL", "TEST", "SUI", "L10N", "NAV", "API", "OBS", "ANL", "SEC"))
        )
        (self.docs / "summary_v1.md").write_text("# Summary\n")

    def write_run(self):
        scenario_bytes = (json.dumps(self.scenario) + "\n").encode()
        (self.run / "scenario.json").write_bytes(scenario_bytes)
        self.report["scenario_sha256"] = hashlib.sha256(scenario_bytes).hexdigest()
        (self.run / "observations.json").write_text(json.dumps({"findings": [self.finding]}))
        (self.run / "report.json").write_text(json.dumps(self.report))

    def gate(self, stage="requirement-analysis"):
        env = dict(os.environ, HARNESS_PROJECT_ROOT=str(self.root))
        return subprocess.run(
            ["bash", str(STAGE_GATE), "bug-fixing", stage, str(self.docs)],
            env=env, capture_output=True, text=True, check=False,
        )

    def assert_rejected(self, expected):
        result = self.gate()
        output = result.stdout + result.stderr
        self.assertNotEqual(0, result.returncode, "invalid QA handoff was accepted:\n" + output)
        self.assertIn(expected, output)

    def test_complete_failed_app_report_is_reusable(self):
        result = self.gate()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_missing_report_is_rejected(self):
        (self.run / "report.json").unlink()
        self.assert_rejected("missing report")

    def test_unrelated_inconclusive_checks_do_not_repeat_a_complete_finding(self):
        self.report["status"] = "INCONCLUSIVE"
        self.write_run()
        result = self.gate()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_incomplete_handoff_reference_is_rejected(self):
        self.spec.write_text(self.spec.read_text().replace("- Finding: `F-001`\n", ""))
        self.assert_rejected("Report and Finding")

    def test_markdown_report_uses_existing_structured_companion(self):
        (self.run / "dogfood-report.md").write_text("# F-001 — Picker stays empty\n")
        self.spec.write_text(self.spec.read_text().replace("qa-run/report.json", "qa-run/dogfood-report.md"))
        result = self.gate()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_missing_reproduction_fields_are_rejected(self):
        for field in ("repro_steps", "expected", "actual", "evidence"):
            with self.subTest(field=field):
                original = self.finding.pop(field)
                self.write_run()
                self.assert_rejected(field)
                self.finding[field] = original

    def test_missing_target_is_rejected(self):
        del self.report["target"]["device"]
        self.write_run()
        self.assert_rejected("target.device")

    def test_missing_selected_finding_is_rejected(self):
        self.report["findings"] = []
        self.write_run()
        self.assert_rejected("F-001")

    def test_missing_evidence_is_rejected(self):
        (self.run / "evidence/observation.txt").unlink()
        self.assert_rejected("missing evidence")

    def test_evidence_cannot_escape_run(self):
        (self.root / "external.txt").write_text("outside run")
        self.finding["evidence"] = ["../../external.txt"]
        self.write_run()
        self.assert_rejected("evidence path")

    def test_changed_scenario_is_rejected(self):
        (self.run / "scenario.json").write_text(json.dumps({"scenario_id": "another-run"}))
        self.assert_rejected("scenario digest")

    def test_target_mismatch_is_rejected(self):
        self.scenario["target"] = dict(self.scenario["target"], device="Another device")
        self.write_run()
        self.assert_rejected("target.device differs")

    def test_wrong_installed_binary_is_rejected(self):
        self.report["target"].update(apk_sha256="0" * 64, installed_apk_sha256="1" * 64)
        self.write_run()
        self.assert_rejected("installed APK digest")

    def test_stale_report_finding_is_rejected(self):
        (self.run / "observations.json").write_text(json.dumps({"findings": []}))
        self.assert_rejected("observations")

    def test_setup_failure_is_not_an_app_finding(self):
        self.finding["category"] = "setup"
        self.write_run()
        self.assert_rejected("setup")

    def test_source_drift_is_reported_for_review(self):
        source = self.root / "source.kt"
        source.write_text("new source")
        self.report["generation"]["sources"] = [{"path": "source.kt", "sha256": "0" * 64}]
        self.write_run()
        result = subprocess.run(
            ["python3", str(CONTEXT_READER), "--project-root", str(self.root),
             "--report", str(self.run / "report.json"), "--finding", "F-001"],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("source.kt", result.stdout)
        self.assertIn("historical", result.stdout.lower())

    def test_external_source_reference_requires_review_without_reading_it(self):
        self.report["generation"]["sources"] = [{"path": "../UI_design/reference.pen", "sha256": "0" * 64}]
        self.write_run()
        result = self.gate()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("1 changed source reference", result.stdout)

    def test_malformed_source_fingerprint_is_rejected(self):
        self.report["generation"]["sources"] = [{"sha256": "0" * 64}]
        self.write_run()
        self.assert_rejected("source fingerprint")

    def test_qa_handoff_does_not_replace_red_regression(self):
        result = self.gate("bug-reproduction")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Reproduction Test", result.stdout + result.stderr)

    def test_non_qa_bug_keeps_the_existing_context_path(self):
        text = self.spec.read_text()
        self.spec.write_text(text[text.index("## Rule Applicability"):])
        result = self.gate()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
