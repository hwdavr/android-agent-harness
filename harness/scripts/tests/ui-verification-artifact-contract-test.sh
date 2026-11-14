#!/usr/bin/env bash
# Contract test for check-ui-verification-artifact.sh: ui_verification.json is a per-state
# conformance review; retired pixel-comparison fields and unapproved states are rejected.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$ROOT/harness/scripts/check-ui-verification-artifact.sh"
TEMPLATE="$ROOT/harness/templates/ui-verification-template.json"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/ui-verification-artifact-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

fail_test() { echo "FAIL: $1" >&2; exit 1; }
expect_failure() {
  local expected="$1" output
  if output=$(bash "$VALIDATOR" "$FIXTURE" 2>&1); then fail_test "accepted a report that should fail: $expected"; fi
  printf '%s\n' "$output" | grep -Fq -- "$expected" || { echo "$output" >&2; fail_test "missing diagnostic: $expected"; }
}
mutate() {  # python expression applied to the parsed report `d`
  python3 - "$FIXTURE/ui_verification.json" "$1" <<'PY'
import json, sys
p, expr = sys.argv[1], sys.argv[2]
d = json.load(open(p)); exec(expr); json.dump(d, open(p, "w"))
PY
}
valid() {
  cat > "$FIXTURE/ui_verification.json" <<'JSON'
{
  "version": 1,
  "capture": {"renderer": "robolectric", "density": "xhdpi", "theme": "light", "locale": "en-US", "font_scale": 1.0},
  "build_and_static_checks": {"assembleDebug": "PASS", "lintDebug": "PASS", "ktlintCheck": "PASS", "compose_rules": "PASS"},
  "state_results": [{
    "screen": "Share Invite", "state_id": "invite-expiry-selected", "design_image": "design/share-invite.png",
    "review_capture": "evidence/ui/invite-expiry-selected.png",
    "review_capture_test": "app/src/test/java/example/roborazzi/ShareInviteReviewCaptureTest.kt#expirySelected",
    "structural_check": "app/src/test/java/example/ShareInviteStructureTest.kt#expirySelected",
    "structural_result": "PASS", "reused_components": ["TopActionBar"],
    "review_decision": "approved", "approved_by": "user", "approved_on": "2026-11-09",
    "review_notes": "None", "result": "PASS"
  }]
}
JSON
}

python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$TEMPLATE" || fail_test "template is not valid JSON"
grep -Fq "No screenshot golden is recorded or compared" "$TEMPLATE" || fail_test "template must state the conformance-review method"

valid
bash "$VALIDATOR" "$FIXTURE" >/dev/null || fail_test "valid conformance review was rejected"

rm "$FIXTURE/ui_verification.json"
expect_failure "missing conformance review report"

valid; mutate 'd["runtime_evidence"] = "evidence/roborazzi.json"'
expect_failure "retired pixel-comparison fields present: runtime_evidence"
valid; mutate 'd["state_results"][0]["pixel_parity"] = "verified"'
expect_failure "uses retired pixel-comparison fields"
valid; mutate 'd["build_and_static_checks"]["lintDebug"] = "FAIL"'
expect_failure "every build_and_static_checks entry must be PASS"
valid; mutate 'del d["capture"]["density"]'
expect_failure "capture must declare renderer, density, theme, and locale"
valid; mutate 'del d["state_results"][0]["review_capture_test"]'
expect_failure "is missing review_capture_test"
valid; mutate 'd["state_results"][0]["approved_by"] = "<user>"'
expect_failure "still contains template placeholders"
valid; mutate 'd["state_results"][0]["review_decision"] = "changes-requested"'
expect_failure "cannot PASS without an approved review"
valid; mutate 'd["state_results"][0]["structural_result"] = "FAIL"; d["state_results"][0]["result"] = "FAIL"'
expect_failure "has not passed the conformance review"
valid; mutate 'd["state_results"][0]["approved_on"] = "yesterday"'
expect_failure "approved_on must be YYYY-MM-DD"
valid; mutate 'd["state_results"] = []'
expect_failure "state_results must be a non-empty array"

echo "PASS: ui_verification.json must record an approved, passing conformance review per state."
