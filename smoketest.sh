#!/usr/bin/env bash
# smoketest.sh — run the smoke-test harness and report pass/fail
#
# Usage:
#   ./smoketest.sh
#
# Requirements:
#   • Music_Visualizer_CK/.devsong must exist (or ~/Music must have audio files)
#     so the sketch doesn't open a file picker.
#   • The Processing CLI must be on PATH (same requirement as ./run.sh).
#
# Exit codes:
#   0  — all checks passed
#   1  — one or more failures
#   2  — result file never written (sketch crashed before finishing)

set -euo pipefail

SKETCH_DIR="Music_Visualizer_CK"
TRIGGER="$SKETCH_DIR/.smoketest"
DEVMODE="$SKETCH_DIR/.devmode"
RESULT="$SKETCH_DIR/.smoketest_result"

RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

# ── Sanity checks ─────────────────────────────────────────────────────────────
if ! command -v processing &>/dev/null; then
  echo "${RED}ERROR: 'processing' not found on PATH.${RESET}"
  echo "Install the Processing CLI or add it to PATH."
  exit 2
fi

# Warn (don't block) if no song source is configured
if [[ ! -f "$SKETCH_DIR/.devsong" ]] && [[ -z "$(find ~/Music -maxdepth 3 -name '*.mp3' -o -name '*.wav' -o -name '*.flac' 2>/dev/null | head -1)" ]]; then
  echo "${YELLOW}WARNING: No .devsong file found and ~/Music appears empty.${RESET}"
  echo "The sketch may open a file-picker and block.  Create .devsong to avoid this:"
  echo "  echo '/path/to/song.mp3' > $SKETCH_DIR/.devsong"
fi

# ── Setup ─────────────────────────────────────────────────────────────────────
rm -f "$RESULT"          # clear stale result from any previous run
touch "$TRIGGER"         # signal to the sketch to enter smoke-test mode

# Also ensure devmode so the file picker is skipped
CREATED_DEVMODE=false
if [[ ! -f "$DEVMODE" ]]; then
  touch "$DEVMODE"
  CREATED_DEVMODE=true
fi

cleanup() {
  rm -f "$TRIGGER"
  if $CREATED_DEVMODE; then rm -f "$DEVMODE"; fi
}
trap cleanup EXIT

# ── Run ───────────────────────────────────────────────────────────────────────
echo "${BOLD}Running smoke test across all scenes…${RESET}"
echo "(The Processing window will open, iterate every scene, then close.)"
echo

# processing cli exits with 0 even on sketch exceptions, so we rely on the
# result file rather than the exit code.
processing cli --sketch="$SKETCH_DIR" --force --run 2>&1 | \
  grep --line-buffered -E '^\[SMOKE\]|^\[FAIL\]|╔|╠|╚|║|scenes=|checks=|failures=' || true

# ── Read result ───────────────────────────────────────────────────────────────
echo

if [[ ! -f "$RESULT" ]]; then
  echo "${RED}${BOLD}ERROR: result file was never written.${RESET}"
  echo "The sketch likely crashed before finishing the smoke test."
  echo "Re-run with ./run.sh (no .smoketest trigger) to see the full error in the Processing console."
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
