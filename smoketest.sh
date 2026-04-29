#!/usr/bin/env bash
# smoketest.sh — run the smoke-test harness and report pass/fail

set -euo pipefail

run_processing() {
  if command -v snap >/dev/null 2>&1; then
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
BUILD_ROOT=".build"
SKETCH_NAME="Music_Visualizer_CK"
BUILD_DIR="$BUILD_ROOT/$SKETCH_NAME"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_DIR"

cp Music_Visualizer_CK/*.pde "$BUILD_DIR/" 2>/dev/null || true
cp Music_Visualizer_CK/src/core/*.pde "$BUILD_DIR/" 2>/dev/null || true
cp Music_Visualizer_CK/src/scenes/*.pde "$BUILD_DIR/" 2>/dev/null || true
cp Music_Visualizer_CK/src/scenes/games/*.pde "$BUILD_DIR/" 2>/dev/null || true
cp Music_Visualizer_CK/src/fractals/*.pde "$BUILD_DIR/" 2>/dev/null || true

ORIGIN_DIR="$(pwd)/Music_Visualizer_CK"
ln -s "$ORIGIN_DIR/data" "$BUILD_DIR/data"
ln -s "$ORIGIN_DIR/libraries" "$BUILD_DIR/libraries"
[ -d "$ORIGIN_DIR/code" ] && ln -s "$ORIGIN_DIR/code" "$BUILD_DIR/code"

# ── Setup ─────────────────────────────────────────────────────────────────────
TRIGGER="$BUILD_DIR/.smoketest"
DEVMODE="$BUILD_DIR/.devmode"
RESULT="$BUILD_DIR/.smoketest_result"

RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

# Link .devsong if it exists
if [[ -f "Music_Visualizer_CK/.devsong" ]]; then
  ln -s "$ORIGIN_DIR/.devsong" "$BUILD_DIR/.devsong"
fi

touch "$TRIGGER"
touch "$DEVMODE"

# ── Run ───────────────────────────────────────────────────────────────────────
echo "${BOLD}Running smoke test across refactored structure…${RESET}"
echo

# Skip standalone --build validation: it doesn't see contributed libraries
# (java_websocket lives in the user sketchbook), but --run resolves them.
# Compile errors will still surface in the --run output below.

FULL_LOG="$BUILD_DIR/.smoketest_full.log"
run_processing --sketch="$BUILD_DIR" --force --run 2>&1 | tee "$FULL_LOG" | \
  grep --line-buffered -E '^\[SMOKE\]|^\[FAIL\]|^\[AUDIOTEST\]|╔|╠|╚|║|scenes=|checks=|failures=' || true

# ── Read result ───────────────────────────────────────────────────────────────
echo

if [[ ! -f "$RESULT" ]]; then
  echo "${RED}${BOLD}ERROR: result file was never written.${RESET}"
  exit 2
fi

STATUS=$(head -1 "$RESULT")
FAILURE_COUNT=$(grep '^failures=' "$RESULT" | cut -d= -f2)
PASS_COUNT=$(grep '^checks=' "$RESULT" | cut -d= -f2)
SCENE_COUNT=$(grep '^scenes=' "$RESULT" | cut -d= -f2)

echo "─────────────────────────────────────────"
echo "  Scenes : $SCENE_COUNT"
echo "  Checks : $PASS_COUNT passed"
echo "  Fails  : $FAILURE_COUNT"
echo "─────────────────────────────────────────"

if [[ "$STATUS" == "PASS" ]]; then
  echo "${GREEN}${BOLD}✓ SMOKE TEST PASSED${RESET}"
  exit 0
else
  echo "${RED}${BOLD}✗ SMOKE TEST FAILED — $FAILURE_COUNT failure(s):${RESET}"
  grep '^\[FAIL\]' "$RESULT" | while IFS= read -r line; do
    echo "  ${RED}$line${RESET}"
  done
  exit 1
fi
