#!/usr/bin/env bash
# Contract tests for the shared Kotlin AST checker.
# The fixtures deliberately put rule-shaped text in comments and literals.
# A source-text regex checker reports those as code; the AST checker must not.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
COMPOSE_CHECKER="$REPO_ROOT/harness/scripts/check-compose-rules.sh"
LOCALIZATION_CHECKER="$REPO_ROOT/harness/scripts/check-localization-rules.sh"
ARCHITECTURE_CHECKER="$REPO_ROOT/harness/scripts/check-architecture-rules.sh"
ASSERTIONS_CHECKER="$REPO_ROOT/harness/scripts/check-test-assertions-quality.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ast-checkers-test.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_pass() {
  local label="$1"
  shift
  local output
  if ! output=$("$@" 2>&1); then
    echo "$output" >&2
    fail "$label unexpectedly failed"
  fi
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    fail "command unexpectedly succeeded: $*"
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    fail "failure did not contain: $expected"
  }
}

source_root="$fixture_root/comments/com/example/notesapp"
mkdir -p "$source_root/ui" "$source_root/data" "$source_root/domain"
cat > "$source_root/ui/CommentOnly.kt" <<'KOTLIN'
package com.example.notesapp.ui

// @Composable fun FakeContent() { hiltViewModel(); noteRepository.load() }
/* Button(onClick = {}) Text("wrong") Color.Red Modifier.testTag("tag") */
val documentation = """
    Text("wrong")
    repository.fetch()
    contentDescription = null
"""

@Composable
fun SafeContent() {
    Text(text = stringResource(R.string.safe_label))
}
KOTLIN

cat > "$source_root/data/CommentOnlyData.kt" <<'KOTLIN'
package com.example.notesapp.data

// UiState must not be detected in comments.
val documentation = """UiState"""
KOTLIN

cat > "$source_root/domain/CommentOnlyDomain.kt" <<'KOTLIN'
package com.example.notesapp.domain

// import android.content.Context
val documentation = """import androidx.room.Dao"""
KOTLIN

cat > "$source_root/ui/CommentOnlyTest.kt" <<'KOTLIN'
package com.example.notesapp.ui

fun onlyDocumentation() {
    val output = """svg.contains("<svg") and svg.contains("</svg>")"""
}
KOTLIN

expect_pass "comment and literal Compose fixture" \
  bash "$COMPOSE_CHECKER" --all "$fixture_root/comments/com/example/notesapp"
expect_pass "comment and literal localization fixture" \
  bash "$LOCALIZATION_CHECKER" --all "$fixture_root/comments/com/example/notesapp"

animation_labels_root="$fixture_root/animation-labels/com/example/notesapp/ui"
mkdir -p "$animation_labels_root"
cat > "$animation_labels_root/SafeLabels.kt" <<'KOTLIN'
package com.example.notesapp.ui

@Composable
fun SafeLabels() {
    val transition = rememberInfiniteTransition(label = "mic_pulse")
    AnimatedContent(targetState = transition, label = "content_transition") { }
}

data class UiState(
    val inputText: String = "",
    val title: String = "",
)
KOTLIN
expect_pass "animation labels and data-class state defaults are not user-visible copy" \
  bash "$LOCALIZATION_CHECKER" --all "$fixture_root/animation-labels/com/example/notesapp"

expect_pass "comment and literal architecture fixture" \
  bash "$ARCHITECTURE_CHECKER" --all "$fixture_root/comments/com/example/notesapp"
expect_pass "comment and literal assertion fixture" \
  bash "$ASSERTIONS_CHECKER" "$fixture_root/comments/com/example/notesapp/ui"

default_scan_root="$fixture_root/default-scan"
mkdir -p "$default_scan_root/app/src/test" "$default_scan_root/app/src/androidTest"
cat > "$default_scan_root/app/src/test/JvmRendererTest.kt" <<'KOTLIN'
fun jvmRenderingTest() {
    val output = renderer.render()
    assertTrue(output.contains(">Label</text>"))
}
KOTLIN
cat > "$default_scan_root/app/src/androidTest/AndroidRendererTest.kt" <<'KOTLIN'
fun androidRenderingTest() {
    val output = renderer.render()
    assertTrue(output.contains("<svg"))
    assertTrue(output.contains("</svg>"))
}
KOTLIN
expect_failure "envelope-only assertions" \
  bash "$ASSERTIONS_CHECKER" --project-root "$default_scan_root"

actual_compose="$fixture_root/actual-compose/com/example/notesapp/ui"
mkdir -p "$actual_compose"
cat > "$actual_compose/Bad.kt" <<'KOTLIN'
package com.example.notesapp.ui

@Composable
fun Bad() {
    Button(onClick = {}) { Text(stringResource(R.string.action)) }
}
KOTLIN
expect_failure "interactive Composables but no Modifier.testTag" \
  bash "$COMPOSE_CHECKER" --all "$fixture_root/actual-compose/com/example/notesapp"

catalog_source="$fixture_root/non-composable-catalog/com/example/notesapp/domain"
mkdir -p "$catalog_source"
cat > "$catalog_source/AnalyticsActionCatalog.kt" <<'KOTLIN'
package com.example.notesapp.domain

enum class AnalyticsElementType(val value: String) {
    Button("button"),
}

data class AnalyticsAction(val elementType: AnalyticsElementType)
KOTLIN
expect_pass "domain button type names are not interactive Compose elements" \
  bash "$COMPOSE_CHECKER" --all "$fixture_root/non-composable-catalog/com/example/notesapp"

actual_localization="$fixture_root/actual-localization/com/example/notesapp/ui"
mkdir -p "$actual_localization"
cat > "$actual_localization/Bad.kt" <<'KOTLIN'
package com.example.notesapp.ui

@Composable
fun Bad() {
    Text("Visible text")
}
KOTLIN
expect_failure "Text() called with a raw string literal" \
  bash "$LOCALIZATION_CHECKER" --all "$fixture_root/actual-localization/com/example/notesapp"

actual_architecture="$fixture_root/actual-architecture/com/example/notesapp/ui"
mkdir -p "$actual_architecture" "$fixture_root/actual-architecture/com/example/notesapp/data" \
  "$fixture_root/actual-architecture/com/example/notesapp/domain"
cat > "$actual_architecture/Bad.kt" <<'KOTLIN'
package com.example.notesapp.ui

@Composable
fun Bad() {
    noteRepository.load()
}
KOTLIN
expect_failure "repository, use case, or data source directly" \
  bash "$ARCHITECTURE_CHECKER" --all "$fixture_root/actual-architecture/com/example/notesapp"

safe_await_root="$fixture_root/safe-await/com/example/notesapp/ui/viewmodel"
mkdir -p "$safe_await_root"
cat > "$safe_await_root/SafeFoldersViewModel.kt" <<'KOTLIN'
package com.example.notesapp.ui

class SafeFoldersViewModel {
    fun refresh() {
        val deferred = async { repository.load() }
        deferred.await()
    }
}
KOTLIN
mkdir -p "$fixture_root/safe-await/app/src/test"
cat > "$fixture_root/safe-await/app/src/test/SafeFoldersViewModelTest.kt" <<'KOTLIN'
package com.example.notesapp.ui

class SafeFoldersViewModelTest
KOTLIN
expect_pass "coroutine Deferred.await fixture" \
  bash "$ARCHITECTURE_CHECKER" --all --project-root "$fixture_root/safe-await" \
    --source-root "$fixture_root/safe-await/com/example/notesapp" \
    "$fixture_root/safe-await/com/example/notesapp"

direct_retrofit_root="$fixture_root/direct-retrofit/com/example/notesapp/ui/viewmodel"
mkdir -p "$direct_retrofit_root"
cat > "$direct_retrofit_root/BadRetrofitViewModel.kt" <<'KOTLIN'
package com.example.notesapp.ui

class BadRetrofitViewModel {
    fun refresh() {
        apiService.get().await()
    }
}
KOTLIN
mkdir -p "$fixture_root/direct-retrofit/app/src/test"
cat > "$fixture_root/direct-retrofit/app/src/test/BadRetrofitViewModelTest.kt" <<'KOTLIN'
package com.example.notesapp.ui

class BadRetrofitViewModelTest
KOTLIN
expect_failure "ViewModel calls a Retrofit API service directly" \
  bash "$ARCHITECTURE_CHECKER" --all --project-root "$fixture_root/direct-retrofit" \
    --source-root "$fixture_root/direct-retrofit/com/example/notesapp" \
    "$fixture_root/direct-retrofit/com/example/notesapp"

cat > "$fixture_root/actual-architecture/com/example/notesapp/data/BadState.kt" <<'KOTLIN'
package com.example.notesapp.data

class BadState(private val state: UiState)
KOTLIN
expect_failure "data layer must not reference UI state types" \
  bash "$ARCHITECTURE_CHECKER" --all "$fixture_root/actual-architecture/com/example/notesapp"

cat > "$fixture_root/actual-architecture/com/example/notesapp/domain/BadPlatform.kt" <<'KOTLIN'
package com.example.notesapp.domain

import android.content.Context

class BadPlatform
KOTLIN
expect_failure "domain layer must not import Android framework classes" \
  bash "$ARCHITECTURE_CHECKER" --all "$fixture_root/actual-architecture/com/example/notesapp"

actual_assertions="$fixture_root/actual-assertions"
mkdir -p "$actual_assertions"
cat > "$actual_assertions/RendererTest.kt" <<'KOTLIN'
fun renderingTest() {
    val svg = renderer.render()
    assertTrue(svg.contains("<svg"))
    assertTrue(svg.contains("</svg>"))
}
KOTLIN
expect_failure "envelope-only assertions" \
  bash "$ASSERTIONS_CHECKER" "$actual_assertions"

# Registered design-system components: a wrapped Material primitive may only be called by its wrapper.
registry_project="$fixture_root/registry-project"
registry_src="$registry_project/app/src/main/java/com/example/notesapp/ui"
mkdir -p "$registry_src/components" "$registry_src/home" "$registry_project/docs/product"
# The dynamic test-tag rule is out of scope here; reuse the project registry.
export DOCUMENTED_DYNAMIC_TAGS_REGISTRY="$REPO_ROOT/docs/harness/documented-dynamic-test-tags.json"
cat > "$registry_project/docs/product/design_system.md" <<'MD'
# Design System

### Component Registry

| Component | Pen component | Composable | Required testTag | Wraps Material |
|---|---|---|---|---|
| TopActionBar | comp/top-bar | ui/components/TopActionBar.kt | top_action_bar | TopAppBar, CenterAlignedTopAppBar |
MD
cat > "$registry_src/components/TopActionBar.kt" <<'KOTLIN'
package com.example.notesapp.ui.components

@Composable
fun TopActionBar(title: String) {
    TopAppBar(title = { Text(title) }, modifier = Modifier.testTag("top_action_bar"))
}
KOTLIN
cat > "$registry_src/home/HomeScreen.kt" <<'KOTLIN'
package com.example.notesapp.ui.home

@Composable
fun HomeScreen() {
    TopActionBar(title = stringResource(R.string.home))
}
KOTLIN
expect_pass "screens that reuse the registered wrapper" \
  bash "$COMPOSE_CHECKER" --project-root "$registry_project" --all "$registry_src"
cat > "$registry_src/home/SettingsScreen.kt" <<'KOTLIN'
package com.example.notesapp.ui.home

@Composable
fun SettingsScreen() {
    CenterAlignedTopAppBar(title = { Text(stringResource(R.string.settings)) }, modifier = Modifier.testTag("settings_bar"))
}
KOTLIN
expect_failure "CenterAlignedTopAppBar has a registered design-system wrapper; use TopActionBar" \
  bash "$COMPOSE_CHECKER" --project-root "$registry_project" --all "$registry_src"

unset DOCUMENTED_DYNAMIC_TAGS_REGISTRY
echo "PASS: Kotlin AST checker ignores rule-shaped comments/literals and rejects actual violations."
