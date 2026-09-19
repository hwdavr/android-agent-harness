#!/usr/bin/env bash
# Contract test for the Android instrumented-test loopback boundary checker.
# It proves the checker accepts a complete shipped-client boundary and rejects
# production fixture symbols or a missing server lifecycle.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
CHECKER="$REPO_ROOT/harness/scripts/check-android-test-http-boundary.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/android-test-http-boundary.XXXXXX")"
bad_root="$(mktemp -d "${TMPDIR:-/tmp}/android-test-http-boundary-bad.XXXXXX")"
trap 'rm -rf "$fixture_root" "$bad_root"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

[ -x "$CHECKER" ] || fail "Android instrumented-test HTTP boundary checker is missing or not executable"

bash "$CHECKER" --project-root "$REPO_ROOT"

mkdir -p "$fixture_root/app/src/main/java/example" \
    "$fixture_root/app/src/androidTest/java/example"

cat > "$fixture_root/app/src/androidTest/java/example/LoopbackApiInstrumentedTest.kt" <<'KOTLIN'
class LoopbackApiInstrumentedTest {
    private val server = MockWebServer()

    fun launchAndAssert() {
        server.start(0)
        val apiBaseUrl = server.url("/")
        launchActivity<MainActivity>(apiBaseUrl)
        val request = server.takeRequest()
        assertEquals("GET", request.method)
        assertEquals("/notes", request.path)
        server.shutdown()
    }
}
KOTLIN

bash "$CHECKER" --project-root "$fixture_root"

cat > "$fixture_root/app/src/main/java/example/ProductionFixture.kt" <<'KOTLIN'
class ProductionFixture {
    private val fixtureServer = MockWebServer()
}
KOTLIN

if output=$(bash "$CHECKER" --project-root "$fixture_root" 2>&1); then
    echo "$output" >&2
    fail "checker accepted a production MockWebServer fixture"
fi
printf '%s\n' "$output" | grep -Fq 'production source contains instrumented-test fixture symbols' \
    || { echo "$output" >&2; fail "checker missed the production fixture regression"; }

mkdir -p "$bad_root/app/src/androidTest/java/example"
cat > "$bad_root/app/src/androidTest/java/example/BadLoopbackApiInstrumentedTest.kt" <<'KOTLIN'
class BadLoopbackApiInstrumentedTest {
    private val server = MockWebServer()

    fun launchAndAssert() {
        launchActivity<MainActivity>(server.url("/"))
        val request = server.takeRequest()
        assertEquals("GET", request.method)
    }
}
KOTLIN

if output=$(bash "$CHECKER" --project-root "$bad_root" 2>&1); then
    echo "$output" >&2
    fail "checker accepted a loopback test without server startup and teardown"
fi
printf '%s\n' "$output" | grep -Fq 'loopback server is not started' \
    || { echo "$output" >&2; fail "checker missed the missing server startup"; }

echo "PASS: Android instrumented-test HTTP boundary checker rejects production fixtures and incomplete lifecycle"
