#!/usr/bin/env bash
# Contract test for check-edge-to-edge-insets.sh: a screen that ignores the system-bar insets fails with a
# path:line diagnostic; screens that take parentPadding or apply an inset modifier, and non-screen files, pass.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CHECKER="$REPO_ROOT/harness/scripts/check-edge-to-edge-insets.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/edge-to-edge-test.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

screen_dir="$fixture_root/app/src/main/java/com/example/notesapp/ui/demo/screen"
mkdir -p "$screen_dir"

write_screen() {
    printf '%s\n' 'package com.example.notesapp.ui.demo.screen' '' '@Composable' "$2" '    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {}' '}' > "$screen_dir/$1.kt"
}

write_screen DemoReaderScreen 'fun DemoReaderScreen(onBack: () -> Unit) {'
if output="$("$CHECKER" --project-root "$fixture_root" 2>&1)"; then
    echo "FAIL: a screen without inset handling was accepted" >&2
    exit 1
fi
case "$output" in
    *"DemoReaderScreen.kt:4: DemoReaderScreen ignores system-bar insets"*) ;;
    *) echo "FAIL: diagnostic lacks path:line and screen name: $output" >&2; exit 1 ;;
esac

write_screen DemoReaderScreen 'fun DemoReaderScreen(parentPadding: PaddingValues, onBack: () -> Unit) {'
"$CHECKER" --project-root "$fixture_root" > /dev/null

printf '%s\n' 'package x' '@Composable' 'fun DemoPickerScreen() {' '    Column(Modifier.statusBarsPadding()) {}' '}' > "$screen_dir/DemoPickerScreen.kt"
"$CHECKER" --project-root "$fixture_root" > /dev/null

printf '%s\n' 'package x' '@Composable' 'fun DemoHelper() {}' > "$screen_dir/DemoHelper.kt"
printf '%s\n' 'package x' '@Composable' 'fun DemoComponentScreen() {}' > "$fixture_root/app/src/main/java/com/example/notesapp/ui/demo/DemoComponentScreen.kt"
"$CHECKER" --project-root "$fixture_root" > /dev/null

echo "PASS: edge-to-edge inset contract"
