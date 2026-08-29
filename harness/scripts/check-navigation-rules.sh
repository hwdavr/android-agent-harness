#!/usr/bin/env bash
# Validates the project's Navigation Compose conventions.
#
# Usage: bash harness/scripts/check-navigation-rules.sh [project-root]
#
# The optional project root makes the checker testable against temporary
# fixtures. The default is the repository containing this script.

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_ROOT="${1:-$SCRIPT_ROOT}"
NAVIGATION_RULES="$PROJECT_ROOT/.agents/rules/navigation-rules.md"
NAVIGATION_SOURCE="$PROJECT_ROOT/app/src/main/java/com/example/notesapp/navigation"
DESTINATIONS_FILE="$NAVIGATION_SOURCE/Destinations.kt"
NAV_GRAPH_FILE="$NAVIGATION_SOURCE/AppNavGraph.kt"
NAV_HOST_FILE="$NAVIGATION_SOURCE/AppNavigationHost.kt"
NAV_TEST_DIR="$PROJECT_ROOT/app/src/androidTest/java/com/example/notesapp/navigation"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

[ -d "$PROJECT_ROOT" ] || fail "project root does not exist: $PROJECT_ROOT"
[ -f "$NAVIGATION_RULES" ] || fail "navigation rules file is missing: $NAVIGATION_RULES"
[ -d "$NAVIGATION_SOURCE" ] || fail "navigation source directory is missing: $NAVIGATION_SOURCE"
[ -f "$DESTINATIONS_FILE" ] || fail "route definition file is missing: $DESTINATIONS_FILE"
[ -f "$NAV_GRAPH_FILE" ] || fail "navigation graph file is missing: $NAV_GRAPH_FILE"
[ -f "$NAV_HOST_FILE" ] || fail "navigation host file is missing: $NAV_HOST_FILE"

VIOLATIONS_FILE="$(mktemp "${TMPDIR:-/tmp}/navigation-rules-violations.XXXXXX")"
trap 'rm -f "$VIOLATIONS_FILE"' EXIT

record_violation() {
    printf '%s\n' "$1" >> "$VIOLATIONS_FILE"
}

route_names='onboarding|notes|folders|settings|collectionNotes|moveTo|folderDescription|editor|voiceRecorder|exportNote|sharedUsers|shareInvite|manageAccess'

if ! rg -q 'sealed class Destinations' "$DESTINATIONS_FILE"; then
    record_violation "$DESTINATIONS_FILE: route definitions must use the Destinations sealed class"
fi

# Navigation calls and start destinations must reference Destinations rather
# than embedding a route name directly in a Kotlin string literal.
while IFS=: read -r file line details; do
    [ -n "${file:-}" ] || continue
    record_violation "$file:$line: raw route literal; use Destinations constants or createRoute()"
done < <(
    rg -n -P --glob '*.kt' --glob '!**/Destinations.kt' \
        "(?:composable|navigate|popUpTo)\\s*\\(\\s*\"(?:$route_names)(?:[?/{][^\"]*)?\"|startDestination\\s*=\\s*\"(?:$route_names)(?:[?/{][^\"]*)?\"" \
        "$PROJECT_ROOT/app/src" || true
)

# Route classification must not depend on raw prefixes that can collide with
# future route names.
while IFS=: read -r file line details; do
    [ -n "${file:-}" ] || continue
    record_violation "$file:$line: raw route prefix; compare against Destinations route metadata"
done < <(
    rg -n -P --glob '*.kt' \
        "startsWith\\s*\\(\\s*\"(?:$route_names)\"" \
        "$PROJECT_ROOT/app/src" || true
)

# Dynamic route values must be URI encoded before interpolation. These checks
# intentionally focus on values known to be route arguments, not UI strings.
while IFS=: read -r file line details; do
    [ -n "${file:-}" ] || continue
    record_violation "$file:$line: dynamic route argument is interpolated without Uri.encode()"
done < <(
    rg -n -H -P \
        '\$(noteId|folderId|type)\b|\$\{(noteId|folderId|type)([^}]*)\}' \
        "$DESTINATIONS_FILE" || true
)

route_start() {
    local destination="$1"
    rg -n -m1 "route = Destinations\\.${destination}\\.route" "$NAV_HOST_FILE" \
        | cut -d: -f1 || true
}

route_end() {
    local start="$1"
    local next
    next="$(awk -v start="$start" 'NR > start && /route = Destinations\.[A-Za-z]+\.route/ { print NR; exit }' "$NAV_HOST_FILE")"
    if [ -n "$next" ]; then
        printf '%s\n' "$next"
    else
        printf '%s\n' "$(( $(wc -l < "$NAV_HOST_FILE") + 1 ))"
    fi
}

argument_lines() {
    local start="$1"
    local end="$2"
    local argument="$3"
    awk -v start="$start" -v end="$end" -v argument="$argument" '
        NR < start || NR >= end { next }
        index($0, "navArgument(\"" argument "\")") > 0 { in_argument = 1 }
        in_argument && $0 ~ /defaultValue[[:space:]]*=/ { print NR }
        in_argument && $0 ~ /^[[:space:]]*}/ { in_argument = 0 }
    ' "$NAV_HOST_FILE"
}

check_required_argument() {
    local destination="$1"
    local argument="$2"
    local start
    start="$(route_start "$destination")"
    if [ -z "$start" ]; then
        record_violation "$NAV_HOST_FILE: missing route block for Destinations.$destination"
        return
    fi
    local end
    end="$(route_end "$start")"
    local default_line
    default_line="$(argument_lines "$start" "$end" "$argument")"
    if [ -n "$default_line" ]; then
        record_violation "$NAV_HOST_FILE:$default_line: required $destination.$argument must not define defaultValue"
    fi
}

check_optional_argument() {
    local destination="$1"
    local argument="$2"
    local start
    start="$(route_start "$destination")"
    if [ -z "$start" ]; then
        record_violation "$NAV_HOST_FILE: missing route block for Destinations.$destination"
        return
    fi
    local end
    end="$(route_end "$start")"
    local default_line
    default_line="$(argument_lines "$start" "$end" "$argument")"
    if [ -z "$default_line" ]; then
        record_violation "$NAV_HOST_FILE:$start: optional $destination.$argument must define defaultValue"
    fi
}

check_required_argument MoveTo itemType
check_required_argument MoveTo itemId
check_required_argument ExportNote noteId
check_required_argument SharedUsers noteId
check_required_argument ManageAccess noteId
check_required_argument ShareInvite noteId

check_optional_argument CollectionNotes type
check_optional_argument CollectionNotes folderId
check_optional_argument CollectionNotes label
check_optional_argument Editor noteId
check_optional_argument Editor folderId
check_optional_argument VoiceRecorder noteId
check_optional_argument VoiceRecorder source
check_optional_argument VoiceRecorder focusedBlockId

# The navigation tests must mount the production graph. This prevents a
# separate fake graph from masking route drift.
NAVIGATION_TEST_FILE="$NAV_TEST_DIR/NavigationTest.kt"
CONTRACT_TEST_FILE="$NAV_TEST_DIR/NavigationContractTest.kt"
[ -f "$NAVIGATION_TEST_FILE" ] || record_violation "$NAVIGATION_TEST_FILE: production navigation test is missing"
[ -f "$CONTRACT_TEST_FILE" ] || record_violation "$CONTRACT_TEST_FILE: navigation contract test is missing"
if [ -f "$NAVIGATION_TEST_FILE" ] && ! rg -q 'AppNavigationHost' "$NAVIGATION_TEST_FILE"; then
    record_violation "$NAVIGATION_TEST_FILE: test must mount AppNavigationHost"
fi
if [ -f "$CONTRACT_TEST_FILE" ] && ! rg -q 'AppNavigationHost' "$CONTRACT_TEST_FILE"; then
    record_violation "$CONTRACT_TEST_FILE: contract test must inspect AppNavigationHost"
fi

if [ -s "$VIOLATIONS_FILE" ]; then
    echo "Navigation rule violations:" >&2
    sed 's/^/  - /' "$VIOLATIONS_FILE" >&2
    violation_count="$(wc -l < "$VIOLATIONS_FILE" | tr -d ' ')"
    fail "$violation_count navigation rule violation(s) found"
fi

echo "PASS: navigation rules satisfied."
