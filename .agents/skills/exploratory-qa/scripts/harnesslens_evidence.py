"""Reverify run-scoped HarnessLens captures; never trust submitted PASS flags."""
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_path(run_dir, value):
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        raise ValueError('Evidence paths must be non-empty and relative to the QA run')
    path = (run_dir / value).resolve()
    if not path.is_relative_to(run_dir.resolve()):
        raise ValueError('Evidence path escapes the QA run: ' + value)
    return path


def qa_run_dir(path):
    resolved = path.resolve()
    if not any(parent.name == '.qa-artifacts' for parent in resolved.parents):
        raise ValueError('Generated QA output must be inside .qa-artifacts/<run-id>/')
    return resolved


def qa_project_root(run_dir):
    for parent in run_dir.parents:
        if parent.name == '.qa-artifacts':
            return parent.parent
    raise ValueError('QA run directory is not rooted under .qa-artifacts')


def read_object(path):
    value = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(value, dict):
        raise ValueError('Expected JSON object: ' + path.name)
    return value


def capture_records(path, run_id):
    records = [json.loads(line) for line in path.read_text(encoding='utf-8').splitlines() if line.strip()]
    if not records or any(not isinstance(row, dict) or row.get('run_id') != run_id for row in records):
        raise ValueError('Empty capture or capture run identity mismatch')
    if (records[0].get('type') != 'capture_ready' or records[0].get('version') != 1
            or any(row.get('type') not in ('state', 'event') for row in records[1:])):
        raise ValueError('Capture must start with one version-1 capture_ready marker')
    sequences = [row.get('sequence') for row in records[1:]]
    if (any(type(seq) is not int or seq <= 0 for seq in sequences)
            or sequences != sorted(set(sequences))):
        raise ValueError('Capture sequences must be positive and strictly increasing')
    return records


def approved_contract(run_dir, declaration, manifest, scenario):
    if not isinstance(declaration.get('source'), str) or not declaration['source'].strip():
        raise ValueError('Missing approved expectation source')
    source_name = declaration['source'].split('#', 1)[0]
    if not source_name or Path(source_name).is_absolute():
        raise ValueError('Approved source must be a project-relative contract path')
    root = qa_project_root(run_dir)
    source = (root / source_name).resolve()
    if not source.is_relative_to(root):
        raise ValueError('Approved source escapes the consuming project: ' + source_name)
    generated_sources = scenario.get('generation', {}).get('sources', [])
    source_entry = next((item for item in generated_sources
                         if isinstance(item, dict) and item.get('path') == source_name), None)
    source_hash = digest(source)
    if not source_entry or source_entry.get('sha256') != source_hash:
        raise ValueError('Approved source is missing from generation.sources or its hash changed')
    path = local_path(run_dir, declaration.get('contract'))
    if (manifest.get('contracts', {}).get(declaration['contract']) != digest(path)
            or digest(path) != source_hash):
        raise ValueError('Contract differs from the approved source hash recorded before UI actions')
    return path, read_object(path)


def verify(run_dir, capture, contract, run_id, kind, output_name, cli_root):
    output = local_path(run_dir, 'harnesslens/reports/' + output_name + '/report.json')
    markdown = local_path(run_dir, 'harnesslens/reports/' + output_name + '/report.md') if kind == 'analytics' else None
    log = local_path(run_dir, 'harnesslens/reports/' + output_name + '/verifier.log')
    output.parent.mkdir(parents=True, exist_ok=True)
    # A previous successful report must never survive a failed invocation.
    if output.exists():
        output.unlink()
    if markdown is not None and markdown.exists():
        markdown.unlink()
    if log.exists():
        log.unlink()
    if sys.version_info < (3, 10):
        raise ValueError('HarnessLens requires Python 3.10+; run the reporter with a supported interpreter')
    env = {key: os.environ[key] for key in ('PATH', 'LANG', 'LC_ALL', 'SYSTEMROOT') if key in os.environ}
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    if cli_root is not None:
        source = cli_root.resolve() / 'cli'
        if not (source / 'harnesslens/cli.py').is_file():
            raise ValueError('HarnessLens CLI source is unavailable at ' + str(source))
        env['PYTHONPATH'] = str(source)
    command = [sys.executable, '-m', 'harnesslens', kind, 'verify', '--file', str(capture),
               '--run-id', run_id, '--contract', str(contract)]
    command += ['--out', str(output)] if kind == 'state' else ['--report-dir', str(output.parent)]
    try:
        process = subprocess.run(command, capture_output=True, text=True, env=env, timeout=60, check=False)
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout or ''
        stderr = error.stderr or ''
        if isinstance(stdout, bytes):
            stdout = stdout.decode('utf-8', errors='replace')
        if isinstance(stderr, bytes):
            stderr = stderr.decode('utf-8', errors='replace')
        log.write_text(stdout + stderr, encoding='utf-8')
        raise ValueError('HarnessLens verifier timed out; see ' + str(log.relative_to(run_dir))) from error
    log.write_text(process.stdout + process.stderr, encoding='utf-8')
    if not output.is_file():
        raise ValueError('Verifier produced no report (exit %s); see %s' % (process.returncode, log.relative_to(run_dir)))
    result = read_object(output)
    if result.get('status') not in ('PASS', 'FAIL', 'INCONCLUSIVE') or process.returncode != {
            'PASS': 0, 'FAIL': 1, 'INCONCLUSIVE': 2}.get(result.get('status')):
        raise ValueError('Verifier exit/status disagreement; see ' + str(log.relative_to(run_dir)))
    receipt = {'command': command, 'exit_code': process.returncode,
               'capture': str(capture.relative_to(run_dir)), 'capture_sha256': digest(capture),
               'contract': str(contract.relative_to(run_dir)), 'contract_sha256': digest(contract),
               'report': str(output.relative_to(run_dir)), 'report_sha256': digest(output)}
    if cli_root is not None:
        package = cli_root.resolve() / 'cli/harnesslens'
        hasher = hashlib.sha256()
        source_files = sorted(package.glob('*.py'))
        if not source_files:
            raise ValueError('HarnessLens Python source package is empty')
        for source_file in source_files:
            hasher.update(source_file.name.encode('utf-8') + b'\0')
            hasher.update(source_file.read_bytes())
        receipt['cli_source_sha256'] = hasher.hexdigest()
    return result, receipt


def outcome(results):
    return 'FAIL' if 'FAIL' in results else 'INCONCLUSIVE' if 'INCONCLUSIVE' in results else 'PASS'


def evaluate_harnesslens(scenario, run_dir, scenario_hash, cli_root=None):
    checks, receipts = [], []

    def add(cid, status, detail, evidence=None):
        checks.append({'id': 'harnesslens:' + cid, 'result': status,
                       'kind': 'app' if status == 'FAIL' else 'evidence',
                       'detail': detail, 'evidence': evidence or []})

    errors = (OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.TimeoutExpired)
    try:
        declared = scenario.get('expectations', {}).get('harnesslens')
        if not isinstance(declared, dict):
            raise ValueError('Required HarnessLens state and analytics expectations are missing; use dogfood for UI-only work')
        checkpoints = declared.get('state_checkpoints')
        if not isinstance(checkpoints, list) or not checkpoints or not isinstance(declared.get('analytics'), dict):
            raise ValueError('HarnessLens requires non-empty state_checkpoints and an analytics contract')
        ids = [item.get('id') for item in checkpoints if isinstance(item, dict)]
        if (len(ids) != len(checkpoints) or len(set(ids)) != len(ids)
                or any(not isinstance(cid, str) or not re.fullmatch(r'[a-zA-Z0-9_-]+', cid) for cid in ids)):
            raise ValueError('State checkpoint IDs must be unique simple names')
        manifest_path = local_path(run_dir, 'harnesslens/run.json')
        manifest = read_object(manifest_path)
        run_id = manifest.get('run_id')
        if not isinstance(run_id, str) or not re.fullmatch(r'[0-9a-f]{32}', run_id):
            raise ValueError('Missing valid HarnessLens run_id from capture start')
        target = scenario.get('target', {})
        for field, expected in [('app_id', scenario.get('app_id')),
                                ('device_id', target.get('device_id')), ('platform', target.get('platform'))]:
            if not isinstance(expected, str) or not expected or manifest.get(field) != expected:
                raise ValueError('HarnessLens target identity differs or is missing: ' + field)
        if manifest.get('scenario_sha256') != scenario_hash:
            raise ValueError('Scenario differs from the hash recorded before UI actions')
        final_path = local_path(run_dir, declared.get('capture'))
        final_records = capture_records(final_path, run_id)
        add('capture', 'PASS', 'Capture readiness, run, target and scenario identity checked',
            ['harnesslens/run.json', declared['capture']])
    except errors as error:
        add('required-evidence', 'INCONCLUSIVE', str(error))
        return checks, receipts

    previous_sequence = 0
    for checkpoint_index, checkpoint in enumerate(checkpoints):
        cid = checkpoint['id']
        try:
            if (checkpoint.get('ui_check_id') not in scenario.get('expectations', {}).get('ui_checks', [])
                    or not isinstance(checkpoint.get('action'), str) or not checkpoint['action'].strip()):
                raise ValueError('Checkpoint must name its UI check and actual entry action')
            captured = local_path(run_dir, checkpoint.get('capture'))
            records = capture_records(captured, run_id)
            if records != final_records[:len(records)]:
                raise ValueError('Checkpoint is not a prefix of this run capture')
            boundary = manifest.get('checkpoints', {}).get(cid, {}).get('after_sequence')
            if type(boundary) is not int or boundary < previous_sequence:
                raise ValueError('Missing or out-of-order pre-action sequence boundary')
            boundary_capture = manifest.get('checkpoints', {}).get(cid, {}).get('boundary_capture')
            if boundary == 0:
                if checkpoint_index != 0 or boundary_capture is not None:
                    raise ValueError('Only the first action of a fresh run can use sequence boundary 0')
            else:
                if boundary_capture is None:
                    raise ValueError('Pre-action capture is required to prove the sequence boundary')
                before = local_path(run_dir, boundary_capture)
                before_records = capture_records(before, run_id)
                if (before_records != final_records[:len(before_records)]
                        or before_records[-1].get('sequence') != boundary):
                    raise ValueError('Pre-action capture does not prove the declared sequence boundary')
            previous_sequence = records[-1].get('sequence', 0)
            contract_path, contract = approved_contract(run_dir, checkpoint, manifest, scenario)
            assertions = contract.get('assertions')
            if not isinstance(assertions, list) or not assertions:
                raise ValueError('State contract must contain at least one assertion')
            if any(not isinstance(rule, dict) or any(not isinstance(rule.get(key), str) or not rule[key]
                    for key in ('scope', 'field')) or 'equals' not in rule for rule in assertions):
                raise ValueError('Every state assertion requires scope, field and equals')
            result, receipt = verify(run_dir, captured, contract_path, run_id, 'state', 'state-' + cid, cli_root)
            receipts.append(receipt)
            if len(result.get('checks', [])) != len(assertions):
                raise ValueError('State verifier did not evaluate every assertion')
            verdicts, stale = [], []
            for rule, check in zip(assertions, result['checks']):
                states = [row for row in records if row['type'] == 'state' and row.get('scope') == rule['scope']]
                if not states or states[-1]['sequence'] <= boundary:
                    stale.append(rule['scope'] + '.' + rule['field'])
                    verdicts.append('INCONCLUSIVE')
                else:
                    verdicts.append('INCONCLUSIVE' if check.get('inconclusive') else
                                    'PASS' if check.get('passed') is True else 'FAIL')
            detail = ('No fresh post-action state for: ' + ', '.join(stale)) if stale else (
                '%s state assertion(s); expected/actual values in %s' % (len(assertions), receipt['report']))
            add('state:' + cid, outcome(verdicts), detail, [checkpoint['capture'], receipt['report']])
        except errors as error:
            add('state:' + cid, 'INCONCLUSIVE', str(error))

    try:
        contract_path, contract = approved_contract(run_dir, declared['analytics'], manifest, scenario)
        if contract.get('scenario') != scenario.get('scenario_id'):
            raise ValueError('Analytics contract scenario identity differs')
        result, receipt = verify(run_dir, final_path, contract_path, run_id, 'analytics', 'analytics', cli_root)
        receipts.append(receipt)
        status = result['status']
        if status == 'PASS' and (not result.get('checks') or not result.get('event_count')):
            raise ValueError('No executed analytics assertions/events; instrumentation is unproven')
        add('analytics', status, result.get('reason') or 'App-side analytics contract verified; see ' + receipt['report'],
            [declared['capture'], receipt['report']])
    except errors as error:
        add('analytics', 'INCONCLUSIVE', str(error))
    return checks, receipts
