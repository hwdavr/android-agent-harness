#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-ui-verification-artifact.sh"
STAGE_VALIDATOR="$REPO_ROOT/harness/scripts/check-stage-artifacts.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/ui-verification-artifact-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

write_valid_fixture() {
  local docs_dir="$1"
  mkdir -p "$docs_dir/design" "$docs_dir/evidence"
  printf 'reference mockup' > "$docs_dir/design/mockup_editor.png"
  printf 'actual screenshot' > "$docs_dir/evidence/editor_actual.png"
  cat > "$docs_dir/ui_verification.json" <<'FIXTURE'
{
  "version": "1",
  "reference_design": "design/mockup_editor.png",
  "build_and_static_checks": {
    "assembleDebug": "PASS",
    "lintDebug": "PASS",
    "ktlintCheck": "PASS"
  },
  "instrumented_tests": { "passed": "5", "total": "5" },
  "normalization": {
    "reference_resolution": "390x844",
    "reference_density": "2x",
    "runtime_resolution": "1080x2400",
    "runtime_density": "2.75x",
    "logical_space": "393x873 dp",
    "theme": { "reference": "light", "runtime": "light", "match": true },
    "font_scale": { "reference": 1.0, "runtime": 1.0, "match": true },
    "locale": { "reference": "en-US", "runtime": "en-US", "match": true }
  },
  "scope": {
    "type": "partial",
    "area_of_interest": "table handles",
    "rationale": "spec US-2",
    "in_scope_regions": ["table_handles"],
    "out_of_scope_regions": ["header"]
  },
  "regression_checks": [
    { "region": "header", "exists": true, "not_clipped": true, "no_layout_shift": true, "result": "PASS" }
  ],
  "region_decomposition": [
    { "region": "table_handles", "bounds_dp": { "x_start": 0, "x_end": 390, "y_start": 200, "y_end": 600 } }
  ],
  "structural_verification": {
    "tolerances": { "position_dp": 4, "size_percent": 5, "spacing_dp": 4 },
    "checks": [
      {
        "region": "table_handles",
        "element": "row_handle",
        "property": "alignment",
        "expected": "right edge == grid left ± 2dp",
        "actual": "right edge == grid left + 1dp",
        "within_tolerance": true,
        "result": "PASS"
      }
    ]
  },
  "dynamic_content_masking": [],
  "perceptual_comparison": [
    { "region": "table_handles", "confidence": "high", "notes": "handles match reference" }
  ],
  "defect_classification": [],
  "ai_visual_evaluation": {
    "status": "PASS",
    "area_of_interest": "table handles",
    "issues": [],
    "regression_summary": { "header": "PASS — exists, visible, no layout shift" }
  },
  "design_deviations": [],
  "verdict": {
    "result": "PASS",
    "reason": "",
    "critical_findings": 0,
    "major_findings_unresolved": 0,
    "minor_findings_warnings": 0
  }
}
FIXTURE
}

write_evidence_backed_fixture() {
  local docs_dir="$1"
  mkdir -p "$docs_dir/design" "$docs_dir/evidence"
  printf 'reference mockup' > "$docs_dir/design/mockup_editor.png"
  printf '%2048s' 'x' > "$docs_dir/evidence/editor_actual.png"
  cat > "$docs_dir/design/design_anchors.json" <<'FIXTURE'
{
  "version": "1",
  "coordinate_space": { "unit": "dp" },
  "anchors": [
    {
      "screen": "editor",
      "element_id": "editor_row_handle_visual",
      "metric": "height",
      "expected": 24,
      "tolerance_dp": 2
    }
  ]
}
FIXTURE
  cat > "$docs_dir/evidence/ui_frames.json" <<'FIXTURE'
{
  "version": "1",
  "producer": {
    "kind": "ComposeUiTest",
    "test_name": "com.example.notesapp.EditorVisualFlowTest#captureEditor"
  },
  "coordinate_space": { "unit": "dp" },
  "normalization": { "theme": "light", "font_scale": 1, "locale": "en-US" },
  "screens": [
    {
      "name": "editor",
      "screenshot": "evidence/editor_actual.png",
      "elements": {
        "editor_row_handle_visual": { "x": 344, "y": 288, "width": 24, "height": 25 }
      }
    }
  ]
}
FIXTURE
  cat > "$docs_dir/ui_verification.json" <<'FIXTURE'
{
  "version": "2",
  "reference_design": "design/mockup_editor.png",
  "design_anchors": "design/design_anchors.json",
  "runtime_evidence": "evidence/ui_frames.json",
  "visual_contract": {
    "required_roles": ["visual_bounds"],
    "checks": [
      {
        "screen": "editor",
        "element_id": "editor_row_handle_visual",
        "role": "visual_bounds",
        "runtime_test": "com.example.notesapp.EditorVisualFlowTest#captureEditor",
        "assertion": "The rendered handle shape is measured separately from its touch target."
      }
    ]
  },
  "build_and_static_checks": { "assembleDebug": "PASS", "lintDebug": "PASS", "ktlintCheck": "PASS" },
  "instrumented_tests": { "passed": "1", "total": "1" },
  "normalization": {
    "reference_resolution": "390x844",
    "runtime_resolution": "393x873",
    "logical_space": "390x844 dp",
    "theme": { "reference": "light", "runtime": "light", "match": true },
    "font_scale": { "reference": 1, "runtime": 1, "match": true },
    "locale": { "reference": "en-US", "runtime": "en-US", "match": true }
  },
  "scope": { "type": "partial", "area_of_interest": "table handle", "rationale": "spec US-2", "in_scope_regions": ["table_handle"], "out_of_scope_regions": ["header"] },
  "region_decomposition": [{ "region": "table_handle", "bounds_dp": { "x_start": 0, "x_end": 390, "y_start": 200, "y_end": 600 } }],
  "structural_verification": {
    "checks": [{ "region": "table_handle", "screen": "editor", "element_id": "editor_row_handle_visual", "metric": "height", "note": "The handle stays compact." }]
  },
  "defect_classification": [],
  "ai_visual_evaluation": { "status": "PASS", "area_of_interest": "table handle", "issues": [], "regression_summary": { "header": "PASS" } },
  "verdict": { "result": "PASS", "reason": "", "critical_findings": 0, "major_findings_unresolved": 0, "minor_findings_warnings": 0 }
}
FIXTURE
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "FAIL: validator unexpectedly accepted fixture" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "FAIL: validator did not report '$expected'." >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
}

# Test 1: valid fixture passes both validators
valid="$fixture_root/valid"
write_valid_fixture "$valid"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$valid")
(cd "$REPO_ROOT" && bash "$STAGE_VALIDATOR" create-ui-and-verify ui-verification "$valid")

# Test 1b: the machine-readable Android evidence contract calculates bounds
# from Compose frames and requires the visual-risk contract for version 2 PASS.
evidence_backed="$fixture_root/evidence-backed"
write_evidence_backed_fixture "$evidence_backed"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$evidence_backed")
(cd "$REPO_ROOT" && bash "$STAGE_VALIDATOR" create-ui-and-verify ui-verification "$evidence_backed")

missing_visual_contract="$fixture_root/missing-visual-contract"
write_evidence_backed_fixture "$missing_visual_contract"
jq 'del(.visual_contract)' "$missing_visual_contract/ui_verification.json" > "$missing_visual_contract/ui_verification.tmp"
mv "$missing_visual_contract/ui_verification.tmp" "$missing_visual_contract/ui_verification.json"
expect_failure "version 2+ PASS reports must declare non-empty visual_contract roles and checks" \
  bash "$VALIDATOR" "$missing_visual_contract"

missing_visual_frame="$fixture_root/missing-visual-frame"
write_evidence_backed_fixture "$missing_visual_frame"
jq '.visual_contract.checks[0].element_id = "missing_visual_icon"' \
  "$missing_visual_frame/ui_verification.json" > "$missing_visual_frame/ui_verification.tmp"
mv "$missing_visual_frame/ui_verification.tmp" "$missing_visual_frame/ui_verification.json"
expect_failure "visual_contract check visual_bounds/editor/missing_visual_icon is missing from runtime evidence" \
  bash "$VALIDATOR" "$missing_visual_frame"

target_only_handle_anchor="$fixture_root/target-only-handle-anchor"
write_evidence_backed_fixture "$target_only_handle_anchor"
sed 's/editor_row_handle_visual/editor_row_handle/g' \
  "$target_only_handle_anchor/design/design_anchors.json" > "$target_only_handle_anchor/design/design_anchors.tmp"
mv "$target_only_handle_anchor/design/design_anchors.tmp" "$target_only_handle_anchor/design/design_anchors.json"
expect_failure "must use the handle's visual shape identifier, not interactive target editor_row_handle" \
  bash "$VALIDATOR" "$target_only_handle_anchor"

oversized="$fixture_root/oversized-anchor"
write_evidence_backed_fixture "$oversized"
jq '.screens[0].elements.editor_row_handle_visual.height = 32' \
  "$oversized/evidence/ui_frames.json" > "$oversized/evidence/ui_frames.tmp"
mv "$oversized/evidence/ui_frames.tmp" "$oversized/evidence/ui_frames.json"
expect_failure "editor/editor_row_handle_visual/height is outside tolerance: expected 24 dp ± 2 dp, measured 32 dp" \
  bash "$VALIDATOR" "$oversized"

# Test 2: missing structural checks fails
missing_checks="$fixture_root/missing-checks"
write_valid_fixture "$missing_checks"
jq '.structural_verification.checks = []' "$missing_checks/ui_verification.json" \
  > "$missing_checks/ui_verification.tmp"
mv "$missing_checks/ui_verification.tmp" "$missing_checks/ui_verification.json"
expect_failure "needs at least one structural_verification check" \
  bash "$VALIDATOR" "$missing_checks"

# Test 3: missing verdict fails
missing_verdict="$fixture_root/missing-verdict"
write_valid_fixture "$missing_verdict"
jq 'del(.verdict)' "$missing_verdict/ui_verification.json" \
  > "$missing_verdict/ui_verification.tmp"
mv "$missing_verdict/ui_verification.tmp" "$missing_verdict/ui_verification.json"
expect_failure "missing required key 'verdict'" \
  bash "$VALIDATOR" "$missing_verdict"

# Test 4: missing reference design asset fails
missing_asset="$fixture_root/missing-asset"
write_valid_fixture "$missing_asset"
rm "$missing_asset/design/mockup_editor.png"
expect_failure "references missing or empty design asset" \
  bash "$VALIDATOR" "$missing_asset"

echo "PASS: UI verification artifact validator correctly validates JSON structure and rejects invalid fixtures."
