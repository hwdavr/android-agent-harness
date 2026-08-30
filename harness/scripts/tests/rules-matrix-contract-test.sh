#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MATRIX_VALIDATOR="$PROJECT_ROOT/harness/scripts/check-rules-matrix-contract.sh"
COMPOSE_CHECKER="$PROJECT_ROOT/harness/scripts/check-compose-rules.sh"
CATALOG="$PROJECT_ROOT/harness/rules-matrix/rule-enforcement.json"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/rules-matrix-contract-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    fail "command unexpectedly succeeded: $*"
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    fail "failure did not contain: $expected"
  }
}

write_matrix_fixture() {
  local fixture="$1"
  mkdir -p "$fixture/harness/rules-matrix" "$fixture/harness/scripts"
  cp "$CATALOG" "$fixture/harness/rules-matrix/rule-enforcement.json"
  cp "$PROJECT_ROOT/harness/rules-matrix/architecture-rules-enforcement-matrix.md" \
    "$fixture/harness/rules-matrix/architecture-rules-enforcement-matrix.md"
  cp "$PROJECT_ROOT/harness/rules-matrix/compose-rules-enforcement-matrix.md" \
    "$fixture/harness/rules-matrix/compose-rules-enforcement-matrix.md"
  cp "$PROJECT_ROOT/harness/rules-matrix/localization-rules-enforcement-matrix.md" \
    "$fixture/harness/rules-matrix/localization-rules-enforcement-matrix.md"
  touch "$fixture/detekt.yml" \
    "$fixture/harness/scripts/check-architecture-rules.sh" \
    "$fixture/harness/scripts/check-compose-rules.sh" \
    "$fixture/harness/scripts/check-localization-rules.sh"
}

bash "$MATRIX_VALIDATOR"
bash "$COMPOSE_CHECKER" >/dev/null

stale_summary="$fixture_root/stale-summary"
write_matrix_fixture "$stale_summary"
sed 's/| 🤖 Scripted only | 20 |/| 🤖 Scripted only | 19 |/' \
  "$stale_summary/harness/rules-matrix/architecture-rules-enforcement-matrix.md" \
  > "$stale_summary/harness/rules-matrix/architecture-rules-enforcement-matrix.tmp"
mv "$stale_summary/harness/rules-matrix/architecture-rules-enforcement-matrix.tmp" \
  "$stale_summary/harness/rules-matrix/architecture-rules-enforcement-matrix.md"
expect_failure "architecture summary is stale or malformed" \
  bash "$MATRIX_VALIDATOR" --root "$stale_summary" \
  --catalog "$stale_summary/harness/rules-matrix/rule-enforcement.json"

unknown_owner="$fixture_root/unknown-owner"
write_matrix_fixture "$unknown_owner"
jq '(.matrices[] | select(.id == "compose").groups[] | select(.summary_label == "🤖 Scripted only").owners["1.7"]) = "unsupported-tool"' \
  "$unknown_owner/harness/rules-matrix/rule-enforcement.json" \
  > "$unknown_owner/harness/rules-matrix/rule-enforcement.tmp"
mv "$unknown_owner/harness/rules-matrix/rule-enforcement.tmp" \
  "$unknown_owner/harness/rules-matrix/rule-enforcement.json"
expect_failure "compose scripted rule 1.7 names missing or unknown owner" \
  bash "$MATRIX_VALIDATOR" --root "$unknown_owner" \
  --catalog "$unknown_owner/harness/rules-matrix/rule-enforcement.json"

dynamic_source="$fixture_root/dynamic-source"
mkdir -p "$dynamic_source"
printf '%s\n' 'Modifier.testTag("editor_code_block_${userInput}")' > "$dynamic_source/UnregisteredTag.kt"
expect_failure "dynamic testTag is not an approved documented immutable identifier" \
  bash "$COMPOSE_CHECKER" "$dynamic_source"

printf '%s\n' 'Modifier.testTag("editor_code_block_${index}")' > "$dynamic_source/TransientTag.kt"
expect_failure "dynamic testTag is not an approved documented immutable identifier" \
  bash "$COMPOSE_CHECKER" "$dynamic_source"

invalid_registry="$fixture_root/invalid-registry.json"
jq '(.entries[] | select(.id == "code-block-card").documentation) = "docs/product/missing-design.md"' \
  "$PROJECT_ROOT/harness/rules-matrix/documented-dynamic-test-tags.json" > "$invalid_registry"
expect_failure "references missing documentation" \
  env DOCUMENTED_DYNAMIC_TAGS_REGISTRY="$invalid_registry" \
  bash "$COMPOSE_CHECKER" "$dynamic_source"

echo "PASS: rules-matrix validator rejects stale counts and owners; Compose accepts only documented immutable dynamic tags."
