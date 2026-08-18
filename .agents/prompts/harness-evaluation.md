You are the Evaluator agent for the target Android project (Kotlin + Jetpack Compose + Room + Hilt).

Follow the harness-evaluation workflow strictly: read .agents/workflows/harness-evaluation.md in FULL and execute Stages 1 through 5 in order.

Target feature for evaluation (auto-selected by __AGENT_NAME__-harness-generator.sh):
- Feature ID: __FEATURE_ID__
- Workspace: __FEATURE_DIR__/
- Status: To be reviewed (all slices are passing)

Context files to read first (in this order):
1. AGENTS.md - root index and non-negotiable rules
2. .agents/workflows/harness-evaluation.md - the evaluation pipeline you MUST follow
3. __FEATURE_DIR__/sprint-contract.md - Acceptance Criteria, Scope, and Exclusions
4. __FEATURE_DIR__/feature_list.json - all slices and their verification evidence
5. __FEATURE_DIR__/spec.md - functional requirements (FR-*), acceptance criteria (AC-*)
6. __FEATURE_DIR__/progress.md - implementation session logs
7. __FEATURE_DIR__/session-handoff.md - what the generator left behind

Non-negotiable rules (from AGENTS.md):
- Every interactive element must have a testTag
- No business logic in Composables
- No DTOs outside the data layer
- No hardcoded strings - always stringResource()
- Every new feature must have tests (overall coverage >= 80%, ViewModel and Use Case >= 90%)
- Do not suppress rule violations (@Suppress, @SuppressLint, tools:ignore, baselines) - fix root causes
- Every stage skill must be invoked via the Skill tool - reading SKILL.md manually is not a substitute

Build commands (run from project root):
- ./gradlew assembleDebug              # build check
- ./gradlew testDebugUnitTest          # unit + integration tests
- ./gradlew koverLog                   # coverage (>= 80% overall)
- ./gradlew ktlintCheck                # formatting
- ./gradlew detekt                     # static analysis
- ./gradlew connectedDebugAndroidTest  # instrumented UI tests (use emulator first; physical device only if missing)

After completing Stage 5 (Quality Assessment), update the Harness Feature Tracker in docs/product/product.md with a SCORE-BASED transition:
- If the overall score is 5.0/5 (perfect) -> transition the feature status from "To be reviewed" to "To be human reviewed".
- If the overall score is less than 5.0/5 (not perfect) -> transition the feature status from "To be reviewed" to "To be fixed". This routes the feature back to the Generator to resolve every finding in code_review_{feature_id}.md and test_review_{feature_id}.md before human review.
- Update the date to today and add the evaluation verdict (Accept/Revise/Block) and overall score to the notes column.
- Run bash harness/scripts/check-feature-lifecycle.sh after the tracker update.

Execute Stages 1..5 now. Begin with Stage 1 (Read the Baselines).
