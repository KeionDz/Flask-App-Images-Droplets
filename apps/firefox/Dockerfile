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
      '    "SkipTermsOfUse": true' \
      '  }' \
      '}' \
      > /usr/lib/firefox/distribution/policies.json

# App launch command consumed by the base xstartup + relaunch supervisor.
ENV APP_CMD="firefox"

# Per-app runtime hook (this app's own startup.sh), sourced by base xstartup.
COPY apps/firefox/startup.sh /dockerstartup/app-hook.sh
RUN chmod +x /dockerstartup/app-hook.sh

USER ${APPUSER}
