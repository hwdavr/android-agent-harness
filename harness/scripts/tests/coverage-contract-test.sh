#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CHECKER="$REPO_ROOT/harness/scripts/check-coverage.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/coverage-contract-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

report="$fixture_root/report.xml"
cat > "$report" <<'EOF'
<?xml version="1.0" ?>
<report name="fixture">
<package name="com/example/notes">
<class name="com/example/notes/NewViewModel" sourcefilename="NewViewModel.kt">
<method name="load">
<counter type="LINE" missed="1" covered="9"/>
</method>
<counter type="LINE" missed="1" covered="9"/>
</class>
<class name="com/example/notes/NoteMapper" sourcefilename="NoteMapper.kt">
<method name="map">
<counter type="LINE" missed="5" covered="5"/>
</method>
<counter type="LINE" missed="2" covered="8"/>
</class>
</package>
<package name="com/example/thirdparty">
<class name="com/example/thirdparty/Library" sourcefilename="Library.kt">
<counter type="LINE" missed="100" covered="0"/>
</class>
</package>
</report>
EOF

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "FAIL: coverage checker unexpectedly passed" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "FAIL: coverage checker did not report '$expected'" >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
}

bash "$CHECKER" "$report" \
  --exclude-package com/example/thirdparty \
  --min-overall 80 \
  --min-file NewViewModel.kt=90

expect_failure "overall project-owned line coverage 14.17% is below" \
  bash "$CHECKER" "$report" --min-overall 80

expect_failure "expected exactly one coverage file matching 'Missing.kt', found 0" \
  bash "$CHECKER" "$report" --min-overall 0 --min-file Missing.kt=90

expect_failure "file NewViewModel.kt coverage 90.00% is below" \
  bash "$CHECKER" "$report" --min-overall 0 --min-file NewViewModel.kt=95

expect_failure "all coverage classes were excluded" \
  bash "$CHECKER" "$report" --exclude-package com/example

expect_failure "excluded package prefix matched no coverage classes: com/example/missing" \
  bash "$CHECKER" "$report" --exclude-package com/example/missing

echo "PASS: coverage checker enforces weighted Kover thresholds, package exclusions, and per-file thresholds."
