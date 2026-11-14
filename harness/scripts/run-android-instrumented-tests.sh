#!/usr/bin/env bash
# Run app instrumented tests directly through AndroidJUnitRunner. The Gradle
# connected-test task is intentionally not used because UTP uninstalls the app
# package when it finishes.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  ANDROID_SERIAL=<device-serial> bash harness/scripts/run-android-instrumented-tests.sh --class <Class[#method]> [--class <Class[#method]> ...]
  ANDROID_SERIAL=<device-serial> bash harness/scripts/run-android-instrumented-tests.sh --all

Options:
  --serial <device-serial>   Select an Android device (defaults to ANDROID_SERIAL).
  --class <selector>         Run a fully-qualified class, optionally followed by #method.
                             Repeat to run multiple classes/methods in one process.
  --all                      Run every instrumented test in the test APK.
  --output-dir <directory>   Store the runner log and JUnit XML in this directory.
EOF
}

PROJECT_ROOT="${ANDROID_TEST_PROJECT_ROOT:-$PWD}"
GRADLEW="${ANDROID_TEST_GRADLEW:-$PROJECT_ROOT/gradlew}"
ADB_BIN="${ANDROID_TEST_ADB:-adb}"
SERIAL="${ANDROID_SERIAL:-}"
OUTPUT_DIR=""
RUN_ALL=false
SELECTORS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --serial)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      SERIAL="$2"
      shift 2
      ;;
    --class)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      SELECTORS+=("$2")
      shift 2
      ;;
    --all)
      RUN_ALL=true
      shift
      ;;
    --output-dir)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[ -d "$PROJECT_ROOT/app/src/androidTest" ] || {
  echo "FAIL: project root has no app/src/androidTest: $PROJECT_ROOT" >&2
  exit 2
}
[ -x "$GRADLEW" ] || {
  echo "FAIL: Gradle wrapper is not executable: $GRADLEW" >&2
  exit 2
}
command -v "$ADB_BIN" >/dev/null 2>&1 || {
  echo "FAIL: adb executable was not found: $ADB_BIN" >&2
  exit 2
}
[ -n "$SERIAL" ] || {
  echo "FAIL: set ANDROID_SERIAL or pass --serial to select the test device" >&2
  exit 2
}
if [ "$RUN_ALL" = true ] && [ "${#SELECTORS[@]}" -gt 0 ]; then
  echo "FAIL: --all cannot be combined with --class" >&2
  exit 2
fi
if [ "$RUN_ALL" = false ] && [ "${#SELECTORS[@]}" -eq 0 ]; then
  echo "FAIL: select at least one --class or pass --all" >&2
  exit 2
fi

APP_PACKAGE="com.example.notesapp"
TEST_PACKAGE="com.example.notesapp.test"
TEST_RUNNER="com.example.notesapp.HiltTestRunner"
APP_APK="$PROJECT_ROOT/app/build/outputs/apk/debug/app-debug.apk"
TEST_APK="$PROJECT_ROOT/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"

"$ADB_BIN" -s "$SERIAL" get-state | grep -Fxq "device" || {
  echo "FAIL: device $SERIAL is not online" >&2
  exit 2
}

echo "Building app and androidTest APKs without running the connected-test task."
(cd "$PROJECT_ROOT" && "$GRADLEW" :app:assembleDebug :app:assembleDebugAndroidTest)
[ -f "$APP_APK" ] || { echo "FAIL: app APK was not produced: $APP_APK" >&2; exit 1; }
[ -f "$TEST_APK" ] || { echo "FAIL: androidTest APK was not produced: $TEST_APK" >&2; exit 1; }

echo "Installing/updating $APP_PACKAGE with adb install -r."
"$ADB_BIN" -s "$SERIAL" install -r "$APP_APK"
echo "Installing/updating $TEST_PACKAGE with adb install -r -t."
"$ADB_BIN" -s "$SERIAL" install -r -t "$TEST_APK"

instrumentation_list=$("$ADB_BIN" -s "$SERIAL" shell pm list instrumentation)
printf '%s\n' "$instrumentation_list" | grep -Fq \
  "instrumentation:$TEST_PACKAGE/$TEST_RUNNER (target=$APP_PACKAGE)" || {
  echo "FAIL: expected instrumentation component is not installed: $TEST_PACKAGE/$TEST_RUNNER" >&2
  exit 1
}

if [ -z "$OUTPUT_DIR" ]; then
  RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  OUTPUT_DIR="$PROJECT_ROOT/.qa-artifacts/android-instrumented/$RUN_ID"
fi
mkdir -p "$OUTPUT_DIR"
selector_slug="all"
if [ "${#SELECTORS[@]}" -gt 0 ]; then
  selector_slug=$(printf '%s_' "${SELECTORS[@]}" | tr -cs 'A-Za-z0-9._-' '_')
  selector_slug="${selector_slug%_}"
  # Filesystems commonly limit each filename component to 255 bytes. Preserve
  # readable names for short runs; bind long names to the complete selector
  # list without truncating the AndroidJUnitRunner arguments or log command.
  if [ "${#selector_slug}" -gt 180 ]; then
    selector_hash=$(printf '%s\0' "${SELECTORS[@]}" | python3 -c \
      'import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:16])')
    selector_slug="${selector_slug:0:100}-sha256-${selector_hash}"
  fi
fi
RUN_LOG="$OUTPUT_DIR/${selector_slug}.log"
RUN_XML="$OUTPUT_DIR/TEST-${selector_slug}.xml"

runner_args=("$ADB_BIN" -s "$SERIAL" shell am instrument -w -r)
if [ "${#SELECTORS[@]}" -gt 0 ]; then
  selector_csv=$(IFS=,; printf '%s' "${SELECTORS[*]}")
  runner_args+=(-e class "$selector_csv")
fi
runner_args+=("$TEST_PACKAGE/$TEST_RUNNER")

printf 'COMMAND:' | tee "$RUN_LOG"
printf ' %q' "${runner_args[@]}" | tee -a "$RUN_LOG"
printf '\n' | tee -a "$RUN_LOG"

set +e
"${runner_args[@]}" 2>&1 | tee -a "$RUN_LOG"
runner_status=${PIPESTATUS[0]}
set -e

test_count=$(sed -nE 's/.*OK \(([1-9][0-9]*) tests?\).*/\1/p' "$RUN_LOG" | tail -n 1)
test_status=1
if [ "$runner_status" -eq 0 ] && [ -n "$test_count" ] && ! grep -Fq 'FAILURES!!!' "$RUN_LOG"; then
  test_status=0
fi

set +e
python3 - "$RUN_LOG" "$RUN_XML" "$test_count" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

log_path, xml_path, summary_count = sys.argv[1:]
text = Path(log_path).read_text(encoding="utf-8", errors="replace")
cases = []
status = {}
last_class = "unknown"
last_test = "unknown"
for line in text.splitlines():
    match = re.match(r"INSTRUMENTATION_STATUS: (class|test)=(.*)", line)
    if match:
        if match.group(1) == "class":
            last_class = match.group(2).strip() or "unknown"
        else:
            last_test = match.group(2).strip() or "unknown"
        continue
    match = re.match(r"INSTRUMENTATION_STATUS_CODE: (-?\d+)", line)
    if not match:
        continue
    code = int(match.group(1))
    if code == 1:
        status[(last_class, last_test)] = "started"
    elif code == 0 or code < 0:
        result = "passed" if code == 0 else "failed"
        cases.append((last_class, last_test, result, f"AndroidJUnitRunner status code {code}"))
        status.pop((last_class, last_test), None)

# Any started method without a terminal status is incomplete and must not be
# presented as a passing test.
for (class_name, test_name), state in status.items():
    if state == "started":
        cases.append((class_name, test_name, "failed", "Test started but had no terminal status"))

if not cases:
    raise SystemExit("FAIL: AndroidJUnitRunner emitted no per-test status records")
if summary_count and len(cases) != int(summary_count):
    raise SystemExit(
        f"FAIL: runner summary reports {summary_count} tests but emitted {len(cases)} terminal test records"
    )

failures = sum(result == "failed" for _, _, result, _ in cases)
summary_failed = "FAILURES!!!" in text or re.search(r"Tests run:\s*\d+,\s*Failures:\s*[1-9]", text)
if summary_failed and failures == 0:
    class_name, test_name, _, _ = cases[-1]
    cases[-1] = (class_name, test_name, "failed", "AndroidJUnitRunner summary reported a failure")
    failures = 1
suite = ET.Element("testsuite", {
    "name": "AndroidJUnitRunner",
    "tests": str(len(cases)),
    "failures": str(failures),
    "errors": "0",
    "skipped": "0",
})
for class_name, test_name, result, detail in cases:
    case = ET.SubElement(suite, "testcase", {"classname": class_name, "name": test_name})
    if result == "failed":
        failure = ET.SubElement(case, "failure", {"message": detail, "type": "InstrumentationFailure"})
        failure.text = detail
ET.indent(suite, space="  ")
ET.ElementTree(suite).write(xml_path, encoding="utf-8", xml_declaration=True)
if failures:
    raise SystemExit(f"FAIL: AndroidJUnitRunner reported {failures} failed test method(s)")
PY
xml_status=$?
set -e
if [ "$xml_status" -ne 0 ]; then
  test_status=1
fi

app_path=$("$ADB_BIN" -s "$SERIAL" shell pm path "$APP_PACKAGE" | tr -d '\r')
test_path=$("$ADB_BIN" -s "$SERIAL" shell pm path "$TEST_PACKAGE" | tr -d '\r')
{
  printf 'DEVICE_SERIAL=%s\n' "$SERIAL"
  printf 'APP_PACKAGE_PATH=%s\n' "${app_path:-MISSING}"
  printf 'TEST_PACKAGE_PATH=%s\n' "${test_path:-MISSING}"
  printf 'TEST_COUNT=%s\n' "${test_count:-0}"
  printf 'RUNNER_EXIT_STATUS=%s\n' "$runner_status"
  printf 'JUNIT_XML=%s\n' "$RUN_XML"
} | tee -a "$RUN_LOG"

if [ -z "$app_path" ]; then
  echo "FAIL: $APP_PACKAGE is not installed after instrumentation" >&2
  exit 1
fi
if [ -z "$test_path" ]; then
  echo "FAIL: $TEST_PACKAGE is not installed after instrumentation" >&2
  exit 1
fi
if [ "$test_status" -ne 0 ]; then
  echo "FAIL: instrumented run did not report a successful non-zero test count; see $RUN_LOG and $RUN_XML" >&2
  exit 1
fi

echo "PASS: $test_count instrumented test(s); $APP_PACKAGE remains installed at $app_path"
echo "Evidence log: $RUN_LOG"
echo "JUnit XML: $RUN_XML"
