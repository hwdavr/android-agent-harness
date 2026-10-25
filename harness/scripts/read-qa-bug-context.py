#!/usr/bin/env python3
"""Read one existing QA finding. Exit 0 for reusable context, 2 for invalid evidence."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


def read_object(path, label):
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError("missing %s: %s" % (label, path))
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("%s must be a JSON object" % label)
    return value


def contained_path(root, reference, label):
    if not isinstance(reference, str) or not reference.strip():
        raise ValueError("%s path is missing" % label)
    relative = Path(reference)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("%s path must stay within %s" % (label, root))
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("%s path escapes %s" % (label, root))
    return path


def spec_handoff(spec, project_root):
    text = spec.read_text(encoding="utf-8")
    section = re.search(r"^## Exploratory QA Handoff\s*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if section is None:
        return None
    values = {}
    for key, value in re.findall(r"^- (Report|Finding):\s*`([^`]+)`\s*$", section[1], re.M):
        if key in values:
            raise ValueError("duplicate QA handoff %s" % key)
        values[key] = value
    if set(values) != {"Report", "Finding"}:
        raise ValueError("QA handoff requires Report and Finding references")
    return contained_path(project_root, values["Report"], "report"), values["Finding"]


def selected_finding(document, finding_id, label):
    findings = document.get("findings")
    if not isinstance(findings, list):
        raise ValueError("%s.findings must be a list" % label)
    matches = [item for item in findings if isinstance(item, dict) and item.get("id") == finding_id]
    if len(matches) != 1:
        raise ValueError("%s must contain exactly one finding %s" % (label, finding_id))
    return matches[0]


def load_context(report_path, finding_id, project_root):
    if report_path.suffix.lower() == ".md":
        if not report_path.is_file() or finding_id not in report_path.read_text(encoding="utf-8"):
            raise ValueError("missing report or selected finding in Markdown report")
        report_path = report_path.with_name("report.json")
    report = read_object(report_path, "report")
    run_dir = report_path.parent
    scenario_path = run_dir / "scenario.json"
    scenario = read_object(scenario_path, "scenario")
    if hashlib.sha256(scenario_path.read_bytes()).hexdigest() != report.get("scenario_sha256"):
        raise ValueError("scenario digest differs from report; regenerate or recover the matching QA artifacts")
    if not report.get("scenario") or report["scenario"] != scenario.get("scenario_id"):
        raise ValueError("scenario identity differs from report")
    if report.get("status") not in {"PASS", "FAIL", "INCONCLUSIVE"}:
        raise ValueError("report status is missing or invalid")
    target = report.get("target")
    scenario_target = scenario.get("target")
    if not isinstance(target, dict) or not isinstance(scenario_target, dict):
        raise ValueError("report/scenario target is missing")
    for key in ("package", "version", "device"):
        if not isinstance(target.get(key), str) or not target[key].strip():
            raise ValueError("target.%s is missing" % key)
        if target[key] != scenario_target.get(key):
            raise ValueError("target.%s differs from scenario" % key)
    for key in ("apk_sha256", "installed_apk_sha256"):
        digest = target.get(key)
        if digest is not None:
            if not isinstance(digest, str) or not re.fullmatch(r"[a-fA-F0-9]{64}", digest):
                raise ValueError("target.%s must be a SHA-256 digest when supplied" % key)
            if digest != scenario_target.get(key):
                raise ValueError("target.%s differs from scenario" % key)
    if target != scenario_target:
        raise ValueError("target differs from scenario")
    if (target.get("apk_sha256") and target.get("installed_apk_sha256")
            and target["apk_sha256"] != target["installed_apk_sha256"]):
        raise ValueError("installed APK digest differs from supplied APK")

    finding = selected_finding(report, finding_id, "report")
    observations = read_object(run_dir / "observations.json", "observations")
    if finding != selected_finding(observations, finding_id, "observations"):
        raise ValueError("selected finding differs from observations; regenerate the report")
    if (finding.get("category", "").lower() in {"setup", "environment", "infrastructure"}
            or finding.get("kind") in {"setup", "evidence"}):
        raise ValueError("selected finding is a setup/environment issue; route it before treating it as an application defect")
    for key in ("title", "severity", "expected", "actual"):
        if not isinstance(finding.get(key), str) or not finding[key].strip():
            raise ValueError("finding.%s is missing" % key)
    for key in ("repro_steps", "evidence"):
        values = finding.get(key)
        if not isinstance(values, list) or not values or any(not isinstance(item, str) or not item.strip() for item in values):
            raise ValueError("finding.%s must contain non-empty entries" % key)
    for reference in finding["evidence"]:
        evidence = contained_path(run_dir, reference, "evidence")
        if not evidence.is_file() or evidence.stat().st_size == 0:
            raise ValueError("missing evidence: %s" % reference)

    sources = report.get("generation", {}).get("sources", [])
    if not isinstance(sources, list):
        raise ValueError("generation.sources must be a list")
    if sources != scenario.get("generation", {}).get("sources", []):
        raise ValueError("source provenance differs from scenario")
    changed = []
    for source in sources:
        if (not isinstance(source, dict) or not isinstance(source.get("path"), str)
                or not source["path"].strip() or not isinstance(source.get("sha256"), str)
                or not re.fullmatch(r"[a-fA-F0-9]{64}", source["sha256"])):
            raise ValueError("source fingerprint requires path and sha256")
        try:
            path = contained_path(project_root, source.get("path"), "source")
        except ValueError:
            changed.append("%s (outside project; review manually)" % source.get("path"))
            continue
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != source["sha256"]:
            changed.append(source["path"])
    return report_path, report, finding, changed, len(sources)


def render_context(report_path, report, finding, changed, source_count):
    target = report["target"]
    lines = [
        "# QA bug context — %s: %s" % (finding["id"], finding["title"]), "",
        "Report: %s" % report_path,
        "Scenario: %s; overall QA verdict: %s" % (report["scenario"], report["status"]),
        "Target: %s; %s; %s" % (target["package"], target["version"], target["device"]),
        "APK SHA-256: %s" % target.get("installed_apk_sha256", target.get("apk_sha256", "not recorded")),
        "Severity: %s" % finding["severity"], "",
        "Expected: " + finding["expected"], "Actual: " + finding["actual"], "",
        "Reproduction steps:",
    ]
    lines.extend("%s. %s" % (index, step) for index, step in enumerate(finding["repro_steps"], 1))
    lines.extend(["", "Evidence:"] + ["- " + str(report_path.parent / item) for item in finding["evidence"]])
    if changed:
        lines.extend(["", "Changed source references — review relevant code/contracts before diagnosis:"] + ["- " + item for item in changed])
    elif source_count:
        lines.extend(["", "Recorded source fingerprints match the current files."])
    else:
        lines.extend(["", "Source fingerprints were not recorded; correlate the reported build with current source."])
    lines.extend(["", "This reuses a historical runtime reproduction. Current-source diagnosis, a RED regression, and post-fix verification remain required."])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--report", type=Path)
    inputs.add_argument("--spec", type=Path)
    parser.add_argument("--finding")
    parser.add_argument("--check", action="store_true", help="Validate without printing the full finding")
    args = parser.parse_args()
    try:
        project_root = args.project_root.resolve()
        if args.spec:
            handoff = spec_handoff(args.spec, project_root)
            if handoff is None:
                print("QA handoff not declared; use the normal bug-context path.")
                return 0
            report_path, finding_id = handoff
        else:
            if not args.finding:
                raise ValueError("--report requires --finding")
            report_path = args.report.resolve()
            finding_id = args.finding
        report_path, report, finding, changed, source_count = load_context(report_path, finding_id, project_root)
        if args.check:
            print("PASS: QA handoff %s has complete historical runtime evidence; %s changed source reference(s) require review." % (finding_id, len(changed)))
        else:
            print(render_context(report_path, report, finding, changed, source_count))
        return 0
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        print("FAIL: QA bug context: " + str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
