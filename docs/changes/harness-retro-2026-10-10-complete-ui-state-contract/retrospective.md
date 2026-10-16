# Retrospective — Complete UI State Contract

**Date**: 2026-10-10  
**Classification**: WORKFLOW_GAP  
**Scope**: Harness workflow, UI contract template, validator, and regression fixture. No application source changed.

## Incident

The requirement-analysis gate reported four mapped UI states even though each mapped image was a short control-region export. The contract called those images states, but neither the reusable schema nor the validator required a full viewport, primary content, state-specific controls, or persistent controls.

## Generic Invariant

Each UI contract state must reference a complete screen viewport export that visibly includes primary content, all state-specific controls, and persistent interactive surfaces. A component crop cannot satisfy a state reference.

## Root Cause

The workflow described state mapping at a high level but the template and validator only checked one-to-one state, source, image, fixture, and plan identifiers. A small PNG could therefore pass as a visual state for any application.

## Repair

- Updated the generic feature-delivery and UI-design workflows to require complete-state coverage without naming any product screen or control type.
- Updated the reusable UI-contract template with explicit viewport, required-region, state-control, and screen-frame fields.
- Updated `check-ui-contract.py` to verify a top-level screen-frame role for Pen states, a non-cropped viewport declaration, image dimensions/aspect ratio, required visible-region categories, and named state controls.
- Added a regression fixture that creates a valid-sized full-screen PNG, replaces it with a short crop, and expects the validator to reject the design-image aspect ratio.

## Verification

- `bash harness/scripts/tests/ui-contract-contract-test.sh` — passes and rejects absent, cropped, duplicate, missing-asset, and unmapped cases.
- `PYTHONPYCACHEPREFIX=/private/tmp/ui-contract-pycache python3 -m py_compile harness/scripts/check-ui-contract.py` — passes.
- `git diff --check` — passes after the harness change.
- The consuming feature contract now maps four complete state frames with a 430×932 viewport and renders them as 860×1864 exports.

## Remaining Risk

The schema verifies declared coverage and non-cropped exports; it cannot determine semantic correctness from pixels alone. The workflow retains visual review of all named state anchors as the final control.
