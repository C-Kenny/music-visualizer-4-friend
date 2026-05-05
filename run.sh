#!/usr/bin/env bash
# run.sh — Stages a flattened build for Processing and runs it.
set -euo pipefail

# Kill any lingering sketch processes so two visualizers don't fight over the
# audio device / controller. Quiet — most runs have nothing to kill.
pkill -f "Music_Visualizer_CK Music_Visualizer_CK" 2>/dev/null || true
pkill -f "Processing cli --sketch=.build/Music_Visualizer_CK" 2>/dev/null || true

run_processing() {
  # Prefer snap when the processing snap is actually installed (not just when
  # `snap` is on PATH — many CI runners have snap but no processing snap).
  if command -v snap >/dev/null 2>&1 && snap list processing >/dev/null 2>&1; then
    snap run processing cli "$@"
  elif [[ -x /snap/bin/processing ]]; then
    /snap/bin/processing cli "$@"
  elif command -v processing >/dev/null 2>&1; then
    processing cli "$@"
  else
    echo "Processing CLI not found. Install Processing 4 CLI or make 'snap run processing cli' available." >&2
    return 127
  fi
}

# ── Stage Build ───────────────────────────────────────────────────────────────
# Processing requires the folder name to match the main .pde filename.
# We create a temporary build root to house the correctly-named sketch folder.
BUILD_ROOT=".build"
SKETCH_NAME="Music_Visualizer_CK"
BUILD_DIR="$BUILD_ROOT/$SKETCH_NAME"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_DIR"

# Copy all .pde files into the flat build directory
cp Music_Visualizer_CK/*.pde "$BUILD_DIR/" 2>/dev/null || true
cp Music_Visualizer_CK/src/core/*.pde "$BUILD_DIR/" 2>/dev/null || true
cp Music_Visualizer_CK/src/scenes/*.pde "$BUILD_DIR/" 2>/dev/null || true
cp Music_Visualizer_CK/src/scenes/games/*.pde "$BUILD_DIR/" 2>/dev/null || true
cp Music_Visualizer_CK/src/fractals/*.pde "$BUILD_DIR/" 2>/dev/null || true

# Symlink resources and libraries from the original repo
# We use absolute paths or relative paths from the BUILD_DIR to the original repo
ORIGIN_DIR="$(pwd)/Music_Visualizer_CK"
ln -s "$ORIGIN_DIR/data" "$BUILD_DIR/data"
ln -s "$ORIGIN_DIR/libraries" "$BUILD_DIR/libraries"
[ -d "$ORIGIN_DIR/code" ] && ln -s "$ORIGIN_DIR/code" "$BUILD_DIR/code"

# Also symlink media so skyboxes can load from ../../media/skyboxes
ln -s "$(pwd)/media" "$BUILD_DIR/../media"

# ── Runner Logic ──────────────────────────────────────────────────────────────
# Create devmode flag
touch "$BUILD_DIR/.devmode"

# Link .devsong if it exists
if [[ -f "Music_Visualizer_CK/.devsong" ]]; then
  ln -s "$ORIGIN_DIR/.devsong" "$BUILD_DIR/.devsong"
fi

# Link .devscene if it exists
if [[ -f "Music_Visualizer_CK/.devscene" ]]; then
  ln -s "$ORIGIN_DIR/.devscene" "$BUILD_DIR/.devscene"
fi

# Link .smoketest if it exists
if [[ -f "Music_Visualizer_CK/.smoketest" ]]; then
  ln -s "$ORIGIN_DIR/.smoketest" "$BUILD_DIR/.smoketest"
fi

# Link .devdemo if it exists (synthetic controller for capture.sh).
# Env-var path (MV_DEMO_MODE=1) doesn't survive snap confinement, so the
# capture script touches a flag file instead.
if [[ -f "Music_Visualizer_CK/.devdemo" ]]; then
  ln -s "$ORIGIN_DIR/.devdemo" "$BUILD_DIR/.devdemo"
fi

# Persist runtime state across runs (.build is wiped each launch). UserPaths.pde
# routes featureflags.json / pins.json / bans.json / .devadmintoken / crash_log
# / prefs through userDataPath() — point it at the source dir in dev mode so
# state lives with the project and `git status` still surfaces drift.
export MV_USER_DATA_DIR="$ORIGIN_DIR"
touch "$ORIGIN_DIR/featureflags.json"
[ -f "$ORIGIN_DIR/.devadmintoken" ] || touch "$ORIGIN_DIR/.devadmintoken"

# `./run.sh device` => start in DEVICE input mode, skip file picker
if [[ "${1:-}" == "device" ]]; then
  export MV_AUDIO_MODE=DEVICE
  shift
  echo "[run.sh] Starting in DEVICE audio mode (env MV_AUDIO_MODE=DEVICE)"
fi

# Run using processing cli
run_processing --sketch="$BUILD_DIR" --force --run --vm-args="-Xmx1g" "$@"
