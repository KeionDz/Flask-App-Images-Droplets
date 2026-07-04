# syntax=docker/dockerfile:1
# flaskapp-workspace/file-manager:1.0 — built FROM our own core base (no kasm images).
# Build context is the REPO ROOT:
#   docker build -f apps/file-manager/Dockerfile -t flaskapp-workspace/file-manager:1.0 .
FROM flaskapp-workspace/core:1.0
USER root
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends thunar \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# App launch command consumed by the base xstartup + relaunch supervisor.
ENV APP_CMD="thunar"

# Per-app runtime hook (this app's own startup.sh), sourced by base xstartup.
COPY apps/file-manager/startup.sh /dockerstartup/app-hook.sh
RUN chmod +x /dockerstartup/app-hook.sh

USER ${APPUSER}
