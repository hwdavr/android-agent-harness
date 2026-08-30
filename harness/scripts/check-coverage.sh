#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: bash harness/scripts/check-coverage.sh [report.xml] [options]

Options:
  --exclude-package <prefix>   Exclude a package prefix, repeatable.
  --min-overall <percent>      Minimum weighted line coverage (default: 80).
  --min-file <path>=<percent>  Minimum coverage for one source file, repeatable.
EOF
  exit 2
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

is_percent() {
  awk -v value="$1" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?$/ && value >= 0 && value <= 100) }'
}

check_threshold() {
  local label="$1"
  local actual="$2"
  local minimum="$3"
  awk -v actual="$actual" -v minimum="$minimum" 'BEGIN { exit !(actual + 1e-9 >= minimum) }' \
    || fail "$label coverage ${actual}% is below the required ${minimum}%"
}

REPORT="app/build/reports/kover/reportDebug.xml"
MIN_OVERALL=80
EXCLUDED_PACKAGES=()
MIN_FILES=()

if [ "$#" -gt 0 ]; then
  case "$1" in
    --*) ;;
    *) REPORT="$1"; shift ;;
  esac
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --exclude-package)
      [ "$#" -ge 2 ] || usage
      [ -n "$2" ] || fail "package exclusion prefix cannot be empty"
      EXCLUDED_PACKAGES+=("$2")
      shift 2
      ;;
    --min-overall)
      [ "$#" -ge 2 ] || usage
      is_percent "$2" || fail "invalid overall threshold: $2"
      MIN_OVERALL="$2"
      shift 2
      ;;
    --min-file)
      [ "$#" -ge 2 ] || usage
      case "$2" in
        *=*)
          file_path="${2%=*}"
          file_threshold="${2##*=}"
          [ -n "$file_path" ] || fail "file threshold has an empty path"
          is_percent "$file_threshold" || fail "invalid file threshold: $file_threshold"
          MIN_FILES+=("$2")
          ;;
        *)
          fail "file threshold must use <path>=<percent>: $2"
          ;;
      esac
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[ -f "$REPORT" ] || fail "coverage report does not exist: $REPORT"
command -v awk >/dev/null 2>&1 || fail "awk is required to parse Kover XML"

coverage_rows=$(mktemp "${TMPDIR:-/tmp}/notes-kover-coverage.XXXXXX")
trap 'rm -f "$coverage_rows"' EXIT

# Kover repeats line counters inside each method and once at class level. Only
# the class-level counter is counted so executable lines are not double-counted.
awk '
  function attr(line, name, marker, start, rest, finish) {
    marker = name "=\""
    start = index(line, marker)
    if (start == 0) return ""
    rest = substr(line, start + length(marker))
    finish = index(rest, "\"")
    if (finish == 0) return ""
    return substr(rest, 1, finish - 1)
  }
  /<package[[:space:]]/ {
    package_name = attr($0, "name")
  }
  /<class[[:space:]]/ {
    in_class = 1
    in_method = 0
    class_name = attr($0, "name")
    source_name = attr($0, "sourcefilename")
  }
  /<method[[:space:]]/ {
    if (in_class) in_method = 1
  }
  /<\/method>/ {
    in_method = 0
  }
  /<counter[[:space:]]/ && in_class && !in_method && $0 ~ /type="LINE"/ {
    missed = attr($0, "missed")
    covered = attr($0, "covered")
    if (missed ~ /^[0-9]+$/ && covered ~ /^[0-9]+$/ && source_name != "") {
      printf "%s\t%s\t%s\t%s\t%s\n", package_name, class_name, source_name, covered, missed + covered
    }
  }
  /<\/class>/ {
    in_class = 0
    in_method = 0
  }
' "$REPORT" > "$coverage_rows"

[ -s "$coverage_rows" ] || fail "coverage report contains no class-level executable line data"

excluded_list=""
if [ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]; then
  excluded_list=$(printf '%s\n' "${EXCLUDED_PACKAGES[@]}")
  for excluded_package in "${EXCLUDED_PACKAGES[@]}"; do
    excluded_class_count=$(awk -F '\t' -v prefix="$excluded_package" '
      index($1, prefix) == 1 { count++ }
      END { print count + 0 }
    ' "$coverage_rows")
    [ "$excluded_class_count" -gt 0 ] \
      || fail "excluded package prefix matched no coverage classes: $excluded_package"
  done
fi

read -r covered_lines executable_lines included_classes <<EOF
$(awk -F '\t' -v excluded="$excluded_list" '
  BEGIN { excluded_count = split(excluded, excluded_prefixes, "\n") }
  {
    ignored = 0
    for (i = 1; i <= excluded_count; i++) {
      if (excluded_prefixes[i] != "" && index($1, excluded_prefixes[i]) == 1) ignored = 1
    }
    if (!ignored) {
      covered += $4
      executable += $5
      classes++
    }
  }
  END { printf "%d %d %d\n", covered + 0, executable + 0, classes + 0 }
' "$coverage_rows")
EOF

[ "$included_classes" -gt 0 ] || fail "all coverage classes were excluded"
[ "$executable_lines" -gt 0 ] || fail "coverage report contains no executable lines after exclusions"
overall_percent=$(awk -v covered="$covered_lines" -v executable="$executable_lines" \
  'BEGIN { printf "%.2f", (covered / executable) * 100 }')

if [ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]; then
  excluded_label=$(IFS=,; echo "${EXCLUDED_PACKAGES[*]}")
  echo "Coverage packages excluded explicitly: $excluded_label"
fi
echo "Overall project-owned line coverage: ${overall_percent}% (${covered_lines}/${executable_lines})"
check_threshold "overall project-owned line" "$overall_percent" "$MIN_OVERALL"

if [ "${#MIN_FILES[@]}" -gt 0 ]; then
  for file_spec in "${MIN_FILES[@]}"; do
    file_path="${file_spec%=*}"
    file_threshold="${file_spec##*=}"
    file_base="${file_path##*/}"

    read -r matching_groups file_covered file_executable <<EOF
$(awk -F '\t' -v excluded="$excluded_list" -v requested="$file_path" -v base="$file_base" '
  function suffix(value, ending) {
    return length(value) >= length(ending) && substr(value, length(value) - length(ending) + 1) == ending
  }
  BEGIN { excluded_count = split(excluded, excluded_prefixes, "\n") }
  {
    ignored = 0
    for (i = 1; i <= excluded_count; i++) {
      if (excluded_prefixes[i] != "" && index($1, excluded_prefixes[i]) == 1) ignored = 1
    }
    candidate = $1 "/" $3
    matches = !ignored && ($3 == requested || $3 == base || candidate == requested || suffix(candidate, "/" requested))
    if (matches) {
      key = $1 SUBSEP $3
      if (!seen[key]++) groups++
      covered += $4
      executable += $5
    }
  }
  END { printf "%d %d %d\n", groups + 0, covered + 0, executable + 0 }
' "$coverage_rows")
EOF

    [ "$matching_groups" -eq 1 ] \
      || fail "expected exactly one coverage file matching '${file_path}', found $matching_groups"
    [ "$file_executable" -gt 0 ] || fail "coverage file has no executable lines: $file_path"
    file_percent=$(awk -v covered="$file_covered" -v executable="$file_executable" \
      'BEGIN { printf "%.2f", (covered / executable) * 100 }')
    echo "File: $file_path — ${file_percent}% (${file_covered}/${file_executable})"
    check_threshold "file $file_path" "$file_percent" "$file_threshold"
  done
fi

echo "PASS: coverage thresholds met."
