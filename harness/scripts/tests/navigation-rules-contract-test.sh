#!/usr/bin/env bash
# Contract test for check-navigation-rules.sh.
# Verifies a compliant fixture passes and a violating fixture fails with
# actionable path/line diagnostics.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CHECKER="$REPO_ROOT/harness/scripts/check-navigation-rules.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/navigation-rules-test.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

write_common_fixture() {
    local root="$1"
    mkdir -p \
        "$root/.agents/rules" \
        "$root/app/src/main/java/com/example/notesapp/navigation" \
        "$root/app/src/androidTest/java/com/example/notesapp/navigation"
    printf '%s\n' '# Navigation Rules' > "$root/.agents/rules/navigation-rules.md"
    printf '%s\n' \
        'package com.example.notesapp.navigation' \
        'sealed class Destinations(val route: String) {' \
        '    data object CollectionNotes : Destinations("collectionNotes?type={type}&folderId={folderId}&label={label}") {' \
        '        fun createRoute(type: String, label: String, folderId: String? = null) =' \
        '            "collectionNotes?type=${Uri.encode(type)}&folderId=${Uri.encode(folderId.orEmpty())}&label=${Uri.encode(label)}"' \
        '    }' \
        '    data object MoveTo : Destinations("moveTo?itemType={itemType}&itemId={itemId}")' \
        '    data object Editor : Destinations("editor?noteId={noteId}&folderId={folderId}")' \
        '    data object VoiceRecorder : Destinations("voiceRecorder?noteId={noteId}&source={source}&focusedBlockId={focusedBlockId}")' \
        '    data object ExportNote : Destinations("exportNote/{noteId}") {' \
        '        fun createRoute(noteId: String) = "exportNote/${Uri.encode(noteId)}"' \
        '    }' \
        '    data object SharedUsers : Destinations("sharedUsers/{noteId}")' \
        '    data object ManageAccess : Destinations("manageAccess/{noteId}")' \
        '    data object ShareInvite : Destinations("shareInvite/{noteId}")' \
        '}' > "$root/app/src/main/java/com/example/notesapp/navigation/Destinations.kt"
    printf '%s\n' \
        'package com.example.notesapp.navigation' \
        'fun classify(route: String?) = route == Destinations.Editor.route' \
        'val documentation = """route.startsWith("editor") composable("home")"""' \
        > "$root/app/src/main/java/com/example/notesapp/navigation/AppNavGraph.kt"
    printf '%s\n' \
        'package com.example.notesapp.navigation' \
        'composable(route = Destinations.MoveTo.route, arguments = listOf(' \
        '    navArgument("itemType") { type = NavType.StringType },' \
        '    navArgument("itemId") { type = NavType.StringType }' \
        '))' \
        'composable(route = Destinations.CollectionNotes.route, arguments = listOf(' \
        '    navArgument("type") { type = NavType.StringType; defaultValue = "all" },' \
        '    navArgument("folderId") { type = NavType.StringType; defaultValue = "" },' \
        '    navArgument("label") { type = NavType.StringType; defaultValue = "" }' \
        '))' \
        'composable(route = Destinations.Editor.route, arguments = listOf(' \
        '    navArgument("noteId") { type = NavType.StringType; defaultValue = "" },' \
        '    navArgument("folderId") { type = NavType.StringType; defaultValue = "" }' \
        '))' \
        'composable(route = Destinations.VoiceRecorder.route, arguments = listOf(' \
        '    navArgument("noteId") { type = NavType.StringType; defaultValue = "" },' \
        '    navArgument("source") { type = NavType.StringType; defaultValue = "EDITOR" },' \
        '    navArgument("focusedBlockId") { type = NavType.StringType; defaultValue = "" }' \
        '))' \
        'composable(route = Destinations.ExportNote.route, arguments = listOf(navArgument("noteId") { type = NavType.StringType }))' \
        'composable(route = Destinations.SharedUsers.route, arguments = listOf(navArgument("noteId") { type = NavType.StringType }))' \
        'composable(route = Destinations.ManageAccess.route, arguments = listOf(navArgument("noteId") { type = NavType.StringType }))' \
        'composable(route = Destinations.ShareInvite.route, arguments = listOf(navArgument("noteId") { type = NavType.StringType }))' \
        > "$root/app/src/main/java/com/example/notesapp/navigation/AppNavigationHost.kt"
    printf '%s\n' \
        'package com.example.notesapp.navigation' \
        'fun productionGraphTest() = AppNavigationHost' \
        > "$root/app/src/androidTest/java/com/example/notesapp/navigation/NavigationTest.kt"
    printf '%s\n' \
        'package com.example.notesapp.navigation' \
        'fun productionContractTest() = AppNavigationHost' \
        > "$root/app/src/androidTest/java/com/example/notesapp/navigation/NavigationContractTest.kt"
}

write_common_fixture "$fixture_root/compliant"
bash "$CHECKER" "$fixture_root/compliant"

write_common_fixture "$fixture_root/violating"
printf '%s\n' \
    'package com.example.notesapp.navigation' \
    'fun bad(route: String?) = route?.startsWith("editor") == true' \
    > "$fixture_root/violating/app/src/main/java/com/example/notesapp/navigation/AppNavGraph.kt"
printf '%s\n' \
    'package com.example.notesapp.navigation' \
    'composable(route = Destinations.MoveTo.route, arguments = listOf(' \
    '    navArgument("itemType") { type = NavType.StringType; defaultValue = "" },' \
    '    navArgument("itemId") { type = NavType.StringType }' \
    '))' \
    > "$fixture_root/violating/app/src/main/java/com/example/notesapp/navigation/AppNavigationHost.kt"
printf '%s\n' \
    'package com.example.notesapp.navigation' \
    'fun badGraph() = composable("home")' \
    > "$fixture_root/violating/app/src/androidTest/java/com/example/notesapp/navigation/NavigationTest.kt"

if output=$(bash "$CHECKER" "$fixture_root/violating" 2>&1); then
    echo "FAIL: checker unexpectedly accepted violating fixture" >&2
    exit 1
fi
printf '%s\n' "$output" | grep -Fq 'raw route prefix' || {
    echo "FAIL: checker did not report raw route prefix" >&2
    printf '%s\n' "$output" >&2
    exit 1
}
printf '%s\n' "$output" | grep -Fq 'required MoveTo.itemType' || {
    echo "FAIL: checker did not report required empty default" >&2
    printf '%s\n' "$output" >&2
    exit 1
}
printf '%s\n' "$output" | grep -Fq 'NavigationTest.kt' || {
    echo "FAIL: checker did not report raw route test evidence" >&2
    printf '%s\n' "$output" >&2
    exit 1
}

# State-driven navigation (enum class AppScreen routed by a composable host) must be
# accepted when every destination has a host branch and a production-entry test mounts
# the host, and rejected when a destination has no branch.
write_state_driven_fixture() {
    local root="$1" missing_branch="$2"
    mkdir -p \
        "$root/.agents/rules" \
        "$root/app/src/main/java/com/example/notesapp/ui/navigation" \
        "$root/app/src/main/java/com/example/notesapp" \
        "$root/app/src/androidTest/java/com/example/notesapp/home"
    printf '%s\n' '# Navigation Rules' > "$root/.agents/rules/navigation-rules.md"
    printf '%s\n' \
        'package com.example.notesapp.ui.navigation' \
        'enum class AppScreen {' \
        '    Home,' \
        '    Editor' \
        '}' > "$root/app/src/main/java/com/example/notesapp/ui/navigation/AppScreen.kt"
    if [ "$missing_branch" = "yes" ]; then
        printf '%s\n' \
            'package com.example.notesapp' \
            'fun Host(screen: AppScreen) = when (screen) {' \
            '    AppScreen.Home -> Home()' \
            '}' > "$root/app/src/main/java/com/example/notesapp/MainActivity.kt"
    else
        printf '%s\n' \
            'package com.example.notesapp' \
            'fun Host(screen: AppScreen) = when (screen) {' \
            '    AppScreen.Home -> Home()' \
            '    AppScreen.Editor -> Editor()' \
            '}' > "$root/app/src/main/java/com/example/notesapp/MainActivity.kt"
    fi
    printf '%s\n' \
        'package com.example.notesapp.home' \
        'class HomeFlowTest {' \
        '    val composeRule = createAndroidComposeRule<MainActivity>()' \
        '}' > "$root/app/src/androidTest/java/com/example/notesapp/home/HomeFlowTest.kt"
}

write_state_driven_fixture "$fixture_root/state-compliant" no
bash "$CHECKER" "$fixture_root/state-compliant" >/dev/null

write_state_driven_fixture "$fixture_root/state-violating" yes
if output=$(bash "$CHECKER" "$fixture_root/state-violating" 2>&1); then
    echo "FAIL: checker accepted state-driven host without a branch for every destination" >&2
    exit 1
fi
printf '%s\n' "$output" | grep -Fq 'navigation host file is missing' || {
    echo "FAIL: checker did not report the missing destination branch" >&2
    printf '%s\n' "$output" >&2
    exit 1
}

echo "PASS: navigation-rules checker accepts compliant and rejects violating fixtures."
