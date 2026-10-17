#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
GRADLE_FILE="$ROOT_DIR/app/build.gradle.kts"

if ! rg -Fq 'taskName.equals("recordRoborazziDebug", ignoreCase = true)' "$GRADLE_FILE"; then
  echo "FAIL: recordRoborazziDebug must select the Roborazzi visual lane." >&2
  exit 1
fi

echo "PASS: recordRoborazziDebug selects the Roborazzi visual lane."
