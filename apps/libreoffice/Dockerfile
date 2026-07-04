# syntax=docker/dockerfile:1
# flaskapp-workspace/libreoffice:1.0 — built FROM our own core base (no kasm images).
# Build context is the REPO ROOT:
#   docker build -f apps/libreoffice/Dockerfile -t flaskapp-workspace/libreoffice:1.0 .
FROM flaskapp-workspace/core:1.0
USER root
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-gtk3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# App launch command consumed by the base xstartup + relaunch supervisor.
ENV APP_CMD="libreoffice"

# Per-app runtime hook (this app's own startup.sh), sourced by base xstartup.
COPY apps/libreoffice/startup.sh /dockerstartup/app-hook.sh
RUN chmod +x /dockerstartup/app-hook.sh

USER ${APPUSER}
