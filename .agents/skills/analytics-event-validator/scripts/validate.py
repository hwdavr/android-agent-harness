#!/usr/bin/env python3
"""Analytics contracts: 0 PASS, 1 FAIL, 2 INCONCLUSIVE, 3 INVALID_INPUT."""
from __future__ import annotations
import argparse
import collections
import datetime as dt
import hashlib
import json
import math
import os
import re
import sre_parse
import sys
from pathlib import Path

MAX_BYTES = 3_000_000
NAME = re.compile(r"[A-Za-z][A-Za-z0-9_]{0,63}")
SHA = re.compile(r"[a-f0-9]{64}")
UNKNOWN = "__unexpected__"


class CaptureIssue(ValueError):
    """Unverified capture, rather than an observed product regression."""


def digest(data):
    return hashlib.sha256(data).hexdigest()


def bounded(path, limit=MAX_BYTES):
    with Path(path).open("rb") as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Input exceeds byte limit")
    return data


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def decode(data):
    def constant(_):
        raise ValueError("Nonfinite JSON number")
    try:
        return json.loads(data, object_pairs_hook=_pairs, parse_constant=constant)
    except (UnicodeError, json.JSONDecodeError, RecursionError):
        raise ValueError("Malformed JSON or encoding") from None


def fields(value, allowed, required=()):
    if not isinstance(value, dict) or set(value) - set(allowed) or set(required) - set(value):
        raise ValueError("Missing or unknown object fields")


def name(value):
    if not isinstance(value, str) or not NAME.fullmatch(value):
        raise ValueError("Invalid event or parameter identifier")


def scalar_type(value):
    if value is None:
        return "null"
    if type(value) is bool:
        return "boolean"
    if type(value) is int and abs(value) <= 2 ** 53:
        return "integer"
    if type(value) is float and math.isfinite(value):
        return "number"
    if isinstance(value, str) and len(value) <= 256:
        return "string"
    return "unsupported"


def equivalent(left, right):
    return scalar_type(left) == scalar_type(right) and left == right


def safe_pattern(pattern):
    """Bounded subset prevents untrusted regex from unbounded backtracking."""
    if not isinstance(pattern, str) or len(pattern) > 128:
        raise ValueError("Invalid regex")
    try:
        parsed = list(sre_parse.parse(pattern))
    except re.error:
        raise ValueError("Invalid regex") from None
    repeats = 0
    simple = {sre_parse.LITERAL, sre_parse.NOT_LITERAL, sre_parse.ANY, sre_parse.IN, sre_parse.AT}
    for token, value in parsed:
        if token in {sre_parse.MAX_REPEAT, sre_parse.MIN_REPEAT}:
            repeats += 1
            _, high, body = value
            if repeats > 1 or high > 128 or len(body) != 1 or body[0][0] not in simple - {sre_parse.AT}:
                raise ValueError("Regex requires at most one bounded simple repetition")
        elif token not in simple:
            raise ValueError("Unsupported regex construct")
    return re.compile(pattern)


def param_ok(value, rule):
    actual = scalar_type(value)
    if actual != rule["type"] and not (rule["type"] == "number" and actual == "integer"):
        return False
    if "equals" in rule and not equivalent(value, rule["equals"]):
        return False
    if "one_of" in rule and not any(equivalent(value, item) for item in rule["one_of"]):
        return False
    return "matches" not in rule or re.fullmatch(rule["matches"], value) is not None


def load_contract(path):
    value = decode(bounded(path, 256_000))
    fields(value, {"schema_version", "scenario_id", "approval", "sources", "allow_unexpected",
                   "expected_events", "forbidden_events", "order"},
           {"schema_version", "scenario_id", "approval", "sources", "expected_events"})
    if type(value["schema_version"]) is not int or value["schema_version"] != 1:
        raise ValueError("Unsupported contract version")
    if not isinstance(value["scenario_id"], str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,127}", value["scenario_id"]):
        raise ValueError("Invalid scenario identity")
    fields(value["approval"], {"status", "reference"}, {"status", "reference"})
    if value["approval"]["status"] not in ("draft", "example", "approved"):
        raise ValueError("Invalid approval status")
    if not isinstance(value["approval"]["reference"], str) or not 1 <= len(value["approval"]["reference"]) <= 512:
        raise ValueError("Missing approval reference")
    if not isinstance(value["sources"], list) or len(value["sources"]) > 50:
        raise ValueError("Invalid contract sources")
    for source in value["sources"]:
        fields(source, {"path", "sha256", "section"}, {"path", "sha256", "section"})
        if (not isinstance(source["path"], str) or not source["path"] or
                not isinstance(source["sha256"], str) or not SHA.fullmatch(source["sha256"]) or
                not isinstance(source["section"], str) or not source["section"]):
            raise ValueError("Invalid contract source")
    if value["approval"]["status"] == "approved" and not value["sources"]:
        raise ValueError("Approved contracts require hashed tracking sources")
    if type(value.get("allow_unexpected", True)) is not bool:
        raise ValueError("allow_unexpected must be boolean")
    events = value["expected_events"]
    if not isinstance(events, list) or not 1 <= len(events) <= 100:
        raise ValueError("Expected events must be a nonempty bounded list")
    names, limits = set(), {}
    for event in events:
        fields(event, {"name", "count", "params"}, {"name", "count"})
        name(event["name"])
        if event["name"] in names:
            raise ValueError("Duplicate expected event")
        names.add(event["name"])
        count = event["count"]
        fields(count, {"exact", "min", "max"})
        if not count or ("exact" in count and len(count) != 1):
            raise ValueError("Use exact or min/max counts")
        if any(type(item) is not int or not 0 <= item <= 100_000 for item in count.values()):
            raise ValueError("Invalid count bound")
        if count.get("min", 0) > count.get("max", 100_000):
            raise ValueError("Contradictory count bounds")
        limits[event["name"]] = count.get("exact", count.get("max", 100_000))
        rules = event.get("params", {})
        if not isinstance(rules, dict) or len(rules) > 50:
            raise ValueError("Invalid parameter rules")
        for key, rule in rules.items():
            name(key)
            fields(rule, {"required", "type", "equals", "one_of", "matches"}, {"type"})
            if not isinstance(rule["type"], str) or rule["type"] not in {"string", "integer", "number", "boolean", "null"}:
                raise ValueError("Invalid parameter type")
            if type(rule.get("required", True)) is not bool:
                raise ValueError("required must be boolean")
            if "matches" in rule:
                if rule["type"] != "string":
                    raise ValueError("Regex requires a string rule")
                safe_pattern(rule["matches"])
            if "one_of" in rule:
                if not isinstance(rule["one_of"], list) or not 1 <= len(rule["one_of"]) <= 100:
                    raise ValueError("Invalid enum")
                reduced = {k: v for k, v in rule.items() if k not in {"one_of", "equals"}}
                if not all(param_ok(item, reduced) for item in rule["one_of"]):
                    raise ValueError("Enum contradicts parameter type/pattern")
            if "equals" in rule and not param_ok(rule["equals"], rule):
                raise ValueError("Equality contradicts parameter rule")
    forbidden, order = value.get("forbidden_events", []), value.get("order", [])
    for items in (forbidden, order):
        if not isinstance(items, list) or len(items) > 500:
            raise ValueError("Invalid event name list")
        for item in items:
            name(item)
    if len(set(forbidden)) != len(forbidden) or names.intersection(forbidden):
        raise ValueError("Duplicate or contradictory forbidden event")
    if any(item not in names for item in order):
        raise ValueError("Order references undeclared event")
    if any(total > limits[item] for item, total in collections.Counter(order).items()):
        raise ValueError("Order contradicts event count")
    return value


def verify_sources(contract, root):
    if contract["approval"]["status"] != "approved":
        raise CaptureIssue("Tracking contract is not approved")
    for source in contract["sources"]:
        try:
            if digest(bounded(Path(root) / source["path"], 10_000_000)) != source["sha256"]:
                raise CaptureIssue("Tracking source changed")
        except OSError:
            raise CaptureIssue("Tracking source unavailable") from None


def context(run_dir):
    data = bounded(Path(run_dir) / "scenario.json", 256_000)
    scenario = decode(data)
    if not isinstance(scenario, dict):
        raise ValueError("Invalid analytics run scenario")
    sid, package = scenario.get("scenario_id"), scenario.get("app_id")
    if not isinstance(sid, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,127}", sid):
        raise ValueError("Invalid QA scenario identity")
    if not isinstance(package, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", package):
        raise ValueError("Invalid QA package")
    return {"scenario_id": sid, "package": package, "scenario_sha256": digest(data)}


def check_raw(data, contract, earliest=0, latest=2 ** 53):
    """Discard ALL parameter values; retain contract-bound boolean checks."""
    try:
        if not data or len(data) > MAX_BYTES:
            raise ValueError("Empty or oversized capture")
        records = [decode(line) for line in data.splitlines() if line.strip()]
        if not 2 <= len(records) <= 20_002 or any(not isinstance(item, dict) for item in records):
            raise ValueError("Invalid event stream")
        ready, complete = records[0], records[-1]
        fields(ready, {"type", "version", "timestamp_ms"}, {"type", "version", "timestamp_ms"})
        fields(complete, {"type", "version", "timestamp_ms", "event_count"},
               {"type", "version", "timestamp_ms", "event_count"})
        if (ready["type"] != "capture_ready" or complete["type"] != "capture_complete" or
                type(ready["version"]) is not int or ready["version"] != 1 or
                type(complete["version"]) is not int or complete["version"] != 1 or
                type(complete["event_count"]) is not int or complete["event_count"] != len(records) - 2):
            raise ValueError("Missing or invalid readiness/flush marker")
        times = [record.get("timestamp_ms") for record in records]
        if any(type(item) is not int or not earliest <= item <= latest for item in times) or times != sorted(times):
            raise ValueError("Invalid or stale capture timestamp")
        specs = {item["name"]: item.get("params", {}) for item in contract["expected_events"]}
        known = set(specs) | set(contract.get("forbidden_events", []))
        checked = []
        for event in records[1:-1]:
            fields(event, {"type", "name", "params", "timestamp_ms"}, {"type", "name", "params", "timestamp_ms"})
            if event["type"] != "event":
                raise ValueError("Unexpected initialization/flush marker")
            name(event["name"])
            if not isinstance(event["params"], dict) or len(event["params"]) > 100:
                raise ValueError("Invalid event parameters")
            for key, val in event["params"].items():
                name(key)
                if scalar_type(val) == "unsupported":
                    raise ValueError("Unsupported parameter payload")
            rules = specs.get(event["name"], {})
            checked.append({
                "name": event["name"] if event["name"] in known else UNKNOWN,
                "params": {key: {"present": key in event["params"],
                                 "valid": key not in event["params"] or param_ok(event["params"][key], rule)}
                           for key, rule in rules.items()},
                "unapproved_params": len(set(event["params"]) - set(rules)) if event["name"] in specs else 0,
            })
        return {"schema_version": 1, "contract_sha256": None, "started_ms": times[0],
                "completed_ms": times[-1], "events": checked}
    except (ValueError, TypeError, RecursionError):
        raise CaptureIssue("Capture is malformed, stale, or lacks a completed flush; no raw content retained") from None


def validate_checked(value, contract, contract_hash):
    try:
        fields(value, {"schema_version", "contract_sha256", "started_ms", "completed_ms", "events"},
               {"schema_version", "contract_sha256", "started_ms", "completed_ms", "events"})
        if (type(value["schema_version"]) is not int or value["schema_version"] != 1 or
                value["contract_sha256"] != contract_hash or
                type(value["started_ms"]) is not int or type(value["completed_ms"]) is not int or
                not 0 <= value["started_ms"] <= value["completed_ms"] <= 2 ** 53 or
                not isinstance(value["events"], list) or len(value["events"]) > 20_000):
            raise ValueError("Invalid checked capture")
        specs = {item["name"]: item.get("params", {}) for item in contract["expected_events"]}
        known = set(specs) | set(contract.get("forbidden_events", [])) | {UNKNOWN}
        for event in value["events"]:
            fields(event, {"name", "params", "unapproved_params"}, {"name", "params", "unapproved_params"})
            if not isinstance(event["name"], str) or event["name"] not in known or not isinstance(event["params"], dict):
                raise ValueError("Unapproved retained data")
            if set(event["params"]) != set(specs.get(event["name"], {})):
                raise ValueError("Parameter checks do not match contract")
            if type(event["unapproved_params"]) is not int or not 0 <= event["unapproved_params"] <= 100:
                raise ValueError("Invalid privacy count")
            for param in event["params"].values():
                fields(param, {"present", "valid"}, {"present", "valid"})
                if any(type(flag) is not bool for flag in param.values()) or (not param["present"] and not param["valid"]):
                    raise ValueError("Invalid parameter check")
    except (ValueError, TypeError, KeyError):
        raise CaptureIssue("Invalid checked capture; no assertions trusted") from None


def evaluate(contract, checked, mode, issue=None):
    report = {"schema_version": 1, "scenario_id": contract["scenario_id"], "mode": mode,
              "status": "INCONCLUSIVE" if issue else "PASS", "capture_issue": issue,
              "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(), "checks": [],
              "event_count": 0, "timeline": [],
              "limitations": ["App-side calls do not prove provider ingestion.",
                              "Scope is app-side analytics contract validation."]}
    if mode == "offline":
        report["limitations"].append("Offline/synthetic validation is not a live app result.")
    if issue:
        return report
    events = checked["events"]
    report["event_count"] = len(events)
    report["timeline"] = [event["name"] for event in events]

    def add(key, ok, detail):
        report["checks"].append({"id": key, "status": "PASS" if ok else "FAIL", "detail": detail})

    for spec in contract["expected_events"]:
        matched = [item for item in events if item["name"] == spec["name"]]
        count, total = spec["count"], len(matched)
        ok = total == count["exact"] if "exact" in count else count.get("min", 0) <= total <= count.get("max", 100_000)
        add("count:" + spec["name"], ok, "Observed count: %d" % total)
        for key, rule in spec.get("params", {}).items():
            if matched:
                missing = sum(not item["params"][key]["present"] for item in matched)
                invalid = sum(not item["params"][key]["valid"] for item in matched)
                add("param:" + spec["name"] + "." + key,
                    (not rule.get("required", True) or missing == 0) and invalid == 0,
                    "Missing: %d; invalid: %d (values discarded)" % (missing, invalid))
    for event_name in contract.get("forbidden_events", []):
        total = sum(item["name"] == event_name for item in events)
        add("forbidden:" + event_name, total == 0, "Observed count: %d" % total)
    unexpected = sum(item["name"] == UNKNOWN for item in events)
    add("unexpected-events", contract.get("allow_unexpected", True) or unexpected == 0,
        "Unexpected event count: %d; names/values discarded" % unexpected)
    order = contract.get("order", [])
    if order:
        cursor = 0
        for event in events:
            if cursor < len(order) and event["name"] == order[cursor]:
                cursor += 1
        add("order", cursor == len(order), "Matched ordered subsequence: %d/%d" % (cursor, len(order)))
    privacy_issues = sum(item["unapproved_params"] for item in events)
    if any(check["status"] == "FAIL" for check in report["checks"]):
        report["status"] = "FAIL"
    if privacy_issues:
        report["checks"].append({"id": "capture-policy", "status": "INCONCLUSIVE",
                                 "detail": "Unapproved parameter keys discarded: %d" % privacy_issues})
        if report["status"] != "FAIL":
            report["status"] = "INCONCLUSIVE"
    return report


def write_new(path, data):
    path = Path(path)
    if path.parent.is_symlink():
        raise ValueError("Output directory cannot be a symlink")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    with os.fdopen(os.open(str(path), flags, 0o600), "wb") as stream:
        stream.write(data)


def json_bytes(value):
    return (json.dumps(value, indent=2, allow_nan=False) + "\n").encode("utf-8")


def render(report):
    lines = ["# Analytics contract report", "", "**Status:** " + report["status"],
             "**Mode:** " + report["mode"], "**Scenario:** " + report["scenario_id"],
             "**Captured events:** " + str(report["event_count"]), ""]
    if report["capture_issue"]:
        lines += ["Capture issue: " + report["capture_issue"], ""]
    lines += ["| Check | Status | Detail |", "|---|---|---|"]
    for check in report["checks"]:
        lines.append("| %s | %s | %s |" % (check["id"], check["status"], check["detail"]))
    lines += ["", "## Limitations", ""] + ["- " + item for item in report["limitations"]]
    return "\n".join(lines) + "\n"


def live_capture(run_dir, contract, ctx, contract_hash, source_root):
    verify_sources(contract, source_root)
    directory = Path(run_dir) / "analytics"
    if any((directory / leaf).exists() for leaf in ("collection-error.json", "reset-error.json")):
        raise CaptureIssue("A failed capture attempt invalidated this run")
    try:
        reset_data = bounded(directory / "reset.json", 64_000)
        receipt = decode(bounded(directory / "collection.json", 64_000))
        reset = decode(reset_data)
        capture_data = bounded(directory / "events.checked.json")
        checked = decode(capture_data)
        reset_fields = {"schema_version", "status", "scenario_id", "package", "scenario_sha256", "contract_sha256", "identity", "started_ms"}
        receipt_fields = {"schema_version", "status", "scenario_id", "package", "scenario_sha256", "contract_sha256", "identity", "reset_sha256", "collected_ms", "raw_sha256", "raw_bytes", "capture_sha256"}
        fields(reset, reset_fields, reset_fields)
        fields(receipt, receipt_fields, receipt_fields)
        if type(receipt["raw_bytes"]) is not int or not 1 <= receipt["raw_bytes"] <= MAX_BYTES:
            raise CaptureIssue("Invalid capture byte count")
        for record in (reset, receipt):
            if not isinstance(record, dict):
                raise CaptureIssue("Invalid receipt")
            if any(record.get(key) != value for key, value in ctx.items()):
                raise CaptureIssue("Receipt scenario mismatch")
            if record.get("contract_sha256") != contract_hash:
                raise CaptureIssue("Receipt contract mismatch")
            if type(record.get("schema_version")) is not int or record["schema_version"] != 1:
                raise CaptureIssue("Unsupported receipt version")
            identity = record.get("identity", {})
            keys = {"serial", "package", "apk_sha256", "api", "version_code"}
            fields(identity, keys, keys)
            if (not isinstance(identity["serial"], str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,119}", identity["serial"]) or
                    type(identity["api"]) is not int or not 1 <= identity["api"] <= 100 or
                    type(identity["version_code"]) is not int or identity["version_code"] < 0 or
                    not isinstance(identity["apk_sha256"], list) or not 1 <= len(identity["apk_sha256"]) <= 50 or
                    any(not isinstance(item, str) or not SHA.fullmatch(item) for item in identity["apk_sha256"])):
                raise CaptureIssue("Invalid target identity")
            if (not isinstance(identity, dict) or identity.get("package") != ctx["package"] or
                    not identity.get("apk_sha256") or not identity.get("serial")):
                raise CaptureIssue("Receipt target identity unavailable")
        if (reset.get("status") != "RESET" or receipt.get("status") != "COLLECTED" or
                receipt.get("reset_sha256") != digest(reset_data) or
                receipt.get("identity") != reset.get("identity") or
                receipt.get("capture_sha256") != digest(capture_data) or
                not isinstance(receipt.get("raw_sha256"), str) or not SHA.fullmatch(receipt["raw_sha256"]) or
                type(reset.get("started_ms")) is not int or type(receipt.get("collected_ms")) is not int):
            raise CaptureIssue("Receipt identity/hash/window mismatch")
        validate_checked(checked, contract, contract_hash)
        if not reset["started_ms"] <= checked["started_ms"] <= checked["completed_ms"] <= receipt["collected_ms"]:
            raise CaptureIssue("Capture window is stale")
        return checked
    except (OSError, ValueError, TypeError, KeyError):
        raise CaptureIssue("Live capture receipts unavailable, mismatched or stale") from None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--capture", type=Path, help="Synthetic/raw capture; only with --offline")
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    if bool(args.capture) != args.offline:
        parser.error("--offline requires --capture; live mode reads collection receipts")
    try:
        contract = load_contract(args.contract)
        ctx = context(args.run_dir)
        if ctx["scenario_id"] != contract["scenario_id"]:
            raise ValueError("Contract and QA scenario differ")
        output = args.run_dir / "analytics"
        if any((output / leaf).exists() for leaf in ("report.json", "report.md")):
            raise ValueError("Report exists; use a fresh run")
        contract_hash = digest(bounded(args.contract, 256_000))
        checked, issue = None, None
        try:
            if args.offline:
                checked = check_raw(bounded(args.capture), contract)
                if contract["approval"]["status"] == "draft":
                    raise CaptureIssue("Tracking expectations are still draft")
            else:
                checked = live_capture(args.run_dir, contract, ctx, contract_hash, args.source_root)
        except (CaptureIssue, OSError, ValueError):
            issue = "Capture, approval or provenance is unavailable/unhealthy; inspect setup"
        report = evaluate(contract, checked, "offline" if args.offline else "live", issue)
        report["provenance"] = {**ctx, "contract_sha256": contract_hash}
        if args.offline and args.capture.is_file():
            try:
                report["provenance"]["input_sha256"] = digest(bounded(args.capture))
            except (ValueError, OSError):
                pass
        write_new(output / "report.json", json_bytes(report))
        write_new(output / "report.md", render(report).encode())
    except (ValueError, OSError, TypeError, RecursionError):
        print("INVALID_INPUT: invalid contract, scenario, output or input bounds", file=sys.stderr)
        return 3
    print("%s: analytics %s (%s)" % (report["status"], report["scenario_id"], report["mode"]))
    return {"PASS": 0, "FAIL": 1, "INCONCLUSIVE": 2}[report["status"]]


if __name__ == "__main__":
    sys.exit(main())
