# Music Visualizer for a Friend

[![Smoke Test](https://github.com/C-Kenny/music-visualizer-4-friend/actions/workflows/smoke-test.yml/badge.svg?branch=master)](https://github.com/C-Kenny/music-visualizer-4-friend/actions/workflows/smoke-test.yml)
[![Latest tag](https://img.shields.io/github/v/tag/C-Kenny/music-visualizer-4-friend?label=release&sort=semver)](https://github.com/C-Kenny/music-visualizer-4-friend/tags)

Real-time audio-reactive music visualizer in [Processing 4](https://processing.org/). Dozens of scenes, FFT + beat detection + oscilloscope, GLSL post-processing, Xbox 360 / Xbox One controller (or your phone over WiFi) for live performance.

### Why

A friend of mine passed away — we used to play a lot of Halo together. This visualizer is dedicated to him, using his Halo 3 emblem as inspiration.

![Halo 3 Emblem](media/h3_emblem.jpg)

---

### Preview

Sample scenes (synthetic controller input + auto-played track — see `capture.sh`):

| | | |
|---|---|---|
| ![Dot Mandala](media/previews/scene_41_dot_mandala.gif)<br>Dot Mandala | ![Maze Puzzle](media/previews/scene_28_maze_puzzle.gif)<br>Maze Puzzle | ![Table Tennis 3D](media/previews/scene_25_table_tennis_3d.gif)<br>Table Tennis 3D |
| ![Gravity Strings](media/previews/scene_13_gravity_strings.gif)<br>Gravity Strings | ![Recursive Fractal](media/previews/scene_17_fractal.gif)<br>Recursive Fractal | ![GPU Shader Lesson](media/previews/scene_18_shader_lesson.gif)<br>GPU Shader Lesson |
| ![Worm Colony](media/previews/scene_19_worm.gif)<br>Worm Colony | ![Recursive Mandala](media/previews/scene_23_recursive_mandala.gif)<br>Recursive Mandala | ![Sacred Geometry](media/previews/scene_32_sacred_geometry.gif)<br>Sacred Geometry |
| ![Torus Knot](media/previews/scene_34_torus_knot.gif)<br>Torus Knot | ![Merkaba](media/previews/scene_42_merkaba.gif)<br>Merkaba | ![Pentagonal Vortex](media/previews/scene_43_pentagonal_vortex.gif)<br>Pentagonal Vortex |

> Many scenes are far more dynamic with live controller input — the previews above use a synthetic stick + beat-driven button driver, but a human at the pad changes colours, sweeps the kaleidoscope, drives the worm colony, etc.

Hand-recorded HD walkthroughs (with controller overlay): _coming back soon, see [issues](https://github.com/C-Kenny/music-visualizer-4-friend/issues)._

---

### Install

**Linux (.deb):** download from [Releases](https://github.com/C-Kenny/music-visualizer-4-friend/releases), then:

```bash
sudo dpkg -i music-visualizer_*.deb
music-visualizer
```

**From source (any OS):** see [Run from source](#run-from-source).

---

### Guides

Pick the one that matches what you're doing:

- **[Just want to enjoy it at home?](documentation/guide_casual.md)** — install, run, basic controls, nothing technical.
- **[Performing live (VJ)?](documentation/guide_vj.md)** — live audio input, setlists, scene control, safety hotkeys, what to do if something breaks mid-set.
- **[Setting up / running the tech at a venue?](documentation/guide_venue_admin.md)** — network setup, streaming, phone control, PIN/admin, show-night checklist.

---

### Controls

#### Keyboard

**Scenes**

| Key | Action |
|-----|--------|
| `1`–`9`, `0` | Jump to scene at that slot in `SCENE_ORDER` |
| `<` / `>` | Previous / next scene |
| `Tab` | Scene switcher overlay |
| `w` / `v` | Jump to hotkey-only scenes (Math Wave / Explainer) — not in the rotation |

**Stage**

| Key | Action |
|-----|--------|
| `Ctrl+Enter` | Showtime macro — fullscreen + strobe safety on, one shot |
| `F11` | Toggle fullscreen on current display |
| `Ctrl+1`..`Ctrl+9` | Move window to display N |
| `Esc` | **Kill switch** — emergency fade-to-black (re-press to restore) |
| `F12` | Toggle strobe safety cap |
| `F3` / `Shift+F3` | Toggle live text overlay (DJ name / track title) / cycle layout |
| `F4` | MIDI bridge — scan + open inputs |
| `F5` | Start / stop mp4 recording |
| `F6` / `F7` | Toggle LAN stream (`F7` is the fallback if the WM eats `F6`); `Shift+F6`/`F7` cycles bandwidth profile |
| `F8` | Toggle per-phase frame budget HUD |
| `F9` / `Shift+F9` | Toggle auto-switcher / cycle mode |
| `:` | Toggle knob autopilot — drifts scene params when idle |

**Tempo & setlist**

| Key | Action |
|-----|--------|
| `\` | Tap tempo (4 taps to lock) |
| `\|` | Clear tempo lock |
| `]` / `[` | Setlist: next / previous entry |
| `}` | Setlist: toggle auto-advance |
| `{` | Setlist: reload `setlist.txt` |

**Audio**

| Key | Action |
|-----|--------|
| `'` (apostrophe) | Audio source switcher (file vs live device) |
| `s` | Pause / resume song |
| `n` / `N` | Next / shuffle song |
| `o` / `O` | Open file picker / pick a folder to shuffle |
| `↑` / `↓` | Master volume ±5% |
| `←` / `→` | Skip ±10s |
| `+` / `-` | Nudge live-input gain (DEVICE mode only) |
| `V` | Toggle the volume icon in the AUDIO HUD badge |

**Visuals & backgrounds**

| Key | Action |
|-----|--------|
| `G` / `Shift+G` | Cycle PostFX stack / disable all (bloom, chroma, scanlines, vignette, pixel-sort) |
| `t` / `p` / `P` | Toggle tunnel / plasma / polar-plasma background |
| `h` / `H` | Cycle / toggle hand-drawn renderer |

**Info**

| Key | Action |
|-----|--------|
| `?` | Toggle the stage hotkey help overlay |
| `m` | Toggle metadata HUD |
| `i` | Toggle controller-guide overlay |
| `` ` `` | Toggle code/formula overlay |

**System**

| Key | Action |
|-----|--------|
| `c` | Calibrate controller stick centre |
| `l` / `L` | Toggle verbose console logging |
| `q` | Quit |

#### Xbox controller

![Xbox 360 Controller Layout](documentation/xbox-360-controller.png)

- **LB / RB** — previous / next scene
- **LB + Y** — cycle PostFX  ·  **LB + X** — disable PostFX
- **D-pad up/left/right** — toggle tunnel / plasma / polar-plasma background  ·  **D-pad down** — clear all three
- **Back** — stop song  ·  **Start** — start song  ·  **Back + Start** — kill switch (fade-to-black)
- **Sticks / triggers** — per-scene; press `i` for the in-sketch guide
- **L3** — toggle auto-switcher  ·  **R3** — cycle auto-switcher mode

#### Phone controller (WiFi)

The sketch starts an HTTP + WebSocket server on launch. Bottom-left badge shows a URL like `http://<lan-ip>:8080`. Open it on a phone on the same network for a touch controller. Pin / lockdown / kick controls are available via the admin panel.

---

### Run from source

Requires [Processing 4](https://processing.org/download) (CLI: `processing` or the `processing` snap).

```bash
git clone git@github.com:C-Kenny/music-visualizer-4-friend.git
cd music-visualizer-4-friend
./run.sh                 # opens file picker, select a song
./run.sh device          # start in live audio capture mode
./watch.sh               # hot-reload dev mode (restarts on .pde save)
```

Low-power machines:

```bash
./run.sh --args --lowpower
./run.sh --args --lowpower-scale=4
```

Both drop MSAA (4x→2x) and disable bloom. `--lowpower-scale` doesn't currently
shrink the actual render resolution — that path is disabled pending a
scene-wide refactor (scenes draw in display coordinates, not buffer
coordinates, so a smaller buffer currently misplaces geometry) — so expect
the MSAA/bloom savings only, not a full resolution cut.

#### Dev overrides

All gitignored, all live in `Music_Visualizer_CK/`:

| File | Effect |
|------|--------|
| `.devmode` | Skip file picker, use random song from `~/Music` |
| `.devsong` | Override song path |
| `.devscene` | Start on a specific scene index or name (e.g. `echo 25 > .devscene` or `echo SimCube > .devscene`) |
| `.devvolume` | Start playback at a given listening volume, 0-100% (e.g. `echo 5 > .devvolume` for 5%) — handy for running locally at low volume |
| `.devdemo` | Run with synthetic controller input (Lissajous sweep + beat-driven button taps) — same as `MV_DEMO_MODE=1` |
| `.devpreview` | Save a frame to `/tmp/vis_preview.png` every 5s. **Do not leave on** — `saveFrame()` blocks the render thread |
| `.smoketest` | Headless pass through every scene (exceptions + per-scene frame-time), write `.smoketest_result`, exit — same harness `smoketest.sh` runs |
| `.display` | Persisted display index + fullscreen flag (managed by `F11` / `Ctrl+1..9`) |
| `featureflags.json` | Per-machine flag overrides (HEADACHE_FREE_MODE, BLOOM_ENABLED, AUTO_SWITCH_MODE, etc.) |

#### Tests

```bash
./run-tests.sh           # Maven JUnit checks (requires mvn on PATH)
touch Music_Visualizer_CK/.smoketest && ./run.sh   # full scene sweep
```

#### Capturing preview gifs

```bash
./capture.sh                                            # all 12 default scenes
./capture.sh --only 17,19 --duration 20                 # subset, longer
./capture.sh --song /path/to/track.mp3
```

Needs `xdotool`, `ffmpeg`, `pactl`. Outputs `media/previews/scene_NN_*.{mp4,gif}`.

---

### Live-show readiness

Built-in features for performing in front of an audience:

- **Crash resilience** — scene exceptions are caught, logged to `crash_log.txt`, blacklisted after 3 failures, and auto-skipped (`SceneGuard` + `FrameWatchdog` frame-stall detection).
- **Emergency kill switch** — `Esc` (or controller Back+Start) fades to black for wardrobe / safety.
- **Display select + fullscreen** — `F11` and `Ctrl+1..9`; preference persists in `.display`.
- **Strobe safety cap** — `F12`, auto-enables with fullscreen; dampens unsafe flash rate / luma jumps.
- **Tap tempo / BPM lock** — `` \ `` to tap (4 taps locks), `|` to clear.
- **MIDI bridge** — `F4`; pad notes map to `SCENE_ORDER`.
- **Setlist** — `]` `[` `}` `{`; supports per-entry duration, auto-advance, reload from disk.
- **Live text overlay** — `F3` (DJ name / track title, `Shift+F3` cycles layout).
- **mp4 recording** — `F5`, half-res ffmpeg pipe.
- **LAN streaming** (phone / TV) — `F6`/`F7`, WebRTC + HLS via MediaMTX, with a low-bandwidth venue profile (`Shift+F6`/`F7`).
- **Web control + queue** — phone controller over WiFi, admin lockdown/kick, PIN auth.
- **Headache-free mode** — calmer palette / dimmer composite for long sets, toggleable via `featureflags.json` or the admin web UI.
- **Auto-switcher** — `F9` cycles scenes automatically (time-based or beat-aware modes).
- **Knob autopilot** — `:` drifts scene parameters when idle, for unattended "sit back" viewing.

Still open: operator HUD on a second display, per-scene preset snapshots, and verifying live DJ-mixer input end-to-end — tracked in [`documentation/production_readiness_for_live_shows.md`](documentation/production_readiness_for_live_shows.md).

---

### Libraries

Install via Processing's **Contribution Manager** (Sketch → Import Library → Manage Libraries):

| Library | Used for |
|---------|----------|
| [Minim](http://code.compartmental.net/tools/minim/) | Audio playback, FFT, beat detection, live device capture |
| [Game Control Plus v1.2.2](http://lagers.org.uk/gamecontrol/) | Xbox controller input |
| [Handy](https://github.com/gicentre/handy) | Hand-drawn line aesthetic |
| [PeasyCam](https://mrfeinberg.com/peasycam/) | 3D camera (Shapes3D scene) |
| [DashedLines](https://github.com/garciadelcastillo/dashed-lines) | Dashed line rendering |

---

### Credits

- [Luis Gonzalez](https://luis.net/) — Processing tunnels + plasma backgrounds
- ttaM — incredible help on Bezier curves (fins)

---

### Resources

- [Source on GitHub](https://github.com/C-Kenny/music-visualizer-4-friend)
- [Issue tracker](https://github.com/C-Kenny/music-visualizer-4-friend/issues)
- [Casual / at-home guide](documentation/guide_casual.md)
- [VJ / live performance guide](documentation/guide_vj.md)
- [Venue admin / tech guide](documentation/guide_venue_admin.md)
- [Scene list + state numbers](documentation/scene_list.md)
- [Architecture notes](documentation/architecture.md)
- [Production-readiness roadmap](documentation/production_readiness_for_live_shows.md)
- [Processing coding standards](documentation/coding_standards_processing.md)
