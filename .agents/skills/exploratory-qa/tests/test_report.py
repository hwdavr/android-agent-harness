import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import report

SCENARIO = {
    'scenario_id': 'report-test',
    'execution': {'mode': 'ephemeral', 'driver': 'agent-device',
                  'regression_targets': [], 'ci_required': False},
    'entry_points': [{'id': 'editor-sticker', 'surface': 'Photo editor tool rail',
                      'action': 'Tap Sticker', 'expected': 'Sticker picker opens',
                      'check_id': 'success_screen'}],
    'expectations': {'ui_checks': ['success_screen'], 'no_unexpected_crash': True,
                     'requests': [{'method': 'POST', 'host': 'qa.example.test', 'path_glob': '/pay',
                                   'min_count': 1, 'max_count': 1, 'allowed_statuses': [200]}]},
}
OK = {'proxy_verified': True, 'ui_checks': {'success_screen': True}, 'unexpected_crashes': 0}
NETWORK = [{'scenario_id': 'report-test', 'method': 'POST', 'host': 'qa.example.test',
            'path': '/pay', 'status': 200, 'transport_error': False}]


class ReportTest(unittest.TestCase):
    def test_missing_execution_intent_cannot_pass(self):
        scenario = copy.deepcopy(SCENARIO)
        scenario.pop('execution')
        self.assertEqual(report.evaluate(scenario, OK, NETWORK)[0], 'INCONCLUSIVE')

    def test_ephemeral_run_cannot_declare_regression_or_ci(self):
        for override in ({'mode': 'regression'}, {'driver': 'AndroidJUnitRunner'},
                         {'regression_targets': ['app/src/androidTest/TemporaryWireMockTest.kt']},
                         {'ci_required': True}):
            with self.subTest(override=override):
                scenario = copy.deepcopy(SCENARIO)
                scenario['execution'].update(override)
                result, checks = report.evaluate(scenario, OK, NETWORK)
                self.assertEqual(result, 'FAIL')
                self.assertTrue(any(c['id'] == 'execution-intent' and c['result'] == 'FAIL' for c in checks))

    def test_pass(self):
        self.assertEqual(report.evaluate(SCENARIO, OK, NETWORK)[0], 'PASS')

    def test_fails_on_duplicate_request(self):
        self.assertEqual(report.evaluate(SCENARIO, OK, NETWORK * 2)[0], 'FAIL')

    def test_unverified_proxy_cannot_assert_absence(self):
        self.assertEqual(report.evaluate(SCENARIO, {**OK, 'proxy_verified': False}, [])[0], 'INCONCLUSIVE')

    def test_does_not_infer_crash_count(self):
        obs = {'proxy_verified': True, 'ui_checks': {'success_screen': True}}
        self.assertEqual(report.evaluate(SCENARIO, obs, NETWORK)[0], 'INCONCLUSIVE')

    def test_ui_failure_is_failure(self):
        self.assertEqual(report.evaluate(SCENARIO, {**OK, 'ui_checks': {'success_screen': False}}, NETWORK)[0], 'FAIL')

    def test_missing_entry_point_inventory_cannot_pass(self):
        scenario = copy.deepcopy(SCENARIO)
        scenario.pop('entry_points')
        result, checks = report.evaluate(scenario, OK, NETWORK)
        self.assertEqual(result, 'INCONCLUSIVE')
        self.assertTrue(any(c['id'] == 'entry-point-inventory' and c['result'] == 'INCONCLUSIVE' for c in checks))

    def test_false_entry_point_observation_fails(self):
        result, checks = report.evaluate(SCENARIO, {**OK, 'ui_checks': {'success_screen': False}}, NETWORK)
        self.assertEqual(result, 'FAIL')
        self.assertTrue(any(c['id'] == 'entry-point:editor-sticker' and c['result'] == 'FAIL' for c in checks))

    def test_unmapped_entry_point_is_inconclusive(self):
        scenario = copy.deepcopy(SCENARIO)
        scenario['entry_points'][0]['check_id'] = 'missing_check'
        result, checks = report.evaluate(scenario, OK, NETWORK)
        self.assertEqual(result, 'INCONCLUSIVE')
        self.assertTrue(any(c['id'] == 'entry-point:editor-sticker' and c['result'] == 'INCONCLUSIVE' for c in checks))

    def test_entry_points_cannot_share_a_check_id(self):
        scenario = copy.deepcopy(SCENARIO)
        scenario['entry_points'].append({'id': 'home-sticker', 'surface': 'Home', 'action': 'Tap Stickers',
                                         'expected': 'Sticker mode opens', 'check_id': 'success_screen'})
        with self.assertRaisesRegex(ValueError, 'route-specific check_id'):
            report.evaluate(scenario, OK, NETWORK)

    def test_no_checks_is_inconclusive(self):
        self.assertEqual(report.evaluate({}, {}, [])[0], 'INCONCLUSIVE')

    def test_sample_ui_network_checks_pass_when_observed(self):
        scenario = json.loads((ROOT / 'examples/scenario.example.json').read_text())
        obs = {'proxy_verified': False, 'unexpected_crashes': 0,
               'ui_checks': {key: True for key in scenario['expectations']['ui_checks']}}
        self.assertEqual(report.evaluate(scenario, obs, [])[0], 'PASS')

    def test_workflow_sample_does_not_preapprove_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            run_dir = Path(directory) / '.qa-artifacts' / 'example'
            run_dir.mkdir(parents=True)
            scenario_path = run_dir / 'scenario.json'
            scenario_path.write_bytes((ROOT / 'examples/scenario.example.json').read_bytes())
            code = report.main(['--run-dir', str(run_dir), '--scenario', str(scenario_path)])
            result = json.loads((run_dir / 'report.json').read_text())
            self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
            self.assertEqual(next(c['result'] for c in result['checks'] if c['id'] == 'entry-point-inventory'), 'PASS')
            self.assertEqual(next(c['result'] for c in result['checks'] if c['id'] == 'entry-point:editor-sticker-tool'), 'INCONCLUSIVE')
            self.assertTrue(all(c['result'] == 'INCONCLUSIVE' for c in result['checks']
                                if c['id'] not in ('entry-point-inventory', 'execution-intent')))
            self.assertTrue(result['generation']['sources'])

    def test_different_run_receipt_cannot_pass(self):
        receipts = [{**NETWORK[0], 'scenario_id': 'another-run'}]
        self.assertNotEqual(report.evaluate(SCENARIO, OK, receipts)[0], 'PASS')

    def mock_case(self):
        scenario = copy.deepcopy(SCENARIO)
        scenario['apiMocks'] = [{'id': 'expected-error', 'status': 500}]
        scenario['expectations']['requests'][0]['allowed_statuses'] = [500]
        receipt = {**NETWORK[0], 'status': 500, 'mocked': True, 'mock_rule_id': 'expected-error',
                   'fixture_sha256': hashlib.sha256(b'fixture').hexdigest(), 'mock_scenario_sha256': 'scenario-hash'}
        return scenario, receipt

    def test_expected_500_and_recovery_ui_can_pass(self):
        scenario, receipt = self.mock_case()
        result, checks = report.evaluate(scenario, OK, [receipt], 'scenario-hash', {'expected-error': receipt['fixture_sha256']})
        self.assertEqual(result, 'PASS')
        self.assertTrue(any(c['id'] == 'mock:expected-error' and c['result'] == 'PASS' for c in checks))

    def test_unused_required_mock_is_inconclusive(self):
        scenario, _ = self.mock_case()
        scenario['expectations']['requests'] = []
        self.assertEqual(report.evaluate(scenario, OK, [])[0], 'INCONCLUSIVE')

    def test_unmatched_mock_is_setup_failure(self):
        scenario, receipt = self.mock_case()
        result, checks = report.evaluate(scenario, OK, [{**receipt, 'unmatched_mock': True}])
        self.assertEqual(result, 'FAIL')
        self.assertTrue(any(c['id'] == 'mock-routing' and c['kind'] == 'setup' for c in checks))

    def test_changed_fixture_or_scenario_cannot_pass(self):
        scenario, receipt = self.mock_case()
        for digest, fixtures in [('changed-scenario', {'expected-error': receipt['fixture_sha256']}),
                                 ('scenario-hash', {'expected-error': 'changed-fixture'})]:
            with self.subTest(digest=digest, fixtures=fixtures):
                self.assertEqual(report.evaluate(scenario, OK, [receipt], digest, fixtures)[0], 'INCONCLUSIVE')

    def test_invalid_observations_fail_clearly(self):
        with self.assertRaises(ValueError):
            report.evaluate(SCENARIO, {'ui_checks': []}, NETWORK)


if __name__ == '__main__':
    unittest.main()
