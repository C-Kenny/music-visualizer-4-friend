#!/usr/bin/env bash
# ci-install-libs.sh — install bundled Processing libraries into the sketchbook.
#
# Libraries are bundled in Music_Visualizer_CK/libraries/*.zip (see that
# directory's THIRD_PARTY_LICENSES.md for attribution). We bundle rather than
# download because upstream URLs (lagers.org.uk, gicentre.net, jdf/peasycam
# release assets, ddf/Minim release assets) have rotted and CI runs were
# failing on every push.
#
# Usage:
#   bash scripts/ci-install-libs.sh
set -euo pipefail

LIBS="${SKETCHBOOK_LIBS:-$HOME/sketchbook/libraries}"
mkdir -p "$LIBS"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLED="$REPO_ROOT/Music_Visualizer_CK/libraries"

echo "Installing Processing libraries to: $LIBS"
for zip in "$BUNDLED"/*.zip; do
  name=$(basename "$zip" .zip)
  echo "  → $name"
  unzip -qo "$zip" -d "$LIBS"
done

echo "Done. Libraries installed:"
ls "$LIBS"
