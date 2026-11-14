#!/usr/bin/env python3
"""A screen-frame design is a whole screen: a review capture of a padded component must be rejected."""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / "harness/scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("check_ui_contract", SCRIPTS / "check-ui-contract.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)

REVIEW = "app/src/test/java/example/roborazzi/ShareReviewCaptureTest.kt"

CHROME_FRAME = (
    "@Composable\nfun ShareFrame(state: State) {\n"
    "    Box {\n"
    "        Scaffold(contentWindowInsets = WindowInsets(top = StatusBarHeight)) { ShareScreenContent(state) }\n"
    "        ReviewStatusBar()\n"
    "    }\n}\n"
)
SCRIM_FRAME = (
    "@Composable\nfun ShareFrame(state: State) {\n"
    "    Box {\n"
    "        Scaffold(contentWindowInsets = WindowInsets(top = StatusBarHeight)) { ShareScreenContent(state) }\n"
    "        ReviewStatusBar()\n"
    "        Box(Modifier.background(Color.Black.copy(alpha = 0.32f))) // scrim\n"
    "    }\n}\n"
)


class ScreenFrameCaptureTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="screen-frame-capture-")
        self.root = Path(self.temp.name)
        for directory in ("app/src/main/java/example", "app/src/test/java/example/roborazzi"):
            (self.root / directory).mkdir(parents=True)
        (self.root / "app/src/main/java/example/ShareScreen.kt").write_text(
            "fun ShareScreenContent(state: State) { }\nfun ShareChip(label: String) { }\n")

    def tearDown(self):
        self.temp.cleanup()

    def review(self, body, helpers=""):
        (self.root / REVIEW).write_text(
            "class ShareReviewCaptureTest {\n    @Test\n    fun padded() {\n" + body + "\n    }\n}\n")
        if helpers:
            (self.root / "app/src/test/java/example/ShareFrames.kt").write_text(helpers)

    def run_check(self, controls="Search field; results"):
        return CHECK.validate_screen_frame_capture(self.root, f"{REVIEW}#padded", "share-open", controls)

    def test_padded_component_is_rejected(self):
        self.review("        render { Box(Modifier.fillMaxSize()) { ShareChip(label) } }\n"
                    "        captureRoboImage(\"share-open.png\")")
        with self.assertRaisesRegex(ValueError, "renders no production screen"):
            self.run_check()

    def test_production_screen_passes(self):
        self.review("        render { ShareFrame(state) }\n        captureRoboImage(\"share-open.png\")", helpers=CHROME_FRAME)
        self.run_check()

    def test_screen_without_a_system_bar_inset_is_rejected(self):
        self.review("        render { ShareFrame(state) }\n        captureRoboImage(\"share-open.png\")",
                    helpers="@Composable\nfun ShareFrame(state: State) {\n    ReviewStatusBar()\n    ShareScreenContent(state)\n}\n")
        with self.assertRaisesRegex(ValueError, "applies no system-bar inset"):
            self.run_check()

    def test_screen_without_status_bar_chrome_is_rejected(self):
        self.review("        render { ShareFrame(state) }\n        captureRoboImage(\"share-open.png\")",
                    helpers="@Composable\nfun ShareFrame(state: State) {\n"
                            "    Scaffold(contentWindowInsets = WindowInsets(top = 24.dp)) { ShareScreenContent(state) }\n}\n")
        with self.assertRaisesRegex(ValueError, "draws no status bar"):
            self.run_check()

    def test_dialog_state_without_a_scrim_is_rejected(self):
        self.review("        render { ShareFrame(state) }\n        captureScreenRoboImage(\"share-open.png\")",
                    helpers=CHROME_FRAME)
        with self.assertRaisesRegex(ValueError, "dim scrim"):
            self.run_check(controls="Confirm dialog; results")

    def test_dialog_state_with_a_scrim_passes(self):
        self.review("        render { ShareFrame(state) }\n        captureScreenRoboImage(\"share-open.png\")",
                    helpers=SCRIM_FRAME)
        self.run_check(controls="Confirm dialog; results")

    def test_screen_reached_through_a_test_frame_helper_passes(self):
        self.review("        render { ShareFrame(state) }\n        captureRoboImage(\"share-open.png\")",
                    helpers=CHROME_FRAME)
        self.run_check()

    def test_helper_that_never_reaches_a_screen_is_rejected(self):
        self.review("        render { ShareFrame(state) }\n        captureRoboImage(\"share-open.png\")",
                    helpers="@Composable\nfun ShareFrame(state: State) {\n    ShareChip(label)\n}\n")
        with self.assertRaisesRegex(ValueError, "renders no production screen"):
            self.run_check()

    def test_sheet_state_needs_a_whole_window_capture(self):
        self.review("        render { ShareFrame(state) }\n        onRoot().captureRoboImage(\"share-open.png\")",
                    helpers=SCRIM_FRAME)
        with self.assertRaisesRegex(ValueError, "captureScreenRoboImage"):
            self.run_check(controls="Share bottom sheet; results")

    def test_sheet_state_with_whole_window_capture_passes(self):
        self.review("        render { ShareFrame(state) }\n        captureScreenRoboImage(\"share-open.png\")",
                    helpers=SCRIM_FRAME)
        self.run_check(controls="Share bottom sheet; results")

    def test_placeholder_file_without_the_method_keeps_existing_behavior(self):
        (self.root / REVIEW).write_text("class ShareReviewCaptureTest\n")
        self.run_check()


if __name__ == "__main__":
    unittest.main()
