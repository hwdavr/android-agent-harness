#!/usr/bin/env bash
# Verifies required stage artifacts exist in a dated feature workspace before a workflow stage advances.
#
# Usage: bash harness/scripts/check-stage-artifacts.sh <workflow> <stage> <workspace> [feature-id]
#   workspace: .scratch/<YYYY-MM-DD>-<feature-id>/ (every lane; docs/current/ is retired)
#   feature-delivery:  specify | ui-contract | ux-design | analyze | implementation-plan | ui-verification | testing
#   bug-fixing:        bug-context | bug-reproduction | analyze | implementation-plan | ui-verification | testing
#
# analyze             = every planning check before the package is presented for approval
#                       (block Status and recorded SHA-256 not yet required)
# implementation-plan = the same checks after approval, including the approval fields
#
# implementation-plan.md owns how the code changes and the Rule Applicability matrix; test-plan.md
# owns all test material (bug Reproduction Test and QA handoff, Spec Coverage Matrix, acceptance
# test cases, Production Journey contracts, UI state verification).
#   harness-generator: orient (requires the slice feature-id)
#   api-contract-update is an alias of feature-delivery.
#
# The specification is the approved feature block(s) in docs/product/requirements/*.md plus the
# implementation plan's Rule Applicability; compose-feature-spec.py assembles that view.
# Exits 0 when the stage's artifacts are present and valid, 1 otherwise, 2 on usage errors.
# Designed to run on macOS /bin/bash (Bash 3.2) — no mapfile, no arrays with set -u.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(pwd)}"

WORKFLOW="${1:-}"
STAGE="${2:-}"
DOCS_DIR="${3:-}"
FEATURE_ID="${4:-}"

usage() {
  echo "Usage: $0 <workflow> <stage> <workspace> [feature-id]" >&2
  echo "  feature-delivery:  specify | ui-contract | ux-design | analyze | implementation-plan | ui-verification | testing" >&2
  echo "  bug-fixing:        bug-context | bug-reproduction | analyze | implementation-plan | ui-verification | testing" >&2
  echo "  harness-generator: orient <workspace> <feature-id>" >&2
}

if [ -z "$WORKFLOW" ] || [ -z "$STAGE" ] || [ -z "$DOCS_DIR" ]; then
  usage
  exit 2
fi
[ "$WORKFLOW" = "api-contract-update" ] && WORKFLOW="feature-delivery"

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
for nested in "$PROJECT_ROOT/android-agent-harness" "$PROJECT_ROOT/.harness"; do
  if [ -d "$nested" ]; then
    nested="$(cd "$nested" && pwd -P)"
    case "$DOCS_DIR" in
      "$nested"|"$nested"/*)
        echo "FAIL: stage artifacts must be under the consuming project's .scratch/; $DOCS_DIR is owned by the shared harness submodule." >&2
        exit 1
        ;;
    esac
  fi
done

WORKSPACE_NAME="$(basename "$DOCS_DIR")"
case "$(basename "$(dirname "$DOCS_DIR")")" in
  .scratch) ;;
  *)
    echo "FAIL: $DOCS_DIR is not a dated feature workspace under .scratch/ (docs/current/ is retired)." >&2
    exit 1
    ;;
esac
if ! printf '%s\n' "$WORKSPACE_NAME" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]*$'; then
  echo "FAIL: workspace '$WORKSPACE_NAME' must be named <YYYY-MM-DD>-<feature-id> in lowercase kebab case." >&2
  exit 1
fi

PLAN="$DOCS_DIR/implementation-plan.md"
TEST_PLAN="$DOCS_DIR/test-plan.md"
SUMMARY="$DOCS_DIR/summary.md"
COMPOSED_SPEC="$(mktemp "${TMPDIR:-/tmp}/composed-spec.XXXXXX")"
trap 'rm -f "$COMPOSED_SPEC"' EXIT

require_file() {
  local name="$1"
  local label="$2"
  if [ ! -f "$DOCS_DIR/$name" ]; then
    echo "FAIL: no '$name' in $DOCS_DIR ($label)." >&2
    exit 1
  fi
  echo "OK: $DOCS_DIR/$name"
}

warn_if_missing() {
  if [ ! -f "$DOCS_DIR/$1" ]; then
    echo "WARN: no '$1' in $DOCS_DIR ($2) — recommended but not required here." >&2
  fi
}

require_tracker_row() {
  (cd "$PROJECT_ROOT" && bash "$SCRIPT_DIR/check-feature-lifecycle.sh")
  if ! grep -Fq ".scratch/$WORKSPACE_NAME" "$PROJECT_ROOT/docs/product/product.md" 2>/dev/null; then
    echo "FAIL: docs/product/product.md Harness Feature Tracker has no row linking .scratch/$WORKSPACE_NAME." >&2
    exit 1
  fi
  echo "OK: tracker row links .scratch/$WORKSPACE_NAME"
}

compose_spec() {
  if ! python3 "$SCRIPT_DIR/compose-feature-spec.py" "$DOCS_DIR" --project-root "$PROJECT_ROOT" --out "$COMPOSED_SPEC"; then
    exit 1
  fi
}

require_specified_blocks() {
  local blocks
  blocks="$(python3 "$SCRIPT_DIR/compose-feature-spec.py" "$DOCS_DIR" --project-root "$PROJECT_ROOT" --list-blocks)"
  if [ -z "$blocks" ]; then
    echo "FAIL: no feature block for $WORKSPACE_NAME under '## Planned changes' in docs/product/requirements/." >&2
    exit 1
  fi
  if grep -Fq "[NEEDS CLARIFICATION" "$COMPOSED_SPEC"; then
    echo "FAIL: the feature block still contains [NEEDS CLARIFICATION] markers; resolve them in the Clarifications log." >&2
    exit 1
  fi
  if ! grep -Eq '^#{2,4}[[:space:]]+FR-[0-9]{3}' "$COMPOSED_SPEC"; then
    echo "FAIL: the feature block defines no FR-### requirement." >&2
    exit 1
  fi
  echo "OK: feature block(s) specified in: $(printf '%s' "$blocks" | tr '\n' ' ')"
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
  python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --spec "$specification" \
    --design-system "$PROJECT_ROOT/docs/product/design_system.md" "$@"
}

require_plan_rules() {
  require_file "implementation-plan.md" "implementation plan with the canonical Rule Applicability matrix"
  require_rule_applicability "$PLAN" "$1"
}

require_test_plan_mapping() {
  require_canonical_rule_reference "$TEST_PLAN" "$PLAN" "$1"
  require_required_rule_mappings "$TEST_PLAN" "$PLAN" "$1"
}

plan_lane() {
  sed -n -E 's/^\*\*Lane\*\*:[[:space:]]*`?(single|sliced)`?.*/\1/p' "$PLAN" | head -n 1
}

require_planning_contracts() {
  if [ "$STAGE" = "analyze" ]; then
    bash "$SCRIPT_DIR/check-spec-plan-consistency.sh" "$DOCS_DIR" --project-root "$PROJECT_ROOT" --pre-approval
  else
    bash "$SCRIPT_DIR/check-spec-plan-consistency.sh" "$DOCS_DIR" --project-root "$PROJECT_ROOT"
  fi
  if [ "$(plan_lane)" = "sliced" ]; then
    # Slice contracts exist only in the sliced lane (feature_list.json, tasks.md, per-story tests).
    bash "$SCRIPT_DIR/check-platform-evidence.sh" "$DOCS_DIR" --planning
    bash "$SCRIPT_DIR/check-journey-planning-contract.sh" "$DOCS_DIR"
    bash "$SCRIPT_DIR/check-acceptance-test-traceability.sh" "$DOCS_DIR" --planning
  fi
  if spec_has_ui "$COMPOSED_SPEC"; then
    require_ui_contract "$COMPOSED_SPEC" --plan "$PLAN" --test-plan "$TEST_PLAN"
    bash "$SCRIPT_DIR/check-visual-evidence-contract.sh" "$DOCS_DIR" --planning
  fi
}

require_testing_evidence() {
  require_file "summary.md" "stage evidence record"
  require_file "test-plan.md" "test plan"
  require_test_plan_mapping "$1"
  if sui_is_active "$COMPOSED_SPEC" || ime_is_active "$COMPOSED_SPEC"; then
    require_file "UI_contract.md" "per-state UI and IME design contract"
    python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --spec "$COMPOSED_SPEC" \
      --test-plan "$TEST_PLAN" --runtime --project-root "$PROJECT_ROOT"
  fi
  nav_row="$(grep -E "^[[:space:]]*\|[[:space:]]*NAV[[:space:]]*\|" "$PLAN" | head -n 1 || true)"
  case "$nav_row" in
    *"| Required |"*) require_production_journey "$TEST_PLAN" ;;
  esac
}

require_ui_verification() {
  require_file "UI_contract.md" "per-state UI design contract"
  require_file "ui_verification.json" "UI conformance review report"
  bash "$SCRIPT_DIR/check-ui-verification-artifact.sh" "$DOCS_DIR"
  python3 "$SCRIPT_DIR/check-ui-contract.py" "$DOCS_DIR/UI_contract.md" --spec "$COMPOSED_SPEC" \
    --design-system "$PROJECT_ROOT/docs/product/design_system.md" \
    --plan "$PLAN" --report "$DOCS_DIR/ui_verification.json" --test-plan "$TEST_PLAN" \
    --runtime --project-root "$PROJECT_ROOT"
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

sui_is_active() {
  local specification="$1"
  grep -E '^[[:space:]]*\|[[:space:]]*SUI[[:space:]]*\|' "$specification" |
    grep -Eq '\|[[:space:]]*(Required|Exception — approved by)[^|]*\|'
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

case "$WORKFLOW/$STAGE" in
  harness-generator/orient)
    if [ -z "$FEATURE_ID" ]; then
      echo "FAIL: harness-generator/orient requires the selected slice id to validate its summary." >&2
      exit 2
    fi
    require_file "summary_${FEATURE_ID}.md" "slice evidence record"
    ;;
  feature-delivery/specify)
    require_tracker_row
    require_file "summary.md" "stage evidence record"
    compose_spec
    require_specified_blocks
    ;;
  feature-delivery/ui-contract|feature-delivery/ux-design)
    compose_spec
    require_specified_blocks
    if spec_has_ui "$COMPOSED_SPEC"; then
      if [ "$STAGE" = "ui-contract" ]; then
        require_ui_contract "$COMPOSED_SPEC" --inventory
      else
        require_ui_contract "$COMPOSED_SPEC"
      fi
    else
      echo "N/A: the feature block has no Screen States (no UI scope)."
    fi
    ;;
  feature-delivery/analyze|bug-fixing/analyze|feature-delivery/implementation-plan|bug-fixing/implementation-plan)
    require_tracker_row
    require_plan_rules "$WORKFLOW implementation plan"
    compose_spec
    if [ "$WORKFLOW" = "feature-delivery" ]; then
      require_specified_blocks
    fi
    require_file "test-plan.md" "test plan"
    require_test_plan_mapping "$WORKFLOW test plan"
    require_planning_contracts
    ;;
  feature-delivery/ui-verification|bug-fixing/ui-verification)
    require_file "implementation-plan.md" "implementation plan (Rule Applicability validated at the implementation-plan stage)"
    compose_spec
    if spec_has_ui "$COMPOSED_SPEC"; then
      require_ui_verification
    else
      echo "N/A: no UI scope; UI verification does not apply."
    fi
    ;;
  feature-delivery/testing|bug-fixing/testing)
    require_file "implementation-plan.md" "implementation plan (Rule Applicability validated at the implementation-plan stage)"
    compose_spec
    require_testing_evidence "$WORKFLOW testing"
    ;;
  bug-fixing/bug-context)
    require_tracker_row
    require_file "summary.md" "stage evidence record"
    require_plan_rules "bug-fixing bug context"
    if ! grep -Eq '^## Root Cause & Reproduction' "$PLAN"; then
      echo "FAIL: $PLAN is missing '## Root Cause & Reproduction' (bug context)." >&2
      exit 1
    fi
    compose_spec
    if [ -f "$TEST_PLAN" ]; then
      python3 "$SCRIPT_DIR/read-qa-bug-context.py" --project-root "$PROJECT_ROOT" --spec "$TEST_PLAN" --check
    fi
    ;;
  bug-fixing/bug-reproduction)
    require_file "summary.md" "stage evidence record"
    require_file "implementation-plan.md" "bug context (Root Cause & Reproduction)"
    require_file "test-plan.md" "test plan with the Reproduction Test"
    require_bug_reproduction_evidence "$TEST_PLAN" "$SUMMARY"
    ;;
  *)
    echo "FAIL: unknown workflow/stage '$WORKFLOW/$STAGE'." >&2
    usage
    exit 2
    ;;
esac

echo "Stage '$WORKFLOW/$STAGE' artifacts present."
