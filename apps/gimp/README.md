# GIMP

GNU Image Manipulation Program for photo editing.

- **Image:** `flaskapp-workspace/gimp:1.0`
- **Category:** Graphics
- **Default resources:** 2 CPU core(s), 4096 MB RAM, 6144 MB disk
- **Launch command:** `gimp`

## Build

From the repository root:

```bash
python tools/build.py --only gimp
# or directly:
docker build -f apps/gimp/Dockerfile -t flaskapp-workspace/gimp:1.0 .
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Builds the image FROM `flaskapp-workspace/core:1.0`. |
| `startup.sh` | Per-app runtime hook (sourced by the base session; sets `APP_CMD`). |
| `metadata.json` | Registry metadata + admin-configurable defaults. |
| `icon.png` | Catalog icon. |

Window behaviour and audio come from the shared base image; closing the app
window relaunches it (the workspace stays alive until ended from the web app).
