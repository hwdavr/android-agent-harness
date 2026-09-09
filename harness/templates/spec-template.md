# Spec Adhoc — <Feature Name>

Use this template when producing `spec_v<N>.md` in the **Requirement, Impact & Design Analysis** stage for adhoc workflows.

**Date**: YYYY-MM-DD
**Status**: Draft / Final

---

## Requirement Summary
<description>

## Rule Applicability

Complete every row before approval. Use `Required`, `Not applicable — <feature-specific reason>`, or `Exception — approved by <user/date>`, and preserve this matrix in the implementation and review artifacts.

| Rule ID | Rule document | Decision | Feature-specific evidence or reason |
|---|---|---|---|
| ARCH | `android-architecture.md` | <decision> | |
| IMPL | `implementation-rules.md` | <decision> | |
| TEST | `testing-strategy.md` | <decision> | |
| SUI | `compose-rules.md` | <decision> | |
| L10N | `localization-rules.md` | <decision> | |
| NAV | `navigation-rules.md` | <decision> | |
| API | `api-contract-rules.md` | <decision> | |
| OBS | `observability.md` | <decision> | |
| ANL | `analytics-rules.md` | <decision> | |

### Android Security Boundary (cross-cutting, outside the nine rows)

Record `Android security: Required` when the feature touches authentication,
sensitive storage, URI/IPC, exported components, networking/TLS, WebView, AI/model,
SDK, or release-security boundaries, and name the planned boundary evidence. Otherwise
record `Android security: Not applicable — no Android security boundary is changed`.
Load `.agents/rules/android-security.md` when this decision is `Required`.

## Functional Requirements

- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

---

## Success Criteria *(mandatory)*

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]

---

## Edge Cases

- What happens when [boundary condition]?
- How does system handle [error scenario]?

---

## Explicit Assumptions
1. <assumption>

---

## Open Questions
- <question>
