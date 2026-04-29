#!/usr/bin/env bash
# build-deb.sh — wrap Processing's exported Linux app into a .deb.
#
# Usage:
#   bash scripts/build-deb.sh <path-to-exported-app> [version]
#
# <path-to-exported-app> is the folder Processing's exporter produced, e.g.
# .export/Music_Visualizer_CK (containing 'Music_Visualizer_CK' executable +
# 'lib/' + bundled JRE under 'java/').
#
# Output: dist/music-visualizer_<version>_amd64.deb
#
# Install: sudo apt install ./music-visualizer_*.deb
# Run:     music-visualizer    (or pick from app menu)
# Remove:  sudo apt remove music-visualizer
set -euo pipefail

APP_SRC="${1:?usage: $0 <exported-app-dir> [version]}"
VERSION="${2:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo 0.0.0)}"
PKG=music-visualizer
ARCH=amd64

[ -d "$APP_SRC" ] || { echo "ERROR: $APP_SRC not found"; exit 1; }

# ── stage layout ──────────────────────────────────────────────────────────────
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

install -d "$ROOT/DEBIAN"
install -d "$ROOT/opt/$PKG"
install -d "$ROOT/usr/bin"
install -d "$ROOT/usr/share/applications"
install -d "$ROOT/usr/share/icons/hicolor/256x256/apps"
install -d "$ROOT/usr/share/doc/$PKG"

# Copy the exported app payload (preserves executable bits, symlinks, JRE)
cp -a "$APP_SRC"/. "$ROOT/opt/$PKG/"

# Identify the launcher binary that Processing produced.
# It's named after the sketch — find the executable file with no extension.
LAUNCHER=$(find "$ROOT/opt/$PKG" -maxdepth 1 -type f -executable ! -name "*.*" | head -1)
[ -n "$LAUNCHER" ] || { echo "ERROR: no launcher found in $APP_SRC"; exit 1; }
LAUNCHER_NAME=$(basename "$LAUNCHER")

# /usr/bin shim — chdir into /opt/<pkg> so relative paths (data/, libraries/) work.
cat > "$ROOT/usr/bin/$PKG" <<EOF
#!/bin/sh
cd /opt/$PKG && exec ./$LAUNCHER_NAME "\$@"
EOF
chmod 755 "$ROOT/usr/bin/$PKG"

# .desktop entry — picked up by GNOME/KDE/XFCE app menus.
cat > "$ROOT/usr/share/applications/$PKG.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Music Visualizer
GenericName=Audio Visualizer
Comment=Audio-reactive visualizer with 40+ scenes
Exec=$PKG
Icon=$PKG
Terminal=false
Categories=AudioVideo;Audio;Player;
Keywords=music;audio;visualizer;fft;
EOF

# Icon (optional — drop a 256x256 PNG at media/icon.png to use)
if [ -f media/icon.png ]; then
  cp media/icon.png "$ROOT/usr/share/icons/hicolor/256x256/apps/$PKG.png"
else
  echo "[warn] media/icon.png missing — package builds, but no menu icon"
  # Strip Icon= line so .desktop doesn't reference a missing file
  sed -i "/^Icon=/d" "$ROOT/usr/share/applications/$PKG.desktop"
fi

# Copyright (lintian wants this; users can read it from /usr/share/doc/)
cat > "$ROOT/usr/share/doc/$PKG/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Music Visualizer
Source: https://github.com/slaughtrdestny/music-visualizer-4-friend

Files: *
Copyright: $(date +%Y) CK
License: see project repository
EOF

# ── DEBIAN/control ────────────────────────────────────────────────────────────
INSTALLED_KB=$(du -sk "$ROOT/opt" "$ROOT/usr" | awk '{s+=$1} END {print s}')

cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: sound
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_KB
Depends: libgl1, libglu1-mesa, libfreetype6, libfontconfig1, libxrender1, libxtst6, libxi6, libxrandr2, libxext6, libxcursor1, pulseaudio | pipewire-pulse | libpulse0
Maintainer: CK <slaughtrdestny@gmail.com>
Homepage: https://github.com/slaughtrdestny/music-visualizer-4-friend
Description: Audio-reactive visualizer with 40+ scenes
 Processing-based music visualizer driven by FFT + beat detection,
 Xbox controller input, and a phone web controller.
 Bundles its own Java runtime — no system Java required.
EOF

# ── postinst — refresh icon + desktop caches ──────────────────────────────────
cat > "$ROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q /usr/share/icons/hicolor || true
  fi
fi
EOF
chmod 755 "$ROOT/DEBIAN/postinst"

# ── build ─────────────────────────────────────────────────────────────────────
mkdir -p dist
DEB="dist/${PKG}_${VERSION}_${ARCH}.deb"

# --root-owner-group: file ownership becomes root:root regardless of build user
# (skip --root-owner-group on older dpkg-deb; fall back to fakeroot if needed)
if dpkg-deb --help 2>&1 | grep -q -- '--root-owner-group'; then
  dpkg-deb --build --root-owner-group "$ROOT" "$DEB"
else
  fakeroot dpkg-deb --build "$ROOT" "$DEB"
fi

echo
echo "Built: $DEB"
echo "Size:  $(du -h "$DEB" | cut -f1)"
echo
echo "Validate:"
echo "  dpkg-deb -I $DEB         # show control metadata"
echo "  dpkg-deb -c $DEB | head  # list contents"
echo "  lintian $DEB             # policy-check (optional)"
echo
echo "Install:"
echo "  sudo apt install ./$DEB"
