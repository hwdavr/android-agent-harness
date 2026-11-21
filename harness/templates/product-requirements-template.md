# Product Requirements Template

A new capability file is created by `harness/scripts/archive-change.py` from the change's
`specs/<capability>.md` delta (title and `**User goal**:` line), in the format defined by
[`capability-spec-template.md`](capability-spec-template.md). Do not hand-write a capability file
for planned behavior: the living file states delivered behavior only.

Lifecycle remains in `docs/product/product.md`; add the new capability to that index after archiving.
