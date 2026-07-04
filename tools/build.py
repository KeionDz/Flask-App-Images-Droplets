#!/usr/bin/env python3
"""Build workspace images from this repository.

Always builds the shared base (flaskapp-workspace/core) first, then the selected
apps. The build context is the repo root so app Dockerfiles can reference base/.

Usage:
  python tools/build.py --all                 # base + every app
  python tools/build.py --only firefox,chrome # base + those apps
  python tools/build.py --validate            # validate metadata only, no build
  python tools/build.py --all --report out.json
  python tools/build.py --all --no-base       # skip rebuilding the base
"""
from __future__ import annotations
import argparse, json, os, subprocess, sys, time

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS_DIR = os.path.join(REPO_ROOT, "apps")
BASE_IMAGE = "flaskapp-workspace/core:1.0"
BASE_DOCKERFILE = "base/Dockerfile"

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import validate as _validate  # noqa: E402


def discover() -> list[str]:
    return _validate.discover()


def _run_build(dockerfile: str, tag: str) -> tuple[bool, str, float]:
    t0 = time.time()
    env = dict(os.environ, DOCKER_BUILDKIT="1")
    proc = subprocess.run(
        ["docker", "build", "-f", dockerfile, "-t", tag, "."],
        cwd=REPO_ROOT, env=env, capture_output=True, text=True,
    )
    dt = time.time() - t0
    tail = (proc.stdout + proc.stderr).strip().splitlines()[-4:]
    return proc.returncode == 0, "\n".join(tail), dt


def _image_size(tag: str) -> str:
    p = subprocess.run(["docker", "images", tag, "--format", "{{.Size}}"],
                       capture_output=True, text=True)
    return p.stdout.strip() or "?"


def main() -> int:
    ap = argparse.ArgumentParser(description="Build workspace images")
    ap.add_argument("--all", action="store_true", help="build every app")
    ap.add_argument("--only", help="comma-separated slugs to build")
    ap.add_argument("--no-base", action="store_true", help="do not (re)build the base")
    ap.add_argument("--validate", action="store_true", help="validate only, do not build")
    ap.add_argument("--report", help="write a JSON build report to this path")
    args = ap.parse_args()

    print("== validating metadata ==")
    if _run_validation() != 0:
        return 1
    if args.validate:
        return 0

    if args.only:
        slugs = [s.strip() for s in args.only.split(",")]
    elif args.all:
        slugs = discover()
    else:
        print("nothing to build: pass --all or --only slug,...")
        return 2

    report = {"base": None, "apps": [], "started": time.strftime("%Y-%m-%dT%H:%M:%S")}
    ok_all = True

    if not args.no_base:
        print(f"\n== building base {BASE_IMAGE} ==")
        ok, tail, dt = _run_build(BASE_DOCKERFILE, BASE_IMAGE)
        report["base"] = {"image": BASE_IMAGE, "ok": ok, "seconds": round(dt, 1),
                          "size": _image_size(BASE_IMAGE) if ok else None, "tail": tail}
        print(f"   {'OK' if ok else 'FAIL'} ({dt:.0f}s)")
        if not ok:
            print(tail)
            _write_report(args.report, report)
            return 1

    for slug in slugs:
        meta_path = os.path.join(APPS_DIR, slug, "metadata.json")
        with open(meta_path, encoding="utf-8") as fh:
            meta = json.load(fh)
        tag = meta["docker_image"]
        dockerfile = f"{meta['build_path']}/Dockerfile"
        print(f"\n== building {slug} -> {tag} ==")
        ok, tail, dt = _run_build(dockerfile, tag)
        entry = {"slug": slug, "image": tag, "ok": ok, "seconds": round(dt, 1),
                 "size": _image_size(tag) if ok else None, "tail": tail}
        report["apps"].append(entry)
        ok_all = ok_all and ok
        print(f"   {'OK' if ok else 'FAIL'} ({dt:.0f}s){'  ' + entry['size'] if ok else ''}")
        if not ok:
            print(tail)

    built = sum(1 for a in report["apps"] if a["ok"])
    failed = sum(1 for a in report["apps"] if not a["ok"])
    print(f"\n== summary: {built} built, {failed} failed ==")
    _write_report(args.report, report)
    return 0 if ok_all else 1


def _run_validation() -> int:
    """Validate all apps via validate.py helpers (0 == ok). Avoids argv parsing."""
    all_errs = []
    for slug in discover():
        errs = _validate.validate_app(slug)
        all_errs.extend(errs)
        print(f"  {'FAIL' if errs else 'OK  '}  {slug}")
        for e in errs:
            print(f"        - {e}")
    return 1 if all_errs else 0


def _write_report(path: str | None, report: dict) -> None:
    if not path:
        return
    with open(path, "w", newline="\n", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)
        fh.write("\n")
    print(f"report -> {path}")


if __name__ == "__main__":
    sys.exit(main())
