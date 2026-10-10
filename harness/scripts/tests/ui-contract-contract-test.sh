#!/usr/bin/env bash
# Regression: UI planning cannot pass with missing, collapsed, or unmapped states.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$ROOT/harness/scripts/check-stage-artifacts.sh"
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

# This was a false PASS before the retrospective: the wildcard stage printed SKIP.
expect_failure "no file matching 'UI_contract.md'" \
  bash "$GATE" create-ui-and-verify reference-design "$FIXTURE"

mkdir -p "$FIXTURE/design"
printf 'Pen fixture' > "$FIXTURE/design/source.pen"
printf 'PNG fixture crop' > "$FIXTURE/design/mockup_crop.png"
printf 'PNG fixture rotate' > "$FIXTURE/design/mockup_rotate.png"
cat > "$FIXTURE/UI_contract.md" <<'EOF'
# UI Contract

## Screen States

| Screen | State ID | Design source | Design node ID | Design image | Runtime fixture | Comparison | Content difference | Plan stage |
|---|---|---|---|---|---|---|---|---|
| Transform | crop | `design/source.pen` | crop-node | `design/mockup_crop.png` | crop-fixture | structural | Pen photo differs from device photo | UI-01 |
| Transform | rotate | `design/source.pen` | rotate-node | `design/mockup_rotate.png` | rotate-fixture | exact | None | UI-02 |
EOF
cat > "$FIXTURE/spec_v1.md" <<'EOF'
# Spec

## Rule Applicability

| Rule ID | Rule document | Decision | Evidence |
|---|---|---|---|
| ARCH | rule.md | Required | test |
| IMPL | rule.md | Required | test |
| TEST | rule.md | Required | test |
| SUI | rule.md | Required | test |
| L10N | rule.md | Required | test |
| NAV | rule.md | Not applicable — no navigation | test |
| API | rule.md | Not applicable — no API | test |
| OBS | rule.md | Not applicable — no async work | test |
| ANL | rule.md | Not applicable — analytics: none | test |
| SEC | rule.md | Not applicable — no security boundary | test |

## Screen States

| Screen | State ID | Requirement | Acceptance Criteria |
|---|---|---|---|
| Transform | crop | FR-01 | AC-01 |
| Transform | rotate | FR-02 | AC-02 |
EOF
cat > "$FIXTURE/implementation_plan_v1.md" <<'EOF'
# Plan

## UI State Stages

| Stage ID | Implementation | Verification |
|---|---|---|
| UI-01 | Implement crop selected controls | Capture crop fixture and compare anchors |
| UI-02 | Implement rotate selected controls | Capture rotate fixture and compare pixels |
EOF
touch "$FIXTURE/summary_v1.md"

bash "$GATE" create-ui-and-verify reference-design "$FIXTURE" >/dev/null
bash "$GATE" create-ui-and-verify implementation-plan "$FIXTURE" >/dev/null
bash "$GATE" feature-delivery requirement-analysis "$FIXTURE" >/dev/null

cp "$FIXTURE/UI_contract.md" "$FIXTURE/original-contract"
sed 's/rotate-node/crop-node/' "$FIXTURE/original-contract" > "$FIXTURE/UI_contract.md"
expect_failure "design node reused across states" python3 "$CHECK" "$FIXTURE/UI_contract.md"
cp "$FIXTURE/original-contract" "$FIXTURE/UI_contract.md"

sed 's|design/source.pen|../UI_design/../../design/source.pen|' "$FIXTURE/original-contract" > "$FIXTURE/UI_contract.md"
expect_failure "unsafe design path" python3 "$CHECK" "$FIXTURE/UI_contract.md"
cp "$FIXTURE/original-contract" "$FIXTURE/UI_contract.md"

rm "$FIXTURE/design/mockup_rotate.png"
expect_failure "missing or empty design PNG" python3 "$CHECK" "$FIXTURE/UI_contract.md"
printf 'PNG fixture rotate' > "$FIXTURE/design/mockup_rotate.png"

cp "$FIXTURE/spec_v1.md" "$FIXTURE/original-spec"
sed '/| Transform | rotate | FR-02 | AC-02 |/d' "$FIXTURE/original-spec" > "$FIXTURE/spec_v1.md"
expect_failure "UI contract states differ from spec" \
  bash "$GATE" feature-delivery requirement-analysis "$FIXTURE"
cp "$FIXTURE/original-spec" "$FIXTURE/spec_v1.md"

cp "$FIXTURE/implementation_plan_v1.md" "$FIXTURE/original-plan"
sed '/| UI-02 | Implement rotate selected controls |/d' "$FIXTURE/original-plan" > "$FIXTURE/implementation_plan_v1.md"
expect_failure "UI plan stages differ from contract" \
  bash "$GATE" create-ui-and-verify implementation-plan "$FIXTURE"
cp "$FIXTURE/original-plan" "$FIXTURE/implementation_plan_v1.md"

mkdir -p "$FIXTURE/evidence"
cat > "$FIXTURE/evidence/ui_frames.json" <<'EOF'
{"screens":[{"name":"crop-runtime","screenshot":"evidence/crop.png"},{"name":"rotate-runtime","screenshot":"evidence/rotate.png"}]}
EOF
cat > "$FIXTURE/ui_verification.json" <<'EOF'
{
  "runtime_evidence":"evidence/ui_frames.json",
  "state_results":[
    {"screen":"Transform","state_id":"crop","design_image":"design/mockup_crop.png","runtime_screen":"crop-runtime","comparison":"structural","pixel_parity":"not-claimed","assertion":"Crop icon bounds match the approved reference","result":"PASS"},
    {"screen":"Transform","state_id":"rotate","design_image":"design/mockup_rotate.png","runtime_screen":"rotate-runtime","comparison":"exact","pixel_parity":"verified","assertion":"Rotate icon and text match the approved export","result":"PASS"}
  ]
}
EOF
python3 "$CHECK" "$FIXTURE/UI_contract.md" --report "$FIXTURE/ui_verification.json" >/dev/null

cp "$FIXTURE/ui_verification.json" "$FIXTURE/original-report"
python3 - "$FIXTURE/ui_verification.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data["state_results"].pop()
with open(path, "w") as output:
    json.dump(data, output)
PY
expect_failure "UI verification states differ from contract" \
  python3 "$CHECK" "$FIXTURE/UI_contract.md" --report "$FIXTURE/ui_verification.json"

echo "PASS: UI contract gates reject absent, duplicate, missing-asset, and unmapped screen states and verification results."
