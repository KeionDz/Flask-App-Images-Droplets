# LibreOffice

Full office suite — documents, spreadsheets, presentations.

- **Image:** `flaskapp-workspace/libreoffice:1.0`
- **Category:** Productivity
- **Default resources:** 2 CPU core(s), 4096 MB RAM, 6144 MB disk
- **Launch command:** `libreoffice`

## Build

From the repository root:

```bash
python tools/build.py --only libreoffice
# or directly:
docker build -f apps/libreoffice/Dockerfile -t flaskapp-workspace/libreoffice:1.0 .
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
