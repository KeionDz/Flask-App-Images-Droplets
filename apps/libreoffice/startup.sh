#!/bin/sh
# ============================================================================
# LibreOffice — per-app runtime hook.
#
# Installed into the image as /dockerstartup/app-hook.sh and SOURCED by the base
# ~/.vnc/xstartup before the app is launched under the relaunch supervisor.
# Use it for app-specific runtime setup and to (re)declare APP_CMD. The base
# already sets APP_CMD via ENV in the Dockerfile; we re-export it here so this
# file is the single readable source of the launch command for this app.
#
# Window/lifecycle behaviour is handled by the base:
#   * opens as a normal, movable/resizable window (not maximized/fullscreen)
#   * closing the window relaunches the app (workspace stays alive)
# ============================================================================
export APP_CMD="${APP_CMD:-libreoffice}"
