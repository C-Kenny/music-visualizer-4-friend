#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKETCH_DIR="$SCRIPT_DIR/Music_Visualizer_CK"
DEVMODE_FLAG="$SKETCH_DIR/.devmode"
PID=""

start() {
  # Create devmode flag in all locations the sketch checks
  touch "$SKETCH_DIR/.devmode"
  touch "$SCRIPT_DIR/.devmode"
  touch "$HOME/.devmode"
  /snap/bin/processing cli --sketch="$SKETCH_DIR" --force --run &
  PID=$!
  echo "Started (PID $PID)"
}

stop() {
  pkill -KILL -f "sketch[=-].*Music_Visualizer_CK" 2>/dev/null
  pkill -KILL -f "Processing cli.*Music_Visualizer_CK" 2>/dev/null
  while pgrep -f "sketch[=-].*Music_Visualizer_CK" > /dev/null 2>&1; do sleep 0.2; done
  echo "Stopped all sketch processes"
  PID=""
}

cleanup() {
  stop
  rm -f "$SKETCH_DIR/.devmode" "$SCRIPT_DIR/.devmode" "$HOME/.devmode"
  echo "Dev mode flag removed"
}

trap cleanup EXIT

echo "Watching $SKETCH_DIR for changes..."
start

inotifywait -m -e close_write,moved_to,create -r "$SKETCH_DIR" --include '.*\.pde' -q |
while read -r dir events file; do
  [[ "$file" == *.tmp* ]] && continue
  echo "Change detected: $file — restarting..."
  stop
  sleep 0.5
  start
done
