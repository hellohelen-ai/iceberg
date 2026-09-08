#!/usr/bin/env python3
"""Remove legacy iceberg handlers while preserving other Cursor hooks/settings."""
import json
from pathlib import Path
import shlex
import sys


def is_iceberg(handler):
    if not isinstance(handler, dict) or not isinstance(handler.get("command"), str):
        return False
    try:
        words = shlex.split(handler["command"])
    except ValueError:
        return False
    return any(word.endswith("/hooks/cursor-context.sh") for word in words)


def clean(path):
    try:
        data = json.loads(path.read_text())
        hooks = data.get("hooks")
        if not isinstance(hooks, dict):
            return
    except (ValueError, AttributeError):
        print(f"  left {path} unchanged: could not parse hooks; legacy iceberg hook is inert.")
        return
    changed = False
    for event, handlers in list(hooks.items()):
        if not isinstance(handlers, list):
            continue
        kept = [handler for handler in handlers if not is_iceberg(handler)]
        if len(kept) == len(handlers):
            continue
        changed = True
        if kept:
            hooks[event] = kept
        else:
            del hooks[event]
    if not changed:
        return
    if not hooks and set(data) <= {"version", "hooks"}:
        path.unlink()
    else:
        path.write_text(json.dumps(data, indent=2) + "\n")
    print(f"  removed legacy iceberg hooks from {path}")


if __name__ == "__main__":
    clean(Path(sys.argv[1]))
