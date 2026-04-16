#!/usr/bin/env bash
# run.sh — Stages a flattened build for Processing and runs it.

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

# Symlink resources and libraries from the original repo
# We use absolute paths or relative paths from the BUILD_DIR to the original repo
ORIGIN_DIR="$(pwd)/Music_Visualizer_CK"
ln -s "$ORIGIN_DIR/data" "$BUILD_DIR/data"
ln -s "$ORIGIN_DIR/libraries" "$BUILD_DIR/libraries"

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

# Run using processing cli
processing cli --sketch="$BUILD_DIR" --force --run --vm-args="-Xmx1g" "$@"
