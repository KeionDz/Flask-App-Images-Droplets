# Chrome Browser

Google Chrome in an isolated, disposable workspace.

- **Image:** `flaskapp-workspace/chrome:1.0`
- **Category:** Browser
- **Default resources:** 1 CPU core(s), 2048 MB RAM, 4096 MB disk
- **Launch command:** `google-chrome --no-sandbox --no-first-run --no-default-browser-check`

## Build

From the repository root:

```bash
python tools/build.py --only chrome
# or directly:
docker build -f apps/chrome/Dockerfile -t flaskapp-workspace/chrome:1.0 .
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
