"""Exact-allowlist metadata capture; no live bodies, headers or raw flows."""
import json
import os
import re
import time
from pathlib import Path
from urllib.parse import urlsplit

OUTPUT = Path(os.environ['QA_NETWORK_FILE'])
HOSTS = {h.strip().lower().rstrip('.') for h in os.environ['QA_ALLOWED_HOSTS'].split(',') if h.strip()}
SCENARIO_ID = os.environ['QA_SCENARIO_ID']


def load(loader):
    loader.add_option('qa_run_id', str, '', 'Exploratory QA process identity')


def running():
    ready = Path(os.environ['QA_READY_FILE'])
    temporary = ready.with_suffix('.tmp')
    temporary.write_text(json.dumps({'pid': os.getpid(), 'scenario_id': SCENARIO_ID}))
    temporary.replace(ready)


def safe_path(raw_path):
    path = urlsplit(raw_path).path or '/'
    path = re.sub(r'/[0-9a-f]{8}-[0-9a-f-]{27,}', '/:uuid', path, flags=re.I)
    path = re.sub(r'/\d+', '/:id', path)
    path = re.sub(r'/[^/]*@[^/]*', '/:email', path)
    path = re.sub(r'/[A-Za-z0-9_-]{28,}', '/:opaque', path)
    return path[:256]


def write_event(flow, transport_error):
    if flow.metadata.get('exploratory_qa_written'):
        return
    flow.metadata['exploratory_qa_written'] = True
    req = flow.request
    if req is None or req.scheme not in {'http', 'https'} or req.host.lower().rstrip('.') not in HOSTS:
        return
    end = (flow.response.timestamp_end if flow.response else None) or time.time()
    event = {
        'scenario_id': SCENARIO_ID, 'timestamp': round(time.time(), 3),
        'method': req.method.upper(), 'host': req.host.lower().rstrip('.'), 'path': safe_path(req.path),
        'status': flow.response.status_code if flow.response else None,
        'duration_ms': round(max(0, end - req.timestamp_start) * 1000, 1) if req.timestamp_start else None,
        'transport_error': bool(transport_error),
        'mocked': flow.metadata.get('mocked') is True,
        'unmatched_mock': flow.metadata.get('unmatched_mock') is True,
    }
    for key in ('mock_rule_id', 'fixture_sha256', 'mock_scenario_sha256'):
        if key in flow.metadata:
            event[key] = flow.metadata[key]
    with OUTPUT.open('a', encoding='utf-8') as stream:
        stream.write(json.dumps(event, separators=(',', ':')) + '\n')


def response(flow):
    write_event(flow, False)


def error(flow):
    write_event(flow, True)
