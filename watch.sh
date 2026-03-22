#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKETCH_DIR="$SCRIPT_DIR/Music_Visualizer_CK"
PID=""

start() {
  touch "$SKETCH_DIR/.devmode" "$SCRIPT_DIR/.devmode" "$HOME/.devmode"
  # setsid gives Processing its own process group so stop() can kill it
  # safely without affecting this script or inotifywait
  setsid /snap/bin/processing cli --sketch="$SKETCH_DIR" --force --run &
  PID=$!
  echo "Started (PID $PID)"
}

stop() {
  if [ -n "$PID" ]; then
    # Kill the entire process group spawned by setsid (launcher + JVM)
    PGID=$(ps -o pgid= "$PID" 2>/dev/null | tr -d ' ')
    [ -n "$PGID" ] && kill -KILL -- -"$PGID" 2>/dev/null || true
    kill -KILL "$PID" 2>/dev/null || true
  fi
  # Fallback: match only the Processing launcher binary, not this script or inotifywait
  pkill -KILL -f "/snap/bin/processing" 2>/dev/null || true
  # Give the JVM time to fully release the audio device
  sleep 0.8
  PID=""
}

cleanup() {
  stop
  rm -f "$SKETCH_DIR/.devmode" "$SCRIPT_DIR/.devmode" "$HOME/.devmode"
  echo "Dev mode flag removed"
}

trap cleanup EXIT

echo "Watching $SKETCH_DIR for changes..."
stop   # kill any pre-existing instance before we start our own
start

inotifywait -m -e close_write,moved_to,create -r "$SKETCH_DIR" --include '.*\.pde' -q |
while read -r dir events file; do
  [[ "$file" == *.tmp* ]] && continue
  echo "Change detected: $file — restarting..."
  stop
  start
done
