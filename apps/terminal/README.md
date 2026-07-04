# Terminal

Minimal Linux shell (xfce4-terminal) in a browser tab.

- **Image:** `flaskapp-workspace/terminal:1.0`
- **Category:** Development
- **Default resources:** 1 CPU core(s), 1024 MB RAM, 2048 MB disk
- **Launch command:** `xfce4-terminal`

## Build

From the repository root:

```bash
python tools/build.py --only terminal
# or directly:
docker build -f apps/terminal/Dockerfile -t flaskapp-workspace/terminal:1.0 .
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
