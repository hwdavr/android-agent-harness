#!/usr/bin/env bash
# Verifies required stage artifacts exist on disk before advancing a workflow stage.
#
# Usage: bash harness/scripts/check-stage-artifacts.sh <workflow> <stage> [artifact-directory]
#   workflow: feature-delivery | bug-fixing | api-contract-update | harness-planning | create-ui-and-verify
#   stage:    requirement-analysis | implementation-plan | feature-specification | slice-planning | ui-verification
#
# Exits 0 if required artifacts are present, 1 otherwise.
# Designed to run on macOS /bin/bash (Bash 3.2) — no mapfile, no arrays with set -u.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKFLOW="${1:-}"
STAGE="${2:-}"
DOCS_DIR="${3:-docs/current}"

if [ -z "$WORKFLOW" ] || [ -z "$STAGE" ]; then
  echo "Usage: $0 <workflow> <stage> [artifact-directory]" >&2
  echo "Workflows: feature-delivery, bug-fixing, api-contract-update, harness-planning, create-ui-and-verify" >&2
  echo "Stages: requirement-analysis, implementation-plan, feature-specification, slice-planning, ui-verification" >&2
  exit 2
fi

if [ ! -d "$DOCS_DIR" ]; then
  echo "FAIL: $DOCS_DIR does not exist — run the stage's skill to produce artifacts first." >&2
  exit 1
fi

if [ "$WORKFLOW" = "harness-planning" ]; then
  bash "$SCRIPT_DIR/check-feature-lifecycle.sh"
fi

require_file() {
  local pattern="$1"
  local label="$2"
  local found
  if [[ "$pattern" == *"*"* ]]; then
    found=$(latest_versioned_file "$pattern")
  elif [ -f "$DOCS_DIR/$pattern" ]; then
    found="$DOCS_DIR/$pattern"
  fi
  if [ -z "$found" ]; then
    echo "FAIL: no file matching '$pattern' in $DOCS_DIR ($label)." >&2
    exit 1
  fi
  echo "OK: $found"
}

warn_if_missing() {
  local pattern="$1"
  local label="$2"
  local found
  if [[ "$pattern" == *"*"* ]]; then
    found=$(latest_versioned_file "$pattern")
  elif [ -f "$DOCS_DIR/$pattern" ]; then
    found="$DOCS_DIR/$pattern"
  fi
  if [ -z "$found" ]; then
    echo "WARN: no file matching '$pattern' in $DOCS_DIR ($label) — recommended but not required for this workflow." >&2
  fi
}

latest_versioned_file() {
  local pattern="$1"
  find "$DOCS_DIR" -maxdepth 1 -name "$pattern" -print 2>/dev/null |
    while IFS= read -r file; do
      version=$(basename "$file" | sed -n 's/.*_v\([0-9][0-9]*\)\.md/\1/p')
      if [ -n "$version" ]; then
        printf '%s\t%s\n' "$version" "$file"
      fi
    done |
    sort -n |
    tail -n 1 |
    cut -f2-
}

case "$WORKFLOW/$STAGE" in
  feature-delivery/requirement-analysis)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "requirement/impact/design spec"
    ;;
  feature-delivery/implementation-plan)
    require_file "implementation_plan_v*.md" "implementation plan"
    require_file "test_plan_v*.md" "test plan"
    ;;
  bug-fixing/requirement-analysis)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "bug context/root cause spec"
    ;;
  bug-fixing/implementation-plan)
    require_file "implementation_plan_v*.md" "fix plan"
    warn_if_missing "test_plan_v*.md" "test plan (required by feature-delivery, optional for bug-fixing)"
    ;;
  api-contract-update/requirement-analysis)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "requirement/impact/design spec"
    ;;
  api-contract-update/implementation-plan)
    require_file "implementation_plan_v*.md" "implementation plan"
    require_file "test_plan_v*.md" "test plan"
    ;;
  harness-planning/feature-specification)
    require_file "spec.md" "feature specification"
    if [ -f "$DOCS_DIR/design.md" ] || grep -q "Screen States" "$DOCS_DIR/spec.md" || (git diff --name-only HEAD 2>/dev/null | grep -q "/ui/"); then
      if [ ! -f "docs/product/design_system.md" ]; then
        echo "FAIL: docs/product/design_system.md is required for UI planning." >&2
        exit 1
      fi
      require_file "design.md" "design specification"
      if ! grep -Fq "docs/product/design_system.md" "$DOCS_DIR/design.md"; then
        echo "FAIL: $DOCS_DIR/design.md must reference docs/product/design_system.md." >&2
        exit 1
      fi
      bash "$SCRIPT_DIR/check-keyboard-mockup-contract.sh" "$DOCS_DIR"
    fi
    ;;
  harness-planning/slice-planning)
    require_file "feature_list.json" "feature list"
    require_file "sprint-contract.md" "sprint contract"
    require_file "progress.md" "progress tracker"
    require_file "platform-capability-matrix.md" "platform capability matrix"
    if [ -f "$DOCS_DIR/design.md" ]; then
      bash "$SCRIPT_DIR/check-keyboard-mockup-contract.sh" "$DOCS_DIR"
    fi
    if ! grep -q "Acceptance Test Cases" "$DOCS_DIR/sprint-contract.md"; then
      echo "FAIL: sprint contract has no 'Acceptance Test Cases' matrix." >&2
      exit 1
    fi
    if ! grep -q "| Test ID | Covers AC | Test layer |" "$DOCS_DIR/sprint-contract.md"; then
      echo "FAIL: sprint contract acceptance tests must use the required traceability table." >&2
      exit 1
    fi
    if ! grep -q "## Spec Coverage Matrix" "$DOCS_DIR/sprint-contract.md"; then
      echo "FAIL: sprint contract has no required Spec Coverage Matrix." >&2
      exit 1
    fi
    if [ -f "$DOCS_DIR/spec.md" ]; then
      coverage_matrix=$(awk '
        /^## Spec Coverage Matrix/ { in_matrix = 1; next }
        in_matrix && /^## / { exit }
        in_matrix { print }
      ' "$DOCS_DIR/sprint-contract.md")
      missing_requirements=""
      for requirement_id in $(grep -oE 'FR-[0-9]+' "$DOCS_DIR/spec.md" | sort -u); do
        if ! printf '%s\n' "$coverage_matrix" | grep -q "$requirement_id"; then
          missing_requirements="$missing_requirements $requirement_id"
        fi
      done
      for requirement_id in $(grep -oE 'AC-[0-9]+' "$DOCS_DIR/spec.md" | sort -u); do
        if ! printf '%s\n' "$coverage_matrix" | grep -q "$requirement_id"; then
          missing_requirements="$missing_requirements $requirement_id"
        fi
      done
      if [ -n "$missing_requirements" ]; then
        echo "FAIL: sprint contract is missing source-spec coverage for:$missing_requirements" >&2
        exit 1
      fi
    fi
    if ! jq -e '
      .features | type == "array" and
      all(
        has("affects_ui") and (.affects_ui | type == "boolean") and
        has("requires_visual_verification") and
        (.requires_visual_verification | type == "boolean")
      )
    ' "$DOCS_DIR/feature_list.json" >/dev/null; then
      echo "FAIL: every feature must declare boolean affects_ui and requires_visual_verification fields." >&2
      exit 1
    fi
    bash "$SCRIPT_DIR/check-platform-evidence.sh" "$DOCS_DIR" --planning
    ui_feature_count=$(jq '[.features[] | select(.affects_ui)] | length' "$DOCS_DIR/feature_list.json")
    visual_owner_count=$(jq '[.features[] | select(.requires_visual_verification)] | length' "$DOCS_DIR/feature_list.json")
    if [ "$ui_feature_count" -eq 0 ] && [ "$visual_owner_count" -ne 0 ]; then
      echo "FAIL: a non-UI feature plan must not declare a visual-verification owner." >&2
      exit 1
    fi
    if [ "$ui_feature_count" -gt 0 ] && [ "$visual_owner_count" -ne 1 ]; then
      echo "FAIL: a UI feature plan must declare exactly one final visual-verification owner." >&2
      exit 1
    fi
    if [ "$visual_owner_count" -eq 1 ]; then
      visual_owner=$(jq -r '.features[] | select(.requires_visual_verification) | .id' "$DOCS_DIR/feature_list.json")
      visual_owner_is_ui=$(jq -r '.features[] | select(.requires_visual_verification) | .affects_ui' "$DOCS_DIR/feature_list.json")
      last_feature_id=$(jq -r '.features | max_by(.priority) | .id' "$DOCS_DIR/feature_list.json")
      if [ "$visual_owner_is_ui" != "true" ]; then
        echo "FAIL: visual-verification owner $visual_owner must affect UI." >&2
        exit 1
      fi
      if [ "$visual_owner" != "$last_feature_id" ]; then
        echo "FAIL: visual-verification owner $visual_owner must be the final priority slice $last_feature_id." >&2
        exit 1
      fi
    fi
    while IFS='|' read -r feature_id requires_visual; do
      story_block=$(awk -v heading="### $feature_id:" '
        index($0, heading) == 1 { in_story = 1; next }
        in_story && /^### US-[0-9]+:/ { exit }
        in_story { print }
      ' "$DOCS_DIR/sprint-contract.md")
      visual_row_count=$(printf '%s\n' "$story_block" | grep -c "| TC-${feature_id}-VIS" || true)
      if [ "$requires_visual" = "true" ] && [ "$visual_row_count" -eq 0 ]; then
        echo "FAIL: visual-verification owner $feature_id has no TC-${feature_id}-VIS row." >&2
        exit 1
      fi
      if [ "$requires_visual" = "false" ] && [ "$visual_row_count" -ne 0 ]; then
        echo "FAIL: intermediate slice $feature_id declares TC-${feature_id}-VIS rows; visual verification belongs only to the final owner." >&2
        exit 1
      fi
    done <<EOF
$(jq -r '.features[] | "\(.id)|\(.requires_visual_verification)"' "$DOCS_DIR/feature_list.json")
EOF
    bash "$SCRIPT_DIR/check-visual-evidence-contract.sh" "$DOCS_DIR" --planning
    ;;
  create-ui-and-verify/ui-verification)
    require_file "ui_verification.json" "UI verification report"
    bash "$SCRIPT_DIR/check-ui-verification-artifact.sh" "$DOCS_DIR"
    ;;
  create-ui-and-verify/*)
    echo "SKIP: create-ui-and-verify has no doc-artifact gate for '$STAGE'."
    ;;
  *)
    echo "FAIL: unknown workflow/stage '$WORKFLOW/$STAGE'." >&2
    echo "Known workflow/stage pairs:" >&2
    echo "  feature-delivery/requirement-analysis" >&2
    echo "  feature-delivery/implementation-plan" >&2
    echo "  bug-fixing/requirement-analysis" >&2
    echo "  bug-fixing/implementation-plan" >&2
    echo "  api-contract-update/requirement-analysis" >&2
    echo "  api-contract-update/implementation-plan" >&2
    echo "  harness-planning/feature-specification" >&2
    echo "  harness-planning/slice-planning" >&2
    echo "  create-ui-and-verify/ui-verification" >&2
    echo "  create-ui-and-verify/* (no artifact gate for other stages)" >&2
    exit 2
    ;;
esac

echo "Stage '$WORKFLOW/$STAGE' artifacts present."
