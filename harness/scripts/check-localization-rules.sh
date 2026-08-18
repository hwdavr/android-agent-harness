#!/usr/bin/env bash
# =============================================================================
# check-localization-rules.sh
#
# Checks Kotlin source files for violations of the project's
# localization-rules.md constraints. Uses ripgrep (rg) when available,
# falls back to grep -P otherwise.
#
# Usage:
#   ./harness/scripts/check-localization-rules.sh [--all] [<source-root>]
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

# ---------- argument parsing --------------------------------------------------
SCAN_ALL=false
if [[ "${1:-}" == "--all" ]]; then
    SCAN_ALL=true
    shift
fi

SOURCE_ROOT="${1:-$PROJECT_ROOT/app/src/main/java}"

# ---------- file collection ---------------------------------------------------
kt_files=()
collect_kt_files() {
    while IFS= read -r file; do
        kt_files+=("$file")
    done
}
if [[ "$SCAN_ALL" == "true" ]]; then
    collect_kt_files < <(find "$SOURCE_ROOT" -name "*.kt" -type f)
else
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        collect_kt_files < <(
            {
                git diff --name-only --diff-filter=d HEAD 2>/dev/null
                git diff --name-only --cached --diff-filter=d 2>/dev/null
                git ls-files --others --exclude-standard 2>/dev/null
            } | grep '\.kt$' | sort -u | sed "s|^|$PROJECT_ROOT/|" | grep "^$SOURCE_ROOT/"
        )
    fi
    if [[ ${#kt_files[@]} -eq 0 ]]; then
        collect_kt_files < <(find "$SOURCE_ROOT" -name "*.kt" -type f)
    fi
fi

# ---------- colour helpers ----------------------------------------------------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- search back-end ---------------------------------------------------
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
                        skip=true; break
                    fi
                done
                [[ "$skip" == "false" ]] && filtered_files+=("$file")
            done
            files=("${filtered_files[@]}")
        fi
        [[ ${#files[@]} -eq 0 ]] && return 0
        rg --color never --with-filename -n "${rg_args[@]}" "$pattern" "${files[@]}" || true
    }
else
    _search() {
        local pattern="$1"; shift
        local grep_args=()
        local files=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --type|--type=kotlin) shift; [[ "$1" != --* ]] && shift || true ;;
                --multiline|--pcre2) shift ;;
                --exclude) grep_args+=("--exclude=$2"); shift 2 ;;
                --) shift; files+=("$@"); break ;;
                *) grep_args+=("$1"); shift ;;
            esac
        done
        grep -rn -P --include='*.kt' "${grep_args[@]}" "$pattern" "${files[@]}" 2>/dev/null || true
    }
fi

# ---------- state -------------------------------------------------------------
TOTAL_VIOLATIONS=0

# ---------- helpers -----------------------------------------------------------
_header() {
    echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"
}

_rule_header() {
    echo -e "  ${YELLOW}Rule: $1${RESET}"
}

_print_match() {
    echo -e "    ${RED}$1${RESET}"
}

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
echo -e "${BOLD}  Localization Rules Checker — $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo -e "${BOLD}======================================================${RESET}"
echo -e "  Source root: ${SOURCE_ROOT}"
echo -e "  Files scanned: ${#kt_files[@]}\n"

# ── 1. Hardcoded Strings in Text() ───────────────────────────────────────────
_header "1 · Hardcoded Strings in Text()"
echo -e "  ${YELLOW}All user-visible text must use stringResource(), not raw string literals.${RESET}"

_run_check \
    'Text() called with a raw string literal (not stringResource)' \
    '\bText\s*\(\s*"[^"]{1,}' \
    --type kotlin

# ── 2. Hardcoded Strings in Composable Parameters ────────────────────────────
_header "2 · Hardcoded Strings in Composable Parameters"
echo -e "  ${YELLOW}title=, placeholder=, and hint= must not use raw string literals.${RESET}"

_run_check \
    'Button/title/placeholder/hint set as a hardcoded string' \
    '(title|placeholder|hint)\s*=\s*"[^"]' \
    --type kotlin

# ── 3. Hardcoded Local UI String Variables ────────────────────────────────────
_header "3 · Hardcoded Local UI String Variables"
echo -e "  ${YELLOW}Local variables holding UI labels must not be assigned raw string literals.${RESET}"

_run_check \
    'Local UI label variable set as a hardcoded string' \
    'val\s+\w*(Label|Text|Title|Placeholder|Description|Action)\w*\s*=\s*"[^"]' \
    --type kotlin

# ── 4. Null contentDescription on Interactive Icons ───────────────────────────
_header "4 · Null contentDescription on Interactive Icons"
echo -e "  ${YELLOW}Non-text interactive elements must have contentDescription = stringResource(...), not null.${RESET}"

INTERACTIVE_MARKERS='(IconButton\(|EditorBarButton\(|\.clickable\()'
_check_null_content_description() {
    local matches=""
    if [[ ${#kt_files[@]} -gt 0 ]]; then
        matches=$(_search 'contentDescription\s*=\s*null' --type kotlin -- "${kt_files[@]}" 2>/dev/null || true)
    fi
    if [[ -z "$matches" ]]; then
        echo -e "    ${GREEN}✓ No violations${RESET}"
        return
    fi
    local found=false
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local file lineno _match
        IFS=: read -r file lineno _match <<< "$line"
        if [[ -z "$file" || -z "$lineno" ]]; then
            continue
        fi
        local context_start=$((lineno > 10 ? lineno - 10 : 1))
        local context
        context=$(sed -n "${context_start},${lineno}p" "$file" 2>/dev/null || true)
        if echo "$context" | grep -qE "$INTERACTIVE_MARKERS"; then
            _print_match "$line"
            found=true
            (( TOTAL_VIOLATIONS++ ))
        fi
    done <<< "$matches"
    if [[ "$found" == "false" ]]; then
        echo -e "    ${GREEN}✓ No violations${RESET}"
    fi
}
_rule_header 'contentDescription set to null on an interactive icon (should use stringResource for accessibility)'
_check_null_content_description

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BOLD}======================================================${RESET}"
if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ All localization rules passed — 0 violations${RESET}"
    echo -e "${BOLD}======================================================${RESET}"
    exit 0
else
    echo -e "${RED}${BOLD}  ✗ $TOTAL_VIOLATIONS violation(s) found — see above${RESET}"
    echo -e "${BOLD}======================================================${RESET}"
    exit 1
fi
