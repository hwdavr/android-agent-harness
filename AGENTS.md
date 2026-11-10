# AGENTS.md
This is the root context file. Read this first, then navigate to the relevant workflow. This file is an Index & Map — not an encyclopedia. Keep it under 120 lines.
## Project
Kotlin + Jetpack Compose + Room Android notes app. Treat it as a production product, not a demo.

**Tech stack**: Kotlin · Jetpack Compose · Material 3 · Navigation Compose · Room · Hilt · KSP · Java/Kotlin 17 · minSdk 24 / targetSdk 34
**Module structure**:
- `app/` — Android application module
- `UX/` — design assets
- `sharedContracts/` — OpenAPI contract + shared test scenarios
## Context Loading — L1 / L2 / L3
Load context in layers; more is not better.
| Layer | When | What to load |
|-------|------|-------------|
| **L1 — Always** | Every session | This file + `.agents/rules/android-architecture.md` + `.agents/rules/testing-strategy.md` |
| **L2 — Phase-triggered** | Per stage | The current stage's skill(s) plus `harness/templates/rule-applicability-template.md` for requirements/planning/review. Load `implementation-rules.md` only during Implementation. Load a conditional rule only if Required, excepted, or diff-triggered. Load `android-security.md` for `SEC` or a security/AI/WebView/network/manifest boundary; load `testing-practices.md` during test authoring/review, `testing-runtime-evidence.md` for UI/navigation/visual/platform/runtime claims, and `docs/product/design_system.md` for UI work. |
| **L3 — On-demand** | When needed | `docs/knowledge/` docs, `sharedContracts/openapi.yaml`, and feature-specific evidence or rule detail newly triggered by the approved Rule Applicability matrix |

Do not preload unrelated skills or conditional rules. Requirements, planning, and review use the trigger catalog and load only Required, excepted, or diff-triggered rules. For a sliced-lane slice, run
`bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"` after selection. Its output is disposable and must be regenerated when either source hash changes.
---
## Harness Structure
| Folder | Purpose |
|--------|---------|
| `.agents/workflows/` | **Start here.** Pick the workflow that matches the task. |
| `.agents/rules/` | Mandatory constraints (L1 core + L3 on-demand). |
| `.agents/skills/` | How-to guides and modular workflow steps (L2). |
| `.agents/gates/` | CI checks and review/release checklists. |
| `harness/templates/` | Standard output formats for plans, reviews, tests. |
| `harness/scripts/` | Validation scripts and contract test runners. |
| `.scratch/<YYYY-MM-DD>-<feature-id>/` | One dated workspace per feature or bug fix: plans, summaries, design, and evidence. |
| `docs/product/requirements/` | One living file per capability; a change's specification is its feature block under `## Planned changes`. |
| `docs/knowledge/` | Past bugs, pitfalls, architecture decisions (L3). |
| `docs/changes/` | Audit trail — one directory per delivered change. |
| `docs/product/product.md` | Product capabilities, roadmap, and the authoritative Harness Feature Tracker. |
## Agent Roles
Planner: requirements, architecture, design, acceptance, and slices. Implementer: approved Kotlin/Compose/Room changes and findings.
Tester: test authorship, bug reproduction, verification, and evidence. Evaluator: independent code, test, evidence, and quality review.
Codex uses `.codex/agents/`; other clients use equivalent roles. Workflows own assignment, stages, approvals, and gates.
## Workflow Routing — Mandatory Step Before Any Task
**Before starting ANY task, you MUST:** identify the task type, then read the matching workflow **in full** and follow its pipeline without skipping stages or stops. Do not write code before reading the selected workflow and its current-stage skill.

| Task type | Read this file first |
|-----------|----------------------|
| New feature or enhancement, any size (Specify selects the single or sliced lane) | `.agents/workflows/harness-planning.md` |
| Bug, crash, regression, or unexpected behavior | `.agents/workflows/bug-fixing.md` |
| Appearance-only tweak an approved design or the design system already defines | `.agents/skills/android-ui-layer/SKILL.md` (direct lane; entry check + conformance review) |
| Implement an approved single-lane feature | `.agents/workflows/single-lane-generator.md` |
| Next slice of an approved sliced-lane feature | `.agents/workflows/sliced-lane-generator.md` |
| Sliced-lane evaluator findings (`To be fixed`) | `.agents/workflows/harness-fix.md` |
| Independent review: single lane / sliced-lane slice | `.agents/workflows/feature-review.md` / `.agents/workflows/harness-evaluation.md` |
| Plan, approve, and execute post-merge feature acceptance | `.agents/workflows/feature-acceptance.md` (invokes `exploratory-qa` after approval) |
| UI-only mobile exploration | `.agents/skills/dogfood/SKILL.md` |
| APK QA with scenario reports or network capture/mocks | `.agents/skills/exploratory-qa/SKILL.md` (reuses `dogfood`) |
| Harness documentation, rule, gate, or evidence repairs | `.agents/skills/harness-retrospective/SKILL.md` |
| App-side analytics event contracts | `.agents/skills/analytics-event-validator/SKILL.md` (standalone; optional in `exploratory-qa`) |
| Controlled REST/GraphQL backend responses during mobile QA | `.agents/skills/api-mocking/SKILL.md` (shared WireMock adapter; optional in QA and analytics) |

## Skills Index
Key skills under `.agents/skills/`:
- **Planning & Requirements**: `spec-driven-development`, `feature-specification` (Specify + Clarify), `implementation-plan` (Plan + Tasks + Analyze)
- **UX & Design**: `ux-design`
- **Implementation**: `android-implementation`, `android-ui-layer`, `api-contract-update`
- **Testing & Verification**: `android-testing`, `ui-verification`, `android-unit-test`, `shared-json-scenarios`, `dogfood`, `exploratory-qa`, `analytics-event-validator`, `api-mocking`
- **Review & Quality**: `code-quality-fix`, `android-code-review`, `code-review-and-quality`, `android-test-review`, `android-code-quality-checks`
- **Session & Knowledge**: `context-management`, `knowledge-capture`, `documentation-and-adrs`, `karpathy-guidelines`

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
- **Implementation authorization must be approved by the user before code is written** — every lane requires the approved `implementation-plan.md` and `test-plan.md` (block SHA-256 recorded); the sliced lane adds `tasks.md` and `feature_list.json`, and `sliced-lane-generator` must not generate a duplicate plan
- **Direct UI lane is appearance-only** — `android-ui-layer` may change an existing screen's appearance without a plan only when it passes the skill's entry check (no new state, interaction, navigation, data, or API; target defined by an approved design or the design system) and ends with the `ui-verification` conformance review; anything else uses `harness-planning` (or `bug-fixing` for a defect)
- **UI appearance is approved by a conformance review, never a screenshot golden** — review captures at the Pen frame size, structural checks, registered design-system components, and user approval
- **Every stage gate must pass before advancing** — do not skip gates
- **Every stage skill must be invoked through the available skill mechanism** — use the Skill tool when it is exposed. If this environment does not expose it, read the repository's matching `SKILL.md`, follow its workflow, and record the unavailable invocation interface in the stage evidence. An unavailable interface never permits skipping an executable stage gate or verification command named by the skill.
- **Every implementation plan contains the complete Rule Applicability matrix** (`harness/templates/rule-applicability-template.md`) — use `Required`, `Not applicable — <feature-specific reason>`, or `Exception — approved by <user/date>` for all ten rules. The approved `implementation-plan.md` is canonical: `test-plan.md` links its `#rule-applicability` anchor and maps only `Required` rows to evidence; reviews independently reconcile all ten decisions rather than copy them.
- **Memory of prior approval does not bypass workflow stages** — source of truth is on disk: the approved feature block in `docs/product/requirements/` and the dated `.scratch/` workspace (`docs/current/` is retired). Re-run the owning stage for missing artifacts.
- **Validate harness lifecycle state** — run `bash harness/scripts/check-feature-lifecycle.sh` before selecting tracked work and after every tracker transition. Folder location never represents status; the tracker and per-slice evidence do.
- **Stage completion requires evidence** — when marking a stage complete in the workspace `summary.md` (or slice summary), cite the artifact path and paste a one-line excerpt. A stage is not complete until the artifact exists on disk and is referenced from the summary. Summaries reference canonical scope and Rule Applicability artifacts; they do not duplicate their matrices, acceptance criteria, or slice metadata.
- **Do not suppress rule violations** — agents must fix root causes, not add `@Suppress`, `@SuppressLint`, `tools:ignore`, ktlint/detekt disable comments, baselines, or broader excludes unless the user explicitly approves a documented false positive
- **Instruction-file changes require approval** — before editing `.agents/rules/`, `.agents/workflows/`, or `.agents/skills/`, present the exact file list and proposed changes and get explicit user approval. Approval applies only to listed files; ask again if scope changes.
- **Fix rule/workflow/skill mismatches through a PR** — if an agent finds conflicting, stale, or mismatched instructions across rules, workflows, skills, gates, or templates, it must state the issue and why the fix is needed, then raise a PR that corrects the source instruction instead of silently working around it
- **Product documentation flow** — follow `.agents/rules/product-documentation.md`; the feature block in `docs/product/requirements/<capability>.md` is the specification; plans and evidence stay in `.scratch/`.
- **Keep `docs/product/product.md` current** — maintain the capability index and the sole lifecycle tracker for every feature and bug fix. Detailed current and planned behavior lives in the existing capability requirement files, not repeated overview sections.

---
## Build Commands — run from project root
```bash
bash harness/scripts/check-full-source-rules.sh # repository-wide source rules
./gradlew assembleDebug              # build check
./gradlew testDebugUnitTest          # unit + integration tests
./gradlew :app:koverXmlReportDebug   # machine-readable coverage report
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
./gradlew ktlintCheck                # formatting
./gradlew detekt                     # static analysis
ANDROID_SERIAL=<device> bash harness/scripts/run-android-instrumented-tests.sh --all # Android instrumented tests
```

## Distribution Commands
Package and distribute to Firebase App Distribution: `./gradlew appDistributionUploadDebug` (Debug, v1.0-Debug) or `./gradlew appDistributionUploadRelease` (Release, v1.0-Release), both to MyAccounts.

## When you find a bug in the harness itself
Fix it immediately — update the relevant stage/rule/gate to prevent recurrence, and document in `docs/knowledge/pitfalls/` if it could affect future changes.
