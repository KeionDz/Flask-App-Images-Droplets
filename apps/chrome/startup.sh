#!/bin/sh
# ============================================================================
# Chrome Browser — per-app runtime hook.
#
# Installed into the image as /dockerstartup/app-hook.sh and SOURCED by the base
# ~/.vnc/xstartup before the app is launched under the app supervisor.
#
# Persistent-profile hygiene: the workspace container is force-killed on stop,
# so a persistent ~/.config/google-chrome volume can carry a stale Singleton*
# lock into the next session — Chrome would then refuse to open a window (it
# thinks another instance owns the profile). Clear them; real user data
# (cookies, bookmarks, settings) is untouched.
# ============================================================================
rm -f "$HOME/.config/google-chrome/SingletonLock" \
      "$HOME/.config/google-chrome/SingletonSocket" \
      "$HOME/.config/google-chrome/SingletonCookie" 2>/dev/null

# Fallback launch command only — an APP_CMD provided by the image ENV or the
# admin's per-image "startup command" override always wins.
# --hide-crash-restore-bubble: no "restore pages?" nag after a hard stop.
export APP_CMD="${APP_CMD:-google-chrome --no-sandbox --no-first-run --no-default-browser-check --hide-crash-restore-bubble}"
