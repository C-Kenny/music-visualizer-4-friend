#!/usr/bin/env bash
# Linux only. Flip PulseAudio/PipeWire default source to the current sink's
# monitor so JVM (which only sees `default`) captures system audio. Run before
# `./run.sh` then press F10 in sketch and pick `[default]`.
#
# Usage:
#   ./loopback.sh on    # set default source = current sink monitor
#   ./loopback.sh off   # restore previous default source
#   ./loopback.sh show  # print current default source
#
# Stores prior source in /tmp/.vis_loopback_prev so `off` can restore it.

set -euo pipefail

STATE=/tmp/.vis_loopback_prev

case "${1:-show}" in
  on)
    prev=$(pactl get-default-source)
    sink=$(pactl get-default-sink)
    monitor="${sink}.monitor"
    if ! pactl list short sources | awk '{print $2}' | grep -qx "$monitor"; then
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
    if [[ -f "$STATE" ]]; then
      prev=$(cat "$STATE")
      pactl set-default-source "$prev"
      rm -f "$STATE"
      echo "Default source restored: $prev"
    else
      echo "No saved prior source."
    fi
    ;;
  show)
    echo "default source: $(pactl get-default-source)"
    echo "default sink:   $(pactl get-default-sink)"
    ;;
  *)
    echo "Usage: $0 {on|off|show}" >&2
    exit 1
    ;;
esac
