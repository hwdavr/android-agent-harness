#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-existing-screen-baseline-contract.sh"
STAGE_GATE="$REPO_ROOT/harness/scripts/check-stage-artifacts.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/existing-screen-baseline-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

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

write_spec() {
  local feature_dir="$1"
  printf '%s\n' \
    '# Spec' \
    '' \
    '## Screen States' \
    '' \
    '## Rule Applicability' \
    '' \
    '| Rule ID | Rule document | Decision | Evidence |' \
    '|---|---|---|---|' \
    '| ARCH | rule.md | Required | fixture |' \
    '| IMPL | rule.md | Required | fixture |' \
    '| TEST | rule.md | Required | fixture |' \
    '| SUI | rule.md | Required | fixture |' \
    '| L10N | rule.md | Not applicable — no copy | fixture |' \
    '| NAV | rule.md | Not applicable — no route | fixture |' \
    '| API | rule.md | Not applicable — no API | fixture |' \
    '| OBS | rule.md | Not applicable — no boundary | fixture |' \
    '| ANL | rule.md | Not applicable — analytics: none | fixture |' \
    '| SEC | rule.md | Not applicable — no security boundary | fixture |' \
    > "$feature_dir/spec.md"
}

write_test() {
  local root="$1"
  mkdir -p "$root/app/src/androidTest/java/example"
  printf '%s\n' \
    'package example' \
    '' \
    'class ExistingScreenVisualFlowTest {' \
    '    fun captureExistingSurface() {' \
    '        saveScreenshot("existing_editor.png")' \
    '    }' \
    '' \
    '    private fun saveScreenshot(fileName: String) {' \
    '        uiAutomation.takeScreenshot()' \
    '        uiAutomation.executeShellCommand("cp /tmp/$fileName /sdcard/Download/$fileName")' \
    '    }' \
    '}' \
    > "$root/app/src/androidTest/java/example/ExistingScreenVisualFlowTest.kt"
}

write_design() {
  local feature_dir="$1"
  local include_baseline="$2"
  mkdir -p "$feature_dir/design"
  printf '%s\n' \
    '# Design' \
    'Project design system: `docs/product/design_system.md`' \
    '' \
    '## Screens Covered' \
    '' \
    '| # | Screen / Surface | Status |' \
    '|---|---|---|' \
    '| 1 | Existing Editor | Updated |' \
    '' \
    > "$feature_dir/design.md"
  if [ "$include_baseline" = "yes" ]; then
    printf '%s\n' \
      '## Existing Surface Baseline' \
      '' \
      '| Existing surface | Baseline decision | Source test | Test method | Test-produced capture | Pulled baseline asset | Emulator execution evidence |' \
      '|------------------|-------------------|-------------|-------------|-----------------------|-----------------------|-----------------------------|' \
      '| Existing Editor | Required | `app/src/androidTest/java/example/ExistingScreenVisualFlowTest.kt` | `captureExistingSurface` | `existing_editor.png` | `design/baseline_existing_editor.png` | `ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest — PASSED, 1/1 tests` |' \
      >> "$feature_dir/design.md"
    printf 'source-fed png fixture' > "$feature_dir/design/baseline_existing_editor.png"
  fi
}

missing="$fixture_root/missing"
mkdir -p "$missing"
write_spec "$missing"
write_design "$missing" "no"
expect_failure "missing the '## Existing Surface Baseline' section" \
  env HARNESS_PROJECT_ROOT="$fixture_root" bash "$VALIDATOR" "$missing"

valid="$fixture_root/valid"
mkdir -p "$valid"
write_test "$fixture_root"
write_design "$valid" "yes"
env HARNESS_PROJECT_ROOT="$fixture_root" bash "$VALIDATOR" "$valid"

stage_missing="$fixture_root/stage-missing"
mkdir -p "$stage_missing"
write_spec "$stage_missing"
write_design "$stage_missing" "no"
expect_failure "missing the '## Existing Surface Baseline' section" \
  env HARNESS_PROJECT_ROOT="$fixture_root" bash "$STAGE_GATE" harness-planning feature-specification "$stage_missing"

echo "PASS: existing-surface baseline validator accepts source-fed evidence and rejects missing planning baselines."
