# AGENTS.md
Read this index first, then load the relevant workflow. Keep it under 120 lines.
## Project
Android notes app; treat it as a production product, not a demo.

**Tech stack**: Kotlin · Jetpack Compose · Material 3 · Navigation Compose · Room · Hilt · KSP · Java/Kotlin 17 · minSdk 24 / targetSdk 34
**Modules**: `app/` (Android app), `UX/` (design assets), `sharedContracts/` (OpenAPI contract + shared test scenarios)
## Context Loading — L1 / L2 / L3
Load context in layers; more is not better.
| Layer | When | What to load |
|-------|------|-------------|
| **L1 — Always** | Every session | This file + `.agents/rules/android-architecture.md` + `.agents/rules/testing-strategy.md` |
| **L2 — Phase-triggered** | Per stage | Stage skill(s); Rule Applicability template for requirements/planning/review; `implementation-rules.md` during Implementation. Load conditional rules only when Required, excepted, or diff-triggered: `android-security.md` for SEC/security/AI/WebView/network/manifest; `testing-practices.md` for tests/review; `testing-runtime-evidence.md` for UI/navigation/visual/platform/runtime claims; design system for UI. |
| **L3 — On-demand** | When needed | `docs/knowledge/`, `sharedContracts/openapi.yaml`, feature evidence, and newly triggered rule details |

Load no unrelated context. Reconcile all ten triggers in requirements/planning/review; implementation follows approved decisions plus new triggers. For sliced-lane slices, run
`bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"` after selection; regenerate this disposable index when inputs change.
---
## Harness Structure
| Folder | Purpose |
|--------|---------|
| `.agents/workflows/` | **Start here.** Task workflows. |
| `.agents/rules/` | Mandatory constraints (L1 + on-demand). |
| `.agents/skills/` | Stage guides (L2). |
| `.agents/gates/` | CI and review/release checklists. |
| `harness/templates/` | Output formats for plans, reviews, tests. |
| `harness/scripts/` | Validation and contract-test scripts. |
| `.scratch/<YYYY-MM-DD>-<feature-id>/` | Dated workspace per feature/bug fix: plans, summary, design, evidence. |
| `docs/product/requirements/` | One file per capability; a change's spec is its `## Planned changes` feature block. |
| `docs/knowledge/` | Past bugs, pitfalls, architecture decisions (L3). |
| `docs/changes/` | Audit trail — one directory per delivered change. |
| `docs/product/product.md` | Capabilities, roadmap, and the authoritative Harness Feature Tracker. |
## Agent Roles
Planner, Implementer, Tester, Evaluator; workflows own assignment, stages, approvals, and gates.
Codex uses role profiles in `.codex/agents/`; other clients use equivalent roles.
Claude Code: `.claude/agents/`.
## Workflow Routing — Mandatory Step Before Any Task
Before any task, identify its type, read the matching workflow or direct skill **in full**, and follow every stage before writing code.

| Task type | Read this file first |
|-----------|----------------------|
| New feature or enhancement, any size (Specify picks the lane) | `.agents/workflows/harness-planning.md` |
| Bug, crash, regression, or unexpected behavior | `.agents/workflows/bug-fixing.md` |
| Appearance-only tweak an approved design or the design system already defines | `.agents/skills/android-ui-layer/SKILL.md` (direct lane) |
| Implement an approved single-lane feature | `.agents/workflows/single-lane-generator.md` |
| Next slice of an approved sliced-lane feature | `.agents/workflows/sliced-lane-generator.md` |
| Sliced-lane evaluator findings (`To be fixed`) | `.agents/workflows/harness-fix.md` |
| Independent review: single lane / sliced lane | `.agents/workflows/feature-review.md` / `.agents/workflows/harness-evaluation.md` |
| Plan, approve, and execute feature acceptance | `.agents/workflows/feature-acceptance.md` (then `exploratory-qa`) |
| UI-only mobile exploration | `.agents/skills/dogfood/SKILL.md` |
| APK QA with scenario reports or network capture/mocks | `.agents/skills/exploratory-qa/SKILL.md` (reuses `dogfood`) |
| Harness documentation, rule, gate, or evidence changes | `.agents/skills/harness-retrospective/SKILL.md` |
| App-side analytics event contracts | `.agents/skills/analytics-event-validator/SKILL.md` (optional in `exploratory-qa`) |
| Controlled REST/GraphQL responses during mobile QA | `.agents/skills/api-mocking/SKILL.md` (WireMock; optional in QA/analytics) |

## Skills Index (`.agents/skills/`)
- **Planning & Requirements**: `spec-driven-development`, `feature-specification`, `implementation-plan`
- **UX & Design**: `ux-design`
- **Implementation**: `android-implementation`, `android-ui-layer`, `api-contract-update`
- **Testing & Verification**: `android-testing`, `ui-verification`, `android-unit-test`, `shared-json-scenarios`
- **Review & Quality**: `code-quality-fix`, `android-code-review`, `code-review-and-quality`, `android-test-review`, `android-code-quality-checks`
- **Session & Knowledge**: `context-management`, `knowledge-capture`, `documentation-and-adrs`, `karpathy-guidelines`

## Non-negotiable Rules
- **No secrets in source code** — use `local.properties` + `BuildConfig`
- **No business logic in Composables**
- **No DTOs outside the data layer**
- **No hardcoded strings** — always `stringResource()`
- **All UI work follows `docs/product/design_system.md`** — feature designs override it only with an explicit user-approved exception
- **All interactive elements must have `testTag`**
- **Every new feature must have tests**
- **Platform-bound features** require a capability matrix and real instrumented boundary test; fake/JVM evidence is supplemental. Missing runtimes/devices/models/locales/permissions/services fail loudly, never PASS.
- **No dummy production code** — every function/branch/callback implements its requirement. No TODO/stubs/no-op handlers; follow `.agents/rules/implementation-rules.md`.
- **User approval before implementation** — approved `implementation-plan.md` + `test-plan.md` (feature-block SHA-256 recorded); sliced lane adds `tasks.md` + `feature_list.json`; `sliced-lane-generator` never re-plans.
- **Direct UI lane is appearance-only** — `android-ui-layer` must pass its entry check (no new state/interaction/navigation/data/API) and end with a `ui-verification` conformance review; else `harness-planning` or `bug-fixing`.
- **UI appearance is approved by conformance review, never a screenshot golden** — Pen-frame captures, structure checks, registered components, user approval.
- **Pass every stage gate before advancing**
- **Invoke every stage skill through the available skill mechanism** (the Skill tool when exposed); otherwise read the full repository `SKILL.md`, follow it, and record the missing interface in stage evidence. Executable gates stay mandatory.
- **Every implementation plan has all ten Rule Applicability rows** (`harness/templates/rule-applicability-template.md`): `Required`, `Not applicable — <feature-specific reason>`, or `Exception — approved by <user/date>`. The approved `implementation-plan.md` is canonical; `test-plan.md` links its `#rule-applicability` and maps Required rows to evidence. Reviews reconcile all ten.
- **Approval evidence lives on disk**, never memory: the approved feature block in `docs/product/requirements/` and the dated `.scratch/` workspace (`docs/current/` is retired). Re-run the owning stage for missing artifacts.
- **Validate lifecycle state** — run `bash harness/scripts/check-feature-lifecycle.sh` before selecting tracked work and after each tracker transition. Status lives in the tracker and per-slice evidence, never folder location.
- **Stage completion requires evidence** — `summary.md` (or slice summary) cites an existing artifact path and one-line excerpt per completed stage. Link canonical scope/Rule Applicability; do not duplicate matrices, acceptance criteria, or slice metadata.
- **Fix root causes; no suppressions** (`@Suppress`, `@SuppressLint`, `tools:ignore`, ktlint/detekt disables, baselines, broader excludes) without explicit user approval of a documented false positive.
- **Instruction-file changes require approval** — before editing `.agents/rules/`, `.agents/workflows/`, or `.agents/skills/`, present the exact file list and proposed changes and get explicit user approval. Approval applies only to listed files; ask again if scope changes.
- **Fix instruction mismatches through a PR** — state conflicts/staleness across rules/workflows/skills/gates/templates and why repair is needed; raise a PR correcting the authoritative source. Fix harness bugs immediately; log recurring risks in `docs/knowledge/pitfalls/`.
- **Product docs** — follow `.agents/rules/product-documentation.md`: the requirements feature block is the spec, plans/evidence stay in `.scratch/`, and keep `docs/product/product.md` current as the capability index and sole lifecycle tracker.

---
## Build Commands — run from project root
```bash
bash harness/scripts/check-full-source-rules.sh # source rules
./gradlew assembleDebug # build check
./gradlew testDebugUnitTest # unit + integration tests
./gradlew :app:koverXmlReportDebug # coverage XML
bash harness/scripts/check-coverage.sh app/build/reports/kover/reportDebug.xml
./gradlew ktlintCheck # formatting
./gradlew detekt # static analysis
ANDROID_SERIAL=<device> bash harness/scripts/run-android-instrumented-tests.sh --all # instrumented tests
./gradlew appDistributionUploadDebug # Firebase App Distribution to MyAccounts (v1.0-Debug; Release: appDistributionUploadRelease)
```
