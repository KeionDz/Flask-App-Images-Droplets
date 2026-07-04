#!/usr/bin/env python3
"""Validate every app's metadata.json and Dockerfile.

Checks, per app dir under apps/:
  * metadata.json exists and is valid JSON
  * required top-level keys are present
  * docker_image / build_path are consistent with the folder
  * Dockerfile, startup.sh and the declared icon exist

Exit code is non-zero if any app fails, so CI / build.py can gate on it.
"""
from __future__ import annotations
import argparse, json, os, sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS_DIR = os.path.join(REPO_ROOT, "apps")

REQUIRED_KEYS = ["slug", "name", "description", "version", "category",
                 "icon", "docker_image", "build_path", "defaults"]
REQUIRED_DEFAULTS = ["cpu_cores", "memory_mb", "network_mode",
                     "persistent_profile", "startup_command"]


def validate_app(slug: str) -> list[str]:
    d = os.path.join(APPS_DIR, slug)
    errs: list[str] = []
    meta_path = os.path.join(d, "metadata.json")
    if not os.path.isfile(meta_path):
        return [f"{slug}: metadata.json missing"]
    try:
        with open(meta_path, encoding="utf-8") as fh:
            meta = json.load(fh)
    except Exception as e:  # noqa: BLE001
        return [f"{slug}: metadata.json invalid JSON: {e}"]

    for k in REQUIRED_KEYS:
        if k not in meta:
            errs.append(f"{slug}: metadata missing key '{k}'")
    if meta.get("slug") not in (slug, None):
        errs.append(f"{slug}: metadata slug '{meta.get('slug')}' != folder")
    if meta.get("build_path") not in (f"apps/{slug}", None):
        errs.append(f"{slug}: build_path '{meta.get('build_path')}' != apps/{slug}")

    defaults = meta.get("defaults", {})
    for k in REQUIRED_DEFAULTS:
        if k not in defaults:
            errs.append(f"{slug}: defaults missing key '{k}'")

    for fname in ("Dockerfile", "startup.sh", meta.get("icon", "icon.png")):
        if not os.path.isfile(os.path.join(d, fname)):
            errs.append(f"{slug}: file '{fname}' missing")
    return errs


def discover() -> list[str]:
    if not os.path.isdir(APPS_DIR):
        return []
    return sorted(
        name for name in os.listdir(APPS_DIR)
        if os.path.isfile(os.path.join(APPS_DIR, name, "metadata.json"))
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate app metadata + files")
    ap.add_argument("--only", help="comma-separated slugs (default: all)")
    args = ap.parse_args()

    slugs = args.only.split(",") if args.only else discover()
    all_errs: list[str] = []
    for slug in slugs:
        errs = validate_app(slug.strip())
        all_errs.extend(errs)
        print(f"  {'FAIL' if errs else 'OK  '}  {slug}")
        for e in errs:
            print(f"        - {e}")
    if all_errs:
        print(f"\nvalidation FAILED: {len(all_errs)} problem(s)")
        return 1
    print(f"\nvalidation OK: {len(slugs)} app(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
