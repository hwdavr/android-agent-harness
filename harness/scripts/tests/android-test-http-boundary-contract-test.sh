#!/usr/bin/env bash
# Contract test for the Android instrumented-test loopback boundary checker.
# It proves the checker accepts a complete shipped-client boundary and rejects
# production fixture symbols or a missing server lifecycle.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
CHECKER="$REPO_ROOT/harness/scripts/check-android-test-http-boundary.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/android-test-http-boundary.XXXXXX")"
bad_root="$(mktemp -d "${TMPDIR:-/tmp}/android-test-http-boundary-bad.XXXXXX")"
split_root="$(mktemp -d "${TMPDIR:-/tmp}/android-test-http-boundary-split.XXXXXX")"
trap 'rm -rf "$fixture_root" "$bad_root" "$split_root"' EXIT

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

mkdir -p "$split_root/app/src/androidTest/java/example"
cat > "$split_root/app/src/androidTest/java/example/FixtureRule.kt" <<'KOTLIN'
class FixtureRule : ExternalResource() {
    private val server = MockWebServer()
    override fun before() { server.start(8080) }
    override fun after() { server.shutdown() }
    fun takeRequest() = server.takeRequest()
    fun inspect(request: RecordedRequest) = request.method + request.path
}
KOTLIN
cat > "$split_root/app/src/androidTest/java/example/JourneyTest.kt" <<'KOTLIN'
class JourneyTest {
    @get:Rule(order = 1)
    val fixture = FixtureRule()
    @get:Rule(order = 2)
    val composeRule = createAndroidComposeRule<MainActivity>()
    fun verifyReceipt() {
        val request = fixture.takeRequest()
        assertEquals("GET", request.method)
        assertEquals("/notes", request.path)
    }
}
KOTLIN
bash "$CHECKER" --project-root "$split_root"

sed -i.bak 's/order = 2/order = 0/' "$split_root/app/src/androidTest/java/example/JourneyTest.kt"
if output=$(bash "$CHECKER" --project-root "$split_root" 2>&1); then
    echo "$output" >&2
    fail "checker accepted an app launch ordered before fixture startup"
fi
printf '%s\n' "$output" | grep -Fq 'loopback rule has no ordered app-launching owner' \
    || { echo "$output" >&2; fail "checker missed the invalid rule order"; }

mv "$split_root/app/src/androidTest/java/example/JourneyTest.kt.bak" "$split_root/app/src/androidTest/java/example/JourneyTest.kt"
sed -i.bak 's/fixture.takeRequest()/other.takeRequest()/' "$split_root/app/src/androidTest/java/example/JourneyTest.kt"
if output=$(bash "$CHECKER" --project-root "$split_root" 2>&1); then
    echo "$output" >&2
    fail "checker accepted a fixture whose owning test does not read its receipts"
fi
printf '%s\n' "$output" | grep -Fq 'loopback rule has no ordered app-launching owner' \
    || { echo "$output" >&2; fail "checker missed the missing fixture receipt"; }

# The existing Web Bookmark journey mounts the real production navigation host
# in HiltTestActivity, and its fixture/owner live in the same file.
mkdir -p "$split_root/app/src/main/java/com/example/notesapp/navigation"
printf '%s\n' 'internal fun AppNavigationHost() {}' > \
    "$split_root/app/src/main/java/com/example/notesapp/navigation/AppNavigationHost.kt"
rm "$split_root/app/src/androidTest/java/example/FixtureRule.kt"
cat > "$split_root/app/src/androidTest/java/example/JourneyTest.kt" <<'KOTLIN'
class JourneyTest {
    @get:Rule(order = 1)
    val fixture = FixtureRule()
    @get:Rule(order = 2)
    val composeRule = createAndroidComposeRule<HiltTestActivity>()
    fun journey() {
        AppNavigationHost()
        assertTrue(fixture.receipts.any { it.startsWith("POST /v1/notes") })
    }
}
class FixtureRule : ExternalResource() {
    private val server = MockWebServer()
    override fun before() { server.start(8080) }
    override fun after() { server.shutdown() }
    fun record(request: RecordedRequest) { receipts.add(request.method + request.path) }
}
KOTLIN
bash "$CHECKER" --project-root "$split_root"
rm "$split_root/app/src/main/java/com/example/notesapp/navigation/AppNavigationHost.kt"
if output=$(bash "$CHECKER" --project-root "$split_root" 2>&1); then
    echo "$output" >&2
    fail "checker accepted a test Activity without source-backed production navigation"
fi
printf '%s\n' "$output" | grep -Fq 'loopback rule has no ordered app-launching owner' \
    || { echo "$output" >&2; fail "checker missed missing production navigation"; }

echo "PASS: Android instrumented-test HTTP boundary checker rejects production fixtures and incomplete lifecycle"
