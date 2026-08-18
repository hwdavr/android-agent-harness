#!/usr/bin/env bash
# =============================================================================
# check-architecture-rules.sh
#
# Checks Kotlin source files for violations of the project's
# android-architecture.md constraints that CANNOT be covered by Detekt's
# ForbiddenImport rule.
#
# Import-based layer boundary checks are now owned by Detekt (detekt.yml
# forbidden-imports section). Do not add import checks here — add them there.
#
# Remaining checks (what this script owns):
#   Section 1  — UI body-level violations (DAO/API/Repo called inside Composable body)
#   Section 2  — ViewModel body-level violations (direct Retrofit call)
#   Section 5  — State management smells (multiple StateFlow<Boolean>, one-off event fields)
#   Section 7  — DI scoping (Context in domain constructor, missing @Singleton on RepositoryImpl)
#   Section 8  — Forbidden patterns (fully-qualified inline names, business logic in Composable,
#                ViewModel missing test file)
#   Section 9  — Package structure (ViewModel / UseCase / RepositoryImpl misplaced, Mapper in domain)
#   Section 10 — New suppression directives in the current diff
#
# Usage:
#   ./harness/scripts/check-architecture-rules.sh [--all] [<source-root>]
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

# Derive base package path from the actual directory structure on disk.
# This avoids hard-coding the package name and breaking when the script is
# used in a new project (dynamic detection of base package).
BASE_PKG=""
if [[ -d "$SOURCE_ROOT/com" ]]; then
    # Walk up to 4 levels deep to find the first directory that has subdirs
    # matching layer names (ui, domain, data) — that is the base package.
    while IFS= read -r candidate; do
        if [[ -d "$candidate/ui" || -d "$candidate/domain" || -d "$candidate/data" ]]; then
            BASE_PKG="$candidate"
            break
        fi
    done < <(find "$SOURCE_ROOT" -mindepth 1 -maxdepth 4 -type d | sort)
fi
if [[ -z "$BASE_PKG" ]]; then
    BASE_PKG="$SOURCE_ROOT"
fi
UI_ROOT="$BASE_PKG/ui"
DOMAIN_ROOT="$BASE_PKG/domain"
DATA_ROOT="$BASE_PKG/data"

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
    if [[ ${#kt_files[*]} -eq 0 ]]; then
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
        if [[ ${#excludes[*]} -gt 0 && ${#files[*]} -gt 0 ]]; then
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
        [[ ${#files[*]} -eq 0 ]] && return 0
        rg --color never -n "${rg_args[@]}" "$pattern" "${files[@]}" || true
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
    local extra_args=()
    local scoped_files=("${kt_files[@]}")

    local new_args=()
    local in_files=false
    for arg in "$@"; do
        if [[ "$arg" == "--" ]]; then
            in_files=true
        elif [[ "$in_files" == "true" ]]; then
            scoped_files=("$@")
            break
        else
            extra_args+=("$arg")
        fi
    done

    _rule_header "$rule_name"

    local results=""
    if [[ ${#scoped_files[*]} -gt 0 ]]; then
        results=$(_search "$pattern" "${extra_args[@]}" -- "${scoped_files[@]}" 2>/dev/null || true)
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

_run_check_files() {
    local rule_name="$1"
    local pattern="$2"
    shift 2
    local grep_flags=()
    local files=()
    local reading_files=false
    for arg in "$@"; do
        if [[ "$arg" == "--files" ]]; then
            reading_files=true
        elif [[ "$reading_files" == "true" ]]; then
            files+=("$arg")
        else
            grep_flags+=("$arg")
        fi
    done

    _rule_header "$rule_name"

    local results=""
    if [[ ${#files[*]} -gt 0 ]]; then
        results=$(_search "$pattern" "${grep_flags[@]}" -- "${files[@]}" 2>/dev/null || true)
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
# PRE-COMPUTE LAYER FILE SETS
# =============================================================================
ui_files=()
domain_files=()
data_files=()
viewmodel_files=()
for f in "${kt_files[@]}"; do
    [[ "$f" == "$UI_ROOT"/*     ]] && ui_files+=("$f")
    [[ "$f" == "$DOMAIN_ROOT"/* ]] && domain_files+=("$f")
    [[ "$f" == "$DATA_ROOT"/*   ]] && data_files+=("$f")
    [[ "$f" == *"/viewmodel/"*  ]] && viewmodel_files+=("$f")
done

# =============================================================================
# CHECKS
# =============================================================================

echo -e "\n${BOLD}======================================================${RESET}"
echo -e "${BOLD}  Architecture Rules Checker — $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo -e "${BOLD}======================================================${RESET}"
echo -e "  Source root : ${SOURCE_ROOT}"
echo -e "  Files scanned: ${#kt_files[*]}"
echo -e "    UI files    : ${#ui_files[*]}"
echo -e "    Domain files: ${#domain_files[*]}"
echo -e "    Data files  : ${#data_files[*]}"
echo -e ""
echo -e "  ${YELLOW}NOTE: Import-based layer boundary checks run via Detekt (detekt.yml).${RESET}"
echo -e "  ${YELLOW}      Run './gradlew detekt' to verify import rules.${RESET}\n"

# =============================================================================
# SECTION 1 — UI LAYER — BODY-LEVEL VIOLATIONS
# (Import checks removed — now owned by Detekt ForbiddenImport)
# =============================================================================
_header "1 · UI Layer — Direct Data Access Inside Composable Bodies"
echo -e "  ${YELLOW}UI must not call DAOs, API services, repositories, or use cases directly.${RESET}"

# 1a. UI calling Room DAO methods directly in Composable bodies
if [[ ${#ui_files[*]} -gt 0 ]]; then
    _run_check_files \
        'UI Composable calling Room DAO directly (body-level call)' \
        '\bDao\b.*\.(get|insert|update|delete|query)\b' \
        --type kotlin \
        --files "${ui_files[@]}"
fi

# 1b. Repository or UseCase called directly inside @Composable function bodies
if [[ ${#ui_files[*]} -gt 0 ]]; then
    _run_check_files \
        'Composable calling repository or use case directly (not via ViewModel)' \
        '(?s)@Composable\b[^{]*fun\s+\w+[^{]*\{[^}]*(Repository|UseCase|DataSource)\s*\.' \
        --multiline --pcre2 --type kotlin \
        --files "${ui_files[@]}"
fi

# =============================================================================
# SECTION 3 — LAYER BOUNDARY: DOMAIN / DATA IMPORTING FROM UI
# =============================================================================
_header "3 · Layer Boundary — Domain/Data Must Not Import UI Packages"
echo -e "  ${YELLOW}Domain and data layers must not depend on any ui.* package.${RESET}"
echo -e "  ${YELLOW}This is the main guard against UI dependency leakage in domain/data layers.${RESET}"

# Derive the ui package name from UI_ROOT relative to SOURCE_ROOT
# e.g. /abs/path/to/com/example/myapp/ui -> com.example.myapp.ui
UI_PKG=""
if [[ -n "$BASE_PKG" && "$BASE_PKG" != "$SOURCE_ROOT" ]]; then
    UI_PKG="${BASE_PKG#$SOURCE_ROOT/}.ui"
    UI_PKG="${UI_PKG//\//.}"
fi

if [[ -n "$UI_PKG" ]]; then
    # 3a. Domain files importing from ui.*
    if [[ ${#domain_files[*]} -gt 0 ]]; then
        _run_check_files \
            "Domain file importing from ui layer (${UI_PKG}.*) — domain must not depend on UI" \
            "import ${UI_PKG//./\\.}\\." \
            --type kotlin \
            --files "${domain_files[@]}"
    fi

    # 3b. Data files importing from ui.*
    if [[ ${#data_files[*]} -gt 0 ]]; then
        _run_check_files \
            "Data file importing from ui layer (${UI_PKG}.*) — data must not depend on UI" \
            "import ${UI_PKG//./\\.}\\." \
            --type kotlin \
            --files "${data_files[@]}"
    fi
else
    echo -e "  ${YELLOW}Skipped — could not derive UI package path from source root.${RESET}"
fi

# =============================================================================
# SECTION 2 — PRESENTATION LAYER — BODY-LEVEL VIOLATIONS
# (Import checks removed — now owned by Detekt ForbiddenImport)
# =============================================================================
_header "2 · Presentation Layer — Direct Retrofit Calls in ViewModel Bodies"
echo -e "  ${YELLOW}ViewModels must not call Retrofit API services directly — only through use cases / repositories.${RESET}"

# 2a. ViewModel calling Retrofit API service directly in function bodies
if [[ ${#viewmodel_files[*]} -gt 0 ]]; then
    _run_check_files \
        'ViewModel calling Retrofit API service directly' \
        '\bApiService\s*\.\s*(get|post|put|patch|delete|create|fetch|update)\b' \
        --pcre2 --type kotlin \
        --files "${viewmodel_files[@]}"
fi

# =============================================================================
# SECTION 5 — STATE MANAGEMENT VIOLATIONS
# =============================================================================
_header "5 · State Management"
echo -e "  ${YELLOW}Each screen must render from a single UiState. No scattered boolean flags.${RESET}"

# 5a. Multiple separate StateFlow<Boolean> fields in a single ViewModel (heuristic)
_rule_header 'ViewModel with multiple StateFlow<Boolean> properties (scattered boolean flag smell)'
bool_flow_violations=()
for f in "${viewmodel_files[@]}"; do
    count=$(grep -cE 'StateFlow[[:space:]]*<[[:space:]]*Boolean[[:space:]]*>' "$f" 2>/dev/null || true)
    if [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -ge 3 ]]; then
        bool_flow_violations+=("${f#$PROJECT_ROOT/} (${count} StateFlow<Boolean>)")
    fi
done
if [[ ${#bool_flow_violations[*]} -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
else
    for v in "${bool_flow_violations[@]}"; do
        _print_match "$v"
        (( TOTAL_VIOLATIONS++ ))
    done
fi

# 5b. One-off events stored as permanent state fields
if [[ ${#viewmodel_files[*]} -gt 0 ]]; then
    _run_check_files \
        'One-off event stored as a permanent UiState field (use Channel/SharedFlow instead)' \
        'val\s+(showDialog|showToast|showSnackbar|navigateTo|isNavigating|navigationEvent)\s*[=:]' \
        --type kotlin --pcre2 \
        --files "${viewmodel_files[@]}"
fi

# =============================================================================
# SECTION 7 — DEPENDENCY INJECTION
# =============================================================================
_header "7 · Dependency Injection — Hilt Scoping"
echo -e "  ${YELLOW}Singletons must be @Singleton, ViewModel deps @ViewModelScoped. Context must not leak into domain.${RESET}"

# 7a. Context injected into domain layer classes
if [[ ${#domain_files[*]} -gt 0 ]]; then
    _run_check_files \
        'Domain class receiving Context as constructor / inject parameter' \
        '(fun\s+\w+|constructor)\s*\([^)]*\bContext\b' \
        --type kotlin --pcre2 \
        --files "${domain_files[@]}"
fi

# 7b. Missing @Singleton on repository implementations
_rule_header 'RepositoryImpl missing @Singleton annotation (should be app-scoped)'
repo_impl_files=()
for f in "${data_files[@]}"; do
    [[ "$(basename "$f")" == *RepositoryImpl* ]] && repo_impl_files+=("$f")
done
missing_singleton=()
for f in "${repo_impl_files[@]}"; do
    if ! grep -qE '@Singleton' "$f" 2>/dev/null; then
        missing_singleton+=("${f#$PROJECT_ROOT/}")
    fi
done
if [[ ${#missing_singleton[*]} -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
else
    for v in "${missing_singleton[@]}"; do
        _print_match "$v"
        (( TOTAL_VIOLATIONS++ ))
    done
fi

# =============================================================================
# SECTION 8 — FORBIDDEN PATTERNS
# =============================================================================
_header "8 · Forbidden Patterns"
echo -e "  ${YELLOW}Global rules that must never be violated in any file.${RESET}"

# 8a. Fully-qualified class names used inline (not in import statements)
_run_check \
    'Fully-qualified class name used inline (use import at top of file instead)' \
    '(?<!import )(com\.example\.\w+(\.\w+){3,}|io\.mockk\.\w+|retrofit2\.\w+|androidx\.\w+\.\w+)\s*[(<{]' \
    --type kotlin --pcre2 \
    --exclude 'build.gradle.kts'

# 8b. ViewModel calling Retrofit directly (any file, multiline pattern)
_run_check \
    'Direct Retrofit API call in ViewModel (must go through repository/use case)' \
    'class\s+\w+ViewModel[^{]*\{[^}]*\.\s*(enqueue|execute|await)\s*\(' \
    --type kotlin --multiline --pcre2

# 8c. Business rules (domain-model branches) inside Composable bodies
_run_check \
    'Calculation / business logic branch inside @Composable (if/when on domain model properties)' \
    '(?s)@Composable\b[^{]*fun\s+\w+[^{]*\{[^}]*(when\s*\(\s*\w+(\.status|\.state|\.type|\.role|\.kind)\s*\)|if\s*\([^)]*\.(status|state|type|role|kind)\b)' \
    --type kotlin --multiline --pcre2

# 8d. ViewModels missing a corresponding *Test.kt or *IntegrationTest.kt
_rule_header 'ViewModels missing a corresponding *Test.kt or *IntegrationTest.kt'
test_root="$PROJECT_ROOT/app/src/test"
missing_tests=()
for f in "${viewmodel_files[@]}"; do
    if ! grep -qE '^[[:space:]]*(internal|public|private|protected)?[[:space:]]*class[[:space:]]+[[:alnum:]_]+ViewModel\b' "$f" 2>/dev/null; then
        continue
    fi
    vm_name="$(basename "$f" .kt)"
    if ! find "$test_root" \( -name "${vm_name}Test.kt" -o -name "${vm_name}IntegrationTest.kt" \) 2>/dev/null | grep -q .; then
        missing_tests+=("${f#$PROJECT_ROOT/}")
    fi
done
if [[ ${#missing_tests[*]} -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
else
    for v in "${missing_tests[@]}"; do
        _print_match "$v (no matching *Test.kt or *IntegrationTest.kt found)"
        (( TOTAL_VIOLATIONS++ ))
    done
fi

# =============================================================================
# SECTION 9 — PACKAGE STRUCTURE
# =============================================================================
_header "9 · Package Structure — Misplaced Files"
echo -e "  ${YELLOW}Files must reside in their canonical layer folder.${RESET}"

# 9a. ViewModel files NOT inside a viewmodel/ folder
_rule_header 'ViewModel class files placed outside a viewmodel/ folder'
vm_misplaced=()
for f in "${kt_files[@]}"; do
    if grep -qE '^[[:space:]]*class[[:space:]]+[[:alnum:]_]+ViewModel\b' "$f" 2>/dev/null; then
        if [[ "$f" != *"/viewmodel/"* ]]; then
            vm_misplaced+=("${f#$PROJECT_ROOT/}")
        fi
    fi
done
if [[ ${#vm_misplaced[*]} -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
else
    for v in "${vm_misplaced[@]}"; do
        _print_match "$v"
        (( TOTAL_VIOLATIONS++ ))
    done
fi

# 9b. UseCase files NOT inside a usecase/ folder
_rule_header 'UseCase class files placed outside a usecase/ folder'
uc_misplaced=()
for f in "${kt_files[@]}"; do
    if grep -qE '^[[:space:]]*class[[:space:]]+[[:alnum:]_]+UseCase\b' "$f" 2>/dev/null; then
        if [[ "$f" != *"/usecase/"* ]]; then
            uc_misplaced+=("${f#$PROJECT_ROOT/}")
        fi
    fi
done
if [[ ${#uc_misplaced[*]} -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
else
    for v in "${uc_misplaced[@]}"; do
        _print_match "$v"
        (( TOTAL_VIOLATIONS++ ))
    done
fi

# 9c. RepositoryImpl files NOT inside a data/repository/ folder
_rule_header 'RepositoryImpl class files placed outside data/repository/ folder'
repo_misplaced=()
for f in "${kt_files[@]}"; do
    if grep -qE '^[[:space:]]*class[[:space:]]+[[:alnum:]_]+RepositoryImpl\b' "$f" 2>/dev/null; then
        if [[ "$f" != "$DATA_ROOT/repository/"* && ! "$f" =~ ^"$DATA_ROOT"/[^/]+/repository/ ]]; then
            repo_misplaced+=("${f#$PROJECT_ROOT/}")
        fi
    fi
done
if [[ ${#repo_misplaced[*]} -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
else
    for v in "${repo_misplaced[@]}"; do
        _print_match "$v"
        (( TOTAL_VIOLATIONS++ ))
    done
fi

# 9d. Mapper files in wrong layer (DTO→Domain mapper must be in data/, Domain→UI in ui/)
_rule_header 'DTO→Domain mapper placed outside data/ layer'
mapper_violations=false
for f in "${kt_files[@]}"; do
    fname="$(basename "$f")"
    if [[ "$fname" == *Mapper* ]] && [[ "$f" == "$DOMAIN_ROOT"/* ]]; then
        _print_match "${f#$PROJECT_ROOT/} (mapper belongs in data/ or ui/, not domain/)"
        (( TOTAL_VIOLATIONS++ ))
        mapper_violations=true
    fi
done
if [[ "$mapper_violations" == "false" ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
fi

# =============================================================================
# SECTION 10 — SUPPRESSION CONTROL
# =============================================================================
_header "10 · Suppression Control"
echo -e "  ${YELLOW}Agents must fix rule violations, not hide them with suppressions or inline ignores.${RESET}"
echo -e "  ${YELLOW}A suppression requires an explicit user decision and a documented false-positive rationale.${RESET}"

_rule_header 'New suppression / ignore directives added in this diff'
suppression_pattern='(@file:Suppress|@Suppress|@SuppressLint|tools:ignore|ktlint-disable|detekt-disable|noinspection|lint:ignore|baseline([._-]|$))'
suppression_results=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
    suppression_results=$(
        {
            git diff --unified=0 -- app/src/main app/build.gradle.kts build.gradle.kts detekt.yml .editorconfig 2>/dev/null
            git diff --cached --unified=0 -- app/src/main app/build.gradle.kts build.gradle.kts detekt.yml .editorconfig 2>/dev/null
        } |
            grep -E '^\+[^+]' |
            grep -En "$suppression_pattern" || true
    )
fi

if [[ -z "$suppression_results" ]]; then
    echo -e "    ${GREEN}✓ No new suppressions${RESET}"
else
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            _print_match "$line"
            (( TOTAL_VIOLATIONS++ ))
        fi
    done <<< "$suppression_results"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BOLD}======================================================${RESET}"
if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ All architecture rules passed — 0 violations${RESET}"
    echo -e "${BOLD}======================================================${RESET}"
    exit 0
else
    echo -e "${RED}${BOLD}  ✗ $TOTAL_VIOLATIONS violation(s) found — see above${RESET}"
    echo -e "${BOLD}======================================================${RESET}"
    exit 1
fi
