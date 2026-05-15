#!/usr/bin/env bash
# Linux only. Flip PulseAudio/PipeWire default source to the current sink's
# monitor so JVM (which only sees `default`) captures system audio. Run before
# `./run.sh` then press F10 in sketch and pick `[default]`.
#
# Usage:
#   ./loopback.sh on      # set default source = current sink monitor
#   ./loopback.sh off     # restore previous default source
#   ./loopback.sh status  # show whether loopback is active + restore target
#   ./loopback.sh show    # print current default source/sink (no state)
#
# State stored in ~/.cache/music-visualizer/loopback_prev so `off` survives a
# reboot. WirePlumber persists set-default-source to ~/.local/state, so a crash
# or forgotten `off` would otherwise strand the system on the monitor source.

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/music-visualizer"
STATE="$CACHE_DIR/loopback_prev"

source_exists() {
  pactl list short sources | awk '{print $2}' | grep -qx "$1"
}

case "${1:-status}" in
  on)
    mkdir -p "$CACHE_DIR"
    prev=$(pactl get-default-source)
    sink=$(pactl get-default-sink)
    monitor="${sink}.monitor"
    if ! source_exists "$monitor"; then
      echo "Monitor source not found: $monitor"
      echo "Available sources:"
      pactl list short sources | awk '{print "  " $2}'
      exit 1
    fi
    echo "$prev" > "$STATE"
    pactl set-default-source "$monitor"
    echo "Default source -> $monitor (saved prior: $prev)"
    ;;
  off)
    if [[ ! -f "$STATE" ]]; then
      echo "No saved prior source. Current default: $(pactl get-default-source)"
      exit 0
    fi
    prev=$(cat "$STATE")
    if source_exists "$prev"; then
      pactl set-default-source "$prev"
      rm -f "$STATE"
      echo "Default source restored: $prev"
    else
      # Saved source no longer exists (USB unplugged, BT out of range). Picking
      # it would wedge wireplumber. Fall back to first non-monitor source.
      fallback=$(pactl list short sources | awk '$2 !~ /\.monitor$/ {print $2; exit}')
      if [[ -n "$fallback" ]]; then
        pactl set-default-source "$fallback"
        rm -f "$STATE"
        echo "Saved prior '$prev' is gone. Fallback default -> $fallback"
      else
        echo "Saved prior '$prev' is gone and no non-monitor source available."
        echo "Leaving default as-is. Saved state kept at $STATE for inspection."
        exit 1
      fi
    fi
    ;;
  status)
    current=$(pactl get-default-source)
    echo "current default source: $current"
    if [[ -f "$STATE" ]]; then
      saved=$(cat "$STATE")
      echo "loopback: ACTIVE (saved prior: $saved)"
      if source_exists "$saved"; then
        echo "  saved source still exists — \`off\` will restore cleanly."
      else
        echo "  saved source MISSING — \`off\` will fall back to first non-monitor."
      fi
    else
      echo "loopback: inactive (no saved state)"
    fi
    ;;
  show)
    echo "default source: $(pactl get-default-source)"
    echo "default sink:   $(pactl get-default-sink)"
    ;;
  *)
    echo "Usage: $0 {on|off|status|show}" >&2
    exit 1
    ;;
esac
