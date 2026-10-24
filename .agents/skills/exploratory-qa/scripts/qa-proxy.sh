#!/usr/bin/env bash
# Process lifecycle only; device routing and CA trust remain explicit.
set -euo pipefail
QA_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 - "$QA_HELPER_DIR" "$@" <<'PY'
import importlib.util
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path


def main():
    if len(sys.argv) != 4 or sys.argv[2] not in {'start', 'status', 'stop'}:
        raise ValueError('Usage: qa-proxy.sh {start|status|stop} <run-id>')
    base, command, run_id = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,95}', run_id):
        raise ValueError('Invalid run-id')
    run = (Path(os.getenv('QA_RUN_ROOT', '.qa-artifacts')).resolve() / run_id)
    state_file, ready_file = run / 'proxy-state.json', run / 'proxy-ready.json'

    def owned_process(state):
        pid = state.get('pid')
        if not isinstance(pid, int) or pid <= 1:
            return False
        result = subprocess.run(['ps', '-p', str(pid), '-o', 'command='], capture_output=True, text=True)
        return result.returncode == 0 and str(base / 'mitm_capture.py') in result.stdout and ('qa_run_id=' + run_id) in result.stdout.split()

    state = json.loads(state_file.read_text()) if state_file.exists() else {}
    if command == 'status':
        print(('RUNNING PID=' + str(state['pid'])) if owned_process(state) else 'STOPPED')
        return 0
    if command == 'stop':
        if owned_process(state):
            os.kill(state['pid'], signal.SIGTERM)
            deadline = time.monotonic() + 5
            while owned_process(state) and time.monotonic() < deadline:
                time.sleep(0.05)
            if owned_process(state):
                raise ValueError('Proxy did not stop; inspect its owned PID before retrying')
        elif state.get('pid'):
            try:
                os.kill(state['pid'], 0)
            except ProcessLookupError:
                pass
            else:
                raise ValueError('Refusing to signal a PID that no longer belongs to this run')
        state_file.unlink(missing_ok=True)
        ready_file.unlink(missing_ok=True)
        print('STOPPED; restore any device proxy/CA changes made for this run')
        return 0

    executable = shutil.which('mitmdump')
    if executable is None:
        raise ValueError('mitmdump not found')
    if owned_process(state):
        raise ValueError('Proxy already running for this run-id')
    host = os.getenv('QA_LISTEN_HOST', '127.0.0.1')
    if host not in {'127.0.0.1', '::1'}:
        raise ValueError('Refusing a non-loopback listener')
    port = int(os.getenv('QA_PROXY_PORT', '8080'))
    if not 1 <= port <= 65535:
        raise ValueError('Invalid port')
    spec = importlib.util.spec_from_file_location('qa_mock_config', base / 'mitm_mock.py')
    config = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(config)
    hosts = config.allowed_hosts(os.getenv('QA_ALLOWED_HOSTS', ''))
    mock = os.getenv('QA_MOCK_SCENARIO')
    sid = os.getenv('QA_SCENARIO_ID', run_id)
    scenario_hash = None
    if mock:
        mock = str(Path(mock).resolve())
        sid, scenario_hash, _ = config.load_rules(mock, hosts)
    network = run / 'network.jsonl'
    if network.exists():
        raise ValueError('Run already has network evidence; choose a new run-id')
    # Reject an occupied port before launching; readiness also belongs to our PID.
    with socket.socket(socket.AF_INET6 if host == '::1' else socket.AF_INET) as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        probe.bind((host, port))
    os.umask(0o077)
    run.mkdir(parents=True, exist_ok=True, mode=0o700)
    ready_file.unlink(missing_ok=True)
    env = dict(os.environ, QA_NETWORK_FILE=str(network), QA_READY_FILE=str(ready_file), QA_SCENARIO_ID=sid)
    if mock:
        env['QA_MOCK_SCENARIO'] = mock
    args = [executable, '--quiet', '--listen-host', host, '--listen-port', str(port),
            '--set', 'flow_detail=0', '--set', 'qa_run_id=' + run_id, '-s', str(base / 'mitm_capture.py')]
    for allowed in sorted(hosts):
        args += ['--allow-hosts', '^' + re.escape(allowed) + r'(?::[0-9]+)?$']
    if mock:
        args += ['--set', 'connection_strategy=lazy', '-s', str(base / 'mitm_mock.py')]
    if os.getenv('QA_MITM_CONFIG_DIR'):
        args += ['--set', 'confdir=' + str(Path(os.environ['QA_MITM_CONFIG_DIR']).resolve())]
    with (run / 'proxy-process.log').open('w') as log:
        process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                   env=env, start_new_session=True)
    state = {'pid': process.pid, 'mode': 'mock' if mock else 'capture', 'scenario_id': sid,
             'scenario_sha256': scenario_hash, 'host': host, 'port': port}
    state_file.write_text(json.dumps(state, indent=2) + '\n')
    try:
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise ValueError('Proxy exited during startup; inspect proxy-process.log')
            if ready_file.exists() and json.loads(ready_file.read_text()).get('pid') == process.pid:
                with socket.create_connection((host, port), timeout=0.3):
                    print('RUNNING PID=%s mode=%s on %s:%s\nArtifacts: %s' %
                          (process.pid, state['mode'], host, port, run))
                    return 0
            time.sleep(0.1)
        raise ValueError('Proxy readiness timeout; inspect proxy-process.log')
    except BaseException:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        state_file.unlink(missing_ok=True)
        ready_file.unlink(missing_ok=True)
        raise


try:
    sys.exit(main())
except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
    print('Proxy error: ' + str(error), file=sys.stderr)
    sys.exit(2)
PY
