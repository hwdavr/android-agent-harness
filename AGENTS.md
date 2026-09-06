# AGENTS.md
This is the root context file. Read this first, then navigate to the relevant workflow. This file is an Index & Map — not an encyclopedia. Keep it under 120 lines.
---
## Project
Kotlin + Jetpack Compose + Room Android notes app. Treat it as a production product, not a demo.

**Tech stack**: Kotlin · Jetpack Compose · Material 3 · Navigation Compose · Room · Hilt · KSP · Java/Kotlin 17 · minSdk 24 / targetSdk 34
**Module structure**:
- `app/` — Android application module
- `UX/` — design assets
- `sharedContracts/` — OpenAPI contract + shared test scenarios
---
## Context Loading — L1 / L2 / L3
Load context in layers to keep the context window below 40% fill. More is not better.
| Layer | When | What to load |
|-------|------|-------------|
| **L1 — Always** | Every session | This file + `.agents/rules/android-architecture.md` + `.agents/rules/implementation-rules.md` + `.agents/rules/testing-strategy.md` |
| **L2 — Phase-triggered** | Per stage | The current stage's skill(s) and, for requirements/planning/review, `harness/templates/rule-applicability-template.md` plus `compose-rules.md`, `localization-rules.md`, `navigation-rules.md`, `api-contract-rules.md`, `observability.md`, and `analytics-rules.md`; for UI work also `docs/product/design_system.md` |
| **L3 — On-demand** | When needed | `docs/knowledge/` docs, `sharedContracts/openapi.yaml`, and feature-specific evidence or rule detail newly triggered by the approved Rule Applicability matrix |

Do not preload unrelated skills. Requirements, planning, and review must load the full
L1/L2 rule contract so every rule is decided and reconciled; implementation loads only
the rules marked required plus any newly triggered rule. For a complex slice, run
`bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"` after selection; its disposable output derives from the approved contract and feature list, is never authority or a summary copy, and must be regenerated when either hash changes.
---
## Harness Structure
| Folder | Purpose |
|--------|---------|
| `.agents/workflows/` | **Start here.** Pick the workflow that matches the task. |
| `.agents/rules/` | Mandatory constraints (L1 core + L3 on-demand). |
| `.agents/skills/` | How-to guides and modular workflow steps (L2). |
| `.agents/gates/` | CI checks and review/release checklists. |
| `harness/templates/` | Standard output formats for plans, reviews, tests. |
| `harness/rules-matrix/` | Visual matrix mapping of rules to files. |
| `harness/scripts/` | Validation scripts and contract test runners. |
| `docs/product/<YYYY-MM-DD>-<feature-short-name>/` | Stable complex-feature workspace for planning, implementation, evidence, and completed records. |
| `docs/knowledge/` | Past bugs, pitfalls, architecture decisions (L3). |
| `docs/changes/` | Audit trail — one directory per delivered change. |
| `docs/product/product.md` | Product capabilities, roadmap, and the authoritative Harness Feature Tracker. |
---
## Agent Roles
| Role | Responsibility | Primary Actions |
|---|---|---|
| **Planner** | Defines requirements & architectural slices | Creates implementation plans & vertical slice checklists |
| **Coder** | Implements robust features & solves tasks | Delivers clean Kotlin/Compose/Room changes incrementally |
| **Evaluator** | Performs automated & manual quality gates | Runs code quality checks, static analysis, & test coverage reviews |
---
## Workflow Routing — Mandatory Step Before Any Task
**Before starting ANY task, you MUST:** identify the task type, read the matching workflow file **in full**, and follow that pipeline without skipping stages or stops. Do not write code before reading the workflow file.

### Ad-hoc Development (Simple Features & Bug Fixing)

| Task type | Read this file first |
|-----------|----------------------|
| Bug, crash, regression, or unexpected behavior | `.agents/workflows/bug-fixing.md` |
| New feature or simple enhancement | `.agents/workflows/feature-delivery.md` |
| UI implementation or update from a mockup | `.agents/workflows/create-ui-and-verify.md` |
| Independent code review before merge | `.agents/workflows/feature-review.md` |

### Project-Based Development (Complex Features)

| Task type | Read this file first |
|-----------|----------------------|
| Clarifying requirements and planning a complex feature into vertical slices | `.agents/workflows/harness-planning.md` |
| Implementing features step-by-step | `.agents/workflows/harness-generator.md` |
| Resolving evaluator findings when a feature scored below 5.0/5 (`To be fixed`) | `.agents/workflows/harness-fix.md` |
| Code and test review of an implemented change | `.agents/workflows/harness-evaluation.md` |

---
## Skills Index
Key skills under `.agents/skills/`:
- **Planning & Requirements**: `spec-driven-development`, `feature-specification`, `slice-planning`, `implementation-plan`
- **UX & Design**: `ux-design`
- **Implementation**: `android-implementation`, `android-data-layer`, `android-domain-layer`, `android-ui-layer`, `api-contract-update`
- **Testing & Verification**: `android-testing`, `ui-verification`, `android-unit-test`, `android-instrumented-ui-test`, `shared-json-scenarios`
- **Review & Quality**: `code-quality-fix`, `android-code-review`, `code-review-and-quality`, `android-test-review`, `android-code-quality-checks`
- **Session & Knowledge**: `context-management`, `knowledge-capture`, `documentation-and-adrs`, `karpathy-guidelines`

---
## Non-negotiable Rules
- **No secrets in source code** — use `local.properties` + `BuildConfig`
- **No business logic in Composables**
- **No DTOs outside the data layer**
- **No hardcoded strings** — always `stringResource()`
- **All UI design, implementation, verification, and review must follow `docs/product/design_system.md`** — feature designs may override it only with an explicit user-approved exception
- **All interactive elements must have `testTag`**
- **Every new feature must have tests**
- **Platform-bound features must include a platform capability matrix and a real instrumented boundary test** — fake/JVM-only tests are supplemental; missing runtimes, devices, models, locales, permissions, or services fail loudly and cannot be recorded as passing evidence
- **No dummy code in production** — every function, branch, and callback must implement the actual requirement logic; no `TODO()`, `NotImplementedError`, stub return values, no-op handlers, or `// dummy implementation` comments. See `.agents/rules/implementation-rules.md`
- **Implementation authorization must be approved by the user before code is written** — ad-hoc workflows require approval of `implementation_plan_v<N>.md`; the complex harness path uses the approved `feature_list.json` and `sprint-contract.md` from `harness-planning` and must not generate a duplicate implementation plan in `harness-generator`
- **Every stage gate must pass before advancing** — do not skip gates
- **Every stage skill must be invoked via the Skill tool** — reading the SKILL.md manually is not a substitute. The workflow's "INVOKE" instruction is a command, not a suggestion
- **Every requirement artifact must contain the complete Rule Applicability matrix** — use `Required`, `Not applicable — <feature-specific reason>`, or `Exception — approved by <user/date>` for all nine rules, and carry the decisions into plans and review evidence
- **Memory of prior approval does not bypass workflow stages** — source of truth is on disk. Ad-hoc workflows use `docs/current/`; every complex harness feature uses one stable dated workspace under `docs/product/`. If a required artifact is missing, re-run the stage via its skill. Require the approved `spec.md`, `design.md` when UI is affected, `feature_list.json`, and `sprint-contract.md` in that workspace.
- **Validate harness lifecycle state** — run `bash harness/scripts/check-feature-lifecycle.sh` before selecting a complex feature and after every tracker transition. Folder location never represents status; the tracker and per-slice evidence do.
- **Stage completion requires evidence** — when marking a stage complete in `summary_v<N>.md`, cite the artifact path and paste a one-line excerpt. A stage is not complete until the artifact exists on disk and is referenced from the summary. Summaries reference canonical scope and Rule Applicability artifacts; they do not duplicate their matrices, acceptance criteria, or slice metadata.
- **Do not suppress rule violations** — agents must fix root causes, not add `@Suppress`, `@SuppressLint`, `tools:ignore`, ktlint/detekt disable comments, baselines, or broader excludes unless the user explicitly approves a documented false positive
- **Fix rule/workflow/skill mismatches through a PR** — if an agent finds conflicting, stale, or mismatched instructions across rules, workflows, skills, gates, or templates, it must state the issue and why the fix is needed, then raise a PR that corrects the source instruction instead of silently working around it
- **Keep `docs/product/product.md` current** — update the Harness Feature Tracker, Current Product Capabilities, Product Portfolio Summary, and roadmap as delivery state changes. It is the product and complex-feature lifecycle source of truth for agents and humans.

---
## Build Commands — run from project root
```bash
./gradlew assembleDebug              # build check
./gradlew testDebugUnitTest          # unit + integration tests
./gradlew :app:koverXmlReportDebug   # machine-readable coverage report
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
./gradlew ktlintCheck                # formatting
./gradlew detekt                     # static analysis
./gradlew connectedDebugAndroidTest  # instrumented UI tests (when UI changed)
```

---
## Distribution Commands
Package and distribute to Firebase App Distribution: `./gradlew appDistributionUploadDebug` (Debug, v1.0-Debug) or `./gradlew appDistributionUploadRelease` (Release, v1.0-Release), both to MyAccounts.

## When you find a bug in the harness itself
Fix it immediately — update the relevant stage/rule/gate to prevent recurrence, and document in `docs/knowledge/pitfalls/` if it could affect future changes.
