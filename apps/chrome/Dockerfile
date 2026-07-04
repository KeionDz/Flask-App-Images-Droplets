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

# App launch command consumed by the base xstartup + relaunch supervisor.
ENV APP_CMD="google-chrome --no-sandbox --no-first-run --no-default-browser-check --hide-crash-restore-bubble"

# Per-app runtime hook (this app's own startup.sh), sourced by base xstartup.
COPY apps/chrome/startup.sh /dockerstartup/app-hook.sh
RUN chmod +x /dockerstartup/app-hook.sh

USER ${APPUSER}
