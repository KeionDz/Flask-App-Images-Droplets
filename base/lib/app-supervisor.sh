#!/usr/bin/env bash
# ============================================================================
# app-supervisor.sh — owns what happens when the application exits.
#
# The workspace is APP-ONLY: there is no desktop for the user to fall back to,
# so an exited application must never leave an empty screen. Two behaviours,
# selected by APP_EXIT_BEHAVIOR (default: relaunch):
#
#   relaunch   — the app is restarted whenever it exits (window closed, crash).
#                The workspace only ends when the web app stops the container:
#                startup.sh's SIGTERM handler drops the shutdown sentinel and
#                this loop exits.
#   terminate  — closing the app ends the workspace gracefully: we signal
#                PID 1 (tini), which delivers SIGTERM to startup.sh, whose
#                handler tears down VNC/audio and exits the container. The
#                web app's reconciler then marks the session stopped.
#
# The container lifetime is owned by startup.sh (Xvnc + tail keepalive), never
# by this loop, so even while the app is (briefly) not running the session
# stays up.
# ============================================================================
set -u
: "${APP_CMD:?app-supervisor: APP_CMD must be set}"
: "${APP_EXIT_BEHAVIOR:=relaunch}"
SHUTDOWN_SENTINEL="/tmp/.workspace_shutdown"
# The live application's PID, published for startup.sh's shutdown handler.
APP_PID_FILE="${APP_PID_FILE:-/tmp/.workspace_app.pid}"

# Wait for the window manager before the FIRST launch. On a persistent
# profile the app starts fast enough to map its window before xfwm4 exists,
# and an early unmanaged window can end up with permanently blank content.
i=0
while ! wmctrl -m >/dev/null 2>&1; do
  i=$((i + 1)); [ "$i" -gt 30 ] && break
  sleep 0.5
done

# Backoff so a hard-crashing app cannot spin the CPU in a tight loop (cap 5s).
backoff=1
while [ ! -f "$SHUTDOWN_SENTINEL" ]; do
  echo "[app-supervisor] launching: $APP_CMD"
  # `exec` in a background subshell so $! is the application's own PID, not a
  # wrapper shell's. startup.sh's shutdown handler signals exactly this PID:
  # guessing it from APP_CMD's first word does not work for apps whose launcher
  # execs a differently-named binary (google-chrome -> /opt/google/chrome/chrome),
  # and a missed signal means the app is SIGKILLed with its profile unflushed.
  eval "exec $APP_CMD" &
  APP_PID=$!
  echo "$APP_PID" > "$APP_PID_FILE"
  wait "$APP_PID"
  code=$?
  rm -f "$APP_PID_FILE"
  [ -f "$SHUTDOWN_SENTINEL" ] && break

  if [ "$APP_EXIT_BEHAVIOR" = "terminate" ]; then
    echo "[app-supervisor] app exited (code $code) — APP_EXIT_BEHAVIOR=terminate, ending workspace"
    kill -TERM 1 2>/dev/null
    break
  fi

  echo "[app-supervisor] app exited (code $code) — relaunching in ${backoff}s"
  sleep "$backoff"
  backoff=$((backoff + 1))
  [ "$backoff" -gt 5 ] && backoff=5
done
echo "[app-supervisor] exiting"
