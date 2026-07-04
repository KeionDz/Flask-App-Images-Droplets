# syntax=docker/dockerfile:1
# flaskapp-workspace/terminal:1.0 — built FROM our own core base (no kasm images).
# Build context is the REPO ROOT:
#   docker build -f apps/terminal/Dockerfile -t flaskapp-workspace/terminal:1.0 .
FROM flaskapp-workspace/core:1.0
USER root
ARG DEBIAN_FRONTEND=noninteractive

# The core base is app-only and ships NO terminal — install it here, where a
# terminal IS the application the user chose to launch.
RUN apt-get update && apt-get install -y --no-install-recommends xfce4-terminal \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# App launch command consumed by the base xstartup + relaunch supervisor.
ENV APP_CMD="xfce4-terminal"

# Per-app runtime hook (this app's own startup.sh), sourced by base xstartup.
COPY apps/terminal/startup.sh /dockerstartup/app-hook.sh
RUN chmod +x /dockerstartup/app-hook.sh

USER ${APPUSER}
