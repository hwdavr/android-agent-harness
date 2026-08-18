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
