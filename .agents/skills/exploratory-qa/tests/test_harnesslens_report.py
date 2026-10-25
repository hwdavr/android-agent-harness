"""Report-boundary regressions using the real HarnessLens CLI on synthetic captures.

Set HARNESSLENS_ROOT to the pinned HarnessLens checkout, or install its Python package
in the interpreter used to run this suite. These fixtures are not live app QA evidence.
"""
import copy
import hashlib
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import report
import harnesslens_evidence


class HarnessLensReportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.run = Path(self.temp.name) / '.qa-artifacts' / 'synthetic'
        self.run.mkdir(parents=True)
        self.native_run = 'a' * 32
        self.scenario = {
            'scenario_id': 'synthetic-home', 'app_id': 'com.example.debug',
            'target': {'platform': 'android', 'device_id': 'emulator-5554'},
            'generation': {'sources': []},
            'entry_points': [{'id': 'home', 'surface': 'Launcher', 'action': 'Launch',
                              'expected': 'Edit Home visible', 'check_id': 'home_visible'}],
            'expectations': {'ui_checks': ['home_visible'], 'harnesslens': {
                'capture': 'harnesslens/capture.ndjson',
                'state_checkpoints': [{'id': 'home', 'ui_check_id': 'home_visible', 'action': 'Launch',
                'source': '.qa-artifacts/synthetic/harnesslens/approved/home-state.json#assertions',
                                       'capture': 'harnesslens/checkpoints/home.ndjson',
                                       'contract': 'harnesslens/contracts/home.json'}],
                'analytics': {'source': '.qa-artifacts/synthetic/harnesslens/approved/home-analytics.json',
                              'contract': 'harnesslens/contracts/analytics.json'}}}}
        self.records = [
            {'type': 'capture_ready', 'version': 1, 'run_id': self.native_run},
            {'type': 'state', 'run_id': self.native_run, 'sequence': 1,
             'scope': 'home', 'values': {'screen_section': 'edit'}},
            {'type': 'event', 'run_id': self.native_run, 'sequence': 2,
             'name': 'screen_view', 'params': {'screen_name': 'home'}}]
        self.contracts = {
            'harnesslens/contracts/home.json': {'schema_version': 1, 'assertions': [
                {'scope': 'home', 'field': 'screen_section', 'equals': 'edit'}]},
            'harnesslens/contracts/analytics.json': {'schema_version': 1, 'scenario': 'synthetic-home',
                'expected_events': [{'name': 'screen_view', 'count': {'exact': 1},
                                     'params': {'screen_name': {'equals': 'home'}}}]}}
        self.manifest = {'run_id': self.native_run, 'app_id': 'com.example.debug',
                         'device_id': 'emulator-5554', 'platform': 'android',
                         'checkpoints': {'home': {'after_sequence': 0}}}
        self.write_json('observations.json', {'ui_checks': {'home_visible': True}})
        self.prepare()

    def write_json(self, path, value):
        target = self.run / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(value) + '\n', encoding='utf-8')

    def write_capture(self, path, records):
        target = self.run / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(''.join(json.dumps(row) + '\n' for row in records), encoding='utf-8')

    def prepare(self):
        self.manifest['contracts'] = {}
        self.scenario['generation']['sources'] = []
        for path, contract in self.contracts.items():
            name = Path(path).name
            source = 'harnesslens/approved/' + name
            self.write_json(source, contract)
            self.scenario['generation']['sources'].append({
                'path': '.qa-artifacts/synthetic/' + source,
                'sha256': hashlib.sha256((self.run / source).read_bytes()).hexdigest(),
            })
            self.write_json(path, contract)
            self.manifest['contracts'][path] = hashlib.sha256((self.run / path).read_bytes()).hexdigest()
        for checkpoint in self.scenario['expectations']['harnesslens']['state_checkpoints']:
            contract_name = Path(checkpoint['contract']).name
            checkpoint['source'] = '.qa-artifacts/synthetic/harnesslens/approved/' + contract_name + '#assertions'
        analytics_name = Path(self.scenario['expectations']['harnesslens']['analytics']['contract']).name
        self.scenario['expectations']['harnesslens']['analytics']['source'] = (
            '.qa-artifacts/synthetic/harnesslens/approved/' + analytics_name)
        self.write_json('scenario.json', self.scenario)
        self.manifest['scenario_sha256'] = hashlib.sha256((self.run / 'scenario.json').read_bytes()).hexdigest()
        self.write_json('harnesslens/run.json', self.manifest)
        self.write_capture('harnesslens/capture.ndjson', self.records)
        self.write_capture('harnesslens/checkpoints/home.ndjson', self.records[:2])

    def generate(self, cli_root=None):
        args = ['--run-dir', str(self.run), '--scenario', str(self.run / 'scenario.json')]
        selected = cli_root or os.environ.get('HARNESSLENS_ROOT')
        if selected:
            args += ['--harnesslens-root', str(selected)]
        code = report.main(args)
        result = json.loads((self.run / 'report.json').read_text())
        return code, result

    def assert_check(self, result, cid, status, detail=None):
        check = next(item for item in result['checks'] if item['id'] == 'harnesslens:' + cid)
        self.assertEqual(check['result'], status, check)
        if detail:
            self.assertIn(detail, check['detail'])

    def test_real_verifiers_pass_and_retain_expected_actual_and_hashes(self):
        code, result = self.generate()
        self.assertEqual((code, result['status']), (0, 'PASS'), result)
        self.assertEqual(len(result['harnesslens_verifications']), 2)
        state = json.loads((self.run / 'harnesslens/reports/state-home/report.json').read_text())
        self.assertEqual(state['checks'][0]['actual'], 'edit')
        self.assertEqual(state['checks'][0]['expected'], 'edit')
        self.assertTrue(all(len(item['capture_sha256']) == 64 for item in result['harnesslens_verifications']))
        self.assertIn('harnesslens/reports/state-home/report.json', (self.run / 'report.md').read_text())

    def test_ui_pass_cannot_hide_wrong_internal_state(self):
        self.records[1]['values']['screen_section'] = 'profile'
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (1, 'FAIL'))
        self.assert_check(result, 'state:home', 'FAIL')
        state = json.loads((self.run / 'harnesslens/reports/state-home/report.json').read_text())
        self.assertEqual(state['checks'][0]['actual'], 'profile')

    def test_missing_field_is_inconclusive(self):
        self.records[1]['values'] = {}
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE')

    def test_known_mismatch_is_not_hidden_by_another_missing_field(self):
        self.records[1]['values']['screen_section'] = 'profile'
        self.contracts['harnesslens/contracts/home.json']['assertions'].append(
            {'scope': 'home', 'field': 'unexported', 'equals': False})
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (1, 'FAIL'))
        self.assert_check(result, 'state:home', 'FAIL')

    def test_duplicate_analytics_fails(self):
        duplicate = {**copy.deepcopy(self.records[2]), 'sequence': 3}
        self.records.append(duplicate)
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (1, 'FAIL'))
        self.assert_check(result, 'analytics', 'FAIL')

    def test_no_analytics_cannot_pass(self):
        self.records.pop()
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'analytics', 'INCONCLUSIVE', 'No analytics events')

    def test_stale_correct_state_cannot_pass(self):
        self.manifest['checkpoints']['home']['after_sequence'] = 1
        self.manifest['checkpoints']['home']['boundary_capture'] = 'harnesslens/checkpoints/home-before.ndjson'
        self.prepare()
        self.write_capture('harnesslens/checkpoints/home-before.ndjson', self.records[:2])
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE', 'No fresh post-action state')

    def test_later_correct_state_cannot_hide_earlier_checkpoint_failure(self):
        self.records[1]['values']['screen_section'] = 'profile'
        self.records.append({'type': 'state', 'run_id': self.native_run, 'sequence': 3,
                             'scope': 'home', 'values': {'screen_section': 'edit'}})
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (1, 'FAIL'))
        self.assert_check(result, 'state:home', 'FAIL')

    def test_missing_capture_cannot_pass(self):
        (self.run / 'harnesslens/capture.ndjson').unlink()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'required-evidence', 'INCONCLUSIVE')

    def test_omitted_harnesslens_cannot_silently_pass(self):
        self.prepare()
        del self.scenario['expectations']['harnesslens']
        self.write_json('scenario.json', self.scenario)
        self.manifest['scenario_sha256'] = hashlib.sha256((self.run / 'scenario.json').read_bytes()).hexdigest()
        self.write_json('harnesslens/run.json', self.manifest)
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'required-evidence', 'INCONCLUSIVE', 'expectations are missing')

    def test_mixed_runs_cannot_pass(self):
        self.records[1]['run_id'] = 'b' * 32
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'required-evidence', 'INCONCLUSIVE', 'run identity mismatch')

    def test_checkpoint_must_belong_to_final_capture(self):
        self.write_capture('harnesslens/checkpoints/home.ndjson', [self.records[0],
            {**self.records[1], 'values': {'screen_section': 'unrelated'}}])
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE', 'not a prefix')

    def test_changed_contract_cannot_redefine_expectation_after_capture(self):
        self.write_json('harnesslens/contracts/home.json', {'schema_version': 1, 'assertions': [
            {'scope': 'home', 'field': 'screen_section', 'equals': 'profile'}]})
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE', 'Contract differs from the approved source')

    def test_unrecorded_approved_contract_source_cannot_pass(self):
        self.scenario['generation']['sources'][0]['sha256'] = '0' * 64
        self.write_json('scenario.json', self.scenario)
        self.manifest['scenario_sha256'] = hashlib.sha256((self.run / 'scenario.json').read_bytes()).hexdigest()
        self.write_json('harnesslens/run.json', self.manifest)
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE', 'source is missing from generation.sources')

    def test_empty_state_contract_cannot_pass_vacuously(self):
        self.contracts['harnesslens/contracts/home.json']['assertions'] = []
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE', 'at least one assertion')

    def test_missing_cli_cannot_reuse_previous_pass(self):
        self.assertEqual(self.generate()[0], 0)
        code, result = self.generate(self.run / 'missing-cli')
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE', 'CLI source is unavailable')
        self.assertFalse((self.run / 'harnesslens/reports/state-home/report.json').exists())
        self.assertFalse((self.run / 'harnesslens/reports/analytics/report.json').exists())
        self.assertFalse((self.run / 'harnesslens/reports/analytics/report.md').exists())

    def test_unsupported_python_cannot_reuse_a_verifier_pass(self):
        output = self.run / 'harnesslens/reports/state-home/report.json'
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text('{"status":"PASS"}')
        with patch.object(harnesslens_evidence.sys, 'version_info', (3, 9)):
            with self.assertRaisesRegex(ValueError, 'Python 3.10+'):
                harnesslens_evidence.verify(self.run, self.run / 'harnesslens/checkpoints/home.ndjson',
                    self.run / 'harnesslens/contracts/home.json', self.native_run, 'state', 'state-home', ROOT.parent.parent / 'tools/HarnessLens')
        self.assertFalse(output.exists())

    def test_path_escape_cannot_read_another_runs_capture(self):
        self.scenario['expectations']['harnesslens']['capture'] = '../another/capture.ndjson'
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'required-evidence', 'INCONCLUSIVE', 'escapes the QA run')

    def test_generated_reports_cannot_be_written_outside_qa_artifacts(self):
        outside = Path(self.temp.name) / 'docs'
        code = report.main(['--run-dir', str(outside), '--scenario', str(self.run / 'scenario.json')])
        self.assertEqual(code, 2)
        self.assertFalse(outside.exists())

    def test_two_action_checkpoints_verify_their_own_expected_state(self):
        second = copy.deepcopy(self.scenario['expectations']['harnesslens']['state_checkpoints'][0])
        second.update(id='profile', action='Tap Profile', capture='harnesslens/checkpoints/profile.ndjson',
                      contract='harnesslens/contracts/profile.json')
        second['source'] = '.qa-artifacts/synthetic/harnesslens/approved/profile.json#assertions'
        self.scenario['expectations']['harnesslens']['state_checkpoints'].append(second)
        self.contracts[second['contract']] = {'schema_version': 1, 'assertions': [
            {'scope': 'home', 'field': 'screen_section', 'equals': 'profile'}]}
        self.manifest['checkpoints']['profile'] = {'after_sequence': 2}
        self.records.append({'type': 'state', 'run_id': self.native_run, 'sequence': 3,
                             'scope': 'home', 'values': {'screen_section': 'profile'}})
        self.prepare()
        self.manifest['checkpoints']['profile']['boundary_capture'] = 'harnesslens/checkpoints/profile-before.ndjson'
        self.write_json('harnesslens/run.json', self.manifest)
        self.write_capture('harnesslens/checkpoints/profile-before.ndjson', self.records[:3])
        self.write_capture(second['capture'], self.records)
        code, result = self.generate()
        self.assertEqual((code, result['status']), (0, 'PASS'), result)
        self.assert_check(result, 'state:home', 'PASS')
        self.assert_check(result, 'state:profile', 'PASS')

    def test_changed_scenario_cannot_redefine_checks_after_capture(self):
        self.scenario['expectations']['ui_checks'].append('unapproved')
        self.write_json('scenario.json', self.scenario)
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'required-evidence', 'INCONCLUSIVE', 'Scenario differs')

    def test_another_device_manifest_cannot_pass(self):
        self.manifest['device_id'] = 'emulator-5556'
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'required-evidence', 'INCONCLUSIVE', 'target identity differs')

    def test_missing_readiness_cannot_pass(self):
        self.records.pop(0)
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'required-evidence', 'INCONCLUSIVE', 'capture_ready')

    def test_analytics_output_symlink_cannot_write_outside_run(self):
        outside = Path(self.temp.name) / 'outside.md'
        output_dir = self.run / 'harnesslens/reports/analytics'
        output_dir.mkdir(parents=True)
        (output_dir / 'report.md').symlink_to(outside)
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'analytics', 'INCONCLUSIVE', 'escapes the QA run')
        self.assertFalse(outside.exists())

    def test_pre_action_boundary_must_be_backed_by_capture(self):
        self.manifest['checkpoints']['home']['after_sequence'] = 1
        self.prepare()
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE', 'Pre-action capture is required')

    def test_false_sequence_boundary_cannot_hide_recorded_state(self):
        self.manifest['checkpoints']['home'] = {'after_sequence': 0,
            'boundary_capture': 'harnesslens/checkpoints/home-before.ndjson'}
        self.prepare()
        self.write_capture('harnesslens/checkpoints/home-before.ndjson', self.records[:2])
        code, result = self.generate()
        self.assertEqual((code, result['status']), (2, 'INCONCLUSIVE'))
        self.assert_check(result, 'state:home', 'INCONCLUSIVE', 'Only the first action')


if __name__ == '__main__':
    unittest.main()
