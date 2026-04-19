#!/usr/bin/env bash
# ci-install-libs.sh — download all Processing libraries needed to build the sketch.
#
# Run this once locally on a fresh machine, or let GitHub Actions cache the result.
# All URLs should be verified if a download fails — library hosts sometimes move files.
#
# Usage:
#   bash scripts/ci-install-libs.sh
#
set -euo pipefail

LIBS="${SKETCHBOOK_LIBS:-$HOME/sketchbook/libraries}"
mkdir -p "$LIBS"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

dl() {
  local name="$1" url="$2" file="$TMP/$name.zip"
  echo "  → $name"
  wget -q --show-progress "$url" -O "$file"
  unzip -q "$file" -d "$LIBS"
}

echo "Installing Processing libraries to: $LIBS"

# ── Minim 2.2.2  (audio analysis + FFT) ─────────────────────────────────────
# Source: https://github.com/ddf/Minim/releases
dl minim "https://github.com/ddf/Minim/releases/download/v2.2.2/minim-2.2.2.zip"

# ── GameControlPlus 1.2.2  (Xbox 360 controller) ────────────────────────────
# Source: http://lagers.org.uk/gamecontrol/
dl GameControlPlus "https://lagers.org.uk/gamecontrol/download/GameControlPlus-1.2.2.zip"

# ── PeasyCam  (3D camera, Shapes3DScene) ────────────────────────────────────
# Source: https://github.com/jdf/peasycam/releases
dl peasycam "https://github.com/jdf/peasycam/releases/download/206/peasycam-206.zip"

# ── DashedLines  (dashed line rendering) ────────────────────────────────────
# Source: https://www.gicentre.net/utils/dashedlines
dl dashedlines "https://www.gicentre.net/utils/dashedlines/DashedLines.zip"

# ── Handy  (hand-drawn aesthetic) — bundled in repo ─────────────────────────
unzip -q "$REPO_ROOT/Music_Visualizer_CK/libraries/handy.zip" -d "$LIBS"

echo "Done. Libraries installed:"
ls "$LIBS"
