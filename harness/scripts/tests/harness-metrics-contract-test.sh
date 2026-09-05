#!/usr/bin/env bash
# Contract test for Harness Observability Metrics validator and aggregator.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-harness-metrics.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/harness-metrics-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_success() {
  local output
  if ! output=$("$@" 2>&1); then
    echo "$output" >&2
    fail_test "command unexpectedly failed: $*"
  fi
}

expect_failure() {
  local expected_exit="$1"
  local expected_text="$2"
  shift 2
  local output
  set +e
  output=$("$@" 2>&1)
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "$output" >&2
    fail_test "command unexpectedly succeeded: $*"
  fi

  if [ "$status" -ne "$expected_exit" ]; then
    echo "$output" >&2
    fail_test "expected exit code $expected_exit, got $status: $*"
  fi

  printf '%s\n' "$output" | grep -Fq "$expected_text" || {
    echo "$output" >&2
    fail_test "output did not contain expected text '$expected_text': $*"
  }
}

mkdir -p "$FIXTURE_ROOT/docs/product/2026-09-01-feature"
mkdir -p "$FIXTURE_ROOT/docs/current"

# Case 1: Valid summary file passes validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_US-1.md"
# Change Summary — Feature 1

## Stage Progress
| Stage | Status | Timestamp | Notes |
|---|---|---|---|
| Orient | ✅ Completed | 2026-09-01 | Done |

## Observability & Execution Metrics

| Metric | Value |
|---|---|
| **Model** | Claude 3.7 Sonnet |
| **Total Wall-Clock Time** | 20m 00s |
| **Files Read / Modified** | 10 / 4 |
| **Commands Executed** | 8 (First-pass rate: 100.0%) |
| **Gate Failure Retries** | 0 |

```json:metrics
{
  "slice_id": "US-1",
  "model": "Claude 3.7 Sonnet",
  "total_duration_sec": 1200,
  "files_read_count": 10,
  "files_modified_count": 4,
  "commands_executed": 8,
  "first_pass_command_rate": 100.0,
  "gate_retries_total": 0,
  "gate_failure_causes": [],
  "stages": {
    "orient": {"duration_sec": 60, "retries": 0, "commands": 1},
    "implement": {"duration_sec": 900, "retries": 0, "commands": 0},
    "test": {"duration_sec": 240, "retries": 0, "commands": 7}
  }
}
```
EOF

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --validate "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_US-1.md"

# Case 2: Missing file fails validation
expect_failure 2 "Summary file not found" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --validate "$FIXTURE_ROOT/docs/non-existent.md"

# Case 3: Missing section header fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_bad_header.md"
# Change Summary
```json:metrics
{"model": "Claude 3.7 Sonnet"}
```
EOF

expect_failure 2 "Missing section header: '## Observability & Execution Metrics'" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --validate "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_bad_header.md"

# Case 4: Missing json:metrics codeblock fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_no_json.md"
# Change Summary
## Observability & Execution Metrics
No code block here
EOF

expect_failure 2 "No json:metrics block found in summary" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --validate "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_no_json.md"

# Case 5: Malformed JSON in metrics block fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_malformed_json.md"
# Change Summary
## Observability & Execution Metrics
```json:metrics
{
  "model": "Test",
  invalid json
}
```
EOF

expect_failure 2 "Failed to parse json:metrics" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --validate "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_malformed_json.md"

# Case 6: Missing required keys fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_missing_keys.md"
# Change Summary
## Observability & Execution Metrics
```json:metrics
{
  "model": "Claude 3.7 Sonnet"
}
```
EOF

expect_failure 2 "json:metrics missing required key 'total_duration_sec'" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --validate "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_missing_keys.md"

# Case 7: Invalid first_pass_command_rate out of range [0, 100] fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_bad_rate.md"
# Change Summary
## Observability & Execution Metrics
```json:metrics
{
  "slice_id": "US-1",
  "model": "Claude 3.7 Sonnet",
  "total_duration_sec": 100,
  "files_read_count": 5,
  "files_modified_count": 2,
  "commands_executed": 3,
  "first_pass_command_rate": 150.0,
  "gate_retries_total": 0,
  "stages": {}
}
```
EOF

expect_failure 2 "first_pass_command_rate must be between 0 and 100" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --validate "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_bad_rate.md"

# Case 8: Strict mode rejects placeholder string values
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_placeholder.md"
# Change Summary
## Observability & Execution Metrics
```json:metrics
{
  "slice_id": "US-1",
  "model": "{model_name}",
  "total_duration_sec": 100,
  "files_read_count": 5,
  "files_modified_count": 2,
  "commands_executed": 3,
  "first_pass_command_rate": 100.0,
  "gate_retries_total": 0,
  "stages": {}
}
```
EOF

expect_failure 2 "contains placeholder value '{model_name}'" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --strict \
  --validate "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_placeholder.md"

# Case 9: --report aggregates multiple summaries accurately
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/2026-09-01-feature/summary_US-2.md"
# Change Summary — Feature 2
## Observability & Execution Metrics
```json:metrics
{
  "slice_id": "US-2",
  "model": "Gemini 2.5 Flash",
  "total_duration_sec": 600,
  "files_read_count": 6,
  "files_modified_count": 2,
  "commands_executed": 4,
  "first_pass_command_rate": 75.0,
  "gate_retries_total": 1,
  "gate_failure_causes": ["ktlintCheck"],
  "stages": {
    "orient": {"duration_sec": 30, "retries": 0, "commands": 1},
    "implement": {"duration_sec": 450, "retries": 0, "commands": 0},
    "test": {"duration_sec": 120, "retries": 1, "commands": 3}
  }
}
```
EOF

report_output=$(bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --summary-dir "$FIXTURE_ROOT/docs/product" \
  --report)

printf '%s\n' "$report_output" | grep -Fq "Total Delivered Slices:    2" || fail_test "Report missing 2 total delivered slices"
printf '%s\n' "$report_output" | grep -Fq "Claude 3.7 Sonnet" || fail_test "Report missing Claude 3.7 Sonnet model"
printf '%s\n' "$report_output" | grep -Fq "Gemini 2.5 Flash" || fail_test "Report missing Gemini 2.5 Flash model"
printf '%s\n' "$report_output" | grep -Fq "ktlintCheck" || fail_test "Report missing ktlintCheck retry cause"

echo "PASS: All 9 harness-metrics contract test cases passed."
