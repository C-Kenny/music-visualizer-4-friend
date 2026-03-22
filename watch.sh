#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKETCH_DIR="$SCRIPT_DIR/Music_Visualizer_CK"
PID=""

start() {
  touch "$SKETCH_DIR/.devmode" "$SCRIPT_DIR/.devmode" "$HOME/.devmode"
  /snap/bin/processing cli --sketch="$SKETCH_DIR" --force --run &
  PID=$!
  echo "Started (PID $PID)"
}

stop() {
  # Kill the stored launcher PID and all its child processes
  if [ -n "$PID" ]; then
    pkill -KILL -P "$PID" 2>/dev/null || true
    kill -KILL "$PID" 2>/dev/null || true
  fi
  # Fallback: catch any stray instances not tracked by $PID
  # (e.g. a visualizer left running from ./run.sh before watch.sh started)
  pkill -KILL -f "sketch-path=.*Music_Visualizer_CK" 2>/dev/null || true
  pkill -KILL -f "/snap/processing.*Music_Visualizer_CK" 2>/dev/null || true
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
