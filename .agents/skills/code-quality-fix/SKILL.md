---
name: code-quality-fix
description: Run static analysis, formatting, lint checks, and fix violations.
---

# Skill — Code Quality Fix

## Purpose

Run all static check suites, lint rules, and custom compliance rules. Resolve all violations. Fix root causes — do not suppress rules.

---

## Load

Read the approved Rule Applicability matrix from the active specification or generated
complex-slice context index, then load a conditional rule only when its decision is
`Required` or an approved exception. Do not re-read the matrix from a summary file.

---

## Principles

- Minimum code that solves the problem — nothing speculative.
- Touch only what you must. Don't "improve" adjacent code or formatting.
- Every changed line should trace directly to the user's request.
- Surgical changes over large refactors.

---

## Execute

### 1. Run All Quality Checks
Read the active specification's Rule Applicability matrix first. Run the baseline checks
below and the checks needed for every `Required` row; retain explicit non-applicable
and exception rationales. Do not add analytics or logs merely to change a decision.

Execute the following baseline checks:
```bash
./gradlew assembleDebug
./gradlew ktlintCheck
./gradlew detekt
./gradlew lintDebug
bash harness/scripts/check-full-source-rules.sh
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
```

`check-full-source-rules.sh` is the mandatory bundle — it passes `--all` to
architecture, Compose, and localization AST checkers, scans test roots for assertion
quality, runs navigation checks, and aggregates every result. A non-zero result
blocks the stage, including for pre-existing violations. Do not substitute a
changed-file scan.

Additionally check for dummy code:
```bash
grep -rn "TODO()\|NotImplementedError\|// dummy\|// placeholder\|// stub" app/src/main/ sharedContracts/
```
Must return zero matches.

On Windows (using PowerShell or Command Prompt), run the native script launchers instead:
```powershell
harness\scripts\check-full-source-rules.cmd
```

### 2. Auto-Fix Formatting Issues
To resolve Ktlint style and formatting errors automatically, run:
```bash
./gradlew ktlintFormat
```

### 3. Diagnose and Fix Violations
For any remaining failures or warnings:
- Analyze `detekt` and Android `lint` reports.
- Review Compose, localization, and architectural check outputs.
- Fix root causes, do not suppress rules.

### 4. Record Results
**Update `summary_{feature_id}.md`** (or `summary_v<N>.md`) to mark **Code Quality Fix** ✅ with notes and timestamp once all checks pass with 0 violations.

---

## Done When

- [ ] `./gradlew ktlintCheck` — exit code 0
- [ ] `./gradlew detekt` — exit code 0
- [ ] `./gradlew lintDebug` — exit code 0
- [ ] `bash harness/scripts/check-full-source-rules.sh` or `harness\scripts\check-full-source-rules.cmd` — exit code 0
- [ ] `bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml` — exit code 0
- [ ] No dummy code found
- [ ] Every Rule Applicability decision has required check/review evidence or its approved rationale
- [ ] Summary updated and marked complete

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.
