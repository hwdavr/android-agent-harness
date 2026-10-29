import sys
import os
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
HARNESSLENS_ROOT = Path(os.environ.get('HARNESSLENS_ROOT', '/Users/hwdavr/Projects/2026_harness_environment/HarnessLens'))
sys.path.insert(0, str(HARNESSLENS_ROOT / 'cli'))
import report
from harnesslens.wiremock import Admin, WireMockError


class WireMockReportTest(unittest.TestCase):
    def setUp(self):
        self.run = Path('/unused/.qa-artifacts/run-a')
        self.scenario = {'expectations': {'wiremock': [{'name': 'accounts-empty', 'fixture_sha256': 'a' * 64}]}}
        self.obs = {'wiremock_routing_verified': True}

    def check(self, url='http://127.0.0.1:8080', session='run-a', observations=None):
        return report.evaluate_wiremock(self.scenario, self.obs if observations is None else observations,
                                        self.run, url, session, HARNESSLENS_ROOT)

    def test_no_expectations_keep_existing_workflow_independent(self):
        self.assertEqual(report.evaluate_wiremock({}, {}, self.run), ([], []))

    def test_missing_server_or_wrong_run_cannot_pass(self):
        for url, session in ((None, 'run-a'), ('http://127.0.0.1:8080', 'run-b')):
            with patch.object(Admin, 'verify') as verify:
                self.assertEqual(self.check(url, session)[0][0]['result'], 'INCONCLUSIVE')
                verify.assert_not_called()

    def test_unverified_app_routing_cannot_pass(self):
        with patch.object(Admin, 'verify') as verify:
            self.assertEqual(self.check(observations={})[0][0]['result'], 'INCONCLUSIVE')
            verify.assert_not_called()

    def test_report_uses_live_verification_not_a_supplied_pass_flag(self):
        self.obs['wiremock_pass'] = True
        with patch.object(Admin, 'verify', return_value={'status': 'FAIL', 'hits': 0}) as verify:
            checks, receipts = self.check()
            self.assertEqual((checks[0]['result'], receipts[0]['hits']), ('FAIL', 0))
            verify.assert_called_once_with('accounts-empty', 1, None, 'a' * 64)

    def test_missing_mapping_or_hash_mismatch_is_inconclusive(self):
        with patch.object(Admin, 'verify', side_effect=WireMockError('fixture hash differs')):
            self.assertEqual(self.check()[0][0]['result'], 'INCONCLUSIVE')

    def test_expectation_requires_hash_and_positive_hit_count(self):
        for rule in ({'name': 'empty'}, {'name': 'empty', 'fixture_sha256': 'a' * 64, 'min_hits': 0}):
            self.scenario['expectations']['wiremock'] = [rule]
            with self.assertRaisesRegex(ValueError, 'Invalid WireMock'):
                self.check()

    def test_missing_mock_coverage_inventory_is_inconclusive(self):
        check = report.evaluate_mock_coverage(self.scenario)[0]
        self.assertEqual(check['result'], 'INCONCLUSIVE')
        self.assertIn('routing receipt alone does not establish feature API coverage', check['detail'])

    def test_feature_api_interaction_must_link_action_and_fixture(self):
        scenario = {
            'expectations': {
                'ui_checks': ['table_saved'],
                'wiremock': [{'name': 'table-note-save'}],
                'mock_coverage': {
                    'mode': 'feature_api',
                    'interactions': [{
                        'id': 'table-autosave',
                        'check_id': 'table_saved',
                        'operation': 'updateNoteContent',
                        'method': 'PATCH',
                        'path': '/v1/notes/{itemID}/content',
                        'api_source': 'NotesApiService.updateNoteContent',
                        'contract_source': 'note_update_content_001.json#/apiMocks/0',
                        'fixture_ids': ['table-note-save'],
                    }],
                },
            },
        }
        check = report.evaluate_mock_coverage(scenario)[0]
        self.assertEqual(check['result'], 'PASS')

        scenario['expectations']['mock_coverage']['interactions'][0]['check_id'] = 'folders_loaded'
        check = report.evaluate_mock_coverage(scenario)[0]
        self.assertEqual(check['result'], 'INCONCLUSIVE')
        self.assertIn('expectations.ui_checks ID', check['detail'])

    def test_unlinked_fixture_fails_coverage_declaration(self):
        scenario = {
            'expectations': {
                'ui_checks': ['folders_loaded'],
                'wiremock': [{'name': 'folders-list'}, {'name': 'table-note-save'}],
                'mock_coverage': {
                    'mode': 'feature_api',
                    'interactions': [{
                        'id': 'folders-list',
                        'check_id': 'folders_loaded',
                        'operation': 'listItems',
                        'method': 'GET',
                        'path': '/v1/items',
                        'api_source': 'NotesApiService.listItems',
                        'contract_source': 'note_shared_list_001.json#/apiMocks/0',
                        'fixture_ids': ['folders-list'],
                    }],
                },
            },
        }
        check = report.evaluate_mock_coverage(scenario)[0]
        self.assertEqual(check['result'], 'INCONCLUSIVE')
        self.assertIn('unlinked fixture(s): table-note-save', check['detail'])

    def test_routing_only_scope_is_explicitly_not_feature_api_coverage(self):
        scenario = {
            'expectations': {
                'ui_checks': ['folders_loaded'],
                'wiremock': [{'name': 'folders-list'}],
                'mock_coverage': {
                    'mode': 'routing_only',
                    'reason': 'Verify that debug routing reaches the local server only.',
                    'interactions': [{
                        'id': 'folders-route-probe',
                        'check_id': 'folders_loaded',
                        'operation': 'listItems',
                        'method': 'GET',
                        'path': '/v1/items',
                        'api_source': 'NotesApiService.listItems',
                        'contract_source': 'note_shared_list_001.json#/apiMocks/0',
                        'fixture_ids': ['folders-list'],
                    }],
                },
            },
        }
        check = report.evaluate_mock_coverage(scenario)[0]
        self.assertEqual(check['result'], 'PASS')
        self.assertIn('feature API behavior is not covered', check['detail'])


if __name__ == '__main__':
    unittest.main()
