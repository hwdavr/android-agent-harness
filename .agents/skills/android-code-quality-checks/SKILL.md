---
name: android-code-quality-checks
description: Applies a comprehensive suite of Android code quality checks including Ktlint, Detekt, and Android Lint. Use this skill to ensure code adherence to style guides, static analysis rules, and Android best practices.
---

# Android Code Quality Checks

## Overview

This skill provides a unified workflow for running and resolving issues from the three primary static analysis tools used in this project:
1. **Ktlint**: Enforces Kotlin style and formatting.
2. **Detekt**: Performs static code analysis for Kotlin (complexity, smells, etc.).
3. **Android Lint**: Identifies Android-specific issues (performance, security, usability, API compatibility).

## When to Use

- Before submitting any code change.
- When the build fails due to quality gates.
- During code reviews to automate standard checks.
- After significant refactoring.

## Tooling & Commands

### 1. Ktlint (Formatting & Style)

Ktlint ensures code follows the official Kotlin style guide.

- **Check**: `./gradlew ktlintCheck`
- **Auto-fix**: `./gradlew ktlintFormat`

**Common Issues:**
- Missing newlines at end of file.
- Incorrect indentation.
- Wildcard imports (not allowed).
- Unused imports.

### 2. Detekt (Static Analysis)

Detekt finds code smells, complexity issues, and potential bugs.

- **Check**: `./gradlew detekt`

**Common Issues:**
- `LongMethod` / `TooManyFunctions`: Consider refactoring into smaller components.
- `SwallowedException`: Ensure exceptions are logged or handled (or named `ignored`).
- `MagicNumber`: Use named constants instead of raw numbers.
- `MatchingDeclarationName`: File name must match the primary class/object name.

### 3. Android Lint (Android Best Practices)

Android Lint checks for Android-specific problems.

- **Check**: `./gradlew lintDebug` (or `lintRelease`)

**Common Issues:**
- `NewApi`: Using APIs newer than `minSdk` without checks (fix with desugaring or version checks).
- `OldTargetApi`: Target SDK should be updated to the latest version.
- `UnusedResources`: Strings, drawables, or layouts that are no longer used.
- `ModifierParameter`: In Compose, `modifier` should be the first optional parameter.
- `RememberReturnType`: `remember` calls must not return `Unit`.

## Workflow for Resolving Violations

1. **Run All Checks**: Start by running all tools to get a full picture of the debt.
   ```bash
   ./gradlew ktlintCheck detekt lintDebug
   bash harness/scripts/check-compose-rules.sh
   bash harness/scripts/check-localization-rules.sh
   bash harness/scripts/check-architecture-rules.sh
   ```

   On Windows (using PowerShell or Command Prompt), run the native script launchers instead:
   ```powershell
   harness\scripts\check-compose-rules.cmd
   harness\scripts\check-localization-rules.cmd
   harness\scripts\check-architecture-rules.cmd
   ```

2. **Fix Formatting First**: Run `ktlintFormat` to handle low-hanging fruit.
   ```bash
   ./gradlew ktlintFormat
   ```

3. **Address Detekt Smells**: Open the reports (usually in `app/build/reports/detekt/`) and fix high-priority smells. Surgical changes are preferred over large refactors unless necessary.

4. **Resolve Lint Errors**: 
   - Errors will block the build (`abortOnError = true`).
   - Prioritize `NewApi`, `RememberReturnType`, and `ModifierParameter` issues.
   - Use Core Library Desugaring for modern Java APIs on older devices.

5. **Cleanup Resources**: 
   - Remove `UnusedResources` identified by Lint to keep the APK small.
   - Fix `TypographyEllipsis` and other resource-level warnings.

## Best Practices

- **Don't ignore, fix**: Only use `@Suppress` or `tools:ignore` as a last resort when the tool is producing a false positive.
- **Incremental Improvement**: If a file has many violations, fix the ones you touched first, then consider a follow-up task for the rest.
- **Configuration**: If a rule is consistently producing false positives across the project, update `detekt.yml` or the lint configuration instead of suppressing individually.

## Verification

The task is complete when:
- [ ] `./gradlew ktlintCheck` passes.
- [ ] `./gradlew detekt` passes.
- [ ] `./gradlew lintDebug` passes (0 errors).
- [ ] `bash harness/scripts/check-compose-rules.sh` or `harness\scripts\check-compose-rules.cmd` passes (0 violations).
- [ ] `bash harness/scripts/check-localization-rules.sh` or `harness\scripts\check-localization-rules.cmd` passes (0 violations).
- [ ] `bash harness/scripts/check-architecture-rules.sh` or `harness\scripts\check-architecture-rules.cmd` passes (0 violations).
