# Keep UX iteration out of requirements artifacts

When requirements clarification also generates visual designs, every layout revision can restart
analysis, re-version the spec, and rewrite the delivery summary. This makes visual approval hard
to distinguish from requirements or implementation approval.

Feature delivery and harness planning use separate requirements, UX Design, and planning stages.
Requirements gates validate behavior, scope, Rule Applicability, and the required state inventory.
The pre-design UI-contract gate validates state behavior and keyboard coverage before any Pen assets exist. Full UX gates validate the completed Pen references and derived runtime target.
Downstream planning still requires those UX artifacts for UI scope.

Create UI_contract.md first, validate its inventory with only the four design-reference fields
marked Pending, then generate Pen frames from those rows. Complete the node/export mappings and
run the full UX gate before approval or planning. The Pen file contains the actual visual design;
do not add a parallel design.md. Complex runtime target metadata mirrors the contract's state IDs,
viewports, and image paths.

During visual iteration, update the UI contract/derived visual-target manifest, Pen candidates,
and review exports. Return to requirements only when behavior, scope, data, navigation, or the
required state inventory changes. Update summary evidence at stage completion, approval, or a
blocker. Design approval and implementation approval remain distinct.

Regression: `python3 harness/scripts/tests/ux-design-stage-contract-test.py`.
