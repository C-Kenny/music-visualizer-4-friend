#!/usr/bin/env bash
# Fetch MediaMTX, the streaming sidecar used by Streamer (F6 in sketch).
# Single static binary, runs locally, serves WebRTC + HLS + RTSP from a
# single ffmpeg push. Linux x86_64 only — extend for arm64/mac as needed.
#
# Installs into the user data dir so it's auto-located and survives upgrades.
#
# Usage:  ./install-stream.sh
#
# After install, press F6 in the running sketch to start streaming, then open
# the URL printed in the HUD on a TV/phone browser on the same LAN.

set -euo pipefail

VERSION="${MEDIAMTX_VERSION:-1.9.3}"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH_TAG="amd64" ;;
  aarch64|arm64) ARCH_TAG="arm64v8" ;;
  armv7l) ARCH_TAG="armv7" ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

OS="$(uname -s)"
case "$OS" in
  Linux) OS_TAG="linux" ;;
  Darwin) OS_TAG="darwin" ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

USER_DATA_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/music-visualizer"
mkdir -p "$USER_DATA_DIR"

URL="https://github.com/bluenviron/mediamtx/releases/download/v${VERSION}/mediamtx_v${VERSION}_${OS_TAG}_${ARCH_TAG}.tar.gz"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "fetching: $URL"
curl -fsSL "$URL" -o "$TMP/mediamtx.tar.gz"
tar -xzf "$TMP/mediamtx.tar.gz" -C "$TMP"

cp "$TMP/mediamtx"           "$USER_DATA_DIR/mediamtx"
cp "$TMP/mediamtx.yml"       "$USER_DATA_DIR/mediamtx.yml" 2>/dev/null || true
chmod +x "$USER_DATA_DIR/mediamtx"

# Patch config: bind RTSP/WebRTC/HLS to all interfaces so phones/TVs can hit
# the laptop. Default config binds to localhost in some releases.
CFG="$USER_DATA_DIR/mediamtx.yml"
if [[ -f "$CFG" ]]; then
  # idempotent — just rewrite known knobs we care about
  python3 - "$CFG" <<'PY' || echo "(skipped config patch — install python3-yaml or hand-edit $USER_DATA_DIR/mediamtx.yml)"
import sys, re
p = sys.argv[1]
s = open(p).read()
# Set rtspAddress, hlsAddress, webrtcAddress to 0.0.0.0 listeners (port stays default)
def patch(key, val):
    global s
    s = re.sub(r'^(\s*)' + re.escape(key) + r':.*$', r'\1' + key + ': ' + val, s, flags=re.M)
patch('rtspAddress', ':8554')
patch('hlsAddress', ':8888')
patch('webrtcAddress', ':8889')
# enable hls always-on
patch('hlsAlwaysRemux', 'yes')
patch('hlsLowLatency', 'yes')
open(p, 'w').write(s)
print('patched: rtsp/hls/webrtc bind, hls low-latency')
PY
fi

echo
echo "installed: $USER_DATA_DIR/mediamtx"
"$USER_DATA_DIR/mediamtx" --version 2>/dev/null || true
echo
echo "next:"
echo "  1. ./run.sh"
echo "  2. press F6 in sketch to start streaming"
echo "  3. open http://<laptop-lan-ip>:8080/stream.html on the TV/phone browser"
