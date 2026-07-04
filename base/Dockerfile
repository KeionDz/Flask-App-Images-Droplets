# syntax=docker/dockerfile:1
# ============================================================================
# flaskapp-workspace/core — our OWN browser-streaming desktop base image.
#
#   * Ubuntu 22.04 + a MINIMAL XFCE (window manager + one taskbar panel only).
#   * The open-source KasmVNC *server* (Apache-2.0) from its upstream release
#     .deb. NO kasmweb/* or ghcr.io/kasmtech/* image is ever pulled; nothing
#     depends on a Kasm registry.
#   * Audio via PulseAudio (virtual sink) -> ffmpeg (MPEG-TS) -> a self-contained
#     jsmpeg websocket relay -> the browser.
#   * A relaunch supervisor (lib/app-supervisor.sh) keeps the app alive so the
#     workspace never dies when the user closes the app window.
#
# INTERNAL BUILD BASE ONLY — never launchable on its own. Every app image is
# built FROM here and only adds one application + sets APP_CMD.
#
# Build context is the REPO ROOT:
#   docker build -f base/Dockerfile -t flaskapp-workspace/core:1.0 .
# ============================================================================
FROM ubuntu:22.04

ARG KASMVNC_VERSION=1.4.0
ARG DEBIAN_FRONTEND=noninteractive

ENV APPUSER=flaskapp-user \
    HOME=/home/flaskapp-user \
    DISPLAY=:1 \
    VNC_PORT=6901 \
    AUDIO_PORT=4901 \
    VNC_RESOLUTION=1280x720 \
    VNC_COL_DEPTH=24 \
    STARTUPDIR=/dockerstartup \
    PULSE_RUNTIME_PATH=/tmp/pulse \
    LANG=en_US.UTF-8 \
    APP_CMD=""

# --- App-only session stack (NO desktop environment) -----------------------
# Deliberately NO xfce4-panel, NO xfdesktop, NO terminal, NO menus: the user
# must only ever see the application window (RemoteApp/Flowcase-style). xfwm4
# alone provides normal window behaviour (move/resize/min/max); x11-utils
# (xprop) + x11-xserver-utils (xsetroot) serve the xstartup watchdog/backdrop.
RUN apt-get update && apt-get install -y --no-install-recommends \
      xfwm4 xfce4-settings xfconf dbus-x11 \
      wmctrl x11-utils x11-xserver-utils \
      fonts-dejavu-core adwaita-icon-theme \
      pulseaudio pulseaudio-utils ffmpeg nodejs \
      ca-certificates curl wget gnupg sudo locales tini \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- KasmVNC server (open-source release; NOT a kasmweb image) -------------
RUN wget -qO /tmp/kasmvnc.deb \
      "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_jammy_${KASMVNC_VERSION}_amd64.deb" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/kasmvnc.deb \
    && apt-get clean && rm -f /tmp/kasmvnc.deb && rm -rf /var/lib/apt/lists/*

# --- Branded, passwordless-sudo user ---------------------------------------
RUN useradd -m -s /bin/bash -d ${HOME} ${APPUSER} \
    && adduser ${APPUSER} ssl-cert \
    && echo "${APPUSER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# --- Our own startup scripts + audio relay + supervisor + panel config ------
COPY base/audio/websocket-relay.js ${STARTUPDIR}/audio/websocket-relay.js
COPY base/lib/app-supervisor.sh    ${STARTUPDIR}/lib/app-supervisor.sh
COPY base/startup.sh               ${STARTUPDIR}/startup.sh
# Session template lives in STARTUPDIR (outside HOME) so a persistent-profile
# volume mounted at HOME cannot mask it. startup.sh (re)installs it into HOME
# on every boot. We also seed HOME here for the non-persistent fast path.
COPY base/xstartup                 ${STARTUPDIR}/session/xstartup
COPY base/xstartup                 ${HOME}/.vnc/xstartup

RUN chmod +x ${STARTUPDIR}/startup.sh ${STARTUPDIR}/lib/app-supervisor.sh \
             ${STARTUPDIR}/session/xstartup ${HOME}/.vnc/xstartup \
    && mkdir -p ${HOME}/Desktop ${HOME}/Downloads ${HOME}/Documents \
    && chown -R ${APPUSER}:${APPUSER} ${STARTUPDIR} ${HOME}

EXPOSE 6901 4901
USER ${APPUSER}
WORKDIR ${HOME}

# tini (PID 1) reaps Xvnc / pulseaudio / ffmpeg / relay / supervisor children.
ENTRYPOINT ["/usr/bin/tini", "--", "/dockerstartup/startup.sh"]
