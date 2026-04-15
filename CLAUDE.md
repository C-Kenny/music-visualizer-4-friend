# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working with this repo.

> **CRITICAL RULE**: ALWAYS run visualizer using `./run.sh` after finishing new feature or bug fix, so user can confirm visually.

## Running the Visualizer

```bash
# Normal run (opens file picker for song selection)
./run.sh

# Hot-reload dev mode (restarts on .pde file changes)
./watch.sh
```

**Dev overrides** (gitignored, inside `Music_Visualizer_CK/`):
- `.devmode` — Skip file picker, use random/default song
- `.devsong` — Override song path
- `.devscene` — Override starting scene number (e.g. `10`)
- `.devpreview` — Save frame to `/tmp/vis_preview.png` every 5s (for visual verification). **Never leave active** — `saveFrame()` blocks the render thread and causes visible stuttering.

No automated tests. Manual testing = run sketch, verify scene visually.

## Architecture

**Runtime:** Processing 4 (Java). Entry point: `Music_Visualizer_CK/Music_Visualizer_CK.pde`.

### Core Singletons (global, declared at top of main file)

| Variable | Class | Purpose |
|----------|-------|---------|
| `config` | `Config` | All flags and tuneable parameters |
| `audio` | `Audio` | Minim wrapper: FFT, beat detection, playback |
| `controller` | `Controller` | GameControlPlus wrapper for Xbox 360 input |

### State Machine

`config.STATE` holds active scene (integer). Each frame `draw()` runs:
1. `audio.forward()` — FFT snapshot (computed once, read by all scenes)
2. `audio.beat.detect()` — Beat detection
3. `getUserInput()` — Keyboard + controller routing
4. `switch(config.STATE)` → `scene.drawScene()`
5. HUD overlays + crossfade compositing

Scene cycling order defined in `SCENE_ORDER[]`. LB/RB bumpers step through it; number keys jump directly.

### Adding a New Scene

1. Create `Music_Visualizer_CK/MyScene.pde` with class implementing:
   - `void drawScene()` — required
   - `void applyController(Controller c)` — optional
   - `String[] getCodeLines()` — optional, for `` ` `` code overlay
2. Add instance variable in main file, instantiate in `setup()`
3. Add `case N:` in `draw()` switch block
4. Add `N` to `SCENE_ORDER[]`

### Audio

```java
audio.fft.getAvg(i)          // FFT band i (log-averaged)
audio.beat.isOnset()         // true on beat
audio.player.left.get(i)     // raw left channel sample (oscilloscope use)
```

Frequency band convention across scenes:
- **Bass:** bands `0` to `fftSize/6`
- **Mid:** `fftSize/6` to `fftSize/2`
- **High:** `fftSize/2` to `fftSize`

Always `lerp()` FFT values toward target — prevents per-frame flicker.

### Controller

`controller.read()` called once per frame. Scenes call `applyController(controller)`.

- **Sticks:** `lx, ly, rx, ry` — mapped to `0..width` / `0..height`
- **Triggers:** `lt`, `rt` — approx. `0..1` depression (absent axes stay `0`)

> [!WARNING]
> **Held State vs Rising Edge (CRITICAL)**
> Use correct button property to avoid flickering or flashing:
> - **`aButton`, `lbButton`, etc. (Held State)**: Use ONLY for sustained actions, chords (e.g. `c.chord(c.lbButton, c.rbButton)`), or continuous modifiers ("while A is held"). Always map to continuous value via `lerp()`:
>   `float target = c.aButton ? 1.0 : 0.0; effect = lerp(effect, target, 0.12);`
> - **`aJustPressed`, `lbJustPressed`, etc. (Rising Edge)**: Use ONLY for single-frame events — toggling menu, stepping array index, spawning quick particle burst. Returns true exactly *one frame*. Used for sustained behavior = instant flash and decay.

Scene **14 (Neural Weave)** uses extra global-key exclusions in `Music_Visualizer_CK.pde` so `B`/`G`/`X`/stick-clicks don't clash with scene bindings; see `documentation/neural_weave.md`.

### HUD System

Two overlay styles — don't mix both in same scene (causes double-HUD):

- `drawCodeOverlay(String[] lines)` — left-side dark panel, formula/educational text; toggled by `` ` ``
- `drawSceneControlsHUD(String[] lines)` — right-side green terminal panel, live control readout

### Crossfade

Transitions capture outgoing frame with `get()` into `crossfadeSnapshot`, composite over new scene with decaying alpha for `CROSSFADE_DURATION` frames. **Always call `blendMode(BLEND)` before composite step** — scenes using `ADD` or other modes corrupt overlay otherwise.

### Performance Notes

- **Object pooling:** `ParticleFountainScene` pre-allocates and recycles `Particle` objects to avoid GC stutter.
- **Render scaling:** Use `RENDER_SCALE` (e.g. 4×) for per-pixel Java loops — render at reduced resolution, scale up.
- FFT computed once in `draw()` before scene switch — never call `audio.forward()` inside scene.

## Library Dependencies

Install via Processing's Contribution Manager:
- **Minim** — audio analysis (FFT, beat detection, playback)
- **Game Control Plus v1.2.2** — Xbox 360 controller
- **Handy** — hand-drawn line aesthetic
- **PeasyCam** — 3D camera (Shapes3DScene only)
- **DashedLines** — dashed line rendering