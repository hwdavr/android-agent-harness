#!/usr/bin/env bash
# Validates the platform capability contract and, during evaluation, its real
# Android boundary evidence. This is intentionally strict: missing devices,
# models, runtimes, or real boundary tests must not become passing evidence.

set -e

FEATURE_DIR="${1:-}"
MODE="${2:---evaluate}"
SLICE_FLAG="${3:-}"
SLICE_ID="${4:-}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [ -z "$FEATURE_DIR" ]; then
  echo "Usage: bash harness/scripts/check-platform-evidence.sh <feature-directory> [--planning|--evaluate] [--slice <slice-id>]" >&2
  exit 2
fi

if [ "$MODE" != "--planning" ] && [ "$MODE" != "--evaluate" ]; then
  echo "Usage: bash harness/scripts/check-platform-evidence.sh <feature-directory> [--planning|--evaluate] [--slice <slice-id>]" >&2
  exit 2
fi

if [ -n "$SLICE_FLAG" ] && { [ "$SLICE_FLAG" != "--slice" ] || [ -z "$SLICE_ID" ]; }; then
  echo "Usage: bash harness/scripts/check-platform-evidence.sh <feature-directory> [--planning|--evaluate] [--slice <slice-id>]" >&2
  exit 2
fi

FEATURE_JSON="$FEATURE_DIR/feature_list.json"
CONTRACT="$FEATURE_DIR/sprint-contract.md"

[ -f "$FEATURE_JSON" ] || fail "missing $FEATURE_JSON"
[ -f "$CONTRACT" ] || fail "missing $CONTRACT"

jq -e '.platform_validation | type == "object"' "$FEATURE_JSON" >/dev/null \
  || fail "feature_list.json must declare a platform_validation object"

MATRIX_RELATIVE=$(jq -r '.platform_validation.capability_matrix // empty' "$FEATURE_JSON")
[ -n "$MATRIX_RELATIVE" ] || fail "platform_validation.capability_matrix is required"

MATRIX="$FEATURE_DIR/$MATRIX_RELATIVE"
[ -f "$MATRIX" ] || fail "platform capability matrix is missing: $MATRIX"

grep -Fq "# Platform Capability Matrix" "$MATRIX" \
  || fail "platform matrix must contain '# Platform Capability Matrix'"
grep -Fq "## Runtime Matrix" "$MATRIX" \
  || fail "platform matrix must contain '## Runtime Matrix'"
grep -Fq "## Unsupported Environment Policy" "$MATRIX" \
  || fail "platform matrix must contain '## Unsupported Environment Policy'"
grep -Eiq 'minimum[[:space:]_-]*api|minSdk' "$MATRIX" \
  || fail "platform matrix must declare the minimum API"
grep -Eiq 'target[[:space:]_-]*api|targetSdk' "$MATRIX" \
  || fail "platform matrix must declare the target API"
grep -Eiq 'API[[:space:]_-]*[0-9]+' "$MATRIX" \
  || fail "platform matrix must contain explicit API-level rows"
grep -Eiq 'fail_loudly|fail loudly|non-zero|nonzero|blocked|revise' "$MATRIX" \
  || fail "platform matrix must define a loud failure policy"

POLICY=$(jq -r '.platform_validation.unsupported_environment_policy // empty' "$FEATURE_JSON")
[ "$POLICY" = "fail_loudly" ] \
  || fail "platform_validation.unsupported_environment_policy must be fail_loudly"

REQUIRED=$(jq -r 'if (.platform_validation | has("required")) then .platform_validation.required else empty end' "$FEATURE_JSON")
if [ "$REQUIRED" != "true" ] && [ "$REQUIRED" != "false" ]; then
  fail "platform_validation.required must be boolean"
fi

if [ "$REQUIRED" = "false" ]; then
  REASON=$(jq -r '.platform_validation.reason // empty' "$FEATURE_JSON")
  [ -n "$REASON" ] || fail "non-platform feature must explain why platform validation is not required"
  echo "PASS: platform validation is explicitly not required: $REASON"
  exit 0
fi

REAL_REQUIRED=$(jq -r '.platform_validation.real_boundary_test_required // empty' "$FEATURE_JSON")
[ "$REAL_REQUIRED" = "true" ] \
  || fail "platform-bound feature must require a real platform boundary test"

REAL_TEST_IDS=$(jq -r '.platform_validation.real_boundary_test_ids[]? // empty' "$FEATURE_JSON")
[ -n "$REAL_TEST_IDS" ] \
  || fail "platform-bound feature must declare real_boundary_test_ids"

REAL_TEST_FILES=$(jq -r '.platform_validation.real_boundary_test_files[]? // empty' "$FEATURE_JSON")
[ -n "$REAL_TEST_FILES" ] \
  || fail "platform-bound feature must declare real_boundary_test_files"

REAL_SIGNAL=$(jq -r '.platform_validation.real_boundary_test_signal // empty' "$FEATURE_JSON")
[ -n "$REAL_SIGNAL" ] \
  || fail "platform-bound feature must declare real_boundary_test_signal"

if [ -n "$SLICE_ID" ]; then
  jq -e --arg id "$SLICE_ID" '.features[]? | select(.id == $id)' "$FEATURE_JSON" >/dev/null \
    || fail "feature_list.json has no slice with id $SLICE_ID"
fi

if [ "$MODE" = "--planning" ]; then
  echo "PASS: platform capability matrix and planned real-boundary test contract are present."
  exit 0
fi

if [ -n "$SLICE_ID" ]; then
  SLICE_OWNS_REAL_BOUNDARY=false
  while IFS= read -r test_id; do
    [ -n "$test_id" ] || continue
    if jq -e --arg id "$SLICE_ID" --arg test_id "$test_id" \
      '.features[]? | select(.id == $id) | (.acceptance_test_ids // []) | index($test_id) != null' \
      "$FEATURE_JSON" >/dev/null; then
      SLICE_OWNS_REAL_BOUNDARY=true
      break
    fi
  done <<EOF
$REAL_TEST_IDS
EOF

  if [ "$SLICE_OWNS_REAL_BOUNDARY" = false ]; then
    echo "PASS: slice $SLICE_ID does not own a declared real platform boundary test; full-feature evidence is deferred."
    exit 0
  fi
fi

# Evaluation is stricter than planning. A required row that has not been
# executed is a failure, including rows described as skipped or unavailable.
if grep -Eiq '\|[[:space:]]*(pending|unavailable|blocked|skipped|not verified|unverified)[[:space:]]*\|' "$MATRIX"; then
  fail "platform matrix contains pending/unavailable/blocked/skipped runtime evidence; unsupported environments must fail loudly"
fi

while IFS= read -r test_id; do
  [ -n "$test_id" ] || continue

  CONTRACT_ROW=$(grep -F "| $test_id |" "$CONTRACT" || true)
  [ -n "$CONTRACT_ROW" ] || fail "real platform test $test_id is not declared in sprint-contract.md"
  printf '%s\n' "$CONTRACT_ROW" | grep -Eiq 'instrumented|androidTest|android test' \
    || fail "real platform test $test_id must be instrumented"
  printf '%s\n' "$CONTRACT_ROW" | grep -Fq 'connectedDebugAndroidTest' \
    || fail "real platform test $test_id must use connectedDebugAndroidTest"

  EVIDENCE_COUNT=$(jq --arg id "$test_id" '[.features[]?.evidence[]? | select(.test_id == $id and .exit_status == 0 and ((.executed_command // "") | contains("connectedDebugAndroidTest")))] | length' "$FEATURE_JSON")
  [ "$EVIDENCE_COUNT" -gt 0 ] \
    || fail "real platform test $test_id has no successful connected-test evidence"
done <<EOF
$REAL_TEST_IDS
EOF

while IFS= read -r test_file; do
  [ -n "$test_file" ] || continue
  case "$test_file" in
    app/src/androidTest/*) ;;
    *) fail "real platform test file must be under app/src/androidTest: $test_file" ;;
  esac
  if [ ! -f "$test_file" ] && [ -f "$FEATURE_DIR/$test_file" ]; then
    test_file="$FEATURE_DIR/$test_file"
  fi
  [ -f "$test_file" ] || fail "declared real platform test file is missing: $test_file"
  grep -Eiq "$REAL_SIGNAL" "$test_file" \
    || fail "real platform test $test_file has no real-platform signal ($REAL_SIGNAL); fake-only tests cannot satisfy the gate"
  if grep -Eiq 'FakeTranscriptRecognizer|FakeSpeechRecognizer|fake[[:space:]_-]*recogn' "$test_file" \
      && ! grep -Eiq "$REAL_SIGNAL" "$test_file"; then
    fail "real platform test $test_file is fake-only"
  fi
done <<EOF
$REAL_TEST_FILES
EOF

echo "PASS: platform matrix, loud unsupported-environment policy, and real platform boundary evidence are present."
