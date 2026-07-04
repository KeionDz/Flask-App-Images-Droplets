#!/bin/sh
# ============================================================================
# Firefox Browser — per-app runtime hook.
#
# Installed into the image as /dockerstartup/app-hook.sh and SOURCED by the base
# ~/.vnc/xstartup before the app is launched under the app supervisor.
#
# Persistent-profile hygiene: the workspace container is force-killed on stop,
# so a persistent ~/.mozilla volume can carry a stale singleton lock into the
# next session — Firefox would then refuse to start ("Firefox is already
# running, but is not responding"). Clear stale locks and suppress the
# crashed-session restore nag; neither touches real user data.
# ============================================================================
# Purge CACHES (safe — always regenerated; user data like cookies, logins and
# bookmarks lives under .config/mozilla|.mozilla, untouched). A persistent
# profile carries startupCache / GPU / shader caches across force-kills and
# image upgrades, and stale ones wedge Firefox's content rendering (window
# paints, page stays blank).
rm -rf "$HOME/.cache/mozilla" "$HOME/.cache/mesa_shader_cache" 2>/dev/null

# Profile roots: classic (~/.mozilla) AND XDG (~/.config/mozilla) — Mozilla's
# current .deb uses the XDG path when ~/.mozilla does not pre-exist.
for d in "$HOME"/.mozilla/firefox/*/ "$HOME"/.config/mozilla/firefox/*/; do
  [ -d "$d" ] || continue
  rm -f "$d/lock" "$d/.parentlock" 2>/dev/null
  if ! grep -qs 'resume_from_crash' "$d/user.js" 2>/dev/null; then
    echo 'user_pref("browser.sessionstore.resume_from_crash", false);' >> "$d/user.js"
  fi
  # Containers are force-killed on stop; every start looks "uncleanly shut
  # down" to Firefox, and after a few it offers Troubleshoot (safe) Mode.
  # Disable that prompt — standard for kiosk/remote-app profiles.
  if ! grep -qs 'max_resumed_crashes' "$d/user.js" 2>/dev/null; then
    echo 'user_pref("toolkit.startup.max_resumed_crashes", -1);' >> "$d/user.js"
  fi
  # Force software WebRender in profiles created by OLDER image versions: a
  # cached hardware-GPU decision renders blank page content in these GPU-less
  # containers. (New profiles get this from /usr/lib/firefox/defaults/pref.)
  if ! grep -qs 'gfx.webrender.software' "$d/user.js" 2>/dev/null; then
    echo 'user_pref("gfx.webrender.software", true);' >> "$d/user.js"
    echo 'user_pref("layers.acceleration.disabled", true);' >> "$d/user.js"
  fi
done

# Fallback launch command only — an APP_CMD provided by the image ENV or the
# admin's per-image "startup command" override always wins.
export APP_CMD="${APP_CMD:-firefox}"
