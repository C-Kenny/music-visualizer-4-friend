#!/usr/bin/env bash
# profile.sh - attach async-profiler to a running visualizer sketch, sample
# for N seconds, output an interactive flame graph (HTML).
#
# Usage:
#   ./profile.sh               # 60s sample, opens flame.html
#   ./profile.sh 30            # 30s sample
#   ./profile.sh 60 alloc      # CPU + allocation events
#
# Safety notes:
#   - Sampling profiler. ~1% CPU overhead. No code modification.
#   - Attaches to the JVM you already own (no sudo).
#   - On first run, may need: sudo sysctl kernel.perf_event_paranoid=1
#     (one-shot, lasts until reboot). Without it, async-profiler falls back
#     to a lower-fidelity mode but still works.
#   - Requires async-profiler installed at $ASPROF_HOME or in ./tools/.

set -euo pipefail

DURATION="${1:-60}"
EVENT="${2:-cpu}"
OUT="flame-$(date +%Y%m%d-%H%M%S).html"

# Locate asprof
ASPROF=""
if [[ -n "${ASPROF_HOME:-}" && -x "$ASPROF_HOME/bin/asprof" ]]; then
  ASPROF="$ASPROF_HOME/bin/asprof"
elif command -v asprof >/dev/null 2>&1; then
  ASPROF="$(command -v asprof)"
else
  for d in tools/async-profiler-*/bin/asprof ~/async-profiler-*/bin/asprof; do
    if [[ -x "$d" ]]; then ASPROF="$d"; break; fi
  done
fi

if [[ -z "$ASPROF" ]]; then
  echo "async-profiler not found." >&2
  echo "Install:" >&2
  echo "  mkdir -p tools && cd tools" >&2
  echo "  wget https://github.com/async-profiler/async-profiler/releases/download/v3.0/async-profiler-3.0-linux-x64.tar.gz" >&2
  echo "  tar xf async-profiler-*.tar.gz && cd .." >&2
  exit 1
fi

# Find running sketch PID. The processing CLI runs the sketch under a child
# JVM whose command line contains the build dir.
PID=$(pgrep -f "\.build/Music_Visualizer_CK" | head -1 || true)
if [[ -z "$PID" ]]; then
  echo "No running visualizer found. Launch with ./run.sh first." >&2
  exit 1
fi

echo "[profile] PID=$PID  event=$EVENT  duration=${DURATION}s"
echo "[profile] output: $OUT"
"$ASPROF" -d "$DURATION" -e "$EVENT" -f "$OUT" "$PID"

echo "[profile] done. Open: $OUT"
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$OUT" >/dev/null 2>&1 &
fi
