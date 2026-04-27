#!/usr/bin/env bash
# run.sh — Stages a flattened build for Processing and runs it.
set -euo pipefail

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

# Symlink featureflags.json so featureflag-server writes persist across runs (.build is wiped).
touch "$ORIGIN_DIR/featureflags.json"
ln -sf "$ORIGIN_DIR/featureflags.json" "$BUILD_DIR/featureflags.json"

# Same trick for .devadmintoken — otherwise the admin token regenerates every
# launch and prior ?token= URLs / cookies all break.
[ -f "$ORIGIN_DIR/.devadmintoken" ] || touch "$ORIGIN_DIR/.devadmintoken"
ln -sf "$ORIGIN_DIR/.devadmintoken" "$BUILD_DIR/.devadmintoken"

# Run using processing cli
run_processing --sketch="$BUILD_DIR" --force --run --vm-args="-Xmx1g" "$@"
