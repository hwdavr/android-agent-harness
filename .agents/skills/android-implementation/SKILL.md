---
name: android-implementation
description: Implement an Android feature across affected data, domain, and UI layers.
---

# Skill — Android Implementation (Data + Domain + UI)

## Purpose
Implement only the layers affected by the approved change, in small verified increments.
Do not load or execute a Data, Domain, or UI section merely because another layer is in scope.

> This is the **compact implementation stage** used by `feature-delivery` and `bug-fixing` workflows.
> For granular layer-by-layer control, use the individual stages `android-data-layer/SKILL.md`, `android-domain-layer/SKILL.md`, and `android-ui-layer/SKILL.md`.

---

## Load

**At a new session, load L1:**
- `rules/android-architecture.md` (skip if already loaded this session — L1 is session-scoped)
- `rules/implementation-rules.md` (skip if already loaded this session)
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read

**Then load only triggered context:**
- `rules/api-contract-rules.md` when API is `Required` or excepted
- `rules/compose-rules.md`, `rules/localization-rules.md`, `docs/product/design_system.md`, `design.md`, and mockups when the slice affects UI
- `rules/navigation-rules.md`, `rules/analytics-rules.md`, and `rules/observability.md` only when their Rule Applicability decision is `Required` or excepted
- `rules/android-security.md` when `SEC` is Required or excepted, or the slice newly triggers authentication, sensitive storage, URI/IPC, exported components, networking/TLS, WebView, AI/model, SDK, or release-security scope

**Adhoc workflows** (`feature-delivery`, `bug-fixing`):
- `docs/current/implementation_plan_v<N>.md` — implementation plan approved by user
- `docs/current/spec_v<N>.md` — requirement summary, impact analysis, UiState & navigation design
- `docs/current/design.md` — screen purpose, layout, visual/interaction states, copy, components inventory (if UI changes involved)
- `docs/current/design/` — user-provided screenshots or AI-generated `mockup_*.png` images (view these for visual layout reference before implementing UI)

**Harness workflow** (`harness-generator`):
- Run `bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"` and use its hashes and source pointers.
- Read only the selected sprint-contract user story, mapped requirement rows, and acceptance rows. Read the selected `feature_list.json` entry for execution flags and verification IDs.
- Read the summary only for execution-stage evidence, blockers, and decisions made after approval; never treat it as a second requirement source.

---

## Execute

Use the approved plan or generated context index to select the affected layers. Skip
unaffected sections and their checklist rows; a skipped layer must be recorded as
`Not applicable — <slice-specific reason>`, never silently treated as completed.

### Layer 1 — Data Layer
1. **API / DTO**: If API changed, update `sharedContracts/openapi.yaml` first. Add/modify DTOs in `data/remote/dto/`. Optional fields use `T?`. Enums must decode with an unknown/fallback case defensively.
2. **Room / Persistence**: Room entity in `data/local/`. Update DAO queries and increment `AppDatabase` version with migration.
3. **Repository**: Implement in Data layer. Explicitly map DTO → Domain model inside repository (**never pass DTOs to upper layers**). Translate API errors to domain errors before leaving this layer. Handle null defensively: `dto.field ?: defaultValue`.

---

### Layer 2 — Domain Layer
1. **Domain Models**: Data classes only. Import **no Android framework classes** (`Context`, `Bundle`, SDK types). Add UNKNOWN/fallback to enums.
2. **Repository Interface**: Define signatures in domain layer with domain models and `suspend` functions / `Flow`. Framework-independent.
3. **Use Cases**: One use case does one thing. Owns business validation, filtering, sorting, and coordination. Never call data sources directly or import UI frameworks.

---

### Layer 3 — UI Layer
1. **ViewModel**: `StateFlow<UiState>` — one per screen. Handle all states: loading, success, empty, error, retry. Call use cases only (**never call repositories or data sources directly**). Emit one-off events via `Channel<Event>`. Add structured logs only when OBS is `Required`.
2. **UI Models & Mappers**: Create UI models and Domain → UI mappers in Presentation layer when formatting is needed.
3. **Composable Screen**: Split into stateless `Content` + stateful `Screen` wrapper. View design mockups before writing UI. All text via `stringResource()` (**no hardcoded strings**). Add `Modifier.testTag("stable_name")` to all interactive elements. Follow `docs/product/design_system.md` semantic tokens. If owning `requires_visual_verification: true`, implement capture per contract.
4. **Navigation, Analytics & Strings**: Update nav graph with serializable args when NAV is `Required`. Fire analytics from ViewModel (not Composables) when ANL is `Required`; otherwise keep `analytics: none`. Add strings to `res/values/strings.xml`.

---

## Output

Update `summary_{feature_id}.md` (or `summary_v<N>.md` depending on the active workflow): mark the Implementation (Data + Domain + UI) stage complete.

---

## Done When

**This stage is complete when every applicable Execute section rule is mechanically verified:**
- [ ] All layer rules from Execute sections above are satisfied (no DTO leaks, no business logic in Views, no dummy code, etc.)
- [ ] Rule Applicability decisions are implemented or retained with their approved rationale
- [ ] Build compiles without errors (full `./gradlew assembleDebug` gate runs at Code Quality Fix)

**APPROVED →** Return to the active workflow file. 
