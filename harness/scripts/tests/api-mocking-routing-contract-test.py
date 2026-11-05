#!/usr/bin/env python3
"""Prevent stale app snapshots from prescribing a rebuild during installed-app QA."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[3]
GUIDE = ROOT / ".agents/skills/api-mocking/references/routing.md"


def routing_contract_errors(text):
    errors = []
    for stale in (
        "No runtime URL override was found.",
        "has no debug Network Security Configuration",
        "No such app change is implemented here.",
    ):
        if stale in text:
            errors.append(f"stale app-wide assertion: {stale}")
    for required in (
        "## Inspect the installed target first",
        "routing-preflight.md",
        "installed_artifact",
        "routing_control",
        "network_security",
        "app_request_receipt",
        "restore",
        "Do not rebuild or reinstall",
        "debug_api_target_localhost",
        "debug_api_target_production",
    ):
        if required not in text:
            errors.append(f"missing routing instruction: {required}")
    return errors


class ApiMockingRoutingContractTest(unittest.TestCase):
    def test_legacy_snapshot_is_rejected(self):
        legacy = (
            "No runtime URL override was found. The debug manifest has no debug "
            "Network Security Configuration. No such app change is implemented here."
        )
        self.assertTrue(routing_contract_errors(legacy))

    def test_current_guide_preserves_installed_app_and_requires_route_receipt(self):
        self.assertEqual([], routing_contract_errors(GUIDE.read_text()))


if __name__ == "__main__":
    unittest.main()
