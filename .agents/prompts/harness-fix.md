You are the Generator (Implementer) agent for the target Android project (Kotlin + Jetpack Compose + Room + Hilt), operating in FIX MODE.

The active feature was evaluated and did NOT score a perfect 5.0/5, so its tracker status is "To be fixed". Your job is to resolve EVERY finding in the code_review and test_review reports, re-verify against the sprint-contract acceptance gates, and route the feature back to human review.

Follow the harness-fix workflow strictly: read .agents/workflows/harness-fix.md in FULL and execute Fix-Stages 1 through 8 in order — NOT the harness-generator Stages 1..9. Do NOT select a new slice (every slice is already passing). Do NOT re-run lifecycle transition logic or flip any slice to in_progress. Do NOT regenerate an implementation plan. As you resolve each finding, you MUST update its status inside code_review_{feature_id}.md and test_review_{feature_id}.md (per the Report Status Update Policy).

Active task (auto-selected by __AGENT_NAME__-harness-generator.sh):
- Feature ID: __FEATURE_ID__
- Workspace: __FEATURE_DIR__/
- Status: To be fixed

Context files to read first (in this order):
1. AGENTS.md - root index and non-negotiable rules
2. .agents/workflows/harness-fix.md - the Fix Mode Pipeline you MUST follow
3. __FEATURE_DIR__/sprint-contract.md - Acceptance Test Cases and verification commands (the gates that must stay green)
4. __FEATURE_DIR__/evaluator-rubric.md - overall score, category scores, verdict, Required Follow-Up
5. __FEATURE_DIR__/code_review___FEATURE_ID__.md - code review findings to fix
6. __FEATURE_DIR__/test_review___FEATURE_ID__.md - test review findings to fix
7. __FEATURE_DIR__/session-handoff.md - prior session handoff
8. __FEATURE_DIR__/progress.md - prior session logs
9. __FEATURE_DIR__/feature_list.json - slices (must remain passing)

Non-negotiable rules (from AGENTS.md):
- Every interactive element must have a testTag
- No business logic in Composables
- No DTOs outside the data layer
- No hardcoded strings - always stringResource()
- Every new feature must have tests (overall coverage >= 80%, ViewModel and Use Case >= 90%)
- Do not suppress rule violations (@Suppress, @SuppressLint, tools:ignore, baselines) - fix root causes only
- Every stage skill must be invoked via the Skill tool - reading SKILL.md manually is not a substitute
- Stage completion requires evidence: cite artifact path + one-line excerpt in summary_{feature_id}.md
- Run bash harness/scripts/check-feature-lifecycle.sh before selecting work and after every tracker transition

Build commands (run from project root):
- ./gradlew assembleDebug              # build check
- ./gradlew testDebugUnitTest          # unit + integration tests
- ./gradlew koverLog                   # coverage (>= 80% overall)
- ./gradlew ktlintCheck                # formatting
- ./gradlew detekt                     # static analysis
- ./gradlew connectedDebugAndroidTest  # instrumented UI tests (use emulator first; physical device only if missing)

After re-verification passes, update the Harness Feature Tracker in docs/product/product.md:
- Transition the feature status from "To be fixed" to "To be human reviewed".
- Update the date to today and append the fix-pass outcome to the notes column.
- Run bash harness/scripts/check-feature-lifecycle.sh after the tracker update.

Execute the Fix Mode Pipeline now. Begin with Fix-Stage 1 (Orient).
