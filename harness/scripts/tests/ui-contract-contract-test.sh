#!/usr/bin/env bash
# Regression: UI contract states must be complete, uniquely referenced, mapped to the spec, the
# implementation plan (reused registered components), the test plan (review capture + structural
# check), and an approved conformance review.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/harness/scripts/check-ui-contract.py"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/ui-contract-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "$output" >&2
    echo "FAIL: unexpected pass: $*" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    echo "FAIL: expected diagnostic: $expected" >&2
    exit 1
  }
}

png() {
  python3 - "$1" "$2" "$3" <<'PY'
import struct, sys, zlib
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
raw = b"".join(b"\x00" + b"\xff\xff\xff" * w for _ in range(h))
open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                       + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
PY
}

W="$FIXTURE/.scratch/2026-11-09-transform"
mkdir -p "$W/design" "$W/evidence/ui" "$FIXTURE/docs/product" "$FIXTURE/app/src/main/java/example" \
  "$FIXTURE/app/src/test/java/example/review" "$FIXTURE/app/src/androidTest/java/example"
printf 'Pen fixture' > "$W/design/source.pen"
png "$W/design/mockup_crop.png" 430 932
png "$W/design/mockup_rotate.png" 430 932
cat > "$FIXTURE/docs/product/design_system.md" <<'MD'
# Design System

### Component Registry

| Component | Pen component | Composable | Required testTag | Wraps Material |
|---|---|---|---|---|
| ToolDial | comp/dial | ui/components/ToolDial.kt | tool_dial | Slider |
| ActionChip | comp/chip | ui/components/ActionChip.kt | action_chip | AssistChip |
MD
cat > "$W/UI_contract.md" <<'MD'
# UI Contract
Project design system: `docs/product/design_system.md`

## Screen States

| Screen | State ID | Design source | Design node ID | Design node role | Design image | Viewport | Required regions | State controls | Reused components | Runtime fixture | Plan stage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Transform | crop | `design/source.pen` | crop-node | screen-frame | `design/mockup_crop.png` | 430x932 | primary-content; state-controls; persistent-controls | Straighten dial; aspect buttons | `ToolDial`, `ActionChip` | crop-fixture | UI-01 |
| Transform | rotate | `design/source.pen` | rotate-node | screen-frame | `design/mockup_rotate.png` | 430x932 | primary-content; state-controls; persistent-controls | Rotate Left; Rotate Right buttons | `ActionChip` | rotate-fixture | UI-02 |
MD
cat > "$FIXTURE/spec.md" <<'MD'
# Composed spec

## Screen States

| Screen | State ID | Requirement | Acceptance Criteria |
|---|---|---|---|
| Transform | crop | FR-001 | AC-001 |
| Transform | rotate | FR-002 | AC-002 |
MD
cat > "$W/implementation-plan.md" <<'MD'
# Implementation Plan

## Phase 1 — Design

### Project Structure

| Layer | Files affected | Change type |
|---|---|---|
| UI | `app/src/main/java/example/TransformScreen.kt` | modify |

### UI State Stages *(UI scope; remove otherwise)*

| Stage ID | Reused registered components | Implementation |
|---|---|---|
| UI-01 | `ToolDial`, `ActionChip` | Crop controls |
| UI-02 | `ActionChip` | Rotate controls |
MD
cat > "$W/test-plan.md" <<'MD'
# Test Plan

## UI State Verification *(UI scope; remove otherwise)*

| Stage ID | Review capture (test#method) | Structural check (test#method) | Command |
|---|---|---|---|
| UI-01 | `app/src/test/java/example/review/TransformReviewCaptureTest.kt#crop` | `app/src/test/java/example/TransformStructureTest.kt#crop` | `./gradlew testDebugUnitTest --tests "example.TransformStructureTest" --tests "example.review.TransformReviewCaptureTest"` |
| UI-02 | `app/src/test/java/example/review/TransformReviewCaptureTest.kt#rotate` | `app/src/androidTest/java/example/TransformRotateTest.kt#rotate` | `./gradlew testDebugUnitTest --tests "example.review.TransformReviewCaptureTest"` and `ANDROID_SERIAL=emulator-5554 bash harness/scripts/run-android-instrumented-tests.sh --class example.TransformRotateTest#rotate` |
MD
printf 'fun TransformScreen() {\n    ToolDial(value)\n    ActionChip(label)\n}\n' > "$FIXTURE/app/src/main/java/example/TransformScreen.kt"
touch "$FIXTURE/app/src/test/java/example/review/TransformReviewCaptureTest.kt" \
  "$FIXTURE/app/src/test/java/example/TransformStructureTest.kt" \
  "$FIXTURE/app/src/androidTest/java/example/TransformRotateTest.kt"
png "$W/evidence/ui/crop.png" 860 1864
png "$W/evidence/ui/rotate.png" 860 1864
cat > "$W/ui_verification.json" <<'JSON'
{"version": 1, "state_results": [
  {"screen": "Transform", "state_id": "crop", "design_image": "design/mockup_crop.png",
   "review_capture": "evidence/ui/crop.png",
   "review_capture_test": "app/src/test/java/example/review/TransformReviewCaptureTest.kt#crop",
   "structural_check": "app/src/test/java/example/TransformStructureTest.kt#crop", "structural_result": "PASS",
   "review_decision": "approved", "approved_by": "user", "approved_on": "2026-11-09", "result": "PASS"},
  {"screen": "Transform", "state_id": "rotate", "design_image": "design/mockup_rotate.png",
   "review_capture": "evidence/ui/rotate.png",
   "review_capture_test": "app/src/test/java/example/review/TransformReviewCaptureTest.kt#rotate",
   "structural_check": "app/src/androidTest/java/example/TransformRotateTest.kt#rotate", "structural_result": "PASS",
   "review_decision": "approved", "approved_by": "user", "approved_on": "2026-11-09", "result": "PASS"}
]}
JSON

C="$W/UI_contract.md"
DS="$FIXTURE/docs/product/design_system.md"
full() {
  python3 "$CHECK" "$C" --spec "$FIXTURE/spec.md" --design-system "$DS" --plan "$W/implementation-plan.md" \
    --test-plan "$W/test-plan.md" --report "$W/ui_verification.json" --runtime --project-root "$FIXTURE"
}
full >/dev/null

cp "$C" "$FIXTURE/original-contract"
cp "$W/implementation-plan.md" "$FIXTURE/original-plan"
cp "$W/test-plan.md" "$FIXTURE/original-test-plan"
cp "$W/ui_verification.json" "$FIXTURE/original-report"

# Design references
png "$W/design/mockup_crop_rail.png" 860 177
sed 's/mockup_crop.png/mockup_crop_rail.png/' "$FIXTURE/original-contract" > "$C"
expect_failure "design PNG aspect ratio" python3 "$CHECK" "$C"
sed 's/rotate-node/crop-node/' "$FIXTURE/original-contract" > "$C"
expect_failure "design node reused across states" python3 "$CHECK" "$C"
sed 's|design/source.pen|../UI_design/../../design/source.pen|' "$FIXTURE/original-contract" > "$C"
expect_failure "unsafe design path" python3 "$CHECK" "$C"
cp "$FIXTURE/original-contract" "$C"
mv "$W/design/mockup_rotate.png" "$FIXTURE/rotate.bak"
expect_failure "missing or empty design PNG" python3 "$CHECK" "$C"
mv "$FIXTURE/rotate.bak" "$W/design/mockup_rotate.png"

# Spec and registered components
sed '/| Transform | rotate | FR-002 | AC-002 |/d' "$FIXTURE/spec.md" > "$FIXTURE/short-spec.md"
expect_failure "UI contract states differ from spec" python3 "$CHECK" "$C" --spec "$FIXTURE/short-spec.md"
sed 's/| `ActionChip` | rotate-fixture/| `FancyChip` | rotate-fixture/' "$FIXTURE/original-contract" > "$C"
expect_failure "reuses unregistered components ['FancyChip']" python3 "$CHECK" "$C" --design-system "$DS"
sed 's/| `ActionChip` | rotate-fixture/| None — custom canvas only | rotate-fixture/' "$FIXTURE/original-contract" > "$C"
sed 's/| UI-02 | `ActionChip` |/| UI-02 | None — custom canvas only |/' "$FIXTURE/original-plan" > "$W/implementation-plan.md"
python3 "$CHECK" "$C" --design-system "$DS" --plan "$W/implementation-plan.md" >/dev/null
cp "$FIXTURE/original-contract" "$C"
cp "$FIXTURE/original-plan" "$W/implementation-plan.md"

# Implementation plan
sed '/| UI-02 | `ActionChip` | Rotate controls |/d' "$FIXTURE/original-plan" > "$W/implementation-plan.md"
expect_failure "UI plan stages differ from contract" python3 "$CHECK" "$C" --plan "$W/implementation-plan.md"
sed 's/| UI-01 | `ToolDial`, `ActionChip` |/| UI-01 | `ToolDial` |/' "$FIXTURE/original-plan" > "$W/implementation-plan.md"
expect_failure "UI plan stage UI-01 reused components differ from UI_contract.md" python3 "$CHECK" "$C" --plan "$W/implementation-plan.md"
cp "$FIXTURE/original-plan" "$W/implementation-plan.md"
printf 'fun TransformScreen() {\n    ActionChip(label)\n}\n' > "$FIXTURE/app/src/main/java/example/TransformScreen.kt"
expect_failure "UI state UI-01 lists ToolDial, but no UI file" full
printf 'fun TransformScreen() {\n    ToolDial(value)\n    ActionChip(label)\n}\n' > "$FIXTURE/app/src/main/java/example/TransformScreen.kt"

# Test plan verification targets
sed 's@example/review/TransformReviewCaptureTest.kt#crop@example/TransformCaptureTest.kt#crop@' "$FIXTURE/original-test-plan" > "$W/test-plan.md"
expect_failure "review capture must be app/src/test/java/<package>/review/" full
sed 's@run-android-instrumented-tests.sh@run-tests.sh@' "$FIXTURE/original-test-plan" > "$W/test-plan.md"
expect_failure "needs the direct AndroidJUnitRunner wrapper" full
cp "$FIXTURE/original-test-plan" "$W/test-plan.md"

# Conformance review report
python3 - "$W/ui_verification.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["state_results"].pop(); json.dump(d, open(p, "w"))
PY
expect_failure "UI verification states differ from contract" full
cp "$FIXTURE/original-report" "$W/ui_verification.json"
python3 - "$W/ui_verification.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["state_results"][0]["review_decision"] = "changes-requested"; json.dump(d, open(p, "w"))
PY
expect_failure "needs review_decision 'approved'" full
cp "$FIXTURE/original-report" "$W/ui_verification.json"
png "$W/evidence/ui/crop.png" 1080 1080
expect_failure "was not rendered at the contract viewport 430x932" full
png "$W/evidence/ui/crop.png" 860 1864
full >/dev/null

echo "PASS: UI contract gates reject incomplete, duplicate, unmapped, unregistered, and unreviewed UI states."
