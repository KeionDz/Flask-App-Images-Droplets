# Firefox Browser

Mozilla Firefox in an isolated, disposable workspace.

- **Image:** `flaskapp-workspace/firefox:1.0`
- **Category:** Browser
- **Default resources:** 1 CPU core(s), 2048 MB RAM, 4096 MB disk
- **Launch command:** `firefox`

## Build

From the repository root:

```bash
python tools/build.py --only firefox
# or directly:
docker build -f apps/firefox/Dockerfile -t flaskapp-workspace/firefox:1.0 .
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
