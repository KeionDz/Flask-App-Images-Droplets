# VS Code

Visual Studio Code IDE for development workloads.

- **Image:** `flaskapp-workspace/vscode:1.0`
- **Category:** Development
- **Default resources:** 2 CPU core(s), 4096 MB RAM, 6144 MB disk
- **Launch command:** `code --no-sandbox --unity-launch`

## Build

From the repository root:

```bash
python tools/build.py --only vscode
# or directly:
docker build -f apps/vscode/Dockerfile -t flaskapp-workspace/vscode:1.0 .
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
