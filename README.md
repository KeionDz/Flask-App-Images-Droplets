# Flask-App-Images-Droplet

Dedicated repository for the Flask workspace platform's **own** browser-streaming
Docker images. Nothing here pulls or depends on `kasmweb/*`, `ghcr.io/kasmtech/*`,
Kasm registries, Kasm Dockerfiles or Kasm startup scripts. The Flask app consumes
this repository (bind-mounted at `/app/images-repo`) and **auto-discovers** apps —
adding a new workspace requires only a new folder here, no Flask code change.

## Layout

```
base/                     Shared core image (flaskapp-workspace/core:1.0)
  Dockerfile              Ubuntu 22.04 + minimal XFCE + KasmVNC server + audio
  startup.sh              Container entrypoint (VNC + PulseAudio->ffmpeg->jsmpeg relay)
  xstartup                Minimal desktop session; sources per-app hook; runs supervisor
  lib/app-supervisor.sh   Relaunch loop — closing the app never ends the workspace
  config/xfce4-panel.xml  Single taskbar panel
  audio/websocket-relay.js  Zero-dep jsmpeg audio relay
apps/<slug>/              One folder per application
  Dockerfile              FROM flaskapp-workspace/core:1.0; installs the app; sets APP_CMD
  startup.sh              Per-app runtime hook (sourced by base xstartup)
  metadata.json           Registry metadata + admin-configurable defaults
  icon.png                Catalog icon
  README.md               Per-app docs
tools/                    build.py / validate.py / generate_registry.py
registry.json             Generated aggregate of all apps/*/metadata.json
```

## Build

Build context is always the **repo root**.

```bash
python tools/build.py --all                  # base + every app
python tools/build.py --only firefox,chrome  # base + selected apps
python tools/build.py --validate             # validate metadata only
python tools/generate_registry.py            # refresh registry.json
```

## Design highlights

- **No forced maximize/fullscreen** — apps open as normal, movable, resizable
  windows (the base un-maximizes the first window once).
- **No-close policy** — `lib/app-supervisor.sh` relaunches the app if the user
  closes it; the container lives until the workspace is ended from the web app.
- **Audio** — a virtual PulseAudio sink is captured by ffmpeg (MPEG-TS) and fanned
  out over a plain-ws jsmpeg relay on `:4901`, which the app's nginx proxies to the
  browser.
- **Persistent profiles** — the app mounts a per-(user, image) named volume at the
  home dir when the image's *Persistent Profile* toggle is ON (admin dashboard).

## Adding a new application

1. `mkdir apps/<slug>` and add `Dockerfile`, `startup.sh`, `metadata.json`,
   `icon.png`, `README.md` (copy an existing app as a template).
2. `python tools/build.py --only <slug>`.
3. Restart the Flask `web` container — the new app auto-appears in the catalog and
   admin dashboard. No Flask code changes.
