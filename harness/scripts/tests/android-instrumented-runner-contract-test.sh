#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(pwd)"
RUNNER="$REPO_ROOT/harness/scripts/run-android-instrumented-tests.sh"
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/android-instrumented-runner.XXXXXX")
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

mkdir -p "$FIXTURE_ROOT/project/app/src/androidTest" "$FIXTURE_ROOT/bin"
touch "$FIXTURE_ROOT/project/app/src/androidTest/ExampleTest.kt"
cat > "$FIXTURE_ROOT/project/gradlew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GRADLE_LOG"
mkdir -p app/build/outputs/apk/debug app/build/outputs/apk/androidTest/debug
touch app/build/outputs/apk/debug/app-debug.apk
touch app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
EOF
chmod +x "$FIXTURE_ROOT/project/gradlew"

cat > "$FIXTURE_ROOT/bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_ADB_LOG"
case "$*" in
  *"get-state")
    echo device
    ;;
  *"pm list instrumentation")
    echo 'instrumentation:com.example.notesapp.test/com.example.notesapp.HiltTestRunner (target=com.example.notesapp)'
    ;;
  *"shell am instrument"*)
    if [ "${FAKE_EMPTY_TESTS:-false}" = true ]; then
      echo 'INSTRUMENTATION_RESULT: stream=\nOK (0 tests)'
      echo 'INSTRUMENTATION_CODE: -1'
      exit 0
    fi
    echo 'INSTRUMENTATION_STATUS: class=com.example.notesapp.ExampleTest'
    echo 'INSTRUMENTATION_STATUS: test=firstCase'
    echo 'INSTRUMENTATION_STATUS_CODE: 0'
    echo 'INSTRUMENTATION_STATUS: class=com.example.notesapp.ExampleTest'
    echo 'INSTRUMENTATION_STATUS: test=secondCase'
    if [ "${FAKE_TEST_FAILURE:-false}" = true ]; then
      echo 'INSTRUMENTATION_STATUS_CODE: -2'
      echo 'FAILURES!!!'
      echo 'Tests run: 2,  Failures: 1'
    else
      echo 'INSTRUMENTATION_STATUS_CODE: 0'
      echo 'INSTRUMENTATION_RESULT: stream=\nOK (2 tests)'
    fi
    echo 'INSTRUMENTATION_CODE: -1'
    ;;
  *"pm path com.example.notesapp.test")
    echo 'package:/data/app/test/base.apk'
    ;;
  *"pm path com.example.notesapp")
    if [ "${FAKE_APP_MISSING:-false}" != true ]; then
      echo 'package:/data/app/main/base.apk'
    fi
    ;;
  *"install -r"*)
    echo Success
    ;;
  *)
    echo "unexpected adb invocation: $*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FIXTURE_ROOT/bin/adb"

export PATH="$FIXTURE_ROOT/bin:$PATH"
export FAKE_ADB_LOG="$FIXTURE_ROOT/adb.log"
export FAKE_GRADLE_LOG="$FIXTURE_ROOT/gradle.log"
export ANDROID_TEST_PROJECT_ROOT="$FIXTURE_ROOT/project"
export ANDROID_SERIAL="fixture-device"

success_log="$FIXTURE_ROOT/success"
bash "$RUNNER" --class com.example.notesapp.ExampleTest#firstCase --output-dir "$success_log" \
  > "$FIXTURE_ROOT/success.out"
grep -Fq 'PASS: 2 instrumented test(s)' "$FIXTURE_ROOT/success.out" \
  || { echo "FAIL: success case did not report its non-zero test count" >&2; cat "$FIXTURE_ROOT/success.out" >&2; exit 1; }
grep -Fq ':app:assembleDebug :app:assembleDebugAndroidTest' "$FAKE_GRADLE_LOG" \
  || { echo 'FAIL: runner did not build the app and test APKs' >&2; exit 1; }
grep -Fq 'shell am instrument -w -r -e class com.example.notesapp.ExampleTest#firstCase' "$FAKE_ADB_LOG" \
  || { echo 'FAIL: runner did not invoke AndroidJUnitRunner with the selected class/method' >&2; exit 1; }
success_xml="$success_log/TEST-com.example.notesapp.ExampleTest_firstCase.xml"
[ -f "$success_xml" ] \
  || { echo 'FAIL: runner did not produce its JUnit XML evidence' >&2; exit 1; }
grep -Fq 'tests="2" failures="0"' "$success_xml" \
  || { echo 'FAIL: successful JUnit XML did not record the executed test count' >&2; exit 1; }
grep -Fq 'name="firstCase"' "$success_xml" \
  || { echo 'FAIL: JUnit XML omitted the executed test method' >&2; exit 1; }
grep -Fq 'pm path com.example.notesapp' "$FAKE_ADB_LOG" \
  || { echo 'FAIL: runner did not verify that the app package remains installed' >&2; exit 1; }
if grep -Eiq '(^|[[:space:]])uninstall([[:space:]]|$)|connectedDebugAndroidTest' "$FAKE_ADB_LOG" "$FAKE_GRADLE_LOG"; then
  echo 'FAIL: runner attempted an uninstall or connected-test task' >&2
  exit 1
fi

# Grouped journeys can exceed the filesystem's per-component filename limit.
# The full selector list must still be passed to AndroidJUnitRunner.
long_args=()
for index in $(seq 1 12); do
  long_args+=(--class "com.example.notesapp.deeply.nested.Journey${index}InstrumentedTest#returnsToDestination")
done
long_output="$FIXTURE_ROOT/long-selectors"
bash "$RUNNER" "${long_args[@]}" --output-dir "$long_output" > "$FIXTURE_ROOT/long.out"
grep -Fq 'PASS: 2 instrumented test(s)' "$FIXTURE_ROOT/long.out" \
  || { echo 'FAIL: grouped selectors did not complete' >&2; exit 1; }
grep -Fq 'Journey12InstrumentedTest#returnsToDestination' "$FAKE_ADB_LOG" \
  || { echo 'FAIL: grouped selectors were truncated in the runner invocation' >&2; exit 1; }
long_xml=$(find "$long_output" -name 'TEST-*.xml' -print)
[ -f "$long_xml" ] || { echo 'FAIL: grouped run did not produce JUnit XML' >&2; exit 1; }
grep -Fq 'tests="2" failures="0"' "$long_xml" \
  || { echo 'FAIL: grouped run XML does not contain its test results' >&2; exit 1; }
grep -Fq 'Journey1InstrumentedTest#returnsToDestination' "$long_output"/*.log \
  || { echo 'FAIL: grouped log omitted the first selector' >&2; exit 1; }
grep -Fq 'Journey12InstrumentedTest#returnsToDestination' "$long_output"/*.log \
  || { echo 'FAIL: grouped log omitted the last selector' >&2; exit 1; }
long_args+=(--class 'com.example.notesapp.ExtraJourneyTest#anotherDestination')
bash "$RUNNER" "${long_args[@]}" --output-dir "$long_output" > "$FIXTURE_ROOT/long-second.out"
[ "$(find "$long_output" -name 'TEST-*.xml' | wc -l | tr -d ' ')" = 2 ] \
  || { echo 'FAIL: different long selector lists produced the same evidence filename' >&2; exit 1; }

failure_log="$FIXTURE_ROOT/failure"
if FAKE_TEST_FAILURE=true bash "$RUNNER" --class com.example.notesapp.ExampleTest --output-dir "$failure_log" \
  > "$FIXTURE_ROOT/failure.out" 2>&1; then
  echo 'FAIL: runner accepted a failing test result' >&2
  exit 1
fi
failure_xml="$failure_log/TEST-com.example.notesapp.ExampleTest.xml"
grep -Fq 'failures="1"' "$failure_xml" \
  || { echo 'FAIL: failed run did not produce failing JUnit XML evidence' >&2; exit 1; }
grep -Fq 'pm path com.example.notesapp' "$FAKE_ADB_LOG" \
  || { echo 'FAIL: runner skipped the post-run package check after a test failure' >&2; exit 1; }

empty_log="$FIXTURE_ROOT/empty"
if FAKE_EMPTY_TESTS=true bash "$RUNNER" --class com.example.notesapp.ExampleTest --output-dir "$empty_log" \
  > "$FIXTURE_ROOT/empty.out" 2>&1; then
  echo 'FAIL: runner accepted an empty test result' >&2
  exit 1
fi
grep -Fq 'non-zero test count' "$FIXTURE_ROOT/empty.out" \
  || { echo 'FAIL: empty run did not report the missing non-zero test count' >&2; exit 1; }

missing_package_log="$FIXTURE_ROOT/missing-package"
if FAKE_APP_MISSING=true bash "$RUNNER" --class com.example.notesapp.ExampleTest --output-dir "$missing_package_log" \
  > "$FIXTURE_ROOT/missing-package.out" 2>&1; then
  echo 'FAIL: runner accepted a post-test missing app package' >&2
  exit 1
fi
grep -Fq 'is not installed after instrumentation' "$FIXTURE_ROOT/missing-package.out" \
  || { echo 'FAIL: missing package did not produce the expected failure' >&2; exit 1; }

echo 'PASS: direct AndroidJUnitRunner preserves package state and rejects failed/empty runs.'
