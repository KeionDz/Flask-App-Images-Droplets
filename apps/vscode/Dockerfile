# syntax=docker/dockerfile:1
# flaskapp-workspace/vscode:1.0 — built FROM our own core base (no kasm images).
# Build context is the REPO ROOT:
#   docker build -f apps/vscode/Dockerfile -t flaskapp-workspace/vscode:1.0 .
FROM flaskapp-workspace/core:1.0
USER root
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends wget gpg \
    && wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg \
    && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' > /etc/apt/sources.list.d/vscode.list \
    && apt-get update && apt-get install -y --no-install-recommends code \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# App launch command consumed by the base xstartup + relaunch supervisor.
ENV APP_CMD="code --no-sandbox --unity-launch"

# Per-app runtime hook (this app's own startup.sh), sourced by base xstartup.
COPY apps/vscode/startup.sh /dockerstartup/app-hook.sh
RUN chmod +x /dockerstartup/app-hook.sh

USER ${APPUSER}
