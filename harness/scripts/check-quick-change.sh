#!/usr/bin/env bash
# Validate a quick-change workspace record and the diff scope it covers.
# Usage: check-quick-change.sh <change-dir> [--complete] [--base <ref>]
#   default     record is Approved/Archived, entry check complete, diff within lane scope
#   --complete  additionally: Result filled, Archived, fresh review.md with PASS verdict
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: $0 <change-dir> [--complete] [--base <ref>]" >&2; exit 2; }

exec python3 - "$@" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

MAX_PROD_KT = 5
HEADINGS = ["## Intent", "## Entry Check", "## Scenario Affected", "## Files", "## Tests", "## Result"]
ALLOWED = [
    re.compile(r"(^|/)src/main/.*\.kt$"),
    re.compile(r"(^|/)src/test/"),
    re.compile(r"^\.scratch/"),
    re.compile(r"^docs/product/requirements/[^/]+\.md$"),
]
KINDS = ("refactor", "behavior", "bug-fix", "test-only")
CONTRACT_PATH = re.compile(r"(^|/)dto/|Dto\.kt$")
CONTRACT_CODE = re.compile(r"@Entity\b|@Dao\b|@Database\b|\bMigration\(|retrofit2\.http")
AC_ID = re.compile(r"^#### Scenario:\s*(AC-\d+)", re.M)

args = sys.argv[1:]
change_dir = Path(args.pop(0)).resolve()
complete = False
base = None
while args:
    a = args.pop(0)
    if a == "--complete":
        complete = True
    elif a == "--base" and args:
        base = args.pop(0)
    else:
        print(f"unknown argument: {a}", file=sys.stderr)
        sys.exit(2)

errors = []

def fail(msg):
    errors.append(msg)

def git(*cmd, check=True):
    r = subprocess.run(["git", "-C", str(root), *cmd], capture_output=True, text=True)
    if check and r.returncode != 0:
        raise SystemExit(f"FAIL: git {' '.join(cmd)}: {r.stderr.strip()}")
    return r

def section(text, heading):
    m = re.search(rf"^{re.escape(heading)}\s*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1).strip() if m else None

intent_path = change_dir / "intent.md"
if not intent_path.is_file():
    print(f"FAIL: {change_dir} has no intent.md", file=sys.stderr)
    sys.exit(1)
text = intent_path.read_text()

# --- record ---
if not re.search(r"^\*\*Lane\*\*:\s*quick-change\s*$", text, re.M):
    fail("intent.md must declare '**Lane**: quick-change'")
status_m = re.search(r"^\*\*Status\*\*:\s*(.*)$", text, re.M)
status = status_m.group(1).strip() if status_m else ""
if not re.match(r"(Approved|Archived)\b", status):
    fail(f"intent.md **Status** must be Approved or Archived (found '{status or 'none'}')")
kind_m = re.search(r"^\*\*Kind\*\*:\s*(\S+)\s*$", text, re.M)
kind = kind_m.group(1) if kind_m else ""
if kind not in KINDS:
    fail(f"intent.md **Kind** must be one of {', '.join(KINDS)} (found '{kind or 'none'}')")
for h in HEADINGS:
    if section(text, h) is None:
        fail(f"intent.md is missing '{h}'")

entry = section(text, "## Entry Check") or ""
if re.search(r"^\s*-\s*\[ \]", entry, re.M):
    fail("Entry Check has an unchecked item; route to harness-planning or bug-fixing")
if len(re.findall(r"^\s*-\s*\[[xX]\]", entry, re.M)) < 5:
    fail("Entry Check must keep all five checked items")

root = Path(subprocess.run(["git", "-C", str(change_dir), "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, check=True).stdout.strip())

scenario = section(text, "## Scenario Affected") or ""
specs = sorted((change_dir / "specs").glob("*.md")) if (change_dir / "specs").is_dir() else []
tests = section(text, "## Tests") or ""
if not scenario or scenario.startswith("<"):
    fail("Scenario Affected is not filled in")
elif kind in ("refactor", "test-only"):
    if not re.match(r"None\b", scenario):
        fail(f"a {kind} must declare 'Scenario Affected: None — {kind}'")
    if specs:
        fail(f"a {kind} must not have specs/ deltas")
elif kind in ("behavior", "bug-fix"):
    if not re.search(r"[\w-]+\.md#AC-\d+", scenario):
        fail(f"a {kind} must cite '<capability>.md#AC-###' under Scenario Affected")
    if not (re.search(r"\bRED:", tests) and re.search(r"\bGREEN:", tests)):
        fail(f"a {kind} must record 'RED:' and 'GREEN:' runs under Tests")
    if kind == "bug-fix" and specs:
        fail("a bug-fix restores specified behavior and must not have specs/ deltas")
if kind == "behavior":
    if len(specs) != 1:
        fail(f"a behavior change needs exactly one specs/<capability>.md delta (found {len(specs)})")
    for p in specs:
        d = p.read_text()
        if "## ADDED Requirements" in d or "## REMOVED Requirements" in d:
            fail(f"specs/{p.name}: quick-change deltas may only MODIFY an existing requirement")
        if "## MODIFIED Requirements" not in d:
            fail(f"specs/{p.name}: missing '## MODIFIED Requirements'")
        n = len(re.findall(r"^### Requirement:", d, re.M))
        if n != 1:
            fail(f"specs/{p.name}: must modify exactly one requirement (found {n})")
        living = root / "docs/product/requirements" / p.name
        if not living.is_file():
            fail(f"specs/{p.name}: living capability file {living.relative_to(root)} not found")
        else:
            new_acs = set(AC_ID.findall(d)) - set(AC_ID.findall(living.read_text()))
            if len(new_acs) > 1:
                fail(f"specs/{p.name}: adds {len(new_acs)} new scenarios ({', '.join(sorted(new_acs))}); limit 1")

if complete:
    result = section(text, "## Result") or ""
    if not result or result.startswith("<"):
        fail("Result must record gate commands, exit codes, and test counts")
    if not status.startswith("Archived"):
        fail("--complete requires **Status**: Archived")
    review = change_dir / "review.md"
    if not review.is_file():
        fail("--complete requires review.md from a fresh evaluator")
    else:
        rv = review.read_text()
        if not re.search(r"^\*\*Verdict\*\*:\s*PASS\b", rv, re.M):
            fail("review.md must record '**Verdict**: PASS'")
        if not re.search(r"^\*\*Reviewer\*\*:\s*\S", rv, re.M):
            fail("review.md must name the '**Reviewer**:'")

# --- diff scope ---
if base is None:
    for cand in ("origin/HEAD", "origin/main", "main", "origin/master", "master"):
        if git("rev-parse", "--verify", "-q", cand, check=False).returncode == 0:
            base = cand
            break
if base is None:
    print("FAIL: no base ref found; pass --base <ref>", file=sys.stderr)
    sys.exit(1)
mb = git("merge-base", "HEAD", base).stdout.strip()
changed = set(git("diff", "--name-only", mb).stdout.split())
changed |= set(git("ls-files", "--others", "--exclude-standard").stdout.split())

prod_kt = []
for path in sorted(changed):
    if not any(p.search(path) for p in ALLOWED):
        fail(f"{path}: outside quick-change scope (only src/main Kotlin, src/test, .scratch, living requirements)")
        continue
    if re.search(r"(^|/)src/main/.*\.kt$", path):
        if CONTRACT_PATH.search(path):
            fail(f"{path}: DTO/API contract changes are outside quick-change scope")
        prod_kt.append(path)
        f = root / path
        src = f.read_text() if f.is_file() else ""
        if "@Composable" in src:
            fail(f"{path}: contains @Composable; UI changes use design-to-ui or harness-planning")
        m = CONTRACT_CODE.search(src)
        if m:
            fail(f"{path}: contains {m.group(0)}; schema/DAO/migration/API changes are outside quick-change scope")
if kind == "test-only" and prod_kt:
    fail(f"a test-only change must not modify production code ({len(prod_kt)} file(s))")
if len(prod_kt) > MAX_PROD_KT:
    fail(f"{len(prod_kt)} production Kotlin files changed (limit {MAX_PROD_KT})")

if errors:
    for e in errors:
        print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
mode = "complete" if complete else "scope"
print(f"PASS: quick-change {change_dir.name} ({kind}, {mode}; {len(prod_kt)} production Kotlin file(s) vs {base})")
PY
