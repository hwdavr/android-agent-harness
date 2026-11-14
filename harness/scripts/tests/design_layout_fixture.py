"""Test helper: write a valid tool-neutral design layout file next to a fixture design image."""

import hashlib
import json
import sys
from pathlib import Path

TOOLS = {".pen": "pen.dev", ".fig": "openpencil"}


def write_layout(source, node, width, height, out, source_text=None):
    source = Path(source)
    data = source.read_bytes()
    layout = {
        "version": 1,
        "tool": TOOLS[source.suffix],
        "source": source.name,
        "source_sha256": hashlib.sha256(data).hexdigest(),
        "frame": {"id": node, "name": node, "width": width, "height": height},
        "nodes": [{"id": node, "path": node, "name": node, "type": "FRAME",
                   "x": 0, "y": 0, "width": width, "height": height}],
    }
    Path(out).write_text(json.dumps(layout), encoding="utf-8")


if __name__ == "__main__":
    write_layout(sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5])
