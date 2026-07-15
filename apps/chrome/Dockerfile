# syntax=docker/dockerfile:1
# flaskapp-workspace/chrome:1.0 — built FROM our own core base (no kasm images).
# Build context is the REPO ROOT:
#   docker build -f apps/chrome/Dockerfile -t flaskapp-workspace/chrome:1.0 .
FROM flaskapp-workspace/core:1.0
USER root
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends wget gnupg \
    && wget -qO /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && (apt-get install -y --no-install-recommends /tmp/chrome.deb || apt-get -y -f install) \
    && apt-get clean && rm -f /tmp/chrome.deb && rm -rf /var/lib/apt/lists/*

# Reopen the previous session's tabs when the workspace is relaunched.
#
# Chrome's default startup is the New Tab Page, so ending a session and coming
# back gave you an empty window even though the profile (cookies, history, logins)
# had persisted. RestoreOnStartup=1 is "restore the last session". It goes in the
# managed-policy dir rather than the profile's Preferences so it survives a wiped
# profile and cannot be lost by an admin overriding the startup command.
#
# This only works because the workspace is shut down by CLOSING Chrome's window
# (see base/startup.sh): Chrome writes its session on a clean quit, and has
# nothing to restore after a SIGKILL.
#
# DownloadDirectory pins downloads to ~/Downloads, and PromptForDownloadLocation
# stops the "where do you want to save this?" dialog from letting the user pick
# somewhere else. The platform mirrors that one folder into object storage
# (services/downloads_service.py), so its location has to be a contract the browser
# cannot wander off — a file saved to the Desktop would silently never be mirrored.
# Both are managed policy, so a user cannot override them in Settings.
#
# Spelled as an absolute path rather than Chrome's ${users_home} variable: HOME is
# fixed by the base image, the Firefox policy pins the same literal path, and a
# variable that silently failed to expand would send every download somewhere the
# sync does not look.
RUN install -d /etc/opt/chrome/policies/managed \
    && printf '%s\n' \
      '{' \
      '  "RestoreOnStartup": 1,' \
      '  "DownloadDirectory": "/home/flaskapp-user/Downloads",' \
      '  "PromptForDownloadLocation": false' \
      '}' \
       > /etc/opt/chrome/policies/managed/faw-workspace.json

# App launch command consumed by the base xstartup + relaunch supervisor.
ENV APP_CMD="google-chrome --no-sandbox --no-first-run --no-default-browser-check --hide-crash-restore-bubble"

# Per-app runtime hook (this app's own startup.sh), sourced by base xstartup.
COPY apps/chrome/startup.sh /dockerstartup/app-hook.sh
RUN chmod +x /dockerstartup/app-hook.sh

USER ${APPUSER}
