# syntax=docker/dockerfile:1
# flaskapp-workspace/firefox:1.0 — built FROM our own core base (no kasm images).
# Build context is the REPO ROOT:
#   docker build -f apps/firefox/Dockerfile -t flaskapp-workspace/firefox:1.0 .
FROM flaskapp-workspace/core:1.0
USER root
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends wget gnupg \
    && install -d -m 0755 /etc/apt/keyrings \
    && wget -qO /etc/apt/keyrings/packages.mozilla.org.asc https://packages.mozilla.org/apt/repo-signing-key.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main' > /etc/apt/sources.list.d/mozilla.list \
    && printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla \
    && apt-get update && apt-get install -y --no-install-recommends firefox \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# System-wide default prefs (apply to EVERY profile, including first run):
# force software WebRender — these containers have no GPU, and Firefox's
# cached hardware-GPU decision in a persistent profile otherwise renders
# blank page content on the next session. Also skip session-restore nags.
#
# NOTE: current Firefox does not read /usr/lib/firefox/defaults/pref/*.js — that
# is why apps/firefox/startup.sh re-applies those same prefs into each profile's
# user.js. Anything that must actually take effect goes in policies.json below.
#
# browser.startup.page = 3 reopens the tabs the user left open, so relaunching a
# workspace comes back exactly where they were instead of on a blank window (the
# Chrome image does the same via the RestoreOnStartup managed policy). It only
# works because the graceful stop CLOSES the browser window: Firefox writes
# sessionstore.jsonlz4 on a clean quit and has nothing to restore after a SIGKILL.
# Status "default" so the user can still change it in Preferences.
# resume_from_crash stays false — that governs the nag after an *unclean* exit.
#
# The browser.download.* prefs pin downloads to ~/Downloads and are "locked", not
# "default": the platform mirrors exactly that folder into object storage
# (services/downloads_service.py), so a user who redirected downloads to the Desktop
# would find their files were silently never mirrored. folderList=2 means "use
# browser.download.dir"; useDownloadDir=true skips the save-as prompt.
RUN install -d /usr/lib/firefox/defaults/pref /usr/lib/firefox/distribution \
    && printf '%s\n' \
      'pref("gfx.webrender.software", true);' \
      'pref("layers.acceleration.disabled", true);' \
      'pref("browser.sessionstore.resume_from_crash", false);' \
      'pref("toolkit.startup.max_resumed_crashes", -1);' \
      > /usr/lib/firefox/defaults/pref/faw-workspace.js \
    && printf '%s\n' \
      '{' \
      '  "policies": {' \
      '    "DisableAppUpdate": true,' \
      '    "OverrideFirstRunPage": "",' \
      '    "OverridePostUpdatePage": "",' \
      '    "SkipTermsOfUse": true,' \
      '    "Preferences": {' \
      '      "browser.startup.page": { "Value": 3, "Status": "default" },' \
      '      "browser.download.folderList": { "Value": 2, "Status": "locked" },' \
      '      "browser.download.dir": { "Value": "/home/flaskapp-user/Downloads", "Status": "locked" },' \
      '      "browser.download.useDownloadDir": { "Value": true, "Status": "locked" }' \
      '    }' \
      '  }' \
      '}' \
      > /usr/lib/firefox/distribution/policies.json

# App launch command consumed by the base xstartup + relaunch supervisor.
ENV APP_CMD="firefox"

# Per-app runtime hook (this app's own startup.sh), sourced by base xstartup.
COPY apps/firefox/startup.sh /dockerstartup/app-hook.sh
RUN chmod +x /dockerstartup/app-hook.sh

USER ${APPUSER}
