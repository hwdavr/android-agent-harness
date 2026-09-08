#!/usr/bin/env bash
# Contract tests for the AI security source evaluator.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="$SCRIPT_DIR/../check-ai-security-rules.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-security-rules.XXXXXX")"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -x "$CHECKER" ] || fail "missing executable checker: $CHECKER"

mkdir -p "$FIXTURE_ROOT/app/src/main/java/com/example/notesapp" \
  "$FIXTURE_ROOT/app/src/main/assets/mermaid" \
  "$FIXTURE_ROOT/app/build/reports/ai-security"

cat > "$FIXTURE_ROOT/app/src/main/AndroidManifest.xml" <<'EOF'
<manifest><application android:usesCleartextTraffic="false" /></manifest>
EOF
cat > "$FIXTURE_ROOT/app/src/main/java/com/example/notesapp/Safe.kt" <<'EOF'
class Safe {
    fun prompt(note: String): String = "<untrusted_note_content>${note.take(2000)}</untrusted_note_content>"
}
EOF
cat > "$FIXTURE_ROOT/app/src/main/assets/mermaid/index.html" <<'EOF'
mermaid.initialize({ securityLevel: 'strict' })
EOF

safe_report="$FIXTURE_ROOT/app/build/reports/ai-security/safe.md"
bash "$CHECKER" --root "$FIXTURE_ROOT" --format markdown --output "$safe_report" \
  || fail "safe fixture should pass"
[ -s "$safe_report" ] || fail "safe fixture did not produce a report"

cat > "$FIXTURE_ROOT/app/src/main/AndroidManifest.xml" <<'EOF'
<manifest><application android:usesCleartextTraffic="true" /></manifest>
EOF
cat > "$FIXTURE_ROOT/app/src/main/java/com/example/notesapp/Unsafe.kt" <<'EOF'
class Unsafe {
    private val fixtureSecret = "PRIVATE_FIXTURE_NOTE"

    fun render(output: String) {
        webView.settings.javaScriptEnabled = true
        webView.settings.allowFileAccess = true
        webView.settings.domStorageEnabled = true
        container.innerHTML = output
        webView.settings.blockNetworkLoads = false
        Log.d("NotesApp/Unsafe", prompt)
    }
}
EOF
cat > "$FIXTURE_ROOT/app/src/main/assets/mermaid/index.html" <<'EOF'
mermaid.initialize({ securityLevel: 'loose' })
EOF

unsafe_report="$FIXTURE_ROOT/app/build/reports/ai-security/unsafe.json"
if bash "$CHECKER" --root "$FIXTURE_ROOT" --format json --output "$unsafe_report"; then
  fail "unsafe fixture should fail"
fi

[ -s "$unsafe_report" ] || fail "unsafe fixture did not produce a JSON report"
grep -Fq 'AISEC-CLEARTEXT' "$unsafe_report" || fail "cleartext finding missing"
grep -Fq 'AISEC-WEBVIEW-JAVASCRIPT' "$unsafe_report" || fail "JavaScript finding missing"
grep -Fq 'AISEC-WEBVIEW-FILE-ACCESS' "$unsafe_report" || fail "file-access finding missing"
grep -Fq 'AISEC-WEBVIEW-DOM-STORAGE' "$unsafe_report" || fail "DOM-storage finding missing"
grep -Fq 'AISEC-WEBVIEW-NETWORK-LOADS' "$unsafe_report" || fail "network-load finding missing"
grep -Fq 'AISEC-MERMAID-SECURITY-LEVEL' "$unsafe_report" || fail "Mermaid finding missing"
grep -Fq 'AISEC-AI-INPUT-LOGGING' "$unsafe_report" || fail "prompt logging finding missing"
grep -Fq 'AISEC-OUTPUT-HTML-SINK' "$unsafe_report" || fail "output sink finding missing"
if grep -Fq 'PRIVATE_FIXTURE_NOTE' "$unsafe_report"; then
  fail "security report leaked fixture content"
fi

echo "PASS: AI security rule contract tests"
