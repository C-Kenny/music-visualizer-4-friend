#!/usr/bin/env bash
# run.sh wrapper that auto-flips the Pulse default source to the current sink's
# monitor for the duration of the sketch, then guaranteed-restores on exit.
#
# Why: `./loopback.sh on` mutates a global PipeWire/WirePlumber default that
# persists across reboots. If you forget to run `./loopback.sh off`, a reboot
# while loopback is active can wedge wireplumber if the saved prior source
# becomes unavailable (USB unplugged, BT out of range). This wrapper traps
# every exit signal so `off` runs even on Ctrl-C, sketch crash, or terminal
# close.
#
# Usage:  ./run-with-loopback.sh [args forwarded to run.sh]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOOPBACK="$SCRIPT_DIR/loopback.sh"
RUN="$SCRIPT_DIR/run.sh"

if [[ ! -x "$LOOPBACK" || ! -x "$RUN" ]]; then
  echo "loopback.sh or run.sh missing/not executable in $SCRIPT_DIR" >&2
  exit 1
fi

# Refuse if loopback is already active — don't trample state another shell owns.
if [[ -f "${XDG_CACHE_HOME:-$HOME/.cache}/music-visualizer/loopback_prev" ]]; then
  echo "loopback already active. Run './loopback.sh off' first, or use './run.sh' directly." >&2
  exit 1
fi

cleanup() {
  # Always attempt restore. loopback.sh off is idempotent and prints its own
  # status; suppress its exit code so a failed restore doesn't mask the
  # sketch's exit code.
  "$LOOPBACK" off || true
}
trap cleanup EXIT INT TERM

"$LOOPBACK" on
"$RUN" "$@"
