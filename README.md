# Music Visualizer for a Friend

[![Smoke Test](https://github.com/C-Kenny/music-visualizer-4-friend/actions/workflows/smoke-test.yml/badge.svg?branch=master)](https://github.com/C-Kenny/music-visualizer-4-friend/actions/workflows/smoke-test.yml)
[![Latest tag](https://img.shields.io/github/v/tag/C-Kenny/music-visualizer-4-friend?label=release&sort=semver)](https://github.com/C-Kenny/music-visualizer-4-friend/tags)

### What?

Real-time audio-reactive music visualizer with 18 active scenes, built in [Processing 4](https://processing.org/). Controlled with an Xbox 360 / Xbox One controller. Visualizes audio via FFT, beat detection, and oscilloscope waveforms.

### Why?

One of my friends passed away — we used to play a lot of Halo together. This visualizer is dedicated to him, using his Halo 3 Emblem as inspiration.

![Halo3Emblem](media/h3_emblem.jpg)

---

### Preview

With controller overlay: [Music Visualizer with Controller Overlay](https://vimeo.com/501329047)

Without sound:

![MusicVisualizerCK](output/current_output_animated.gif)

---

### Active Scenes

Scenes cycle with **LB / RB** on controller, or **number keys 1–9** (by position in rotation). More scenes reachable with LB/RB beyond key 9.

| Key | Scene | Description |
|-----|-------|-------------|
| 1 | Original | Classic Halo emblem tunnel |
| 2 | Maze Puzzle | Audio-reactive maze |
| 3 | Lissajous Knot | 3D Lissajous curves |
| 4 | Cats Cradle | Bezier string physics |
| 5 | Table Tennis | 2D pong-style reactive |
| 6 | Table Tennis 3D | 3D perspective variant |
| 7 | Prism Codex | Geometry + colour prisms |
| 8 | Gravity Strings | String tension simulation |
| 9 | Neural Weave | Organic neural net |
| LB/RB | Fractal | Recursive fractal zoom |
| LB/RB | Shader | GLSL shader scene |
| LB/RB | Worm Colony | Worm swarm FFT response |
| LB/RB | Recursive Mandala | Layered mandala rings |
| LB/RB | Kaleidoscope | Mirror kaleidoscope |
| LB/RB | Void Bloom | Particle bloom |
| LB/RB | Circuit Maze | PCB-style circuit paths |
| LB/RB | Hourglass | Sand physics + skybox |
| LB/RB | Sacred Geometry | Golden ratio geometry |

---

### Controller Layout

![Xbox 360 Controller Layout](documentation/xbox-360-controller.png)

**LB / RB** — previous / next scene  
**Left stick** — varies per scene  
**Right stick** — varies per scene  
**Start** — toggle HUD  
**Back** — toggle code overlay  

---

### How to Run (Dev Build)

Requires [processing-java](https://github.com/processing/processing4/wiki/Command-Line) on your PATH:

```bash
which processing-java
# /usr/local/bin/processing-java
```

Clone and run:

```bash
git clone git@github.com:C-Kenny/music-visualizer-4-friend.git
cd music-visualizer-4-friend
./run.sh         # opens file picker, select a song
./watch.sh       # hot-reload dev mode (restarts on .pde file save)
```

If your demo machine is CPU-only or low-end, use low-power rendering:

```bash
./run.sh --args --lowpower
```

Use `--lowpower-scale=3` or `--lowpower-scale=4` to reduce render resolution further.

### How to Run Tests

This repo includes a unit + compile check script.

```bash
./run-tests.sh
```

`./run-tests.sh` requires Maven installed on the host machine. If Maven is missing, the script will exit with a clear message instead of attempting an unattended install.

**Dev overrides** (create inside `Music_Visualizer_CK/`, all gitignored):

| File | Effect |
|------|--------|
| `.devmode` | Skip file picker, use default/random song |
| `.devsong` | Override song path |
| `.devscene` | Override starting scene number (e.g. `10`) |

### How to Run (Linux — prebuilt)

Double-click the launcher in a file browser:

```
Music_Visualizer_CK/application.linux64/Music_Visualizer_CK
```

---

### Required Libraries

Install via Processing's **Contribution Manager** (Sketch → Import Library → Manage Libraries):

| Library | Used for |
|---------|----------|
| [Minim](http://code.compartmental.net/tools/minim/) | Audio playback, FFT, beat detection |
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

- [Source code on GitHub](https://github.com/C-Kenny/music-visualizer-4-friend)
- [Issue tracker](https://github.com/C-Kenny/music-visualizer-4-friend/issues)
- [Processing coding standards](documentation/coding_standards_processing.md)
- [Scene list + state numbers](documentation/scene_list.md)
- [Architecture notes](documentation/architecture.md)
