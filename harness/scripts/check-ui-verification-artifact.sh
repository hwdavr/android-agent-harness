#!/usr/bin/env bash
# Validates the ad-hoc UI verification JSON artifact. Checks that required JSON
# keys are present and that referenced design and evidence assets exist on disk.

set -e

DOCS_DIR="${1:-}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [ -z "$DOCS_DIR" ]; then
  echo "Usage: bash harness/scripts/check-ui-verification-artifact.sh <docs-directory>" >&2
  exit 2
fi

[ -d "$DOCS_DIR" ] || fail "missing artifact directory $DOCS_DIR"

REPORT="$DOCS_DIR/ui_verification.json"
[ -f "$REPORT" ] || fail "missing $REPORT"

# Validate it is parseable JSON
jq empty "$REPORT" 2>/dev/null \
  || fail "$REPORT is not valid JSON"

# Required top-level keys
for key in version reference_design build_and_static_checks normalization scope \
           structural_verification defect_classification ai_visual_evaluation verdict; do
  jq -e ".$key" "$REPORT" >/dev/null 2>&1 \
    || fail "$REPORT is missing required key '$key'"
done

# Verdict must have a result
VERDICT_RESULT=$(jq -r '.verdict.result' "$REPORT" 2>/dev/null)
[ -n "$VERDICT_RESULT" ] && [ "$VERDICT_RESULT" != "null" ] \
  || fail "$REPORT verdict must declare a result"

# Reference design asset must exist on disk
REFERENCE_ASSET=$(jq -r '.reference_design' "$REPORT" 2>/dev/null)
[ -n "$REFERENCE_ASSET" ] && [ "$REFERENCE_ASSET" != "null" ] \
  || fail "$REPORT must declare a reference_design asset"
case "$REFERENCE_ASSET" in
  *..*) fail "$REPORT reference asset must stay under design/" ;;
esac
[ -s "$DOCS_DIR/$REFERENCE_ASSET" ] \
  || fail "$REPORT references missing or empty design asset $REFERENCE_ASSET"

# Structural verification must have at least one check
CHECKS_COUNT=$(jq '.structural_verification.checks | length' "$REPORT" 2>/dev/null)
[ "$CHECKS_COUNT" -gt 0 ] 2>/dev/null \
  || fail "$REPORT needs at least one structural_verification check"

# AI visual evaluation must have a status
AI_STATUS=$(jq -r '.ai_visual_evaluation.status' "$REPORT" 2>/dev/null)
[ -n "$AI_STATUS" ] && [ "$AI_STATUS" != "null" ] \
  || fail "$REPORT ai_visual_evaluation must declare a status"

echo "PASS: UI verification JSON artifact is valid with reference design, structural checks, and AI evaluation."
