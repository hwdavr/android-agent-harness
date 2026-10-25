#!/usr/bin/env bash
# Legacy test entry point; UI_contract IME cases own keyboard design coverage.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/ime-state-boundary-contract-test.py" \
  ImeContractTest.test_missing_keyboard_inventory_rejected \
  ImeContractTest.test_input_state_mapping_passes \
  ImeContractTest.test_missing_open_design_rejected \
  ImeContractTest.test_panel_crop_cannot_be_a_window_design \
  ImeContractTest.test_focused_input_must_remain_visible \
  ImeContractTest.test_keyboard_must_be_in_open_design \
  ImeContractTest.test_toolbarless_text_screen_requires_keyboard_mockup \
  ImeContractTest.test_inventory_accepts_pending_visuals_with_complete_ime_behavior \
  ImeContractTest.test_inventory_rejects_missing_ime_states_before_pen \
  ImeContractTest.test_sheet_requires_stays_open_policy \
  ImeContractTest.test_screen_toolbar_requires_dismissal_policy \
  ImeContractTest.test_unknown_keyboard_behavior_rejected
