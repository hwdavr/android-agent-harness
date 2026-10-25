#!/usr/bin/env python3
"""Regression fixtures for omitted IME designs and replaced production windows."""

import os
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CHECK = ROOT / "harness/scripts/check-ui-contract.py"
GATE = ROOT / "harness/scripts/check-stage-artifacts.sh"

STATE_HEADER = "| Screen | State ID | Design source | Design node ID | Design node role | Design image | Viewport | Required regions | State controls | Runtime fixture | Comparison | Content difference | Plan stage |"
IME_HEADER = "| Screen | Input tag | Window viewport | Keyboard closed state | Keyboard open state | Dismissed state | Layout policy | Keyboard behavior | Required visible tags |"
BOUNDARY_HEADER = "| Screen | Input tag | Production activity | Open test | Dismiss test | Command | Result XML |"


class ImeContractTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ime-state-contract-")
        self.root = Path(self.temp.name)
        (self.root / "design").mkdir()
        (self.root / "design/source.pen").write_text("Pen fixture")
        for name in ("closed", "open"):
            self.png(name, 860, 1864)
        self.contract = self.root / "UI_contract.md"
        self.plan = self.root / "test_plan_v1.md"
        self.write_contract()
        self.write_runtime()

    def tearDown(self):
        self.temp.cleanup()

    def png(self, name, width, height):
        (self.root / f"design/mockup_{name}.png").write_bytes(
            b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", width, height)
        )

    def write_contract(self, inventory=True, open_state=True, window="430x932", ime_region=True):
        rows = [STATE_HEADER, "|" + "---|" * 14]
        for index, name in enumerate(("closed", "open") if open_state else ("closed",), 1):
            regions = "primary-content; state-controls; persistent-controls"
            if name == "open" and ime_region:
                regions += "; system-ime"
            rows.append(
                f"| Search | {name} | design/source.pen | {name}-node | screen-frame | "
                f"design/mockup_{name}.png | 430x932 | {regions} | Search field; results; Done | "
                f"{name}-fixture | roborazzi | none | UI-0{index} |"
            )
        text = "# UI contract\n\n## Screen States\n\n" + "\n".join(rows) + "\n"
        if inventory:
            text += (
                "\n## IME State Coverage\n\n" + IME_HEADER + "\n|" + "---|" * 9 + "\n"
                f"| Search | search_input | {window} | closed | open | closed | resize | screen-no-toolbar | search_input; results |\n"
            )
        self.contract.write_text(text)

    def write_runtime(self, replacement=False):
        self.test_file = "app/src/androidTest/java/example/SearchImeTest.kt"
        test_path = self.root / self.test_file
        test_path.parent.mkdir(parents=True, exist_ok=True)
        (self.root / "app/src/main").mkdir(parents=True, exist_ok=True)
        (self.root / "app/src/main/AndroidManifest.xml").write_text(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application>'
            '<activity android:name=".MainActivity" /></application></manifest>'
        )
        replacement_call = 'rule.setContent { SearchContent() }' if replacement else ''
        test_path.write_text('''package example
class SearchImeTest {
    val rule = createAndroidComposeRule<MainActivity>()
    @Test fun opensAboveIme() {
        mount()
        openIme()
        val panel = rule.onNodeWithTag("results").fetchSemanticsNode().boundsInWindow
        assertTrue(panel.bottom <= keyboardTop())
    }
    @Test fun restoresAfterDismissal() {
        mount()
        val before = bounds()
        openIme()
        pressBack()
        rule.waitUntil { !imeVisible() }
        assertEquals(before, bounds())
    }
    private fun mount() { REPLACEMENT }
    private fun openIme() {
        rule.onNodeWithTag("search_input").performClick()
        rule.waitUntil { imeVisible() }
    }
    private fun imeVisible(): Boolean {
        val insets = ViewCompat.getRootWindowInsets(rule.activity.window.decorView)
        val bottom = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
        return insets.isVisible(WindowInsetsCompat.Type.ime()) && bottom > 0
    }
    private fun bounds() = rule.onNodeWithTag("results").fetchSemanticsNode().boundsInWindow
    private fun keyboardTop() = rule.activity.window.decorView.height -
        ViewCompat.getRootWindowInsets(rule.activity.window.decorView).getInsets(WindowInsetsCompat.Type.ime()).bottom
}
'''.replace("REPLACEMENT", replacement_call))
        self.plan.write_text(
            "# Test plan\n\n## IME Production Boundary\n\n" + BOUNDARY_HEADER + "\n|" + "---|" * 7 + "\n"
            f"| Search | search_input | MainActivity | {self.test_file}#opensAboveIme | "
            f"{self.test_file}#restoresAfterDismissal | ./gradlew connectedDebugAndroidTest "
            "-Pandroid.testInstrumentationRunnerArguments.class=example.SearchImeTest | evidence/connected.xml |\n"
        )
        (self.root / "evidence").mkdir(exist_ok=True)
        (self.root / "evidence/connected.xml").write_text(
            '<testsuite tests="2" failures="0" errors="0" skipped="0">'
            '<testcase classname="example.SearchImeTest" name="opensAboveIme" />'
            '<testcase classname="example.SearchImeTest" name="restoresAfterDismissal" /></testsuite>'
        )

    def check(self, *args):
        return subprocess.run(["python3", str(CHECK), str(self.contract), *args], text=True, capture_output=True)

    def rejected(self, result, message):
        self.assertNotEqual(result.returncode, 0, f"unexpected PASS: {result.stdout}")
        self.assertIn(message, result.stdout + result.stderr)

    def test_missing_keyboard_inventory_rejected(self):
        self.write_contract(inventory=False, open_state=False)
        self.rejected(self.check(), "requires ## IME State Coverage")

    def test_input_state_mapping_passes(self):
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_open_design_rejected(self):
        self.write_contract(open_state=False)
        self.rejected(self.check(), "unknown keyboard-open state")

    def test_panel_crop_cannot_be_a_window_design(self):
        self.contract.write_text(self.contract.read_text().replace("| 430x932 | primary", "| 430x420 | primary"))
        for name in ("closed", "open"):
            self.png(name, 860, 840)
        self.rejected(self.check(), "must use the full window viewport")

    def test_search_button_is_not_an_editable_input(self):
        self.write_contract(inventory=False, open_state=False)
        self.contract.write_text(self.contract.read_text().replace("Search field", "Search button"))
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_focused_input_must_remain_visible(self):
        self.contract.write_text(self.contract.read_text().replace("screen-no-toolbar | search_input; results", "screen-no-toolbar | results"))
        self.rejected(self.check(), "must include the focused Input tag")

    def test_keyboard_must_be_in_open_design(self):
        self.write_contract(ime_region=False)
        self.rejected(self.check(), "must include system-ime")

    def test_real_activity_and_results_pass(self):
        result = self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_replaced_activity_content_rejected(self):
        self.write_runtime(replacement=True)
        self.rejected(self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root)),
                      "must not replace production Activity content")

    def test_skipped_runtime_cannot_pass(self):
        report = self.root / "evidence/connected.xml"
        report.write_text(report.read_text().replace('name="opensAboveIme" />', 'name="opensAboveIme"><skipped /></testcase>'))
        self.rejected(self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root)),
                      "did not pass")

    def test_missing_runtime_cannot_pass(self):
        (self.root / "evidence/connected.xml").unlink()
        self.rejected(self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root)),
                      "missing IME result XML")

    def test_wrong_selected_class_cannot_pass(self):
        self.plan.write_text(self.plan.read_text().replace("class=example.SearchImeTest", "class=example.UnrelatedTest"))
        self.rejected(self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root)),
                      "does not select example.SearchImeTest")

    def test_failed_runtime_cannot_pass(self):
        report = self.root / "evidence/connected.xml"
        report.write_text(report.read_text().replace('name="opensAboveIme" />', 'name="opensAboveIme"><failure /></testcase>'))
        self.rejected(self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root)),
                      "did not pass")

    def test_generic_activity_cannot_pass(self):
        source = self.root / self.test_file
        source.write_text(source.read_text().replace("createAndroidComposeRule<MainActivity>", "createAndroidComposeRule<ComponentActivity>"))
        self.rejected(self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root)),
                      "declared production Activity")

    def test_unused_visibility_helper_cannot_supply_proof(self):
        source = self.root / self.test_file
        source.write_text(source.read_text().replace("rule.waitUntil { imeVisible() }", "rule.waitUntil { true }"))
        self.rejected(self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root)),
                      "must poll real IME visibility")

    def test_ime_words_in_comments_do_not_supply_proof(self):
        source = self.root / self.test_file
        source.write_text(source.read_text().replace("return insets.isVisible(WindowInsetsCompat.Type.ime()) && bottom > 0",
            "// isVisible WindowInsetsCompat.Type.ime()\n        return bottom > 0"))
        self.rejected(self.check("--test-plan", str(self.plan), "--runtime", "--project-root", str(self.root)),
                      "must poll real IME visibility")

    def write_workflow_artifacts(self):
        mapping = (
            "\n## Rule Applicability Test Mapping\n\nCanonical: spec_v1.md#rule-applicability\n\n| Rule ID | Evidence |\n|---|---|\n"
            "| ARCH | boundary |\n| IMPL | boundary |\n| TEST | boundary |\n| SUI | boundary |\n"
        )
        spec = "# IME bug\n\n## Rule Applicability\n\n| Rule ID | Decision | Evidence |\n|---|---|---|\n"
        for rule in ("ARCH", "IMPL", "TEST", "SUI", "L10N", "NAV", "API", "OBS", "ANL", "SEC"):
            decision = "Required" if rule in ("ARCH", "IMPL", "TEST", "SUI") else "Not applicable — no boundary change"
            spec += f"| {rule} | {decision} | fixture |\n"
        spec += (
            "\n## Screen States\n\n| Screen | State ID | Requirement | Acceptance Criteria |\n|---|---|---|---|\n"
            "| Search | closed | FR-1 | restored |\n| Search | open | FR-1 | above IME |\n"
            "\n## Reproduction Test\n\n- Test name: `opensAboveIme`\n- Production activity: `MainActivity`\n"
            f"- File: `{self.test_file}`\n- Run result: RED (expected geometry failure)\n"
        )
        (self.root / "spec_v1.md").write_text(spec)
        (self.root / "summary_v1.md").write_text("| Bug Reproduction | Complete RED | fixture |\n")
        implementation = "# Plan\n" + mapping + "\n## UI State Stages\n\n| Stage ID | Implementation | Roborazzi target | Verification |\n|---|---|---|---|\n"
        for index, name in enumerate(("closed", "open"), 1):
            implementation += (
                f"| UI-0{index} | Render {name} | app/src/test/java/example/roborazzi/PickerRoborazziTest.kt#{name} | "
                f"design/mockup_{name}.png: ./gradlew app:verifyRoborazziDebug --tests example.PickerRoborazziTest.{name} |\n"
            )
        (self.root / "implementation_plan_v1.md").write_text(implementation)
        self.plan.write_text(self.plan.read_text() + mapping)

    def stage(self, stage):
        return subprocess.run(["bash", str(GATE), "bug-fixing", stage, str(self.root)],
                              env={**os.environ, "HARNESS_PROJECT_ROOT": str(self.root)}, text=True, capture_output=True)

    def test_bugfix_plan_gate_checks_ime_design(self):
        self.write_workflow_artifacts()
        self.write_contract(inventory=False)
        self.rejected(self.stage("implementation-plan"), "requires ## IME State Coverage")

    def test_bugfix_red_gate_rejects_content_fixture(self):
        self.write_runtime(replacement=True)
        self.write_workflow_artifacts()
        self.rejected(self.stage("bug-reproduction"), "must not replace production Activity content")

    def test_bugfix_red_gate_accepts_production_boundary(self):
        self.write_workflow_artifacts()
        result = self.stage("bug-reproduction")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_bugfix_testing_gate_checks_ime_without_nav_change(self):
        self.write_runtime(replacement=True)
        self.write_workflow_artifacts()
        self.rejected(self.stage("testing"), "must not replace production Activity content")

    def test_bugfix_testing_gate_accepts_production_boundary(self):
        self.write_workflow_artifacts()
        result = self.stage("testing")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_toolbarless_text_screen_requires_keyboard_mockup(self):
        self.write_contract(inventory=False, open_state=False)
        result = subprocess.run(["bash", str(ROOT / "harness/scripts/check-keyboard-mockup-contract.sh"), str(self.root)],
                                text=True, capture_output=True)
        self.rejected(result, "requires ## IME State Coverage")

    def test_inventory_accepts_pending_visuals_with_complete_ime_behavior(self):
        text = self.contract.read_text()
        for name in ("closed", "open"):
            text = text.replace(f"design/source.pen | {name}-node | screen-frame | design/mockup_{name}.png",
                                "Pending | Pending | Pending | Pending")
        self.contract.write_text(text)
        for asset in (self.root / "design").iterdir():
            asset.unlink()
        result = self.check("--inventory")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.rejected(self.check(), "pending design references")

    def test_inventory_rejects_missing_ime_states_before_pen(self):
        self.write_contract(inventory=False)
        self.rejected(self.check("--inventory"), "requires ## IME State Coverage")

    def test_sheet_requires_stays_open_policy(self):
        self.contract.write_text(self.contract.read_text().replace("Search field", "Bottom sheet search field"))
        self.rejected(self.check(), "bottom-sheet input must declare sheet-stays-open")
        self.contract.write_text(self.contract.read_text().replace("screen-no-toolbar", "sheet-stays-open"))
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_screen_toolbar_requires_dismissal_policy(self):
        self.contract.write_text(self.contract.read_text().replace("Search field", "Search field; bottom toolbar"))
        self.rejected(self.check(), "must declare screen-toolbar-dismissed")
        self.contract.write_text(self.contract.read_text().replace("screen-no-toolbar", "screen-toolbar-dismissed"))
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unknown_keyboard_behavior_rejected(self):
        self.contract.write_text(self.contract.read_text().replace("screen-no-toolbar", "Pending"))
        self.rejected(self.check(), "IME Keyboard behavior must be")


if __name__ == "__main__":
    unittest.main()
