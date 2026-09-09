# Rule Applicability Template

Copy this section into every requirement artifact. Keep all ten rows. The approved
artifact is the source of truth for planning, implementation, and review.

## Rule Applicability

### Decision vocabulary

- `Required` — the rule applies to this change; plan concrete work and verification.
- `Not applicable — <feature-specific reason>` — the rule's trigger is absent; state
  why rather than deleting the row. When analytics is not required, use
  `Not applicable — analytics: none`.
- `Exception — approved by <user/date>` — only a direct documented user approval may
  override a rule. Cite the approved exception and its boundary.

| Rule ID | Rule document | Default | Decision for this change | Trigger / rationale | Planned evidence |
|---|---|---|---|---|---|
| ARCH | `android-architecture.md` | Always | <decision> | Layers, dependencies, DI, and state ownership. | <plan/review evidence> |
| IMPL | `implementation-rules.md` | Always | <decision> | Real behavior, branches, callbacks, and approved exceptions. | <tests/review evidence> |
| TEST | `testing-strategy.md` | Always | <decision> | Select the required unit, integration, UI, or contract evidence. | <test IDs/commands> |
| SUI | `compose-rules.md` | Conditional | <decision> | Compose UI, state, accessibility, color, or keyboard/input change. | <design/test/review evidence> |
| L10N | `localization-rules.md` | Conditional | <decision> | User-visible copy, dynamic format, plural, or accessibility label. | <resource/checker evidence> |
| NAV | `navigation-rules.md` | Conditional | <decision> | Route, destination, deep link, tab, or back-stack change. | <navigation/test evidence> |
| API | `api-contract-rules.md` | Conditional | <decision> | Endpoint, DTO, schema, error contract, or OpenAPI change. | <contract/integration evidence> |
| OBS | `observability.md` | Conditional | <decision> | Async/network/persistence/error boundary, recovery, or diagnostic logging change. | <logger/review evidence> |
| ANL | `analytics-rules.md` | Conditional | <decision> | Screen impression, user action, funnel, business outcome, or product-approved error event. | <event/review evidence> |
| SEC | `android-security.md` | Conditional | <decision> | Authentication, sensitive storage, URI/IPC, exported components, network/TLS, WebView, AI/model, SDK, or release-security boundary. | <boundary/test/review evidence> |

### Guardrails

- Do not add analytics or logs only to avoid a `Not applicable` decision.
- Any log that is added must use the project's approved structured logger, an
  appropriate level, and no PII, secrets, or user-generated sensitive content.
- A reviewer independently checks the diff for triggers; an unsupported decision is a
  blocking finding.
