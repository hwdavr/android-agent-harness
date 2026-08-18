#!/usr/bin/env bash
# Validates the machine-constrained Harness Feature Tracker in product.md.
# Designed for macOS /bin/bash (Bash 3.2).

set -e

PRODUCT_FILE="${1:-docs/product/product.md}"
START_MARKER="<!-- HARNESS_TRACKER_START -->"
END_MARKER="<!-- HARNESS_TRACKER_END -->"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

[ -f "$PRODUCT_FILE" ] || fail "$PRODUCT_FILE does not exist."

[ "$(grep -cF "$START_MARKER" "$PRODUCT_FILE")" -eq 1 ] ||
  fail "$PRODUCT_FILE must contain exactly one $START_MARKER marker."
[ "$(grep -cF "$END_MARKER" "$PRODUCT_FILE")" -eq 1 ] ||
  fail "$PRODUCT_FILE must contain exactly one $END_MARKER marker."

header=$(awk -v start="$START_MARKER" -v end="$END_MARKER" '
  $0 == start { in_tracker = 1; next }
  $0 == end { exit }
  in_tracker && /^\| ID \|/ { print; exit }
' "$PRODUCT_FILE")

[ "$header" = "| ID | Feature | Workspace | Status | Updated | Notes |" ] ||
  fail "Harness Feature Tracker must use the required six-column schema."

row_count=0
in_progress_count=0
seen_ids="|"

while IFS='|' read -r _ raw_id raw_feature raw_workspace raw_status raw_updated raw_notes _; do
  feature_id=$(trim "$raw_id")
  feature=$(trim "$raw_feature")
  workspace_cell=$(trim "$raw_workspace")
  status=$(trim "$raw_status")
  updated=$(trim "$raw_updated")
  notes=$(trim "$raw_notes")
  row_count=$((row_count + 1))

  printf '%s' "$feature_id" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' ||
    fail "Tracker ID '$feature_id' must use lowercase kebab case."
  case "$seen_ids" in
    *"|$feature_id|"*) fail "Tracker ID '$feature_id' is duplicated." ;;
  esac
  seen_ids="$seen_ids$feature_id|"

  [ -n "$feature" ] || fail "Tracker row '$feature_id' has no feature name."
  [ -n "$notes" ] || fail "Tracker row '$feature_id' has no notes."
  printf '%s' "$updated" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ||
    fail "Tracker row '$feature_id' has invalid Updated date '$updated'."

  workspace=$(printf '%s\n' "$workspace_cell" | sed -n 's/^\[\(docs\/[^]]*\)\](.*)$/\1/p' | sed 's:/*$::')
  workspace_target=$(printf '%s\n' "$workspace_cell" | sed -n 's/^\[docs\/[^]]*\](\([^)]*\))$/\1/p')
  [ -n "$workspace" ] ||
    fail "Tracker row '$feature_id' must contain one Markdown link labelled with its docs path."
  [ -d "$workspace" ] || fail "Tracker row '$feature_id' points to missing directory '$workspace'."

  case "$workspace" in
    docs/product/*) expected_target="${workspace#docs/product/}/" ;;
    *) fail "Tracker row '$feature_id' must point under docs/product/." ;;
  esac

  case "$status" in
    "Planning"|"Awaiting specification approval"|"Awaiting implementation approval"|"In Progress"|"Blocked") ;;
    "To be reviewed"|"To be fixed"|"To be human reviewed"|"Complete")
      feature_list="$workspace/feature_list.json"
      [ -f "$feature_list" ] || fail "$status tracker row '$feature_id' has no feature_list.json."
      feature_statuses=$(grep -E '"status"[[:space:]]*:' "$feature_list" || true)
      [ -n "$feature_statuses" ] || fail "$status tracker row '$feature_id' has no feature statuses."
      non_passing_statuses=$(printf '%s\n' "$feature_statuses" | grep -Ev '"status"[[:space:]]*:[[:space:]]*"passing"' || true)
      [ -z "$non_passing_statuses" ] || fail "$status tracker row '$feature_id' contains non-passing feature slices."
      ;;
    *) fail "Tracker row '$feature_id' has unsupported status '$status'." ;;
  esac

  [ "$workspace_target" = "$expected_target" ] ||
    fail "Tracker row '$feature_id' link target must be '$expected_target'."

  if [ "$status" = "In Progress" ]; then
    in_progress_count=$((in_progress_count + 1))
  fi
done < <(awk -v start="$START_MARKER" -v end="$END_MARKER" '
  $0 == start { in_tracker = 1; next }
  $0 == end { exit }
  in_tracker && /^\|/ && $0 !~ /^\| ID \|/ && $0 !~ /^\|---/ { print }
' "$PRODUCT_FILE")

[ "$row_count" -gt 0 ] || fail "Harness Feature Tracker has no feature rows."
[ "$in_progress_count" -le 1 ] || fail "Harness Feature Tracker allows at most one In Progress feature."

echo "Feature lifecycle tracker valid: $row_count feature(s), $in_progress_count in progress."
