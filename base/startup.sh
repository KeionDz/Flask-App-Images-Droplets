#!/usr/bin/env bash
# ============================================================================
# flaskapp-workspace — container entrypoint (PID-1 child of tini).
#
# Boot order:  environment -> audio sink -> VNC auth -> Xvnc desktop -> capture.
# A single SIGTERM/SIGINT handler tears the whole stack down cleanly AND drops a
# shutdown sentinel so the in-session app supervisor (lib/app-supervisor.sh)
# stops relaunching the application. The desktop + app are brought up by our own
# ~/.vnc/xstartup, which Xvnc runs.
# ============================================================================
set -uo pipefail

# ---- 1. Environment --------------------------------------------------------
: "${DISPLAY:=:1}"
# Exported so the shutdown handler's wmctrl can reach the X server to close the
# application's windows (the only exit path Chrome flushes its cookie store on).
export DISPLAY
: "${VNC_PORT:=6901}"
: "${AUDIO_PORT:=4901}"
: "${VNC_RESOLUTION:=1280x720}"
: "${VNC_COL_DEPTH:=24}"
: "${VNC_PW:=password}"
: "${STARTUPDIR:=/dockerstartup}"
: "${PULSE_RUNTIME_PATH:=/tmp/pulse}"
export PULSE_RUNTIME_PATH
AUDIO_INGEST_SECRET="flaskapp_audio"
AUDIO_INGEST_PORT=8081
DPYNUM="${DISPLAY#:}"
SHUTDOWN_SENTINEL="/tmp/.workspace_shutdown"

rm -f "$SHUTDOWN_SENTINEL" 2>/dev/null || true
mkdir -p "$HOME/.vnc" "$HOME/.kasmvnc" "$PULSE_RUNTIME_PATH"

# ---- 1b. Install session files into HOME ------------------------------------
# When Persistent Profile is ON a named volume is mounted at HOME, which MASKS
# the xstartup baked into the image. So (re)install our session launcher from
# the STARTUPDIR template every boot (always overwrite — it is ours, not user
# data). No desktop/panel config exists any more: sessions are app-only.
if [ -f "$STARTUPDIR/session/xstartup" ]; then
  install -m 755 "$STARTUPDIR/session/xstartup" "$HOME/.vnc/xstartup"
fi

# ---- 2. Audio sink (before the desktop, so apps find it on launch) --------
pulseaudio --start --exit-idle-time=-1 --disallow-exit >/dev/null 2>&1 || true
for _ in $(seq 1 10); do pactl info >/dev/null 2>&1 && break; sleep 0.5; done
pactl load-module module-null-sink sink_name=virtual_speaker \
      sink_properties=device.description=virtual_speaker >/dev/null 2>&1 || true
pactl set-default-sink   virtual_speaker         >/dev/null 2>&1 || true
pactl set-default-source virtual_speaker.monitor >/dev/null 2>&1 || true

# ---- 3. Web/VNC auth user --------------------------------------------------
# Username MUST be kasm_user: nginx sends base64("kasm_user:<VNC_PW>").
# FAIL FAST if user creation fails (e.g. VNC_PW shorter than kasmvncpasswd's
# 6-char minimum): otherwise vncserver drops into an interactive "create a
# user" prompt loop and spins at 100% CPU forever with no error surfaced.
printf '%s\n%s\n' "$VNC_PW" "$VNC_PW" | kasmvncpasswd -u kasm_user -rwo "$HOME/.kasmpasswd"
if [ ! -s "$HOME/.kasmpasswd" ]; then
  echo "FATAL: VNC user creation failed — is VNC_PW at least 6 characters?" >&2
  exit 1
fi

# ---- 4. Xvnc desktop -------------------------------------------------------
vncserver -kill "$DISPLAY" >/dev/null 2>&1 || true
rm -f "/tmp/.X${DPYNUM}-lock" "/tmp/.X11-unix/X${DPYNUM}" 2>/dev/null || true

# "-select-de manual" keeps OUR ~/.vnc/xstartup verbatim (no interactive prompt).
vncserver "$DISPLAY" \
  -select-de manual \
  -geometry "$VNC_RESOLUTION" \
  -depth "$VNC_COL_DEPTH" \
  -websocketPort "$VNC_PORT" \
  -sslOnly \
  -interface 0.0.0.0 \
  -httpd /usr/share/kasmvnc/www </dev/null

# ---- 5. Audio capture -> jsmpeg relay -> browser --------------------------
node "$STARTUPDIR/audio/websocket-relay.js" "$AUDIO_INGEST_SECRET" "$AUDIO_INGEST_PORT" "$AUDIO_PORT" &
RELAY_PID=$!
sleep 1

# -fragment_size 4096 is CRITICAL: without it libpulse picks the server default
# fragment (~2 s on a monitor source), so ffmpeg receives audio in ~2-second
# bursts and playback in the browser is choppy no matter what the player does.
# 4096 B = ~23 ms at 44.1 kHz s16 stereo -> smooth, low-latency delivery.
# -flush_packets 1 pushes each TS packet to the relay immediately.
ffmpeg -hide_banner -loglevel error -nostdin \
  -f pulse -fragment_size 4096 -ar 44100 -ac 2 -i virtual_speaker.monitor \
  -f mpegts -codec:a mp2 -b:a 128k -muxdelay 0.001 -flush_packets 1 \
  "http://127.0.0.1:${AUDIO_INGEST_PORT}/${AUDIO_INGEST_SECRET}" &
FFMPEG_PID=$!

echo "flaskapp-workspace up — VNC :${VNC_PORT}  AUDIO :${AUDIO_PORT}  APP: ${APP_CMD:-<none>}"

# ---- 6. Clean shutdown -----------------------------------------------------
# Ask the application to exit CLEANLY and wait for it before the X server goes
# away. Critical for persistent profiles: browsers flush their SQLite databases
# (cookies, history, prefs) only on a graceful exit, and losing the X connection
# mid-write corrupts them.
#
# We signal the exact PID the app-supervisor recorded. Deriving a pkill pattern
# from APP_CMD's first word silently missed any app whose launcher execs a
# differently-named binary — `google-chrome` becomes /opt/google/chrome/chrome,
# so `pkill -f google-chrome` only ever hit the crashpad helpers while the
# browser itself was left to be SIGKILLed with an unflushed profile.
# Budget: window-close wait + SIGTERM wait must stay under the orchestrator's
# docker-stop timeout (WORKSPACE_STOP_TIMEOUT_S, 20s) or the container is killed
# mid-flush anyway.
APP_PID_FILE="${APP_PID_FILE:-/tmp/.workspace_app.pid}"
APP_SHUTDOWN_TIMEOUT="${APP_SHUTDOWN_TIMEOUT:-10}"

# True once the application process is gone.
_app_gone() {
  if [ -n "${_pid:-}" ]; then
    kill -0 "$_pid" 2>/dev/null && return 1 || return 0
  fi
  pgrep -f "${APP_CMD%% *}" >/dev/null 2>&1 && return 1 || return 0
}

# Wait up to $1 seconds for the application to exit. 0 = gone, 1 = still running.
_await_app_exit() {
  _ticks=$(( $1 * 2 ))
  while [ "$_ticks" -gt 0 ]; do
    _app_gone && return 0
    _ticks=$(( _ticks - 1 ))
    sleep 0.5
  done
  return 1
}

stop_app() {
  [ -n "${APP_CMD:-}" ] || return 0

  _pid=""
  [ -f "$APP_PID_FILE" ] && _pid="$(cat "$APP_PID_FILE" 2>/dev/null)"

  # 1. Ask the application to CLOSE ITS WINDOWS. This is the only shutdown path
  #    Chrome treats as a real quit: on SIGTERM it takes the SessionEnding()
  #    fast path and exits WITHOUT committing its cookie store, so the user's
  #    logins silently vanish from a persistent profile. Closing the last window
  #    runs the normal quit, which flushes cookies, history and preferences.
  if command -v wmctrl >/dev/null 2>&1; then
    for _wid in $(wmctrl -l 2>/dev/null | awk '$2==0 {print $1}'); do
      wmctrl -i -c "$_wid" 2>/dev/null || true
    done
    _await_app_exit "$APP_SHUTDOWN_TIMEOUT" && return 0
  fi

  # 2. No window manager, no windows, or the app ignored the close request.
  if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
    kill -TERM "$_pid" 2>/dev/null || true
  else
    # Fallback for an app started outside the supervisor: match the basename of
    # the launcher, which is the best guess available.
    pkill -TERM -f "${APP_CMD%% *}" 2>/dev/null || true
    _pid=""
  fi
  _await_app_exit 5 && return 0

  echo "flaskapp-workspace: app did not exit cleanly — forcing"
  [ -n "$_pid" ] && kill -KILL "$_pid" 2>/dev/null || true
}

shutdown() {
  echo "flaskapp-workspace: shutting down..."
  touch "$SHUTDOWN_SENTINEL" 2>/dev/null || true
  stop_app
  kill "$FFMPEG_PID" "$RELAY_PID" 2>/dev/null || true
  vncserver -kill "$DISPLAY" >/dev/null 2>&1 || true
  pulseaudio --kill >/dev/null 2>&1 || true
  exit 0
}
trap shutdown TERM INT

# ---- 7. Stay alive on the VNC session log ---------------------------------
tail -F "$HOME/.vnc/"*"${DPYNUM}".log 2>/dev/null &
wait $!
