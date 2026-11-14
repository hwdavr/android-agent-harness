#!/usr/bin/env python3
"""Extract a state's design layout from an OpenPencil `.fig` source (adapter script for `openpencil`).

Usage: openpencil_layout.py --source <file.fig> --node <top-level-frame-id> --out <state>.layout.json

Reads the source read-only through `openpencil eval` (Figma plugin API) and writes the tool-neutral
layout described in harness/templates/design-layout-template.json. Coordinates are relative to the
frame. Text box widths of auto-width text can be stale in the source; rely on text size, line
height, gaps and paddings, not on text box widths. Fails loudly when the CLI is missing or the node
does not resolve to a top-level frame.
"""

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

JS = """
const root = figma.getNodeById(%(node)s);
if (!root) throw new Error('node not found');
const nodes = [];
function walk(n, path, px, py, isRoot) {
  const ax = isRoot ? 0 : px + (n.x || 0), ay = isRoot ? 0 : py + (n.y || 0);
  const rec = {id: n.id, path: path, name: n.name, type: n.type,
               x: ax, y: ay, width: n.width, height: n.height};
  if (n.layoutMode && n.layoutMode !== 'NONE') {
    rec.layout = {mode: n.layoutMode, gap: n.itemSpacing,
                  padding: [n.paddingTop, n.paddingRight, n.paddingBottom, n.paddingLeft]};
  }
  if (n.type === 'TEXT') {
    const lh = n.lineHeight || {};
    rec.text = {characters: n.characters, fontFamily: n.fontName && n.fontName.family,
                fontStyle: n.fontName && n.fontName.style, fontSize: n.fontSize,
                lineHeight: lh.unit === 'PIXELS' ? lh.value : 'auto'};
  }
  nodes.push(rec);
  (n.children || []).forEach(c => walk(c, path + '/' + c.name, ax, ay, false));
}
walk(root, root.name, 0, 0, true);
return JSON.stringify({parentType: root.parent && root.parent.type, nodes: nodes});
"""


def fail(message):
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--node", required=True)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    if shutil.which("openpencil") is None:
        fail("openpencil CLI is not installed; cannot extract layout (never substitute another tool)")
    if args.source.suffix != ".fig" or not args.source.is_file():
        fail(f"source must be an existing .fig file: {args.source}")
    run = subprocess.run(["openpencil", "eval", str(args.source), "--stdin"],
                         input=JS % {"node": json.dumps(args.node)}, capture_output=True, text=True)
    if run.returncode:
        fail(f"openpencil eval failed for node {args.node}: {run.stdout.strip()} {run.stderr.strip()}")
    try:
        data = json.loads(json.loads(run.stdout.strip()))
    except (json.JSONDecodeError, TypeError) as error:
        fail(f"unexpected openpencil eval output: {error}: {run.stdout[:200]}")
    nodes = data["nodes"]
    frame = nodes[0]
    if data.get("parentType") not in ("PAGE", "CANVAS"):
        fail(f"node {args.node} ({frame['name']}) is not a top-level screen frame (parent {data.get('parentType')})")
    layout = {
        "version": 1,
        "tool": "openpencil",
        "source": args.source.as_posix(),
        "source_sha256": hashlib.sha256(args.source.read_bytes()).hexdigest(),
        "frame": {"id": frame["id"], "name": frame["name"], "width": frame["width"], "height": frame["height"]},
        "nodes": nodes,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(layout, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: wrote {args.out} ({len(nodes)} nodes, frame {frame['id']} {frame['width']}x{frame['height']})")


if __name__ == "__main__":
    main()
