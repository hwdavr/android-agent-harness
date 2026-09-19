# Review Template

Use this template when producing the review summary in the relevant stage. It is the canonical
detailed checklist; `code-review-and-quality` supplies routing, review order, and evidence rules.

---

## Review Summary

**Feature / Bug**: `<brief description>`  
**Reviewer**: Agent  
**Date**: `<date>`

---

## Review Scope and Evidence Provenance

| Item | Value |
|---|---|
| Current commit | |
| Merge base / prior reviewed commit | |
| Baselines reviewed | `spec`, `sprint contract`, plan, test review |
| Changed production files reviewed | |
| Changed tests reviewed | |
| Independently executed checks | |
| Recorded / up-to-date / skipped checks | |

## Rule Applicability Reconciliation

Read the approved decisions and rationales from the canonical specification, then read
the required-rule evidence mapping from the implementation plan. Independently
reconcile all ten rules against the diff and cite the corresponding check or review
evidence. A triggered `Not applicable` rule or an unapproved exception is **REVISION
REQUIRED**.

| Rule ID | Approved decision / rationale | Trigger observed | Evidence checked | Result |
|---|---|---|---|---|
| ARCH | | | | PASS / REVISION REQUIRED |
| IMPL | | | | PASS / REVISION REQUIRED |
| TEST | | | | PASS / REVISION REQUIRED |
| SUI | | | | PASS / REVISION REQUIRED / N/A |
| L10N | | | | PASS / REVISION REQUIRED / N/A |
| NAV | | | | PASS / REVISION REQUIRED / N/A |
| API | | | | PASS / REVISION REQUIRED / N/A |
| OBS | | | | PASS / REVISION REQUIRED / N/A |
| ANL | | | | PASS / REVISION REQUIRED / N/A |
| SEC | | | | PASS / REVISION REQUIRED / N/A |

## Requirement-to-Production Traceability

List every FR, AC, and documented edge case from the active specification and sprint contract.

| Source ID | Required behavior | Production entry point | Completion / cleanup path | Test evidence | Result |
|---|---|---|---|---|---|
| FR-001 | | | | | PASS / REVISION REQUIRED / N/A |

## State Completion and Reachability Audit

| Changed state, callback, job, or listener | Set / entry point | Production completion or cleanup call site | Test-only substitute found? | Result |
|---|---|---|---|---|
| | | | Yes / No | PASS / REVISION REQUIRED |

Required: flag completion paths called only from tests, stale transition flags, ignored callbacks, placeholder/no-op branches, and final-state rendering that lacks a real production trigger.

---

## Build & Test Results

The source-rule result in this table must come from the full-source bundle. Its
output supplies the per-rule details below; individual checker invocations are
diagnostic follow-ups only.

| Check | Exit code | Timestamp / commit | Provenance | Result | Failure detail / scope |
|-------|---:|---|---|---|---|
| `assembleDebug` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `testDebugUnitTest` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `koverLog` overall | | | Independently executed / Recorded / Up-to-date / Not run | ✅ X% ≥ 80% / ❌ | |
| `koverLog` new classes | | | Independently executed / Recorded / Up-to-date / Not run | ✅ X% ≥ 90% / ❌ | |
| `connectedDebugAndroidTest` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL / ⏭ SKIPPED | |
| `ktlintCheck` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `detekt` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `lintDebug` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | |
| `check-full-source-rules.sh` or `check-full-source-rules.cmd` | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | Includes architecture, Compose, localization, navigation, and test-assertion checks over the complete source tree. |
| Suppression audit | | | Independently executed / Recorded / Up-to-date / Not run | ✅ PASS / ❌ FAIL | Confirm no new suppressions, ignores, baselines, or rule exclusions were added to make checks pass. |

Any non-zero required gate makes the verdict non-approved, even when the source is pre-existing. Record the source and scope above.

---

## Rule Detail Findings

### Architecture *(when the diff triggers ARCH)*

Record only the semantic architectural risks introduced by the diff; structural
violations are proven by the architecture checker and ktlint/detekt evidence above.

- [ ] Business-logic ownership is correct.
- [ ] Layer boundaries and DTO containment hold.
- [ ] State and one-off event design have a clear owner and complete transitions.
- [ ] DTO → Domain and Domain → UI mappings are in their required layers.
- [ ] Dependency-injection scope and lifetime match the changed boundary.

### Implementation and Testing

- [ ] Every changed function, branch, and callback performs the required behavior; no
  placeholder return, `TODO()`, no-op handler, or dummy comment exists.
- [ ] The test layer selected by the plan provides sufficient evidence for the changed
  behavior, and every declared acceptance test row has passing evidence.

---

## Layer Violations

- [ ] None found
- Violations found:
  - `<file>`: `<description of violation>`

---

## Unrelated Changes

- [ ] None found
- Found:
  - `<file>`: `<description>`

---

## UI Verification

- [ ] Skipped (no UI changes)
- [ ] Texts verified against design via `adb uiautomator dump`
- [ ] Screenshot captured and compared
- [ ] Design-critical reference anchors have bounds-based runtime proof tied to visual `testTag`s
- [ ] Differences remaining: `<list or "none">`

---

## Security

- [ ] If an Android security boundary changed, `.agents/rules/android-security.md`
  was loaded and its boundary, validation/failure behavior, and evidence are recorded
  below; the full-source bundle's AI/WebView evaluator and contract passed
- [ ] No secrets or tokens hardcoded
- [ ] No user-generated text, transcript, image content, identifier, or other sensitive content logged
- [ ] Sensitive data not stored unencrypted
- Concerns: `<list or "none">`

---

## Release Risk

**Level**: low / medium / high  
**Reason**: `<explanation>`

- Backward compatible: yes / no
- Feature flag required: yes / no
- Force update required: yes / no
- Backend deployment dependency: yes / no

---

## Remaining Risks

1. `<risk>`
2. `<risk>`

---

## Recommendation

- ✅ Ready to merge
- ⚠️ Merge with noted risks
- ❌ Do not merge — `<blocking issue>`
