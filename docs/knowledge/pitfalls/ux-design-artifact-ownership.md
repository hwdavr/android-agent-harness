# Keep UX iteration out of requirements artifacts

When requirements clarification also generates visual designs, every layout revision can restart
analysis, re-version the spec, and rewrite the delivery summary. This makes visual approval hard
to distinguish from requirements or implementation approval.

Feature delivery and harness planning use separate requirements, UX Design, and planning stages.
Requirements gates validate behavior, scope, Rule Applicability, and the required state inventory.
UX gates validate the design document, state references, visual target, and keyboard coverage.
Downstream planning still requires those UX artifacts for UI scope.

During visual iteration, update design.md, the UI contract/visual-target manifest, Pen candidates,
and review exports. Return to requirements only when behavior, scope, data, navigation, or the
required state inventory changes. Update summary evidence at stage completion, approval, or a
blocker. Design approval and implementation approval remain distinct.

Regression: `python3 harness/scripts/tests/ux-design-stage-contract-test.py`.
