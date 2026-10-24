#!/usr/bin/env python3
"""Android debug analytics capture. No app instrumentation is installed by this helper."""
from __future__ import annotations
import argparse
import os
import re
import selectors
import subprocess
import sys
import time
from pathlib import Path

from validate import (MAX_BYTES, CaptureIssue, bounded, check_raw, context, decode,
                      digest, fields, json_bytes, load_contract, verify_sources, write_new)

REMOTE_FILE = "files/analytics-events.ndjson"


def command(argv, limit=256_000, timeout=20):
    """Bound process time and stdout bytes; never echo raw device stderr."""
    process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline, output = time.monotonic() + timeout, bytearray()
    try:
        while selector.get_map():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise CaptureIssue("ADB operation timed out")
            for key, _ in selector.select(min(remaining, 0.25)):
                chunk = os.read(key.fileobj.fileno(), min(65536, limit + 1 - len(output)))
                if not chunk:
                    selector.unregister(key.fileobj)
                else:
                    output.extend(chunk)
                    if len(output) > limit:
                        raise CaptureIssue("ADB output exceeds byte limit")
        try:
            code = process.wait(timeout=max(0.01, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            raise CaptureIssue("ADB operation timed out") from None
        if code:
            raise CaptureIssue("ADB operation failed; check device, package and debug recorder")
        return bytes(output)
    finally:
        selector.close()
        if process.poll() is None:
            process.kill()
        process.wait()
        process.stdout.close()


class Android:
    def __init__(self, serial, package):
        if not isinstance(serial, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,119}", serial):
            raise ValueError("Explicit valid Android serial required")
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", package):
            raise ValueError("Invalid package")
        self.serial, self.package = serial, package

    def run(self, *args, limit=256_000):
        return command(["adb", "-s", self.serial, *args], limit=limit)

    def identity(self):
        if self.run("get-state").strip() != b"device":
            raise CaptureIssue("Selected device is not ready")
        paths = self.run("shell", "pm", "path", self.package).decode("utf-8").splitlines()
        if not paths or len(paths) > 50:
            raise CaptureIssue("Installed APK unavailable")
        hashes = []
        for line in paths:
            if not line.startswith("package:"):
                raise CaptureIssue("Invalid package path")
            path = line[len("package:"):]
            if not re.fullmatch(r"/[A-Za-z0-9_./+=~-]+\.apk", path):
                raise CaptureIssue("Unsupported APK path")
            data = self.run("shell", "sha256sum", path).decode("ascii")
            match = re.match(r"([a-f0-9]{64})\s", data)
            if not match:
                raise CaptureIssue("Installed APK hash unavailable")
            hashes.append(match.group(1))
        package_info = self.run("shell", "dumpsys", "package", self.package).decode("utf-8")
        version = re.search(r"\bversionCode=(\d+)", package_info)
        sdk = self.run("shell", "getprop", "ro.build.version.sdk").strip()
        if not version or not sdk.isdigit():
            raise CaptureIssue("Installed package metadata unavailable")
        self.run("shell", "run-as", self.package, "id")
        return {"serial": self.serial, "package": self.package, "version_code": int(version.group(1)),
                "apk_sha256": sorted(hashes), "api": int(sdk)}

    def inspect_recorder(self):
        self.run("shell", "run-as", self.package, "test", "-f", REMOTE_FILE)
        data = self.run("exec-out", "run-as", self.package, "head", "-c", "512", REMOTE_FILE, limit=512)
        try:
            ready = decode(data.splitlines()[0])
            if (not isinstance(ready, dict) or set(ready) != {"type", "version", "timestamp_ms"} or
                    ready["type"] != "capture_ready" or type(ready["version"]) is not int or
                    ready["version"] != 1 or type(ready["timestamp_ms"]) is not int):
                raise ValueError("Unsupported marker")
        except (ValueError, IndexError):
            raise CaptureIssue("No compatible debug recorder marker") from None

    def clock_ms(self):
        data = self.run("shell", "date", "+%s").strip()
        if not data.isdigit():
            raise CaptureIssue("Device clock unavailable")
        return int(data) * 1000

    def reset(self):
        self.run("shell", "am", "force-stop", self.package)
        self.run("shell", "run-as", self.package, "rm", "-f", REMOTE_FILE)

    def collect(self):
        return self.run("exec-out", "run-as", self.package, "head", "-c", str(MAX_BYTES + 1),
                        REMOTE_FILE, limit=MAX_BYTES)


def execute(action, run_dir, serial, contract_path=None, source_root=Path.cwd()):
    ctx = context(run_dir)
    output = Path(run_dir) / "analytics"
    if output.is_symlink():
        raise ValueError("Analytics directory cannot be a symlink")
    output.mkdir(mode=0o700, parents=True, exist_ok=True)
    target = Android(serial, ctx["package"])
    if action == "inspect":
        if (output / "capability.json").exists():
            raise ValueError("Capability receipt exists; use a fresh run")
        result = {**ctx, "schema_version": 1, "status": "INCONCLUSIVE", "identity": None,
                  "capability": "Existing debuggable Android recorder only",
                  "limitation": "No instrumentation installed; app-side capture is not provider delivery."}
        try:
            result["identity"] = target.identity()
            target.inspect_recorder()
            result["status"] = "AVAILABLE"
        except (CaptureIssue, OSError, UnicodeError):
            result["issue"] = "Package/debug sandbox or compatible recorder is unavailable"
        write_new(output / "capability.json", json_bytes(result))
        return 0 if result["status"] == "AVAILABLE" else 2

    if not contract_path:
        raise ValueError("Reset/collect require an approved contract")
    contract = load_contract(contract_path)
    if contract["scenario_id"] != ctx["scenario_id"]:
        raise ValueError("Contract and QA scenario differ")
    contract_hash = digest(bounded(contract_path, 256_000))
    protected = ["collection.json", "events.checked.json", "collection-error.json", "reset-error.json"]
    if action == "reset":
        protected += ["reset.json", "report.json", "report.md"]
    if any((output / leaf).exists() for leaf in protected):
        if action == "collect" and not (output / "collection-error.json").exists():
            write_new(output / "collection-error.json", json_bytes({"status": "INCONCLUSIVE", "issue": "Reused capture output"}))
        raise ValueError("Used analytics output; use a fresh run")
    try:
        verify_sources(contract, source_root)
        identity = target.identity()
        if action == "reset":
            target.inspect_recorder()
            target.reset()
            started = target.clock_ms()
            write_new(output / "reset.json", json_bytes({
                **ctx, "schema_version": 1, "status": "RESET", "contract_sha256": contract_hash,
                "identity": identity, "started_ms": started}))
            return 0

        reset_data = bounded(output / "reset.json", 64_000)
        reset = decode(reset_data)
        keys = {"schema_version", "status", "scenario_id", "package", "scenario_sha256", "contract_sha256", "identity", "started_ms"}
        fields(reset, keys, keys)
        if (type(reset.get("schema_version")) is not int or reset["schema_version"] != 1 or not isinstance(reset, dict) or reset.get("status") != "RESET" or
                reset.get("identity") != identity or reset.get("contract_sha256") != contract_hash or
                type(reset.get("started_ms")) is not int or
                any(reset.get(key) != value for key, value in ctx.items())):
            raise CaptureIssue("Reset receipt target/scenario/contract differs")
        raw = target.collect()
        collected = target.clock_ms() + 999
        checked = check_raw(raw, contract, reset["started_ms"], collected)
        checked["contract_sha256"] = contract_hash
        if target.identity() != identity:
            raise CaptureIssue("Installed build changed during collection")
        checked_data = json_bytes(checked)
        if len(checked_data) > MAX_BYTES:
            raise CaptureIssue("Checked evidence exceeds byte limit")
        write_new(output / "events.checked.json", checked_data)
        write_new(output / "collection.json", json_bytes({
            **ctx, "schema_version": 1, "status": "COLLECTED", "contract_sha256": contract_hash,
            "identity": identity, "reset_sha256": digest(reset_data), "collected_ms": collected,
            "raw_sha256": digest(raw), "raw_bytes": len(raw), "capture_sha256": digest(checked_data)}))
        return 0
    except (CaptureIssue, OSError, ValueError, UnicodeError):
        leaf = "collection-error.json" if action == "collect" else "reset-error.json"
        write_new(output / leaf, json_bytes({
            **ctx, "schema_version": 1, "status": "INCONCLUSIVE",
            "issue": "Capture unavailable, unapproved, incomplete or provenance changed; no raw content retained"}))
        return 2


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("inspect", "reset", "collect"))
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--contract", type=Path)
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    try:
        result = execute(args.action, args.run_dir, args.serial, args.contract, args.source_root)
    except (ValueError, OSError, TypeError, RecursionError):
        print("INVALID_INPUT: invalid target, scenario, contract or reused output", file=sys.stderr)
        return 3
    print("%s: analytics capture %s" % ("READY" if result == 0 else "INCONCLUSIVE", args.action))
    return result


if __name__ == "__main__":
    sys.exit(main())
