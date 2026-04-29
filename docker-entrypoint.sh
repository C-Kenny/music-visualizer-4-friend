#!/usr/bin/env bash
# docker-entrypoint.sh — boot display + audio, hand off to run.sh.
#
# Modes (auto-detected, override with $MV_MODE):
#   smoke   — Xvfb only, runs ./run.sh with .smoketest, exits with result code.
#   vnc     — Xvfb + x11vnc on :5900, runs ./run.sh foregrounded. Watch with any VNC client.
#   host    — host already provides $DISPLAY (X11 socket mounted). Skips Xvfb.
set -euo pipefail

MODE="${MV_MODE:-${1:-vnc}}"
case "$MODE" in run|"") MODE=vnc ;; esac

# ── audio ─────────────────────────────────────────────────────────────────────
# If host pulse socket isn't mounted, spin up our own with a null sink so
# Minim has a device to open. Real audio out needs -v /run/user/$UID/pulse:...
if [[ -z "${PULSE_SERVER:-}" && ! -S /run/pulse/native ]]; then
  pulseaudio --start --exit-idle-time=-1 --disallow-exit || true
  for i in $(seq 1 20); do pactl info >/dev/null 2>&1 && break; sleep 0.5; done
  pactl load-module module-null-sink sink_name=dummy >/dev/null 2>&1 || true
fi

# ── display ───────────────────────────────────────────────────────────────────
if [[ "$MODE" != "host" ]]; then
  export DISPLAY="${DISPLAY:-:99}"
  Xvfb "$DISPLAY" -screen 0 "${MV_RES:-1920x1080x24}" -nolisten tcp &
  XVFB_PID=$!
  for i in $(seq 1 20); do xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && break; sleep 0.2; done
fi

if [[ "$MODE" == "vnc" ]]; then
  x11vnc -display "$DISPLAY" -forever -shared -nopw -quiet -rfbport 5900 &
  echo "[entrypoint] VNC listening on :5900 (no password). Connect with vncviewer host:5900"
fi

cd /app

case "$MODE" in
  smoke)
    touch Music_Visualizer_CK/.smoketest
    SMOKETEST_QUICK="${SMOKETEST_QUICK:-1}" ./run.sh
    rc=$?
    cat .build/Music_Visualizer_CK/.smoketest_result 2>/dev/null || true
    exit $rc
    ;;
  vnc|host|*)
    exec ./run.sh "$@"
    ;;
esac
