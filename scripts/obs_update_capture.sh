#!/usr/bin/env bash
# obs_update_capture.sh
#
# Finds the running Music Visualizer CK window and patches the OBS scene
# collection so the "Processing" xcomposite capture source points at it.
#
# Usage:
#   1. Start the visualizer:  ./run.sh
#   2. Wait a few seconds for the title bar to update (it shows "Music Visualizer CK | fps: ...")
#   3. Run this script:       ./scripts/obs_update_capture.sh
#   4. Restart OBS (or reload the scene collection: Scene Collection → Untitled)
#
# Requirements: xdotool, python3

set -euo pipefail

OBS_SCENE_FILE="$HOME/.config/obs-studio/basic/scenes/Untitled.json"
SOURCE_NAME="Processing"
TITLE_PATTERN="Music Visualizer CK"

echo "==> Searching for window: '$TITLE_PATTERN'"

# Find window ID — xdotool search --name uses regex
WIN_IDS=$(xdotool search --name "$TITLE_PATTERN" 2>/dev/null || true)

if [ -z "$WIN_IDS" ]; then
  echo ""
  echo "ERROR: No window found matching '$TITLE_PATTERN'."
  echo "Make sure the visualizer has been running for a few seconds"
  echo "(the title bar updates every 100 frames)."
  exit 1
fi

# Take the first match
WIN_ID=$(echo "$WIN_IDS" | head -1)
WIN_TITLE=$(xdotool getwindowname "$WIN_ID")
WIN_CLASS=$(xdotool getwindowclassname "$WIN_ID" 2>/dev/null || echo "unknown")

echo "==> Found window:"
echo "    ID:    $WIN_ID"
echo "    Title: $WIN_TITLE"
echo "    Class: $WIN_CLASS"

# OBS xcomposite_input capture_window format: "WINDOW_ID\r\nTITLE\r\nCLASS"
CAPTURE_VALUE="${WIN_ID}\r\n${WIN_TITLE}\r\n${WIN_CLASS}"

echo ""
echo "==> Patching: $OBS_SCENE_FILE"
echo "    Source:  '$SOURCE_NAME'"
echo "    Value:   $CAPTURE_VALUE"

if [ ! -f "$OBS_SCENE_FILE" ]; then
  echo "ERROR: OBS scene file not found at $OBS_SCENE_FILE"
  exit 1
fi

# Backup
cp "$OBS_SCENE_FILE" "${OBS_SCENE_FILE}.bak"
echo "==> Backup saved: ${OBS_SCENE_FILE}.bak"

# Patch JSON with Python
python3 - "$OBS_SCENE_FILE" "$SOURCE_NAME" "$WIN_ID" "$WIN_TITLE" "$WIN_CLASS" <<'PYEOF'
import json, sys

scene_file  = sys.argv[1]
source_name = sys.argv[2]
win_id      = sys.argv[3]
win_title   = sys.argv[4]
win_class   = sys.argv[5]

with open(scene_file, "r") as f:
    data = json.load(f)

capture_value = f"{win_id}\r\n{win_title}\r\n{win_class}"
patched = False

for source in data.get("sources", []):
    if source.get("name") == source_name and source.get("id") == "xcomposite_input":
        source["settings"]["capture_window"] = capture_value
        patched = True
        print(f"  Patched source '{source_name}'")
        break

if not patched:
    print(f"WARNING: Source '{source_name}' (xcomposite_input) not found in {scene_file}")
    print("  You may need to create it manually in OBS.")
    sys.exit(1)

with open(scene_file, "w") as f:
    json.dump(data, f, separators=(",", ":"))

print("  Done.")
PYEOF

echo ""
echo "==> Done. If OBS is already open:"
echo "    Scene Collection menu → select 'Untitled' to reload."
echo "    Then switch to the 'Music Visualizer' scene to confirm capture."
