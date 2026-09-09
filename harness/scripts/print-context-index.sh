#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: bash harness/scripts/print-context-index.sh --feature-dir <path> --slice <id>" >&2
  exit 2
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    fail "shasum or sha256sum is required to print source hashes"
  fi
}

FEATURE_DIR=""
SLICE_ID=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --feature-dir)
      [ "$#" -ge 2 ] || usage
      FEATURE_DIR="$2"
      shift 2
      ;;
    --slice)
      [ "$#" -ge 2 ] || usage
      SLICE_ID="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[ -n "$FEATURE_DIR" ] && [ -n "$SLICE_ID" ] || usage

CONTRACT="$FEATURE_DIR/sprint-contract.md"
FEATURE_LIST="$FEATURE_DIR/feature_list.json"

[ -f "$CONTRACT" ] || fail "missing $CONTRACT"
[ -f "$FEATURE_LIST" ] || fail "missing $FEATURE_LIST"
command -v jq >/dev/null 2>&1 || fail "jq is required to print the context index"

jq empty "$FEATURE_LIST" 2>/dev/null || fail "$FEATURE_LIST is not valid JSON"

SLICE_COUNT=$(jq --arg id "$SLICE_ID" '[.features[]? | select(.id == $id)] | length' "$FEATURE_LIST")
case "$SLICE_COUNT" in
  0) fail "$FEATURE_LIST has no slice $SLICE_ID" ;;
  1) ;;
  *) fail "$FEATURE_LIST must contain exactly one slice $SLICE_ID" ;;
esac
SLICE_JSON=$(jq -c --arg id "$SLICE_ID" '[.features[]? | select(.id == $id)] | .[0]' "$FEATURE_LIST")
PLATFORM_VALIDATION_REQUIRED=$(jq -r 'if (.platform_validation | has("required")) then .platform_validation.required else empty end' "$FEATURE_LIST")
case "$PLATFORM_VALIDATION_REQUIRED" in
  true|false) ;;
  *) fail "$FEATURE_LIST must declare platform_validation.required as true or false" ;;
esac

RULE_ROWS=$(awk '
  /^## Rule Applicability Contract/ { in_contract = 1; next }
  in_contract && /^## / { exit }
  in_contract && /^\| (ARCH|IMPL|TEST|SUI|L10N|NAV|API|OBS|ANL|SEC) \|/ { print }
' "$CONTRACT")

[ -n "$RULE_ROWS" ] || fail "$CONTRACT has no Rule Applicability Contract rows"

RULE_IDS="ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC"
REQUIRED_RULES=""
EXCEPTION_RULES=""
NON_APPLICABLE_RULES=""
ACTIVE_RULE_FILES=""
NAV_ACTIVE=false

rule_file_for_id() {
  case "$1" in
    ARCH) printf '%s\n' ".agents/rules/android-architecture.md" ;;
    IMPL) printf '%s\n' ".agents/rules/implementation-rules.md" ;;
    TEST) printf '%s\n' ".agents/rules/testing-strategy.md" ;;
    SUI) printf '%s\n' ".agents/rules/compose-rules.md" ;;
    L10N) printf '%s\n' ".agents/rules/localization-rules.md" ;;
    NAV) printf '%s\n' ".agents/rules/navigation-rules.md" ;;
    API) printf '%s\n' ".agents/rules/api-contract-rules.md" ;;
    OBS) printf '%s\n' ".agents/rules/observability.md" ;;
    ANL) printf '%s\n' ".agents/rules/analytics-rules.md" ;;
    SEC) printf '%s\n' ".agents/rules/android-security.md" ;;
    *) fail "no rule file mapping for $1" ;;
  esac
}

for RULE_ID in $RULE_IDS; do
  RULE_COUNT=$(printf '%s\n' "$RULE_ROWS" | awk -F '|' -v id="$RULE_ID" '
    {
      value = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value == id) count++
    }
    END { print count + 0 }
  ')
  [ "$RULE_COUNT" -eq 1 ] || fail "$CONTRACT must contain exactly one $RULE_ID rule row"

  DECISION=$(printf '%s\n' "$RULE_ROWS" | awk -F '|' -v id="$RULE_ID" '
    {
      row_id = $2
      decision = $4
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", row_id)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", decision)
      if (row_id == id) print decision
    }
  ')

  case "$DECISION" in
    Required*)
      REQUIRED_RULES="${REQUIRED_RULES}${RULE_ID}\n"
      ACTIVE_RULE_FILES="${ACTIVE_RULE_FILES}$(rule_file_for_id "$RULE_ID")\n"
      [ "$RULE_ID" != "NAV" ] || NAV_ACTIVE=true
      ;;
    "Exception — approved by "*)
      EXCEPTION_RULES="${EXCEPTION_RULES}${RULE_ID}\n"
      ACTIVE_RULE_FILES="${ACTIVE_RULE_FILES}$(rule_file_for_id "$RULE_ID")\n"
      [ "$RULE_ID" != "NAV" ] || NAV_ACTIVE=true
      ;;
    "Not applicable — "*)
      NON_APPLICABLE_RULES="${NON_APPLICABLE_RULES}${RULE_ID}\n"
      ;;
    *)
      fail "$CONTRACT has an unsupported $RULE_ID decision: $DECISION"
      ;;
  esac
done

to_json_array() {
  printf '%b' "$1" | sed '/^$/d' | jq -R . | jq -sc .
}

REQUIRED_JSON=$(to_json_array "$REQUIRED_RULES")
EXCEPTION_JSON=$(to_json_array "$EXCEPTION_RULES")
NON_APPLICABLE_JSON=$(to_json_array "$NON_APPLICABLE_RULES")
ACTIVE_RULE_FILES_JSON=$(to_json_array "$ACTIVE_RULE_FILES")
STAGE_TESTING_FILES=".agents/rules/testing-practices.md\n"
if [ "$(printf '%s' "$SLICE_JSON" | jq -r '.affects_ui // false')" = "true" ] \
  || [ "$(printf '%s' "$SLICE_JSON" | jq -r '.requires_visual_verification // false')" = "true" ] \
  || [ "$(printf '%s' "$SLICE_JSON" | jq -r '.production_journey.required // false')" = "true" ] \
  || [ "$PLATFORM_VALIDATION_REQUIRED" = "true" ] \
  || [ "$NAV_ACTIVE" = "true" ]; then
  STAGE_TESTING_FILES="${STAGE_TESTING_FILES}.agents/rules/testing-runtime-evidence.md\n"
fi
STAGE_TESTING_FILES_JSON=$(to_json_array "$STAGE_TESTING_FILES")
CONTRACT_HASH=$(sha256_file "$CONTRACT")
FEATURE_LIST_HASH=$(sha256_file "$FEATURE_LIST")

jq -n \
  --arg slice "$SLICE_ID" \
  --arg contract_path "$CONTRACT" \
  --arg feature_list_path "$FEATURE_LIST" \
  --arg contract_hash "$CONTRACT_HASH" \
  --arg feature_list_hash "$FEATURE_LIST_HASH" \
  --argjson platform_validation_required "$PLATFORM_VALIDATION_REQUIRED" \
  --argjson slice_metadata "$SLICE_JSON" \
  --argjson required_rules "$REQUIRED_JSON" \
  --argjson exception_rules "$EXCEPTION_JSON" \
  --argjson non_applicable_rules "$NON_APPLICABLE_JSON" \
  --argjson active_rule_files "$ACTIVE_RULE_FILES_JSON" \
  --argjson testing_context_files "$STAGE_TESTING_FILES_JSON" \
  '{
    slice: $slice,
    authority: {
      sprint_contract: $contract_path,
      feature_list: $feature_list_path,
      sprint_contract_sha256: $contract_hash,
      feature_list_sha256: $feature_list_hash
    },
    rule_context: {
      required: $required_rules,
      exceptions: $exception_rules,
      not_applicable: $non_applicable_rules,
      files: $active_rule_files
    },
    stage_context: {
      testing: $testing_context_files
    },
    execution_flags: {
      affects_ui: $slice_metadata.affects_ui,
      requires_visual_verification: $slice_metadata.requires_visual_verification,
      platform_validation_required: $platform_validation_required,
      production_journey_required: ($slice_metadata.production_journey.required // false)
    },
    acceptance_test_ids: ($slice_metadata.acceptance_test_ids // []),
    source_pointers: {
      rule_applicability: "sprint-contract.md#Rule Applicability Contract",
      slice: ("sprint-contract.md#" + $slice),
      execution_metadata: ("feature_list.json#features[id=" + $slice + "]")
    }
  }'
