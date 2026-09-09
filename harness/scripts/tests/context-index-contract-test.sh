#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INDEX_SCRIPT="$PROJECT_ROOT/harness/scripts/print-context-index.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -f "$INDEX_SCRIPT" ] || fail "missing $INDEX_SCRIPT"
command -v jq >/dev/null 2>&1 || fail "jq is required for the context-index contract test"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/context-index-contract.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

FEATURE_DIR="$TEMP_ROOT/feature"
mkdir -p "$FEATURE_DIR"

cat > "$FEATURE_DIR/sprint-contract.md" <<'EOF'
# Sprint Contract

## Rule Applicability Contract

| Rule ID | Rule document | Decision | Slice evidence |
|---|---|---|---|
| ARCH | `android-architecture.md` | Required | architecture test |
| IMPL | `implementation-rules.md` | Required | implementation test |
| TEST | `testing-strategy.md` | Required | test plan |
| SUI | `compose-rules.md` | Not applicable — no Compose change | N/A |
| L10N | `localization-rules.md` | Not applicable — no user-visible copy | N/A |
| NAV | `navigation-rules.md` | Not applicable — no route or back-stack change | N/A |
| API | `api-contract-rules.md` | Not applicable — no endpoint or DTO change | N/A |
| OBS | `observability.md` | Exception — approved by user/2026-09-06 | diagnostics deferred |
| ANL | `analytics-rules.md` | Not applicable — analytics: none | N/A |
| SEC | `android-security.md` | Required | URI input boundary test |

## User Scenarios & Testing

### US-1: Unit-only regression
EOF

cat > "$FEATURE_DIR/feature_list.json" <<'EOF'
{
  "platform_validation": {"required": false},
  "features": [
    {
      "id": "US-1",
      "affects_ui": false,
      "requires_visual_verification": false,
      "production_journey": {"required": false},
      "acceptance_test_ids": ["TC-US-1-01"]
    }
  ]
}
EOF

INDEX_OUTPUT="$(bash "$INDEX_SCRIPT" --feature-dir "$FEATURE_DIR" --slice US-1)"
printf '%s\n' "$INDEX_OUTPUT" | jq -e '
  .slice == "US-1" and
  .rule_context.required == ["ARCH", "IMPL", "TEST", "SEC"] and
  .rule_context.exceptions == ["OBS"] and
  .rule_context.not_applicable == ["SUI", "L10N", "NAV", "API", "ANL"] and
  .rule_context.files == [
    ".agents/rules/android-architecture.md",
    ".agents/rules/implementation-rules.md",
    ".agents/rules/testing-strategy.md",
    ".agents/rules/observability.md",
    ".agents/rules/android-security.md"
  ] and
  .stage_context.testing == [".agents/rules/testing-practices.md"] and
  .execution_flags.affects_ui == false and
  .execution_flags.platform_validation_required == false and
  .acceptance_test_ids == ["TC-US-1-01"] and
  (.authority.sprint_contract_sha256 | length == 64) and
  (.authority.feature_list_sha256 | length == 64)
' >/dev/null || fail "context index did not preserve the authoritative slice metadata"

jq '.features[0].affects_ui = true | .features[0].requires_visual_verification = true' \
  "$FEATURE_DIR/feature_list.json" > "$FEATURE_DIR/feature_list.json.tmp"
mv "$FEATURE_DIR/feature_list.json.tmp" "$FEATURE_DIR/feature_list.json"
RUNTIME_INDEX_OUTPUT="$(bash "$INDEX_SCRIPT" --feature-dir "$FEATURE_DIR" --slice US-1)"
printf '%s\n' "$RUNTIME_INDEX_OUTPUT" | jq -e '
  .stage_context.testing == [
    ".agents/rules/testing-practices.md",
    ".agents/rules/testing-runtime-evidence.md"
  ]
' >/dev/null || fail "context index did not select conditional runtime testing guidance"
jq '.features[0].affects_ui = false | .features[0].requires_visual_verification = false' \
  "$FEATURE_DIR/feature_list.json" > "$FEATURE_DIR/feature_list.json.tmp"
mv "$FEATURE_DIR/feature_list.json.tmp" "$FEATURE_DIR/feature_list.json"

set +e
UNKNOWN_SLICE_OUTPUT="$(bash "$INDEX_SCRIPT" --feature-dir "$FEATURE_DIR" --slice US-404 2>&1)"
UNKNOWN_SLICE_STATUS=$?
set -e
[ "$UNKNOWN_SLICE_STATUS" -ne 0 ] || fail "unknown slice unexpectedly produced a context index"
printf '%s\n' "$UNKNOWN_SLICE_OUTPUT" | grep -Fq "has no slice US-404" \
  || fail "unknown slice did not report the missing feature-list entry"

jq '.features += [.features[0]]' "$FEATURE_DIR/feature_list.json" > "$FEATURE_DIR/feature_list.json.tmp"
mv "$FEATURE_DIR/feature_list.json.tmp" "$FEATURE_DIR/feature_list.json"
set +e
DUPLICATE_SLICE_OUTPUT="$(bash "$INDEX_SCRIPT" --feature-dir "$FEATURE_DIR" --slice US-1 2>&1)"
DUPLICATE_SLICE_STATUS=$?
set -e
[ "$DUPLICATE_SLICE_STATUS" -ne 0 ] || fail "duplicate slice unexpectedly produced a context index"
printf '%s\n' "$DUPLICATE_SLICE_OUTPUT" | grep -Fq "must contain exactly one slice US-1" \
  || fail "duplicate slice did not report the ambiguous feature-list entry"
jq '.features = [.features[0]]' "$FEATURE_DIR/feature_list.json" > "$FEATURE_DIR/feature_list.json.tmp"
mv "$FEATURE_DIR/feature_list.json.tmp" "$FEATURE_DIR/feature_list.json"

awk '!/^\| SEC \|/' "$FEATURE_DIR/sprint-contract.md" > "$FEATURE_DIR/sprint-contract.md.tmp"
mv "$FEATURE_DIR/sprint-contract.md.tmp" "$FEATURE_DIR/sprint-contract.md"
set +e
INCOMPLETE_RULE_OUTPUT="$(bash "$INDEX_SCRIPT" --feature-dir "$FEATURE_DIR" --slice US-1 2>&1)"
INCOMPLETE_RULE_STATUS=$?
set -e
[ "$INCOMPLETE_RULE_STATUS" -ne 0 ] || fail "incomplete rule matrix unexpectedly produced a context index"
printf '%s\n' "$INCOMPLETE_RULE_OUTPUT" | grep -Fq "exactly one SEC rule row" \
  || fail "incomplete rule matrix did not identify the missing rule row"

echo "PASS: context index derives slice context from authoritative artifacts and rejects incomplete inputs."
