#!/usr/bin/env bash

set -e

REPO_ROOT="$(pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-platform-evidence.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/platform-evidence-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

write_matrix() {
  local feature_dir="$1"
  local status="$2"
  {
    printf '%s\n' '# Platform Capability Matrix'
    printf '%s\n' '' '## Scope' '' '- Minimum API: 24' '- Target API: 34'
    printf '%s\n' '' '## Runtime Matrix' '' '| Runtime/API | Capability | Required behavior | Test ID / exact command | Environment evidence | Status |'
    printf '%s\n' '|---|---|---|---|---|---|' "| API 24 | capability | fallback | TC-US-REAL | fixture | $status |"
    printf '%s\n' '' '## Unsupported Environment Policy' '' 'Policy: fail_loudly. Missing environments must return non-zero or Blocked/Revise.'
  } > "$feature_dir/platform-capability-matrix.md"
}

write_contract() {
  local feature_dir="$1"
  {
    printf '%s\n' '# Sprint Contract' '' '## US-1: Platform behavior' '' '| Test ID | Covers AC | Test layer | Test file and method | Setup and action | Required assertions | Exact command |'
    printf '%s\n' '| TC-US-REAL | AC-US-1-01 | Instrumented UI | app/src/androidTest/java/example/PlatformTest.kt#realBoundary | fixture | real result | connectedDebugAndroidTest |'
  } > "$feature_dir/sprint-contract.md"
}

write_feature_list() {
  local feature_dir="$1"
  {
    printf '%s\n' '{'
    printf '%s\n' '  "platform_validation": {'
    printf '%s\n' '    "required": true,'
    printf '%s\n' '    "capability_matrix": "platform-capability-matrix.md",'
    printf '%s\n' '    "unsupported_environment_policy": "fail_loudly",'
    printf '%s\n' '    "real_boundary_test_required": true,'
    printf '%s\n' '    "real_boundary_test_ids": ["TC-US-REAL"],'
    printf '%s\n' '    "real_boundary_test_files": ["app/src/androidTest/java/example/PlatformTest.kt"],'
    printf '%s\n' '    "real_boundary_test_signal": "SpeechRecognizer"'
    printf '%s\n' '  },'
    printf '%s\n' '  "features": [{'
    printf '%s\n' '    "id": "US-1",'
    printf '%s\n' '    "acceptance_test_ids": ["TC-US-REAL"],'
    printf '%s\n' '    "evidence": [{'
    printf '%s\n' '      "test_id": "TC-US-REAL",'
    printf '%s\n' '      "exit_status": 0,'
    printf '%s\n' '      "executed_command": "ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest"'
    printf '%s\n' '    }]'
    printf '%s\n' '  }]'
    printf '%s\n' '}'
  } > "$feature_dir/feature_list.json"
}

expect_failure() {
  local command_output
  local expected="$1"
  shift
  if command_output=$("$@" 2>&1); then
    echo "FAIL: validator unexpectedly accepted fixture" >&2
    exit 1
  fi
  printf '%s\n' "$command_output" | grep -Fq "$expected" || {
    echo "FAIL: validator did not report '$expected'." >&2
    printf '%s\n' "$command_output" >&2
    exit 1
  }
}

missing_matrix="$fixture_root/missing-matrix"
mkdir -p "$missing_matrix"
write_contract "$missing_matrix"
write_feature_list "$missing_matrix"
expect_failure "platform capability matrix is missing" bash "$VALIDATOR" "$missing_matrix" --planning

pending_runtime="$fixture_root/pending-runtime"
mkdir -p "$pending_runtime/app/src/androidTest/java/example"
write_contract "$pending_runtime"
write_feature_list "$pending_runtime"
write_matrix "$pending_runtime" "Pending"
printf '%s\n' 'class PlatformTest { val recognizer = SpeechRecognizer.createSpeechRecognizer(context) }' > "$pending_runtime/app/src/androidTest/java/example/PlatformTest.kt"
expect_failure "pending/unavailable/blocked/skipped" bash "$VALIDATOR" "$pending_runtime" --evaluate

deferred_slice="$fixture_root/deferred-slice"
mkdir -p "$deferred_slice"
write_contract "$deferred_slice"
write_feature_list "$deferred_slice"
write_matrix "$deferred_slice" "Planned"
jq '.features[0].acceptance_test_ids = []' "$deferred_slice/feature_list.json" > "$deferred_slice/feature_list.json.tmp"
mv "$deferred_slice/feature_list.json.tmp" "$deferred_slice/feature_list.json"
(cd "$deferred_slice" && bash "$VALIDATOR" . --evaluate --slice US-1) | \
  grep -Fq "slice US-1 does not own a declared real platform boundary test"

owner_missing_evidence="$fixture_root/owner-missing-evidence"
mkdir -p "$owner_missing_evidence/app/src/androidTest/java/example"
write_contract "$owner_missing_evidence"
write_feature_list "$owner_missing_evidence"
write_matrix "$owner_missing_evidence" "Verified"
printf '%s\n' 'class PlatformTest { val recognizer = SpeechRecognizer.createSpeechRecognizer(context) }' > \
  "$owner_missing_evidence/app/src/androidTest/java/example/PlatformTest.kt"
jq '.features[0].evidence = []' "$owner_missing_evidence/feature_list.json" > \
  "$owner_missing_evidence/feature_list.json.tmp"
mv "$owner_missing_evidence/feature_list.json.tmp" "$owner_missing_evidence/feature_list.json"
expect_failure "has no successful connected-test evidence" bash "$VALIDATOR" "$owner_missing_evidence" --evaluate --slice US-1

fake_only="$fixture_root/fake-only"
mkdir -p "$fake_only/app/src/androidTest/java/example"
write_contract "$fake_only"
write_feature_list "$fake_only"
write_matrix "$fake_only" "Verified"
printf '%s\n' 'class PlatformTest { val recognizer = FakeTranscriptRecognizer() }' > "$fake_only/app/src/androidTest/java/example/PlatformTest.kt"
expect_failure "no real-platform signal" bash "$VALIDATOR" "$fake_only" --evaluate

valid="$fixture_root/valid"
mkdir -p "$valid/app/src/androidTest/java/example"
write_contract "$valid"
write_feature_list "$valid"
write_matrix "$valid" "Verified"
printf '%s\n' 'class PlatformTest { val recognizer = SpeechRecognizer.createSpeechRecognizer(context) }' > "$valid/app/src/androidTest/java/example/PlatformTest.kt"
(cd "$valid" && bash "$VALIDATOR" . --evaluate)

echo "PASS: platform evidence validator defers non-owning slices and rejects missing matrices, unavailable runtimes, fake-only tests, and boundary owners without evidence."
