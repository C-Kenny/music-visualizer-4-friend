#!/usr/bin/env bash
# Creates a temporary .devmode flag so the sketch picks a random song from
# ~/Music instead of opening the file picker, then cleans up on exit.
DEVMODE="Music_Visualizer_CK/.devmode"
touch "$DEVMODE"
trap 'rm -f "$DEVMODE"' EXIT
processing cli --sketch=Music_Visualizer_CK --force --run
