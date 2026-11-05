#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "$0")/../../.." && pwd)}"

python3 - "$repo_root" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
workflow = (root / '.agents/workflows/feature-acceptance.md').resolve()
qa = (root / '.agents/skills/exploratory-qa/SKILL.md').resolve()
mock = (root / '.agents/skills/api-mocking/SKILL.md').resolve()
design = (root / '.agents/skills/test-design/SKILL.md').resolve()

# Validate owner handoffs instead of requiring copied prose in several entrypoints.
handoffs = {
    workflow: {(design, 'produce-the-test-plan'),
               (qa, 'adaptive-investigation-in-acceptance-support-mode'),
               (qa, 'cleanup'), (mock, 'local-state-side-effects')},
    qa: {(workflow, 'mock-flow-replanning'), (mock, 'run')},
    mock: {(workflow, 'mock-flow-replanning'), (qa, 'network-mode')},
    design: {(workflow, 'generate-the-test-plan-and-request-review--stop'),
             (mock, 'ownership-and-evidence')},
}
documents = {path: path.read_text() for path in handoffs}
for source, required in handoffs.items():
    links = set()
    for destination in re.findall(r'\[[^\]]+\]\(([^)]+)\)', documents[source]):
        filename, _, fragment = destination.partition('#')
        links.add(((source.parent / filename).resolve() if filename else source, fragment))
    for target, fragment in required:
        if (target, fragment) not in links:
            raise SystemExit(f'Missing owner handoff: {source.relative_to(root)} -> {target.relative_to(root)}#{fragment}')
        headings = list(re.finditer(r'^(#{1,6})\s+(.+)$', documents[target], re.M))
        section = next((i for i, heading in enumerate(headings)
                        if re.sub(r'[^\w -]', '', heading[2].lower()).replace(' ', '-') == fragment), None)
        if section is None:
            raise SystemExit(f'Missing owner section: {target.relative_to(root)}#{fragment}')
        heading = headings[section]
        end = next((following.start() for following in headings[section + 1:]
                    if len(following[1]) <= len(heading[1])), len(documents[target]))
        if not documents[target][heading.end():end].strip():
            raise SystemExit(f'Empty owner section: {target.relative_to(root)}#{fragment}')

paragraphs = {}
for source, body in documents.items():
    for paragraph in re.split(r'\n\s*\n', body):
        normalized = ' '.join(paragraph.split())
        if len(normalized.split()) < 35:
            continue
        if normalized in paragraphs:
            raise SystemExit(f'Duplicated procedure: {source.relative_to(root)} and {paragraphs[normalized].relative_to(root)}')
        paragraphs[normalized] = source
print('PASS: QA owner handoffs resolve; no copied long procedures.')
PY
