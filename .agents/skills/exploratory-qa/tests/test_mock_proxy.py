import copy
import hashlib
import http.client
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ProxyTest(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(shutil.which('mitmdump'), 'mitmdump is required; no skipped proxy evidence')
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name) / '.qa-artifacts'
        self.base.mkdir()
        self.scenario = json.loads((ROOT / 'tests/fixtures/mock-scenario.json').read_text())
        self.scenario_file = self.base / 'scenario.json'
        with socket.socket() as port:
            port.bind(('127.0.0.1', 0))
            self.port = port.getsockname()[1]
        self.env = dict(os.environ, QA_RUN_ROOT=str(self.base / 'runs'), QA_PROXY_PORT=str(self.port),
                        QA_ALLOWED_HOSTS='qa.example.test', QA_MOCK_SCENARIO=str(self.scenario_file),
                        QA_MITM_CONFIG_DIR=str(self.base / 'private-config'), PYTHONDONTWRITEBYTECODE='1')
        self.runs = []
        self.addCleanup(self.stop_all)

    def command(self, action, run='case'):
        return subprocess.run(['bash', str(ROOT / 'scripts/qa-proxy.sh'), action, run], env=self.env,
                              text=True, capture_output=True, timeout=25)

    def start(self, run='case'):
        self.scenario_file.write_text(json.dumps(self.scenario))
        result = self.command('start', run)
        log = self.base / 'runs' / run / 'proxy-process.log'
        self.assertEqual(result.returncode, 0, result.stderr + (log.read_text() if log.exists() else ''))
        self.runs.append(run)
        return result

    def stop_all(self):
        for run in self.runs:
            result = self.command('stop', run)
            self.assertEqual(result.returncode, 0, result.stderr)

    def request(self, path='/items', method='GET', host='qa.example.test'):
        connection = http.client.HTTPConnection('127.0.0.1', self.port, timeout=5)
        try:
            connection.request(method, 'http://' + host + path, headers={'Authorization': 'Bearer synthetic-secret'})
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()

    def receipts(self, run='case', count=1):
        path = self.base / 'runs' / run / 'network.jsonl'
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            lines = path.read_text().splitlines() if path.exists() else []
            if len(lines) >= count:
                return [json.loads(line) for line in lines]
            time.sleep(0.05)
        self.fail('Proxy produced no expected metadata receipt')

    def test_fixture_status_body_hash_and_metadata_minimization(self):
        self.start()
        started = time.monotonic()
        status, body = self.request('/items?token=synthetic-secret')
        self.assertGreaterEqual(time.monotonic() - started, 0.04)
        self.assertEqual(status, 503)
        self.assertEqual(json.loads(body), self.scenario['apiMocks'][0]['response'])
        receipt = self.receipts()[0]
        self.assertTrue(receipt['mocked'])
        self.assertEqual(receipt['mock_rule_id'], 'service-error')
        self.assertEqual(receipt['fixture_sha256'], hashlib.sha256(body).hexdigest())
        self.assertEqual(receipt['mock_scenario_sha256'], hashlib.sha256(self.scenario_file.read_bytes()).hexdigest())
        self.assertNotIn('synthetic-secret', json.dumps(receipt))
        self.assertNotIn('body', receipt)
        self.assertNotIn('headers', receipt)

    def test_unmatched_request_never_reaches_upstream(self):
        hits = []

        class Upstream(BaseHTTPRequestHandler):
            def do_GET(self):
                hits.append(self.path)
                self.send_response(418)
                self.end_headers()

            def log_message(self, *args):
                return

        server = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.env['QA_ALLOWED_HOSTS'] = '127.0.0.1'
        self.scenario['apiMocks'][0]['host'] = '127.0.0.1'
        self.start()
        status, body = self.request('/not-mocked', host='127.0.0.1:' + str(server.server_port))
        self.assertEqual(status, 502)
        self.assertEqual(json.loads(body)['error'], 'qa_mock_unmatched')
        self.assertEqual(hits, [])
        self.assertTrue(self.receipts()[0]['unmatched_mock'])

    def test_method_and_explicit_query_are_matched(self):
        self.scenario['apiMocks'][0]['query'] = {'mode': 'error'}
        self.start()
        self.assertEqual(self.request('/items?mode=error')[0], 503)
        self.assertEqual(self.request('/items?mode=other')[0], 502)
        self.assertEqual(self.request('/items?mode=error', method='POST')[0], 502)

    def test_invalid_or_missing_fixture_prevents_start(self):
        original = copy.deepcopy(self.scenario)
        for mutation in ('missing-file', 'traversal', 'wrong-host', 'overlap'):
            with self.subTest(mutation=mutation):
                self.scenario = copy.deepcopy(original)
                rule = self.scenario['apiMocks'][0]
                if mutation in {'missing-file', 'traversal'}:
                    del rule['response']
                    rule['body_file'] = '../outside.json' if mutation == 'traversal' else 'missing.json'
                elif mutation == 'wrong-host':
                    rule['host'] = 'unapproved.example.test'
                else:
                    self.scenario['apiMocks'].append({**rule, 'id': 'overlap'})
                self.scenario_file.write_text(json.dumps(self.scenario))
                result = self.command('start')
                self.assertEqual(result.returncode, 2)
                self.assertIn('Proxy error:', result.stderr)
                self.assertEqual(self.command('status').stdout.strip(), 'STOPPED')

    def test_fixture_changes_after_restart_without_app_build(self):
        self.start('first')
        first = self.request()
        first_receipt = self.receipts('first')[0]
        self.assertEqual(self.command('stop', 'first').returncode, 0)
        self.scenario['apiMocks'][0]['status'] = 200
        self.scenario['apiMocks'][0]['response'] = {'items': []}
        self.start('second')
        second = self.request()
        second_receipt = self.receipts('second')[0]
        self.assertEqual((first[0], second[0]), (503, 200))
        self.assertEqual(json.loads(second[1]), {'items': []})
        self.assertNotEqual(first_receipt['fixture_sha256'], second_receipt['fixture_sha256'])
        self.assertNotEqual(first_receipt['mock_scenario_sha256'], second_receipt['mock_scenario_sha256'])

    def test_status_across_commands_and_port_cleanup(self):
        self.start()
        self.assertIn('RUNNING', self.command('status').stdout)
        self.assertEqual(self.command('stop').returncode, 0)
        self.assertEqual(self.command('status').stdout.strip(), 'STOPPED')
        with socket.socket() as probe:
            self.assertNotEqual(probe.connect_ex(('127.0.0.1', self.port)), 0)

    def test_malformed_body_fixture_is_served_verbatim(self):
        rule = self.scenario['apiMocks'][0]
        del rule['response']
        rule['body_file'] = 'malformed.json'
        rule['headers'] = {'Content-Type': 'application/json'}
        payload = b'{invalid JSON'
        (self.base / 'malformed.json').write_bytes(payload)
        self.start()
        self.assertEqual(self.request(), (503, payload))
        self.assertEqual(self.receipts()[0]['fixture_sha256'], hashlib.sha256(payload).hexdigest())

    def test_capture_only_records_upstream_without_mock(self):
        class Upstream(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'local-origin')

            def log_message(self, *args):
                return

        server = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.env.pop('QA_MOCK_SCENARIO')
        self.env['QA_ALLOWED_HOSTS'] = '127.0.0.1'
        self.env['QA_SCENARIO_ID'] = 'local-capture'
        self.start()
        self.assertEqual(self.request('/origin', host='127.0.0.1:' + str(server.server_port)), (200, b'local-origin'))
        receipt = self.receipts()[0]
        self.assertFalse(receipt['mocked'])
        self.assertEqual(receipt['scenario_id'], 'local-capture')

    def test_report_correlates_real_receipt_and_rejects_changed_fixture(self):
        self.scenario['target'] = {'kind': 'proxy-helper-only'}
        self.scenario['expectations'] = {'requests': [
            {'method': 'GET', 'host': 'qa.example.test', 'path_glob': '/items', 'allowed_statuses': [503]}
        ]}
        self.start()
        self.assertEqual(self.request()[0], 503)
        self.receipts()
        run = self.base / 'runs/case'
        (run / 'observations.json').write_text(json.dumps({'proxy_verified': True, 'ui_checks': {}}))
        run_scenario = run / 'scenario.json'
        run_scenario.write_bytes(self.scenario_file.read_bytes())
        command = [sys.executable, str(ROOT / 'scripts/report.py'), '--run-dir', str(run), '--scenario', str(run_scenario)]
        result = subprocess.run(command, env=self.env, text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 2, result.stderr)
        output = json.loads((run / 'report.json').read_text())
        self.assertEqual((output['status'], output['mocked_request_count']), ('INCONCLUSIVE', 1))
        self.assertEqual(next(c['result'] for c in output['checks'] if c['id'] == 'mock:service-error'), 'PASS')
        self.assertEqual(next(c['result'] for c in output['checks'] if c['id'] == 'harnesslens:required-evidence'), 'INCONCLUSIVE')
        self.scenario['apiMocks'][0]['response'] = {'changed': True}
        self.scenario_file.write_text(json.dumps(self.scenario))
        run_scenario.write_bytes(self.scenario_file.read_bytes())
        changed = subprocess.run(command, env=self.env, text=True, capture_output=True, timeout=5)
        self.assertEqual(changed.returncode, 2, changed.stderr)
        changed_output = json.loads((run / 'report.json').read_text())
        self.assertEqual(changed_output['status'], 'INCONCLUSIVE')
        self.assertEqual(next(c['result'] for c in changed_output['checks'] if c['id'] == 'mock:service-error'), 'INCONCLUSIVE')


if __name__ == '__main__':
    unittest.main()
