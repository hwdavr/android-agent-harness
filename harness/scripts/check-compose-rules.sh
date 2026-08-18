#!/usr/bin/env bash
# =============================================================================
# check-compose-rules.sh
#
# Checks Jetpack Compose source files for violations of the project's
# compose-rules.md constraints. Uses ripgrep (rg) when available, falls back
# to grep -P otherwise.
#
# NOTE: Hardcoded-string checks (stringResource violations) have been moved
# to check-localization-rules.sh which owns all localization-rules.md checks.
#
# Usage:
#   ./harness/scripts/check-compose-rules.sh [--all] [<source-root>]
#
# <source-root> defaults to app/src/main/java
#
# Exit codes:
#   0 — no violations found
#   1 — one or more violations found
# =============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
SCAN_ALL=false
if [[ "${1:-}" == "--all" ]]; then
    SCAN_ALL=true
    shift
fi

SOURCE_ROOT="${1:-$PROJECT_ROOT/app/src/main/java}"

# Determine which files to scan
kt_files=()
collect_kt_files() {
    while IFS= read -r file; do
        kt_files+=("$file")
    done
}
if [[ "$SCAN_ALL" == "true" ]]; then
    collect_kt_files < <(find "$SOURCE_ROOT" -name "*.kt" -type f)
else
    # Find all Kotlin files that are modified, staged, or untracked in Git
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        collect_kt_files < <(
            {
                git diff --name-only --diff-filter=d HEAD 2>/dev/null
                git diff --name-only --cached --diff-filter=d 2>/dev/null
                git ls-files --others --exclude-standard 2>/dev/null
            } | grep '\.kt$' | sort -u | sed "s|^|$PROJECT_ROOT/|" | grep "^$SOURCE_ROOT/"
        )
    fi
    # If no changed files or not in git, fallback to all files
    if [[ ${#kt_files[@]} -eq 0 ]]; then
        collect_kt_files < <(find "$SOURCE_ROOT" -name "*.kt" -type f)
    fi
fi

# ---------- colour helpers ---------------------------------------------------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- search back-end --------------------------------------------------
# _search PATTERN [FLAGS...] PATH
#   FLAGS understood by both back-ends:
#     --type kotlin   → restrict to *.kt files
#     --multiline     → rg: --multiline  /  grep: implicit with -P
#     --pcre2         → rg: --pcre2      /  grep: implicit with -P
#     --exclude FILE  → rg: --glob '!FILE'  /  grep: --exclude=FILE
# All other flags are passed through as-is.

if command -v rg &>/dev/null; then
    _search() {
        local pattern="$1"; shift
        local rg_args=()
        local files=()
        local excludes=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --type)    rg_args+=(--type "$2"); shift 2 ;;
                --type=*)  rg_args+=("$1");         shift   ;;
                --exclude) excludes+=("$2"); rg_args+=(--glob "!$2" --glob "!**/$2"); shift 2 ;;
                --)        shift; files+=("$@");    break   ;;
                *)         rg_args+=("$1");          shift   ;;
            esac
        done
        if [[ ${#excludes[@]} -gt 0 && ${#files[@]} -gt 0 ]]; then
            local filtered_files=()
            local file exclude skip
            for file in "${files[@]}"; do
                skip=false
                for exclude in "${excludes[@]}"; do
                    if [[ "$(basename "$file")" == "$exclude" ]]; then
                        skip=true
                        break
                    fi
                done
                if [[ "$skip" == "false" ]]; then
                    filtered_files+=("$file")
                fi
            done
            files=("${filtered_files[@]}")
        fi
        if [[ ${#files[@]} -eq 0 ]]; then
            return 0
        fi
        rg --color never -n "${rg_args[@]}" "$pattern" "${files[@]}" || true
    }
else
    _search() {
        local pattern="$1"; shift
        local grep_args=()
        local include="--include=*.kt"
        local files=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --type) shift 2 ;;                          # default is *.kt already
                --type=kotlin) shift ;;
                --multiline|--pcre2) shift ;;               # grep -P handles these
                --exclude) grep_args+=("--exclude=$2"); shift 2 ;;
                --) shift; files+=("$@"); break ;;
                *) grep_args+=("$1"); shift ;;
            esac
        done
        grep -rn -P "$include" "${grep_args[@]}" "$pattern" "${files[@]}" 2>/dev/null || true
    }
fi

# ---------- state ------------------------------------------------------------
TOTAL_VIOLATIONS=0

# ---------- helpers ----------------------------------------------------------
_header() {
    echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"
}

_rule_header() {
    echo -e "  ${YELLOW}Rule: $1${RESET}"
}

_print_match() {
    echo -e "    ${RED}$1${RESET}"
}

# _run_check RULE_NAME PATTERN [FLAGS...]
# Always appends $SOURCE_ROOT as the search path.
_run_check() {
    local rule_name="$1"
    local pattern="$2"
    shift 2

    _rule_header "$rule_name"

    local results=""
    if [[ ${#kt_files[@]} -gt 0 ]]; then
        results=$(_search "$pattern" "$@" -- "${kt_files[@]}" 2>/dev/null || true)
    fi

    if [[ -z "$results" ]]; then
        echo -e "    ${GREEN}✓ No violations${RESET}"
    else
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                _print_match "$line"
                (( TOTAL_VIOLATIONS++ ))
            fi
        done <<< "$results"
    fi
}

# =============================================================================
# CHECKS
# =============================================================================

echo -e "\n${BOLD}======================================================${RESET}"
echo -e "${BOLD}  Compose Rules Checker — $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo -e "${BOLD}======================================================${RESET}"
echo -e "  Source root: ${SOURCE_ROOT}\n"

# ── 1. Hardcoded Colors ───────────────────────────────────────────────────────
_header "1 · Hardcoded Colors"
echo -e "  ${YELLOW}Use LocalAppColors.current.<token> — never Color(0x...) or Color.Red etc.${RESET}"
echo -e "  ${YELLOW}AppColors.kt is excluded (it is the canonical definition file).${RESET}"

_run_check \
    'Color(0x...) literal outside AppColors.kt' \
    'Color\s*\(\s*0x[0-9A-Fa-f]+' \
    --type kotlin \
    --exclude 'AppColors.kt'

_run_check \
    'Named Color constant (Color.Red, Color.Black, Color.White, etc.)' \
    '\bColor\.(Red|Green|Blue|Black|White|Gray|Grey|Yellow|Cyan|Magenta|Transparent|DarkGray|LightGray|Unspecified)\b' \
    --type kotlin \
    --exclude 'AppColors.kt'

# ── 2. Missing testTag on Interactive Elements ────────────────────────────────
_header "2 · Missing testTag — Interactive Elements"
echo -e "  ${YELLOW}Button, IconButton, FloatingActionButton, etc. should have Modifier.testTag(...).${RESET}"
echo -e "  ${YELLOW}Heuristic: flags files with interactive elements but zero testTag references.${RESET}"

_rule_header 'Files containing interactive Composables but no testTag'
no_tag_files=()
for f in "${kt_files[@]}"; do
    if grep -qP '\b(Button|FloatingActionButton|IconButton|Chip|Switch|Checkbox|RadioButton|Slider|DropdownMenu|ExposedDropdownMenuBox)\s*\(' "$f" 2>/dev/null; then
        if ! grep -qP 'testTag' "$f" 2>/dev/null; then
            no_tag_files+=("$f")
        fi
    fi
done
if [[ ${#no_tag_files[@]} -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
else
    for f in "${no_tag_files[@]}"; do
        _print_match "${f#$PROJECT_ROOT/}"
        (( TOTAL_VIOLATIONS++ ))
    done
fi

# ── 3. ViewModel Inside Content Composables ───────────────────────────────────
_header "3 · ViewModel Imported Inside Content Composables"
echo -e "  ${YELLOW}hiltViewModel() / viewModel() must only appear in the stateful wrapper, not in *Content composables.${RESET}"

_run_check \
    'hiltViewModel() called inside a *Content composable' \
    '(?s)fun\s+\w+Content\b[^{]*\{[^}]*hiltViewModel\s*\(' \
    --type kotlin --multiline --pcre2

_run_check \
    'viewModel() called inside a *Content composable' \
    '(?s)fun\s+\w+Content\b[^{]*\{[^}]*\bviewModel\s*\(' \
    --type kotlin --multiline --pcre2

# ── 4. Business Logic in Composables ─────────────────────────────────────────
_header "4 · Business Logic Inside Composables"
echo -e "  ${YELLOW}Composables must not call repositories or use cases directly.${RESET}"

_run_check \
    'Repository / UseCase call inside a @Composable function' \
    '(?s)@Composable\b[^{]*fun\s+\w+[^{]*\{[^}]*(Repository|UseCase|DataSource)\s*\.' \
    --type kotlin --multiline --pcre2

# ── 5. Unstable testTag Values ────────────────────────────────────────────────
_header "5 · Unstable testTag Values"
echo -e "  ${YELLOW}testTag values must be descriptive; dynamic values require immutable, documented IDs.${RESET}"

# Key content containers use item-specific tags keyed by stable model IDs.
# Exclude dynamic list item tags (e.g. note_item_*, folder_item_*) if required.
# The emoji picker also uses immutable IDs from the bundled catalog. These
# prefixes are intentionally explicit so transient indexes/random values do
# not become an accidental test-tag convention.

_run_check \
    'testTag with unapproved string interpolation (unstable, ID-dependent)' \
    'testTag\s*\(\s*"(?!note_item_|folder_item_|collection_item_|emoji_category_|emoji_picker_item_|emoji_skin_tone_selector_|emoji_skin_tone_variant_)[^"]*\$\{?' \
    --type kotlin --pcre2 --exclude LayerManagerControl.kt

_run_check \
    'testTag with unapproved string concatenation or derived value (unstable, ID-dependent)' \
    'testTag\s*\(\s*("[^"]*"\s*\+|[A-Za-z_][A-Za-z0-9_]*\s*\+|[^)]*(lowercase|replace)\s*\()' \
    --type kotlin --pcre2

# ── 6. Performance — Column + forEach Instead of LazyColumn ──────────────────
_header "6 · Performance — Column + forEach Instead of LazyColumn"
echo -e "  ${YELLOW}Prefer LazyColumn for lists to avoid rendering all items eagerly.${RESET}"

_run_check \
    'Column { ... .forEach { (use LazyColumn instead)' \
    'Column\s*\{[^}]*\.forEach\s*\{' \
    --type kotlin --multiline --pcre2

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BOLD}======================================================${RESET}"
if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ All Compose rules passed — 0 violations${RESET}"
    echo -e "${BOLD}======================================================${RESET}"
    exit 0
else
    echo -e "${RED}${BOLD}  ✗ $TOTAL_VIOLATIONS violation(s) found — see above${RESET}"
    echo -e "${BOLD}  Hint: run check-localization-rules.sh for string resource violations${RESET}"
    echo -e "${BOLD}======================================================${RESET}"
    exit 1
fi
