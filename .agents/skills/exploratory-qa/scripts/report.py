#!/usr/bin/env python3
"""Evaluate submitted QA evidence. Exit: 0 PASS, 1 FAIL, 2 INCONCLUSIVE/input error."""
import argparse
import fnmatch
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

from mitm_mock import load_rules


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8')) if path.is_file() else None


def read_jsonl(path):
    if not path.is_file():
        return []
    result = []
    for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if line.strip():
            value = json.loads(line)
            if not isinstance(value, dict):
                raise ValueError('Network line %s must be an object' % number)
            result.append(value)
    return result


def evaluate(scenario, observations, requests, scenario_hash=None, fixture_hashes=None):
    if not isinstance(scenario, dict) or (observations is not None and not isinstance(observations, dict)):
        raise ValueError('Scenario/observations must be objects')
    expected = scenario.get('expectations', {})
    observed = observations or {}
    if not isinstance(expected, dict) or not isinstance(observed.get('ui_checks', {}), dict):
        raise ValueError('Invalid expectations or observed ui_checks')
    ui_checks = expected.get('ui_checks', [])
    http_rules = expected.get('requests', [])
    mocks = scenario.get('apiMocks', [])
    if (not isinstance(ui_checks, list) or any(not isinstance(x, str) for x in ui_checks)
            or not isinstance(http_rules, list) or any(not isinstance(x, dict) for x in http_rules)
            or not isinstance(mocks, list) or any(not isinstance(x, dict) for x in mocks)):
        raise ValueError('Invalid check/rule lists')
    if any(not isinstance(x, dict) for x in requests):
        raise ValueError('Network entries must be objects')
    checks = []

    def add(cid, result, detail, kind='app', evidence=None):
        checks.append({'id': cid, 'result': result, 'kind': kind, 'detail': detail, 'evidence': evidence or []})

    sid = scenario.get('scenario_id')
    scoped = [r for r in requests if sid and r.get('scenario_id') == sid]
    if len(scoped) != len(requests):
        add('receipt-scope', 'INCONCLUSIVE', 'Receipts have missing/different scenario identity', 'setup')
    proxy_verified = observed.get('proxy_verified') is True
    for check_id in ui_checks:
        value = observed.get('ui_checks', {}).get(check_id)
        if value is True or value is False:
            add('ui:' + check_id, 'PASS' if value else 'FAIL',
                'Observed expected UI outcome' if value else 'Observed incorrect UI outcome', evidence=['observations.json'])
        else:
            add('ui:' + check_id, 'INCONCLUSIVE', 'No true/false runtime observation', 'evidence')
    if expected.get('no_unexpected_crash') is True:
        count = observed.get('unexpected_crashes')
        if not isinstance(count, int) or isinstance(count, bool) or count < 0:
            add('crash-free', 'INCONCLUSIVE', 'No reliable crash count provided', 'evidence')
        else:
            add('crash-free', 'PASS' if count == 0 else 'FAIL',
                'Observed %s unexpected crash(es)' % count, evidence=['observations.json'])

    for index, rule in enumerate(http_rules, 1):
        method, host, path = rule.get('method', 'GET'), rule.get('host', '*'), rule.get('path_glob', '*')
        if any(not isinstance(x, str) for x in (method, host, path)):
            raise ValueError('Invalid request matcher')
        cid = 'http:%s:%s:%s%s' % (index, method, host, path)
        matched = [r for r in scoped if r.get('method') == method.upper()
                   and fnmatch.fnmatchcase(r.get('host', ''), host)
                   and fnmatch.fnmatchcase(r.get('path', ''), path)]
        if not proxy_verified:
            add(cid, 'INCONCLUSIVE', 'In-app proxy capture not verified; cannot assert count/absence', 'evidence')
            continue
        minimum, maximum = rule.get('min_count', 1), rule.get('max_count')
        if (not isinstance(minimum, int) or isinstance(minimum, bool) or minimum < 0
                or (maximum is not None and (not isinstance(maximum, int) or isinstance(maximum, bool) or maximum < minimum))):
            raise ValueError('Invalid request count bounds')
        problems = []
        if len(matched) < minimum or (maximum is not None and len(matched) > maximum):
            problems.append('count=%s outside declared bounds' % len(matched))
        if 'allowed_statuses' in rule:
            if not isinstance(rule['allowed_statuses'], list):
                raise ValueError('allowed_statuses must be a list')
            if any(r.get('status') not in rule['allowed_statuses'] for r in matched):
                problems.append('disallowed response status')
        if rule.get('no_transport_errors') and any(r.get('transport_error') for r in matched):
            problems.append('transport error')
        add(cid, 'FAIL' if problems else 'PASS', '; '.join(problems) or 'Matched %s request(s)' % len(matched),
            evidence=['network.jsonl'])

    if any(r.get('unmatched_mock') is True for r in scoped):
        add('mock-routing', 'FAIL', 'Unmatched request to a mock host was blocked', 'setup', ['network.jsonl'])
    known_ids = {m.get('id') for m in mocks}
    if any(r.get('mocked') is True and r.get('mock_rule_id') not in known_ids for r in scoped):
        add('mock-identity', 'INCONCLUSIVE', 'Unknown mock rule in receipts', 'setup')
    for mock in mocks:
        rid = mock.get('id')
        if not isinstance(rid, str) or not rid:
            raise ValueError('Mock rule requires id')
        hits = [r for r in scoped if r.get('mocked') is True and r.get('mock_rule_id') == rid]
        required = mock.get('min_hits', 1)
        if not isinstance(required, int) or isinstance(required, bool) or required < 0:
            raise ValueError('Invalid min_hits')
        if not proxy_verified or len(hits) < required:
            add('mock:' + rid, 'INCONCLUSIVE', 'Required in-app fixture receipt not verified', 'evidence')
            continue
        valid = all(r.get('fixture_sha256') and r.get('mock_scenario_sha256')
                    and (scenario_hash is None or r['mock_scenario_sha256'] == scenario_hash)
                    and (fixture_hashes is None or r['fixture_sha256'] == fixture_hashes.get(rid))
                    and r.get('status') == mock.get('status') for r in hits)
        add('mock:' + rid, 'PASS' if valid else 'INCONCLUSIVE',
            'Verified %s mocked receipt(s)' % len(hits) if valid else 'Fixture identity/status differs from scenario',
            'evidence', ['network.jsonl'])
    if not checks:
        add('contract', 'INCONCLUSIVE', 'Scenario defines no verifiable expectations', 'evidence')
    status = 'FAIL' if any(c['result'] == 'FAIL' for c in checks) else (
        'INCONCLUSIVE' if any(c['result'] == 'INCONCLUSIVE' for c in checks) else 'PASS')
    return status, checks


def render_markdown(report):
    lines = ['# Exploratory QA — ' + str(report['scenario']), '', '**Outcome:** ' + report['status'],
             '**Proxy verified:** ' + str(report['proxy_verified']),
             '**Captured requests:** %s (mocked: %s)' % (report['network_request_count'], report['mocked_request_count']),
             '', '## Verification checks', '', '| ID | Result | Kind | Detail |', '|---|---|---|---|']
    for check in report['checks']:
        cells = [str(check[key]).replace('|', '\\|').replace('\n', ' ') for key in ('id', 'result', 'kind', 'detail')]
        lines.append('| ' + ' | '.join(cells) + ' |')
    lines += ['', '## Target and provenance', '', 'See `report.json` and the retained run `scenario.json` for binary/source/fixture hashes.',
              '', '## Exploration notes', '', 'Visited states: ' + ', '.join(map(str, report['states_visited']))]
    for finding in report['findings']:
        lines.append('- %s: %s; evidence: %s' % (finding.get('id', '?'), finding.get('title', ''), ', '.join(finding.get('evidence', []))))
    lines += ['', '## Request summary', '']
    lines += ['- `%s`: %s' % pair for pair in report['network_summary'].items()] or ['No allowlisted requests captured; absence requires verified capture.']
    lines += ['', 'PASS covers declared checks with submitted evidence. Exploration is not exhaustive. Setup failures are not automatically app defects.', '']
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-dir', type=Path, required=True)
    parser.add_argument('--scenario', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        scenario = read_json(args.scenario)
        if not isinstance(scenario, dict):
            raise ValueError('Missing/invalid scenario object')
        digest = hashlib.sha256(args.scenario.read_bytes()).hexdigest()
        hashes = None
        if scenario.get('apiMocks'):
            hosts = {m['host'] for m in scenario['apiMocks']}
            _, _, rules = load_rules(args.scenario, hosts)
            hashes = {r['id']: r['fixture_sha256'] for r in rules}
        observations = read_json(args.run_dir / 'observations.json')
        requests = read_jsonl(args.run_dir / 'network.jsonl')
        status, checks = evaluate(scenario, observations, requests, digest, hashes)
        observations = observations or {}
        report = {
            'scenario': scenario.get('scenario_id', 'unspecified'), 'scenario_sha256': digest,
            'status': status, 'proxy_verified': observations.get('proxy_verified') is True,
            'target': scenario.get('target', {}), 'generation': scenario.get('generation', {}),
            'network_request_count': len(requests), 'mocked_request_count': sum(r.get('mocked') is True for r in requests),
            'network_summary': dict(Counter('%s %s%s -> %s' % (r.get('method'), r.get('host'), r.get('path'), r.get('status')) for r in requests)),
            'fixture_receipts': [{k: r[k] for k in ('mock_rule_id', 'fixture_sha256', 'mock_scenario_sha256') if k in r}
                                 for r in requests if r.get('mocked') is True],
            'checks': checks, 'states_visited': observations.get('states_visited', []), 'findings': observations.get('findings', []),
        }
        args.run_dir.mkdir(parents=True, exist_ok=True)
        (args.run_dir / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        (args.run_dir / 'report.md').write_text(render_markdown(report))
        print('%s: %s' % (status, args.run_dir / 'report.md'))
        return {'PASS': 0, 'FAIL': 1, 'INCONCLUSIVE': 2}[status]
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        print('Report error: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
