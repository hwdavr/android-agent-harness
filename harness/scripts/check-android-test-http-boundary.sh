#!/usr/bin/env bash
# Verify the boundary between production composition and an Android
# instrumented-test loopback HTTP fixture. Runtime execution remains owned by
# the instrumented test target.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="${ANDROID_TEST_HTTP_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd -P)}"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --project-root)
            [[ "$#" -ge 2 ]] || { echo "ERROR: --project-root requires a path" >&2; exit 2; }
            PROJECT_ROOT="$(cd "$2" && pwd -P)"
            shift 2
            ;;
        --help|-h)
            echo "Usage: check-android-test-http-boundary.sh [--project-root <path>]"
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

APP_ROOT="$PROJECT_ROOT/app"
MAIN_ROOT="$APP_ROOT/src/main"
ANDROID_TEST_ROOT="$APP_ROOT/src/androidTest"

if [[ ! -d "$ANDROID_TEST_ROOT" ]]; then
    echo "PASS: Android UI-test HTTP boundary is not applicable (no instrumented-test target)"
    exit 0
fi

fixture_files=()
while IFS= read -r file; do
    [[ -n "$file" ]] && fixture_files+=("$file")
done < <(rg -l --glob '*.kt' \
    -e 'MockWebServer|MockResponse|127\.0\.0\.1|10\.0\.2\.2|loopback|Loopback' \
    "$ANDROID_TEST_ROOT" || true)

if [[ "${#fixture_files[@]}" -eq 0 ]]; then
    echo "PASS: Android UI-test HTTP boundary is not applicable (no instrumented loopback fixture found)"
    exit 0
fi

failures=0
fail() {
    echo "FAIL: $1" >&2
    failures=1
}

if [[ -d "$MAIN_ROOT" ]] && rg -n --glob '*.kt' \
    -e 'MockWebServer|MockResponse|UITestFixtures|usesUITestFixtureStore' "$MAIN_ROOT"; then
    fail "production source contains instrumented-test fixture symbols"
fi

for file in "${fixture_files[@]}"; do
    if ! rg -q 'MockWebServer' "$file"; then
        continue
    fi

    rg -q 'server\.start\(' "$file" \
        || fail "loopback server is not started in the MockWebServer test: $file"
    rg -q '\.(shutdown|close)\(' "$file" \
        || fail "loopback server is not stopped in the MockWebServer test: $file"
    rg -q 'takeRequest\(' "$file" \
        || fail "MockWebServer test does not record a request receipt: $file"
    rg -q '(request|receipt)\.(method|path)|redact(ed)?' "$file" \
        || fail "MockWebServer receipt is not asserted with method/path or redaction: $file"
    rg -q 'server\.url\(|127\.0\.0\.1|10\.0\.2\.2' "$file" \
        || fail "MockWebServer test does not use an allow-listed local endpoint: $file"
    rg -q 'createAndroidComposeRule|AndroidComposeTestRule|ActivityScenario\.launch|launchActivity|startActivity' "$file" \
        || fail "MockWebServer test does not launch the shipped Android entry point: $file"

    if ! awk '
        /\.start\(/ && start == 0 { start = NR }
        /createAndroidComposeRule|AndroidComposeTestRule|ActivityScenario\.launch|launchActivity|startActivity/ && launch == 0 { launch = NR }
        END { exit !(start > 0 && launch > 0 && start < launch) }
    ' "$file"; then
        fail "loopback server must start before the shipped app launch in: $file"
    fi
done

if [[ "$failures" -ne 0 ]]; then
    exit 1
fi

echo "PASS: Android instrumented-test fixture state is test-target-owned and uses a fail-closed local HTTP boundary"
