#!/usr/bin/env python3
"""Aggregate every apps/*/metadata.json into a single registry.json.

The Flask app auto-discovers apps by scanning the folders directly (so adding a
folder needs no code change), but this generated registry.json is a convenient
static snapshot for tooling, CI and quick inspection.
"""
from __future__ import annotations
import json, os, sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS_DIR = os.path.join(REPO_ROOT, "apps")
OUT = os.path.join(REPO_ROOT, "registry.json")


def build() -> dict:
    apps = []
    for name in sorted(os.listdir(APPS_DIR)):
        meta_path = os.path.join(APPS_DIR, name, "metadata.json")
        if not os.path.isfile(meta_path):
            continue
        with open(meta_path, encoding="utf-8") as fh:
            apps.append(json.load(fh))
    return {"vendor": "Flask-App-Workspace", "version": "1.0", "count": len(apps),
            "workspaces": apps}


def main() -> int:
    registry = build()
    with open(OUT, "w", newline="\n", encoding="utf-8") as fh:
        json.dump(registry, fh, indent=2)
        fh.write("\n")
    print(f"wrote {OUT} ({registry['count']} app(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
