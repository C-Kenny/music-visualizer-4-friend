#!/usr/bin/env bash
# Diagnose what audio inputs the visualizer will see on this machine.
# Linux only. Prints: Pulse/PipeWire sources, Pulse default, Java AudioSystem
# input mixers, sample-rate compatibility hints. No GUI required.
#
# Usage:  ./audio-probe.sh
#
# Why: JVM on Linux only enumerates ALSA mixers (typically just `default`),
# so to capture system audio you flip the Pulse default source to a sink
# monitor. This script shows you exactly which monitors exist.

set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
hr()   { printf -- "─%.0s" {1..70}; printf "\n"; }

bold "=== Pulse / PipeWire ==="
if ! command -v pactl >/dev/null 2>&1; then
  echo "pactl not installed — install pulseaudio-utils or pipewire-pulse"
else
  echo "default sink:   $(pactl get-default-sink 2>/dev/null || echo '?')"
  echo "default source: $(pactl get-default-source 2>/dev/null || echo '?')"
  echo
  echo "All sources (live = what apps capture):"
  pactl list short sources | awk '{printf "  [%s] %s  (%s)\n", $1, $2, $3}'
  echo
  echo "Monitor sources (capture system output via these):"
  pactl list short sources | awk '$2 ~ /\.monitor$/ {printf "  %s\n", $2}' || echo "  none"
fi
hr

bold "=== Java AudioSystem (what JVM/Minim sees) ==="
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/Probe.java" <<'EOF'
import javax.sound.sampled.*;
public class Probe {
  public static void main(String[] a) {
    Mixer.Info[] all = AudioSystem.getMixerInfo();
    if (all == null || all.length == 0) { System.out.println("  no mixers"); return; }
    int idx = 0;
    for (Mixer.Info info : all) {
      try {
        Mixer m = AudioSystem.getMixer(info);
        Line.Info[] tlines = m.getTargetLineInfo();
        if (tlines.length == 0) continue; // skip output-only
        System.out.printf("  [%d] %s%n", idx, info.getName());
        System.out.printf("       %s | %s%n", info.getVendor(), info.getDescription());
        idx++;
      } catch (Exception e) { /* skip */ }
    }
    if (idx == 0) System.out.println("  no input-capable mixers");
  }
}
EOF
JAVAC=$(command -v javac || true)
JAVA=$(command -v java || true)
if [[ -z "$JAVAC" || -z "$JAVA" ]]; then
  # Fall back to Processing's bundled JDK
  PJDK="/snap/processing/current/opt/processing/lib/app/resources/jdk/bin"
  [[ -x "$PJDK/javac" ]] && JAVAC="$PJDK/javac"
  [[ -x "$PJDK/java"  ]] && JAVA="$PJDK/java"
fi
if [[ -z "$JAVAC" || -z "$JAVA" ]]; then
  echo "  javac/java not found — install a JDK or run via Processing"
else
  ( cd "$TMP" && "$JAVAC" Probe.java && "$JAVA" -cp . Probe )
fi
hr

bold "=== Recommendation ==="
cat <<'EOF'
To capture system audio (Spotify/YouTube/etc) in the visualizer:

  1. Run:  ./loopback.sh on
     (sets default Pulse source = current sink monitor)
  2. Launch: ./run.sh
  3. Press '  (apostrophe) to open the Audio Source picker
  4. Pick a "monitor" entry, or pick [default] (which is now the monitor)
  5. To restore: ./loopback.sh off

To capture a mic / line-in:
  - Just pick the appropriate row in the picker; default routing handles it.

Operator dashboard at  http://<lan-ip>:8080/operator.html  shows the live
RMS level — easy way to confirm audio is actually flowing.
EOF
