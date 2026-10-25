#!/usr/bin/env bash
# Verifies required stage artifacts exist on disk before advancing a workflow stage.
#
# Usage: bash harness/scripts/check-stage-artifacts.sh <workflow> <stage> [artifact-directory] [feature-id]
#   workflow: feature-delivery | bug-fixing | api-contract-update | harness-generator | harness-planning | create-ui-and-verify
#   stage:    orient | requirement-analysis | ui-contract | ux-design | bug-reproduction | implementation-plan | testing | feature-specification | slice-planning | ui-verification
#
# Exits 0 if required artifacts are present, 1 otherwise.
# Designed to run on macOS /bin/bash (Bash 3.2) — no mapfile, no arrays with set -u.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(pwd)}"

WORKFLOW="${1:-}"
STAGE="${2:-}"
DOCS_DIR="${3:-docs/current}"
FEATURE_ID="${4:-}"

if [ -z "$WORKFLOW" ] || [ -z "$STAGE" ]; then
  echo "Usage: $0 <workflow> <stage> [artifact-directory] [feature-id]" >&2
  echo "Workflows: feature-delivery, bug-fixing, api-contract-update, harness-generator, harness-planning, create-ui-and-verify" >&2
  echo "Stages: orient, requirement-analysis, ui-contract, ux-design, bug-reproduction, implementation-plan, testing, feature-specification, slice-planning, ui-verification" >&2
  exit 2
fi

if ! PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd -P)"; then
  echo "FAIL: project root does not exist: $PROJECT_ROOT" >&2
  exit 2
fi

case "$DOCS_DIR" in
  /*) ;;
  *) DOCS_DIR="$PROJECT_ROOT/$DOCS_DIR" ;;
esac

if [ ! -d "$DOCS_DIR" ]; then
  echo "FAIL: $DOCS_DIR does not exist — run the stage's skill to produce artifacts first." >&2
  exit 1
fi

DOCS_DIR="$(cd "$DOCS_DIR" && pwd -P)"
NESTED_HARNESS_ROOT="$PROJECT_ROOT/android-agent-harness"
if [ -d "$NESTED_HARNESS_ROOT" ]; then
  NESTED_HARNESS_ROOT="$(cd "$NESTED_HARNESS_ROOT" && pwd -P)"
  case "$DOCS_DIR" in
    "$NESTED_HARNESS_ROOT"|"$NESTED_HARNESS_ROOT"/*)
      echo "FAIL: stage artifacts must be under the consuming project's root docs/ or .scratch/; $DOCS_DIR is owned by the shared android-agent-harness submodule." >&2
      exit 1
      ;;
  esac
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

require_rule_applicability() {
  local artifact="$1"
  local label="$2"
  local rule_id
  local row

  if ! grep -Fq "## Rule Applicability" "$artifact"; then
    echo "FAIL: $artifact is missing the '## Rule Applicability' section ($label)." >&2
    exit 1
  fi

  for rule_id in ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC; do
    row=$(grep -E "^[[:space:]]*\|[[:space:]]*$rule_id[[:space:]]*\|" "$artifact" | head -n 1 || true)
    if [ -z "$row" ]; then
      echo "FAIL: $artifact is missing the $rule_id rule-applicability row ($label)." >&2
      exit 1
    fi
    case "$row" in
      *"| Required |"* | *"| Not applicable — "* | *"| Exception — approved by "*)
        ;;
      *)
        echo "FAIL: $artifact has no valid decision for $rule_id ($label). Use Required, Not applicable — <reason>, or Exception — approved by <user/date>." >&2
        exit 1
        ;;
    esac
  done

  echo "OK: $artifact has a complete rule-applicability contract."
}

require_canonical_rule_reference() {
  local artifact="$1"
  local specification="$2"
  local label="$3"
  local specification_reference

  specification_reference="$(basename "$specification")#rule-applicability"
  if ! grep -Fq "$specification_reference" "$artifact"; then
    echo "FAIL: $artifact is missing the canonical Rule Applicability reference '$specification_reference' ($label)." >&2
    exit 1
  fi

  echo "OK: $artifact references $specification_reference."
}

require_required_rule_mappings() {
  local artifact="$1"
  local specification="$2"
  local label="$3"
  local rule_id
  local specification_row

  for rule_id in ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC; do
    specification_row=$(grep -E "^[[:space:]]*\|[[:space:]]*$rule_id[[:space:]]*\|" "$specification" | head -n 1 || true)
    case "$specification_row" in
      *"| Required |"*)
        if ! grep -Eq "^[[:space:]]*\|[[:space:]]*$rule_id[[:space:]]*\|" "$artifact"; then
          echo "FAIL: $artifact is missing the required $rule_id evidence mapping ($label)." >&2
          exit 1
        fi
        ;;
    esac
  done

  echo "OK: $artifact maps every required Rule Applicability row."
}

require_rule_applicability_mapping() {
  local artifact="$1"
  local specification="$2"
  local label="$3"

  require_canonical_rule_reference "$artifact" "$specification" "$label"
  require_required_rule_mappings "$artifact" "$specification" "$label"
}

sui_is_active() {
  local specification="$1"
  grep -E '^[[:space:]]*\|[[:space:]]*SUI[[:space:]]*\|' "$specification" |
    grep -Eq '\|[[:space:]]*(Required|Exception — approved by)[^|]*\|'
}

spec_has_ui() {
  sui_is_active "$1" || grep -q '^## Screen States' "$1"
}

require_ui_contract() {
  local specification="$1"
  shift
  require_file "UI_contract.md" "UI state contract"
  if [ ! -f "$PROJECT_ROOT/docs/product/design_system.md" ]; then
    echo "FAIL: docs/product/design_system.md is required for UX design." >&2
    exit 1
  fi
  if ! grep -Fq "docs/product/design_system.md" "$DOCS_DIR/UI_contract.md"; then
    echo "FAIL: $DOCS_DIR/UI_contract.md must reference docs/product/design_system.md." >&2
    exit 1
  fi
  if [ -n "$specification" ]; then
    python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --spec "$specification" "$@"
  else
    python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" "$@"
  fi
}

require_harness_ux_design() {
  require_ui_contract "$DOCS_DIR/spec.md"
  require_file "visual_evidence/visual-target.json" "UX visual target manifest"
  local manifest="$DOCS_DIR/visual_evidence/visual-target.json"
  local state
  python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --target-manifest "$manifest"
  while IFS= read -r state; do
    bash "$SCRIPT_DIR/visual-target-prompt.sh" --target "$manifest" --state "$state" >/dev/null
  done <<EOF
$(jq -r '.states | keys[]' "$manifest")
EOF
}

ime_is_active() {
  grep -Eiq '(^|[^[:alnum:]_])IME([^[:alnum:]_]|$)|software[[:space:]-]+keyboard|WindowInsets' "$1"
}

ime_text_is_active() {
  printf '%s\n' "$1" |
    grep -Eiq '(^|[^[:alnum:]_])IME([^[:alnum:]_]|$)|software[[:space:]-]+keyboard|WindowInsets'
}

require_bug_reproduction_evidence() {
  local spec="$1"
  local summary="$2"
  local reproduction_section
  local result_line
  local reproduction_file
  local reproduction_test_method
  local test_path

  reproduction_section=$(awk '
    /^## Reproduction Test/ { in_reproduction = 1 }
    in_reproduction && /^## / && !/^## Reproduction Test/ { exit }
    in_reproduction { print }
  ' "$spec")
  if [ -z "$reproduction_section" ]; then
    echo "FAIL: $spec is missing a '## Reproduction Test' section." >&2
    exit 1
  fi

  result_line=$(printf '%s\n' "$reproduction_section" |
    sed -n -E 's/^[[:space:]]*-[[:space:]]*\*{0,2}(Run result|Result)\*{0,2}:[[:space:]]*(.*)$/\2/p' |
    head -n 1)
  if [ -z "$result_line" ]; then
    echo "FAIL: $spec reproduction evidence must record a Run result or Result line." >&2
    exit 1
  fi
  if ! printf '%s\n' "$result_line" | rg -qi 'FAILED|RED'; then
    echo "FAIL: $spec reproduction result must record FAILED or RED evidence." >&2
    exit 1
  fi
  if printf '%s\n' "$result_line" | rg -qi 'PASSED|SUCCESSFUL'; then
    echo "FAIL: $spec reproduction result cannot claim a passing result." >&2
    exit 1
  fi

  if ! rg -qi '^[[:space:]]*\|[[:space:]]*Bug Reproduction[[:space:]]*\|.*(RED|FAILED)' "$summary"; then
    echo "FAIL: $summary must mark Bug Reproduction as RED or FAILED." >&2
    exit 1
  fi

  reproduction_file=$(printf '%s\n' "$reproduction_section" |
    sed -n -E 's/^[[:space:]]*-[[:space:]]*\*{0,2}File\*{0,2}:[[:space:]]*`([^`]+)`.*/\1/p' |
    head -n 1)
  if [ -z "$reproduction_file" ]; then
    echo "FAIL: $spec reproduction evidence must name the test File." >&2
    exit 1
  fi

  case "$reproduction_file" in
    /*) test_path="$reproduction_file" ;;
    *) test_path="$PROJECT_ROOT/$reproduction_file" ;;
  esac
  if [ ! -f "$test_path" ]; then
    echo "FAIL: reproduction test file does not exist: $reproduction_file" >&2
    exit 1
  fi
  if [[ "$reproduction_file" == *RoborazziTest.kt ]] &&
    [[ ! "$reproduction_file" =~ ^app/src/test/java/.+/roborazzi/[^/]+RoborazziTest\.kt$ ]]; then
    echo "FAIL: Roborazzi reproduction tests must live under app/src/test/java/<package>/roborazzi/: $reproduction_file" >&2
    exit 1
  fi
  reproduction_test_method=$(printf '%s\n' "$reproduction_section" |
    sed -n -E 's/^[[:space:]]*-[[:space:]]*\*{0,2}Test name\*{0,2}:[[:space:]]*`([^`]+)`.*/\1/p' |
    head -n 1)
  if [ -z "$reproduction_test_method" ]; then
    reproduction_test_method=$(printf '%s\n' "$reproduction_section" |
      sed -n -E 's/.*(test|method)[[:space:]]+`([A-Za-z_][A-Za-z0-9_]*)`.*/\2/p' |
      head -n 1)
  fi
  if ime_text_is_active "$reproduction_section"; then
    local production_activity
    production_activity=$(printf '%s\n' "$reproduction_section" |
      sed -n -E 's/^[[:space:]]*-[[:space:]]*\*{0,2}Production activity\*{0,2}:[[:space:]]*`([^`]+)`.*/\1/p' |
      head -n 1)
    if [ -z "$production_activity" ] || [ -z "$reproduction_test_method" ]; then
      echo "FAIL: IME reproduction must declare Test name and Production activity in Reproduction Test." >&2
      exit 1
    fi
    python3 "$SCRIPT_DIR/kotlin_ast_checker.py" ime-boundary \
      --project-root "$PROJECT_ROOT" --test-file "$test_path" \
      --test-method "$reproduction_test_method" --production-entry "$production_activity"
  fi
  bash "$SCRIPT_DIR/check-rendered-output-contract.sh" \
    --project-root "$PROJECT_ROOT" \
    --test-file "$test_path" \
    --test-method "$reproduction_test_method" \
    --claim "$reproduction_section"
  echo "OK: $spec records RED reproduction evidence in $reproduction_file"
}

require_production_journey() {
  local artifact="$1"
  local boundary
  local test_file
  local test_method
  local production_entry
  local return_boundary
  local post_return_assertion
  local test_path

  boundary=$(awk '
    /^## Production Journey Boundary[[:space:]]*$/ { in_boundary = 1; next }
    in_boundary && /^## / { exit }
    in_boundary { print }
  ' "$artifact")
  if [ -z "$boundary" ]; then
    echo "FAIL: $artifact requires a '## Production Journey Boundary' section for NAV-scoped testing." >&2
    exit 1
  fi

  test_file=$(printf '%s\n' "$boundary" | sed -n 's/^[[:space:]]*-[[:space:]]*Test file:[[:space:]]*`\([^`]*\)`.*/\1/p' | head -n 1)
  test_method=$(printf '%s\n' "$boundary" | sed -n 's/^[[:space:]]*-[[:space:]]*Test method:[[:space:]]*`\([^`]*\)`.*/\1/p' | head -n 1)
  production_entry=$(printf '%s\n' "$boundary" | sed -n 's/^[[:space:]]*-[[:space:]]*Production entry point:[[:space:]]*`\([^`]*\)`.*/\1/p' | head -n 1)
  return_boundary=$(printf '%s\n' "$boundary" | sed -n 's/^[[:space:]]*-[[:space:]]*Return boundary:[[:space:]]*\(.*\)$/\1/p' | head -n 1)
  post_return_assertion=$(printf '%s\n' "$boundary" | sed -n 's/^[[:space:]]*-[[:space:]]*Post-return assertion:[[:space:]]*\(.*\)$/\1/p' | head -n 1)

  if [ -z "$test_file" ] || [ -z "$test_method" ] || [ -z "$production_entry" ] || [ -z "$return_boundary" ] || [ -z "$post_return_assertion" ]; then
    echo "FAIL: $artifact has an incomplete '## Production Journey Boundary' declaration." >&2
    echo "FAIL: declare Test file, Test method, Production entry point, Return boundary, and Post-return assertion." >&2
    exit 1
  fi

  case "$test_file" in
    /*) test_path="$test_file" ;;
    *) test_path="$PROJECT_ROOT/$test_file" ;;
  esac

  bash "$SCRIPT_DIR/check-journey-test-contract.sh" \
    --project-root "$PROJECT_ROOT" \
    --test-file "$test_path" \
    --test-method "$test_method" \
    --production-entry "$production_entry"
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
  harness-generator/orient)
    if [ -z "$FEATURE_ID" ]; then
      echo "FAIL: harness-generator/orient requires the selected feature id to validate its summary." >&2
      exit 2
    fi
    require_file "summary_${FEATURE_ID}.md" "stage progress tracker"
    ;;
  feature-delivery/requirement-analysis)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "requirement and impact specification"
    require_rule_applicability "$(latest_versioned_file "spec_v*.md")" "feature-delivery requirement analysis"
    ;;
  feature-delivery/ui-contract|feature-delivery/ux-design)
    require_file "spec_v*.md" "clarified requirement specification"
    specification=$(latest_versioned_file "spec_v*.md")
    require_rule_applicability "$specification" "feature-delivery UX input"
    if spec_has_ui "$specification"; then
      if [ "$STAGE" = "ui-contract" ]; then
        require_ui_contract "$specification" --inventory
      else
        require_ui_contract "$specification"
      fi
    else
      echo "N/A: the clarified specification has no UI scope."
    fi
    ;;
  feature-delivery/implementation-plan)
    require_file "spec_v*.md" "canonical requirement/impact/design spec"
    require_file "implementation_plan_v*.md" "implementation plan"
    require_file "test_plan_v*.md" "test plan"
    specification=$(latest_versioned_file "spec_v*.md")
    require_rule_applicability_mapping "$(latest_versioned_file "implementation_plan_v*.md")" "$specification" "feature-delivery implementation plan"
    require_rule_applicability_mapping "$(latest_versioned_file "test_plan_v*.md")" "$specification" "feature-delivery test plan"
    if spec_has_ui "$specification"; then
      require_ui_contract "$specification" --plan "$(latest_versioned_file "implementation_plan_v*.md")" --test-plan "$(latest_versioned_file "test_plan_v*.md")"
    fi
    ;;
  bug-fixing/requirement-analysis)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "bug context/root cause spec"
    require_rule_applicability "$(latest_versioned_file "spec_v*.md")" "bug-fixing requirement analysis"
    python3 "$SCRIPT_DIR/read-qa-bug-context.py" --project-root "$PROJECT_ROOT" \
      --spec "$(latest_versioned_file "spec_v*.md")" --check
    ;;
  bug-fixing/bug-reproduction)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "bug context/root cause spec"
    require_bug_reproduction_evidence \
      "$(latest_versioned_file "spec_v*.md")" \
      "$(latest_versioned_file "summary_v*.md")"
    ;;
  bug-fixing/implementation-plan)
    require_file "spec_v*.md" "canonical bug context/root cause spec"
    require_file "implementation_plan_v*.md" "fix plan"
    warn_if_missing "test_plan_v*.md" "test plan (required by feature-delivery, optional for bug-fixing)"
    specification=$(latest_versioned_file "spec_v*.md")
    require_rule_applicability_mapping "$(latest_versioned_file "implementation_plan_v*.md")" "$specification" "bug-fixing implementation plan"
    if [ -n "$(latest_versioned_file "test_plan_v*.md")" ]; then
      require_rule_applicability_mapping "$(latest_versioned_file "test_plan_v*.md")" "$specification" "bug-fixing test plan"
    fi
    if sui_is_active "$specification" || ime_is_active "$specification"; then
      require_file "UI_contract.md" "per-state UI and IME design contract"
      test_plan_artifact=$(latest_versioned_file "test_plan_v*.md")
      python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --spec "$specification" \
        --plan "$(latest_versioned_file "implementation_plan_v*.md")" \
        --test-plan "${test_plan_artifact:-$DOCS_DIR/test_plan_v1.md}"
    fi
    ;;
  bug-fixing/testing)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "canonical bug context/root cause spec"
    require_file "test_plan_v*.md" "test plan"
    require_rule_applicability_mapping "$(latest_versioned_file "test_plan_v*.md")" "$(latest_versioned_file "spec_v*.md")" "bug-fixing testing"
    test_plan_artifact="$(latest_versioned_file "test_plan_v*.md")"
    specification="$(latest_versioned_file "spec_v*.md")"
    if sui_is_active "$specification" || ime_is_active "$specification"; then
      require_file "UI_contract.md" "per-state UI and IME design contract"
      python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --spec "$specification" \
        --test-plan "$test_plan_artifact" --runtime --project-root "$PROJECT_ROOT"
    fi
    nav_row="$(grep -E "^[[:space:]]*\|[[:space:]]*NAV[[:space:]]*\|" "$test_plan_artifact" | head -n 1 || true)"
    case "$nav_row" in
      *"| Required |"*)
        require_production_journey "$test_plan_artifact"
        ;;
    esac
    ;;
  feature-delivery/testing)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "canonical requirement/impact specification"
    require_file "test_plan_v*.md" "approved feature test plan"
    test_plan_artifact="$(latest_versioned_file "test_plan_v*.md")"
    specification="$(latest_versioned_file "spec_v*.md")"
    require_rule_applicability_mapping "$test_plan_artifact" "$specification" "feature-delivery testing"
    if sui_is_active "$specification" || ime_is_active "$specification"; then
      require_file "UI_contract.md" "per-state UI and IME design contract"
      python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --spec "$specification" \
        --test-plan "$test_plan_artifact" --runtime --project-root "$PROJECT_ROOT"
    fi
    nav_row="$(grep -E "^[[:space:]]*\|[[:space:]]*NAV[[:space:]]*\|" "$specification" | head -n 1 || true)"
    case "$nav_row" in
      *"| Required |"*)
        require_production_journey "$test_plan_artifact"
        ;;
    esac
    ;;
  api-contract-update/requirement-analysis)
    require_file "summary_v*.md" "stage progress tracker"
    require_file "spec_v*.md" "requirement/impact/design spec"
    require_rule_applicability "$(latest_versioned_file "spec_v*.md")" "api-contract-update requirement analysis"
    ;;
  api-contract-update/implementation-plan)
    require_file "spec_v*.md" "canonical requirement/impact/design spec"
    require_file "implementation_plan_v*.md" "implementation plan"
    require_file "test_plan_v*.md" "test plan"
    specification=$(latest_versioned_file "spec_v*.md")
    require_rule_applicability_mapping "$(latest_versioned_file "implementation_plan_v*.md")" "$specification" "api-contract-update implementation plan"
    require_rule_applicability_mapping "$(latest_versioned_file "test_plan_v*.md")" "$specification" "api-contract-update test plan"
    ;;
  harness-planning/feature-specification)
    require_file "spec.md" "feature specification"
    require_rule_applicability "$DOCS_DIR/spec.md" "harness-planning feature specification"
    ;;
  harness-planning/ui-contract|harness-planning/ux-design)
    require_file "spec.md" "clarified feature specification"
    require_rule_applicability "$DOCS_DIR/spec.md" "harness-planning UX input"
    if spec_has_ui "$DOCS_DIR/spec.md"; then
      if [ "$STAGE" = "ui-contract" ]; then
        require_ui_contract "$DOCS_DIR/spec.md" --inventory
      else
        require_harness_ux_design
      fi
    else
      echo "N/A: the clarified specification has no UI scope."
    fi
    ;;
  harness-planning/slice-planning)
    require_file "feature_list.json" "feature list"
    require_file "sprint-contract.md" "sprint contract"
    require_file "progress.md" "progress tracker"
    if jq -e '.platform_validation.required == true' "$DOCS_DIR/feature_list.json" >/dev/null 2>&1; then
      require_file "platform-capability-matrix.md" "platform capability matrix (platform-bound features only)"
    fi
    if { [ -f "$DOCS_DIR/spec.md" ] && spec_has_ui "$DOCS_DIR/spec.md"; } ||
      jq -e '.features | any(.affects_ui == true)' "$DOCS_DIR/feature_list.json" >/dev/null; then
      require_harness_ux_design
    fi
    if ! grep -q "Acceptance Test Cases" "$DOCS_DIR/sprint-contract.md"; then
      echo "FAIL: sprint contract has no 'Acceptance Test Cases' matrix." >&2
      exit 1
    fi
    if ! grep -q "| Test ID | Covers AC | Test layer |" "$DOCS_DIR/sprint-contract.md"; then
      echo "FAIL: sprint contract acceptance tests must use the required traceability table." >&2
      exit 1
    fi
    bash "$SCRIPT_DIR/check-acceptance-test-traceability.sh" "$DOCS_DIR" --planning
    bash "$SCRIPT_DIR/check-journey-planning-contract.sh" "$DOCS_DIR"
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
  create-ui-and-verify/ui-contract)
    require_ui_contract "" --inventory
    ;;
  create-ui-and-verify/reference-design)
    require_file "UI_contract.md" "per-state UI design contract"
    python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md"
    ;;
  create-ui-and-verify/implementation-plan)
    require_file "UI_contract.md" "per-state UI design contract"
    require_file "implementation_plan_v*.md" "approved UI implementation plan"
    test_plan_artifact=$(latest_versioned_file "test_plan_v*.md")
    python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --plan "$(latest_versioned_file "implementation_plan_v*.md")" \
      --test-plan "${test_plan_artifact:-$DOCS_DIR/test_plan_v1.md}"
    ;;
  create-ui-and-verify/ui-verification)
    require_file "UI_contract.md" "per-state UI design contract"
    require_file "implementation_plan_v*.md" "approved UI implementation plan"
    require_file "ui_verification.json" "UI verification report"
    bash "$SCRIPT_DIR/check-ui-verification-artifact.sh" "$DOCS_DIR"
    test_plan_artifact=$(latest_versioned_file "test_plan_v*.md")
    python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --plan "$(latest_versioned_file "implementation_plan_v*.md")" --report "$DOCS_DIR/ui_verification.json" \
      --test-plan "${test_plan_artifact:-$DOCS_DIR/test_plan_v1.md}" --runtime --project-root "$PROJECT_ROOT"
    ;;
  *)
    echo "FAIL: unknown workflow/stage '$WORKFLOW/$STAGE'." >&2
    echo "Known workflow/stage pairs:" >&2
    echo "  harness-generator/orient <artifact-directory> <feature-id>" >&2
    echo "  feature-delivery/requirement-analysis" >&2
    echo "  feature-delivery/ui-contract" >&2
    echo "  feature-delivery/ux-design" >&2
    echo "  feature-delivery/implementation-plan" >&2
    echo "  feature-delivery/testing" >&2
    echo "  bug-fixing/requirement-analysis" >&2
    echo "  bug-fixing/bug-reproduction" >&2
    echo "  bug-fixing/implementation-plan" >&2
    echo "  bug-fixing/testing" >&2
    echo "  api-contract-update/requirement-analysis" >&2
    echo "  api-contract-update/implementation-plan" >&2
    echo "  harness-planning/feature-specification" >&2
    echo "  harness-planning/ui-contract" >&2
    echo "  harness-planning/ux-design" >&2
    echo "  harness-planning/slice-planning" >&2
    echo "  create-ui-and-verify/ui-verification" >&2
    echo "  create-ui-and-verify/reference-design" >&2
    echo "  create-ui-and-verify/ui-contract" >&2
    echo "  create-ui-and-verify/implementation-plan" >&2
    exit 2
    ;;
esac

echo "Stage '$WORKFLOW/$STAGE' artifacts present."
