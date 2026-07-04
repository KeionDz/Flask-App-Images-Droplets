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
shutdown() {
  echo "flaskapp-workspace: shutting down..."
  touch "$SHUTDOWN_SENTINEL" 2>/dev/null || true
  # Ask the application to exit CLEANLY and wait briefly before the X server
  # goes away. Critical for persistent profiles: browsers flush their SQLite
  # databases on SIGTERM; losing the X connection mid-write corrupts them.
  if [ -n "${APP_CMD:-}" ]; then
    _app_bin="${APP_CMD%% *}"
    pkill -TERM -f "$_app_bin" 2>/dev/null || true
    for _ in 1 2 3 4 5 6; do
      pgrep -f "$_app_bin" >/dev/null 2>&1 || break
      sleep 0.5
    done
  fi
  kill "$FFMPEG_PID" "$RELAY_PID" 2>/dev/null || true
  vncserver -kill "$DISPLAY" >/dev/null 2>&1 || true
  pulseaudio --kill >/dev/null 2>&1 || true
  exit 0
}
trap shutdown TERM INT

# ---- 7. Stay alive on the VNC session log ---------------------------------
tail -F "$HOME/.vnc/"*"${DPYNUM}".log 2>/dev/null &
wait $!
