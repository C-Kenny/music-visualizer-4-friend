#!/usr/bin/env bash
# capture.sh — record per-scene preview videos for the README grid.
#
# For each scene ID, writes .devscene + .devsong, launches ./run.sh with
# MV_DEMO_MODE=1 (synthetic controller input), waits for the window + beat
# warmup, screen-captures with audio via ffmpeg, then ffmpeg-converts to gif.
#
# Output: media/previews/scene_NN_<name>.{mp4,gif}
#
# Deps: xdotool, ffmpeg, pactl, xrandr, gpu-screen-recorder (flatpak)
#
# x11grab can't read GPU-accelerated GL surfaces on Wayland (XWayland exposes a
# placeholder window only) — captures came out black. We use gpu-screen-recorder
# to record the monitor the sketch lives on, then ffmpeg-crop to the window
# rect. Audio still goes through pactl monitor source.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SKETCH_DIR="$ROOT/Music_Visualizer_CK"
OUT_DIR="$ROOT/media/previews"
mkdir -p "$OUT_DIR"

# ── Defaults ──────────────────────────────────────────────────────────────────
# Song path: override with --song or $MV_CAPTURE_SONG. No personal default
# committed — pick any local audio file when running.
SONG_DEFAULT="${MV_CAPTURE_SONG:-}"
WARMUP_SEC=25         # let the beat kick in
DURATION_SEC=15       # raw record length per scene (ffmpeg trims to TRIM_LEN below)
TRIM_START_SEC=1      # skip encoder warmup at start
TRIM_LEN_SEC=10       # final clip length
CAPTURE_FPS=60        # source recording rate
GIF_FPS=50            # GIF delay is 1/100s; <2cs gets floored by many viewers,
                      # so 50fps is the smooth-but-reliable ceiling. Use the mp4
                      # if you need true 60fps playback.
GIF_WIDTH=720

# Scene IDs (numeric) → label (for filename)
declare -A SCENES=(
  [41]="dot_mandala"
  [28]="maze_puzzle"
  [25]="table_tennis_3d"
  [13]="gravity_strings"
  [17]="fractal"
  [18]="shader_lesson"
  [19]="worm"
  [23]="recursive_mandala"
  [32]="sacred_geometry"
  [34]="torus_knot"
  [42]="merkaba"
  [43]="pentagonal_vortex"
)

# Capture order (associative arrays don't preserve order).
SCENE_ORDER=(41 28 25 13 17 18 19 23 32 34 42 43)

# ── Args ──────────────────────────────────────────────────────────────────────
SONG="$SONG_DEFAULT"
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --song)     SONG="$2"; shift 2 ;;
    --warmup)   WARMUP_SEC="$2"; shift 2 ;;
    --duration) DURATION_SEC="$2"; shift 2 ;;
    --only)     ONLY="$2"; shift 2 ;;   # comma-separated scene IDs
    -h|--help)
      echo "Usage: $0 [--song PATH] [--warmup S] [--duration S] [--only ID,ID,...]"
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$SONG" ]] || { echo "No song specified. Use --song PATH or set \$MV_CAPTURE_SONG." >&2; exit 1; }
[[ -f "$SONG" ]] || { echo "Song not found: $SONG" >&2; exit 1; }
command -v xdotool >/dev/null || { echo "Need xdotool" >&2; exit 1; }
command -v ffmpeg  >/dev/null || { echo "Need ffmpeg"  >&2; exit 1; }
command -v pactl   >/dev/null || { echo "Need pactl (PulseAudio)" >&2; exit 1; }
command -v xrandr  >/dev/null || { echo "Need xrandr (for monitor detection)" >&2; exit 1; }
command -v flatpak >/dev/null || { echo "Need flatpak (for gpu-screen-recorder)" >&2; exit 1; }
flatpak info com.dec05eba.gpu_screen_recorder >/dev/null 2>&1 || {
  echo "Need gpu-screen-recorder. Install with:" >&2
  echo "  flatpak install -y flathub com.dec05eba.gpu_screen_recorder" >&2
  exit 1
}

# --filesystem=/tmp so gsr can write its raw mp4 to host /tmp; the flatpak's
# default sandbox isolates /tmp otherwise and the file silently lands inside
# ~/.var/app/.../tmp where the host script can't see it.
# --filesystem=$HOME/.config/gpu-screen-recorder so the persistent xdg-portal
# session token survives across runs (else KDE re-prompts every scene).
GSR_TOKEN_DIR="$HOME/.config/gpu-screen-recorder"
GSR_TOKEN_FILE="$GSR_TOKEN_DIR/portal-session.token"
mkdir -p "$GSR_TOKEN_DIR"
GSR=(flatpak run
     --filesystem=/tmp
     --filesystem="$GSR_TOKEN_DIR"
     --command=gpu-screen-recorder
     com.dec05eba.gpu_screen_recorder)

# On Wayland (KDE/GNOME), GSR's DRM/KMS monitor capture is unavailable on
# this host — only the xdg-desktop-portal path works. portal mode pops a
# "share screen" dialog the first time; we persist the grant via a token file
# so subsequent runs reuse it without prompting.
USE_PORTAL=1
if [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]] && \
   flatpak run --command=gpu-screen-recorder com.dec05eba.gpu_screen_recorder --list-capture-options 2>&1 | grep -qE '^[A-Z]'; then
  USE_PORTAL=0
fi

DEFAULT_SINK=$(pactl get-default-sink)
AUDIO_SRC="${DEFAULT_SINK}.monitor"
echo "[capture] audio source: $AUDIO_SRC"
echo "[capture] song: $SONG"

# ── Monitor detection ─────────────────────────────────────────────────────────
# Echo "X Y W H" for a monitor name; finds bounds in xrandr output.
monitor_bounds() {
  local name="$1"
  xrandr --query | awk -v n="$name" '
    $1 == n && $2 == "connected" {
      for (i = 3; i <= NF; i++) {
        if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
          split($i, a, "[x+]")
          printf "%d %d %d %d\n", a[3], a[4], a[1], a[2]
          exit
        }
      }
    }'
}

# Echo monitor name whose bounds contain (px, py).
monitor_for_point() {
  local px=$1 py=$2
  xrandr --query | awk -v px="$px" -v py="$py" '
    $2 == "connected" {
      name = $1
      for (i = 3; i <= NF; i++) {
        if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
          split($i, a, "[x+]")
          if (px >= a[3] && px < a[3] + a[1] &&
              py >= a[4] && py < a[4] + a[2]) {
            print name; exit
          }
          break
        }
      }
    }'
}

# ── Per-scene capture ─────────────────────────────────────────────────────────
record_scene() {
  local id="$1"
  local label="$2"
  local base="$OUT_DIR/scene_$(printf '%02d' "$id")_${label}"

  echo
  echo "==== scene $id ($label) ===="

  # Stage flags. .devdemo activates DemoInputDriver inside the JVM —
  # snap confinement strips MV_DEMO_MODE env, so use a flag file instead.
  echo "$id" > "$SKETCH_DIR/.devscene"
  echo "$SONG" > "$SKETCH_DIR/.devsong"
  touch "$SKETCH_DIR/.devdemo"

  # Make sure no zombie sketch is holding audio
  pkill -f "Music_Visualizer_CK Music_Visualizer_CK" 2>/dev/null || true
  pkill -f "Processing cli --sketch=.build/Music_Visualizer_CK" 2>/dev/null || true
  sleep 0.5

  # Launch sketch with synthetic controller input
  ( cd "$ROOT" && MV_DEMO_MODE=1 ./run.sh ) >/tmp/capture_run.log 2>&1 &
  local run_pid=$!
  trap 'kill_sketch' EXIT

  # Wait for window. Processing/P3D creates an AWT parent + a NEWT GL child;
  # we want the largest visible one (the GL surface).
  local win=""
  for _ in $(seq 1 30); do
    local cands=$(xdotool search --onlyvisible --name "Music_Visualizer" 2>/dev/null || true)
    if [[ -n "$cands" ]]; then
      local best="" best_area=0
      for w in $cands; do
        eval $(xdotool getwindowgeometry --shell "$w" 2>/dev/null) || continue
        local area=$(( WIDTH * HEIGHT ))
        if (( area > best_area )); then best=$w; best_area=$area; fi
      done
      win=$best
      [[ -n "$win" ]] && break
    fi
    sleep 1
  done
  if [[ -z "$win" ]]; then
    echo "[capture] window never appeared; tail of log:"
    tail -40 /tmp/capture_run.log
    kill_sketch
    return 1
  fi

  # Raise + focus so terminal/IDE doesn't cover the capture region.
  xdotool windowactivate --sync "$win" 2>/dev/null || true
  sleep 0.5

  # Re-read geometry post-activate (window manager may have repositioned)
  eval $(xdotool getwindowgeometry --shell "$win")
  echo "[capture] window $win @ ${X},${Y} ${WIDTH}x${HEIGHT}"

  # Find which monitor the window is on; gpu-screen-recorder captures by output.
  local mon=$(monitor_for_point "$X" "$Y")
  if [[ -z "$mon" ]]; then
    echo "[capture] no monitor contains window at ${X},${Y}; skipping" >&2
    kill_sketch
    return 1
  fi
  read -r MX MY MW MH <<< "$(monitor_bounds "$mon")"
  echo "[capture] monitor: $mon @ ${MX},${MY} ${MW}x${MH}"

  # Crop rect = window rect, translated into monitor-local coords. Clamp to the
  # monitor (xdotool can report the window 1px past the edge).
  local CX=$(( X - MX ))
  local CY=$(( Y - MY ))
  local CW=$WIDTH
  local CH=$HEIGHT
  (( CX < 0 )) && { CW=$(( CW + CX )); CX=0; }
  (( CY < 0 )) && { CH=$(( CH + CY )); CY=0; }
  (( CX + CW > MW )) && CW=$(( MW - CX ))
  (( CY + CH > MH )) && CH=$(( MH - CY ))
  CW=$(( CW - CW % 2 ))
  CH=$(( CH - CH % 2 ))
  echo "[capture] crop: ${CW}x${CH} @ ${CX},${CY} (monitor-local)"

  echo "[capture] warmup ${WARMUP_SEC}s..."
  sleep "$WARMUP_SEC"

  local raw="/tmp/cap_raw_${id}_$$.mp4"
  rm -f "$raw" /tmp/capture_gsr.log
  local capture_target
  local -a portal_args=()
  if (( USE_PORTAL )); then
    capture_target="portal"
    portal_args=(-restore-portal-session yes -portal-session-token-filepath "$GSR_TOKEN_FILE")
    if [[ ! -s "$GSR_TOKEN_FILE" ]]; then
      echo "[capture] First run on Wayland — KDE will prompt to share a screen."
      echo "[capture] Pick the monitor that has the sketch window and check 'remember'."
    fi
  else
    capture_target="$mon"
  fi
  echo "[capture] launching gpu-screen-recorder ($capture_target) -> $raw"
  "${GSR[@]}" \
    -w "$capture_target" \
    "${portal_args[@]}" \
    -f "$CAPTURE_FPS" \
    -a "$AUDIO_SRC" \
    -c mp4 -k h264 \
    -q very_high \
    -cursor no \
    -o "$raw" >/tmp/capture_gsr.log 2>&1 &
  local rec_pid=$!

  # Wait for first encoded frame (gsr prints "update fps:" once encoding starts)
  # so the requested DURATION_SEC reflects actual recorded content, not gsr's
  # KMS/encoder startup time.
  local ready=0
  for _ in $(seq 1 50); do
    if grep -q "update fps:" /tmp/capture_gsr.log 2>/dev/null; then
      ready=1; break
    fi
    sleep 0.1
  done
  if (( ready == 0 )); then
    echo "[capture] gpu-screen-recorder never started encoding; tail of log:"
    tail -20 /tmp/capture_gsr.log
    kill -SIGINT "$rec_pid" 2>/dev/null || true
    kill_sketch
    return 1
  fi

  echo "[capture] recording ${DURATION_SEC}s..."
  sleep "$DURATION_SEC"
  # SIGINT to the flatpak parent doesn't propagate into the sandbox, so the
  # GSR child keeps recording (and holds its xdg-portal screen-share session,
  # leaving a red dot in the KDE tray). pkill -f hits the actual binary
  # regardless of namespace; SIGINT first to flush, then SIGKILL fallback.
  pkill -SIGINT -f "gpu-screen-recorder.*-w portal" 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    pgrep -f "gpu-screen-recorder.*-w portal" >/dev/null || break
    sleep 0.4
  done
  pkill -SIGKILL -f "gpu-screen-recorder.*-w portal" 2>/dev/null || true
  wait "$rec_pid" 2>/dev/null || true

  if [[ ! -s "$raw" ]]; then
    echo "[capture] gpu-screen-recorder produced no output; tail of log:"
    tail -30 /tmp/capture_gsr.log
    kill_sketch
    return 1
  fi

  echo "[capture] crop+trim -> ${base}.mp4"
  ffmpeg -loglevel error -y \
    -ss "$TRIM_START_SEC" -i "$raw" -t "$TRIM_LEN_SEC" \
    -vf "crop=${CW}:${CH}:${CX}:${CY}" \
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    "${base}.mp4"
  rm -f "$raw"

  kill_sketch

  echo "[capture] gif -> ${base}.gif"
  # Two-pass palette: stats_mode=full uses every pixel (better for noisy
  # particle scenes); paletteuse with sierra2_4a dither hides banding.
  local palette="/tmp/cap_palette_$$.png"
  ffmpeg -loglevel error -y -i "${base}.mp4" \
    -vf "fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos,palettegen=stats_mode=full:max_colors=256" \
    "$palette"
  ffmpeg -loglevel error -y -i "${base}.mp4" -i "$palette" \
    -lavfi "fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos [v]; [v][1:v] paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
    "${base}.gif"
  rm -f "$palette"
  echo "[capture] done: $(du -h "${base}.gif" | cut -f1) gif, $(du -h "${base}.mp4" | cut -f1) mp4"
}

kill_sketch() {
  pkill -f "Music_Visualizer_CK Music_Visualizer_CK" 2>/dev/null || true
  pkill -f "Processing cli --sketch=.build/Music_Visualizer_CK" 2>/dev/null || true
  rm -f "$SKETCH_DIR/.devdemo"
  sleep 0.4
}

# Filter by --only
if [[ -n "$ONLY" ]]; then
  IFS=',' read -ra REQ <<< "$ONLY"
  TARGETS=("${REQ[@]}")
else
  TARGETS=("${SCENE_ORDER[@]}")
fi

for id in "${TARGETS[@]}"; do
  label="${SCENES[$id]:-scene}"
  record_scene "$id" "$label" || echo "[capture] scene $id FAILED, continuing"
done

echo
echo "[capture] all done. Outputs in: $OUT_DIR"
ls -1 "$OUT_DIR"
