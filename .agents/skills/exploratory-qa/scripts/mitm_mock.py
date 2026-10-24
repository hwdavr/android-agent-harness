"""Optional fixture responses; validation also runs with standard-library Python."""
import argparse
import asyncio
import hashlib
import json
import os
import re
from pathlib import Path
from urllib.parse import parse_qsl, urlsplit


def allowed_hosts(raw):
    hosts = {part.strip().lower().rstrip('.') for part in raw.split(',') if part.strip()}
    label = r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
    if not hosts or any(not re.fullmatch(label + r'(?:\.' + label + r')*', h) for h in hosts):
        raise ValueError('QA_ALLOWED_HOSTS requires explicit hostnames, without ports or wildcards')
    return hosts


def integer(value, minimum, maximum, name):
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
        raise ValueError('Invalid ' + name)
    return value


def load_rules(scenario_path, hosts):
    path = Path(scenario_path).resolve()
    raw = path.read_bytes()
    scenario = json.loads(raw)
    if not isinstance(scenario, dict) or not isinstance(scenario.get('scenario_id'), str):
        raise ValueError('Mock scenario requires scenario_id')
    entries = scenario.get('apiMocks')
    if not isinstance(entries, list) or not entries:
        raise ValueError('Mock scenario requires nonempty apiMocks')
    rules, ids = [], set()
    for item in entries:
        if not isinstance(item, dict):
            raise ValueError('Each apiMocks entry must be an object')
        rid = item.get('id', '')
        if not isinstance(rid, str) or not re.fullmatch(r'[A-Za-z0-9._-]{1,64}', rid) or rid in ids:
            raise ValueError('Mock rule IDs must be unique safe identifiers')
        ids.add(rid)
        host, method, route = item.get('host'), item.get('method'), item.get('path')
        if not isinstance(host, str) or host != host.lower().rstrip('.') or host not in hosts:
            raise ValueError('Mock rule host must exactly match an allowed host')
        if not isinstance(method, str) or not re.fullmatch(r'[A-Z]{3,16}', method):
            raise ValueError('Mock method must be uppercase')
        if (not isinstance(route, str) or not route.startswith('/') or route.startswith('//')
                or '?' in route or '#' in route or '\r' in route or '\n' in route):
            raise ValueError('Mock path must be an absolute URL path without query or fragment')
        query = item.get('query')
        if query is not None and (not isinstance(query, dict)
                or any(not isinstance(k, str) or not isinstance(v, str) for k, v in query.items())):
            raise ValueError('Mock query must map strings to strings')
        for prior in rules:
            if (host, method, route) == (prior['host'], prior['method'], prior['path']):
                if query is None or prior['query'] is None or query == prior['query']:
                    raise ValueError('Overlapping mock rules')
        if ('response' in item) == ('body_file' in item):
            raise ValueError('Each mock requires exactly one response or body_file')
        if 'body_file' in item:
            relative = item['body_file']
            if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
                raise ValueError('body_file must be relative to the scenario directory')
            body_path = (path.parent / relative).resolve()
            try:
                body_path.relative_to(path.parent)
            except ValueError as exc:
                raise ValueError('body_file escapes the scenario directory') from exc
            body = body_path.read_bytes()
        else:
            body = json.dumps(item['response'], separators=(',', ':'), ensure_ascii=False).encode('utf-8')
        if len(body) > 2 * 1024 * 1024:
            raise ValueError('Mock body exceeds 2 MiB')
        headers = item.get('headers', {})
        if not isinstance(headers, dict):
            raise ValueError('Mock headers must be an object')
        for key, value in headers.items():
            if (not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9!#$%&*+.^_`|~-]+', key)
                    or not isinstance(value, str) or '\r' in value or '\n' in value
                    or key.lower() in {'content-length', 'transfer-encoding', 'connection'}):
                raise ValueError('Invalid or proxy-managed mock header')
        headers = dict(headers)
        if not any(k.lower() == 'content-type' for k in headers):
            headers['Content-Type'] = 'application/json' if 'response' in item else 'application/octet-stream'
        status = integer(item.get('status'), 200, 599, 'mock status')
        if status in {204, 304} and body:
            raise ValueError('204/304 fixtures require an empty body_file')
        rules.append({
            'id': rid, 'host': host, 'method': method, 'path': route, 'query': query,
            'status': status, 'body': body, 'headers': headers,
            'delay_ms': integer(item.get('delay_ms', 0), 0, 30000, 'delay_ms'),
            'min_hits': integer(item.get('min_hits', 1), 0, 1000000, 'min_hits'),
            'fixture_sha256': hashlib.sha256(body).hexdigest(),
        })
    if {rule['host'] for rule in rules} != set(hosts):
        raise ValueError('In mock mode every allowed host must have a rule')
    return scenario['scenario_id'], hashlib.sha256(raw).hexdigest(), rules


class MockResponses:
    def load(self, loader):
        from mitmproxy.exceptions import OptionsError
        try:
            self.hosts = allowed_hosts(os.environ.get('QA_ALLOWED_HOSTS', ''))
            _, self.scenario_hash, self.rules = load_rules(os.environ['QA_MOCK_SCENARIO'], self.hosts)
        except (KeyError, ValueError, OSError) as exc:
            raise OptionsError('Invalid QA mock configuration: ' + str(exc)) from exc

    async def request(self, flow):
        from mitmproxy import http
        request = flow.request
        if request.host.lower().rstrip('.') not in self.hosts:
            return
        path = urlsplit(request.path).path
        query = sorted(parse_qsl(urlsplit(request.path).query, keep_blank_values=True))
        rule = next((r for r in self.rules if
                     (r['host'], r['method'], r['path']) == (request.host.lower().rstrip('.'), request.method, path)
                     and (r['query'] is None or sorted(r['query'].items()) == query)), None)
        flow.metadata['mock_scenario_sha256'] = self.scenario_hash
        if rule is None:
            flow.metadata['unmatched_mock'] = True
            flow.response = http.Response.make(502, b'{"error":"qa_mock_unmatched"}', {'Content-Type': 'application/json'})
            return
        flow.metadata.update(mocked=True, mock_rule_id=rule['id'], fixture_sha256=rule['fixture_sha256'])
        if rule['delay_ms']:
            await asyncio.sleep(rule['delay_ms'] / 1000)
        flow.response = http.Response.make(rule['status'], rule['body'], rule['headers'])


addons = [MockResponses()]

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--validate', required=True, type=Path)
    args = parser.parse_args()
    try:
        sid, digest, rules = load_rules(args.validate, allowed_hosts(os.environ.get('QA_ALLOWED_HOSTS', '')))
        print(json.dumps({'scenario_id': sid, 'sha256': digest, 'rule_count': len(rules)}))
    except (OSError, ValueError) as error:
        parser.exit(2, 'Mock configuration error: ' + str(error) + '\n')
