# Technical Improvements

These are improvements to the codebase infrastructure — things that would make building new
scenes faster, make the live experience better, and reduce the number of bugs per session.

---

## 1. Auto-gain normalisation (high impact, medium effort)

**Problem:** Scenes are tuned for a specific loudness level. A quiet song looks flat; a loud
song makes everything max out.

**Solution:** Track a rolling max across all FFT bands and normalise against it.

```java
// In Audio.pde or as a helper in the main sketch
float rollingMax = 1.0;

float normalisedAvg(int band) {
  float raw = fft.getAvg(band);
  rollingMax = max(rollingMax * 0.997, raw);  // slow decay
  return raw / rollingMax;  // always 0..1
}
```

Scenes would call `audio.normalisedAvg(band)` instead of `audio.fft.getAvg(band)` and get
a value that's always in a useful range. This would make every scene look good on every song
without per-song tuning.

The `0.997` decay rate means the "memory" of the max lasts roughly 300 frames (~5 seconds at
60fps) before it forgets. Tune to taste.

---

## 2. Scene transition system (high impact, medium effort)

**Problem:** Crossfades are abrupt. The snapshot approach works but the new scene "underneath"
is already fully running, which looks odd for scenes with fast-moving content.

**Better approach: hold-and-fade**

When switching scenes, freeze the outgoing scene (keep drawing its last frame) while fading in
the incoming scene. This is closer to how a DJ mixer works.

```java
// On scene switch: save a PImage snapshot of the outgoing scene
// For N frames: draw new scene, then overlay snapshot with decreasing alpha
// After N frames: snapshot = null, transition done
```

Alternatively, introduce a `transitionProgress` (0..1) that scenes can query to draw
themselves fading in — e.g. the worms could spawn from the center on entry, or the FFT worm
could coil into a circle on entry.

**Even better:** a dedicated "transition scene" drawn between the two states. A white flash,
a radial wipe, or a particle explosion that reveals the new scene underneath.

---

## 3. Scene base class (medium impact, low effort)

**Problem:** Every scene has `drawScene()`, `applyController(Controller c)`, `getCodeLines()`.
These are implemented separately in each file with no shared contract. If you rename one, you
have to find all call sites manually.

**Solution:** An interface (or abstract class) in Processing:

```java
// SceneBase.pde
interface VisualizerScene {
  void drawScene();
  void applyController(Controller c);
  String[] getCodeLines();
}
```

Then each scene declares `class WormScene implements VisualizerScene { ... }`.

This unlocks storing scenes in an array/map:
```java
VisualizerScene[] scenes = new VisualizerScene[10];
scenes[3] = wormScene;
scenes[9] = fftWorm;
// In draw(): scenes[config.STATE].drawScene();
// No more switch(config.STATE)!
```

The switch block in `draw()` currently has ~100 lines. This would collapse it to 3.

---

## 4. PShader for per-pixel effects (high impact, high effort)

**Problem:** Per-pixel effects in Java (reaction-diffusion, plasma, pixel sort) are too slow
at full resolution. The current workaround (RENDER_SCALE) works but limits resolution.

**Solution:** GLSL shaders run on the GPU, where per-pixel work is ~1000x faster.

Processing supports fragment shaders via `PShader`:

```java
// In setup():
PShader plasmaShader = loadShader("plasma.glsl");

// In draw():
plasmaShader.set("time", (float)frameCount / 60.0);
plasmaShader.set("bass", bass);
filter(plasmaShader);  // applies to the entire canvas
```

The `plasma.glsl` file lives in `data/shaders/` and is written in GLSL (a C-like language).
It runs once per pixel, in parallel, on the GPU. A reaction-diffusion sim or Lissajous trail
renderer that would take 200ms in Java takes 0.5ms in a shader.

**Good starter project:** rewrite Halo2LogoScene's plasma effect as a fragment shader.
The Java code becomes ~10 lines and the effect runs at full 4K resolution.

---

## 5. Beat history / pattern detection (medium impact, high effort)

**Problem:** All beat reactions are instantaneous — they don't know about the rhythm structure.
A bassline that hits every 4 beats looks the same as random noise to the current code.

**Solution:** Store the last N beat timestamps and compute a BPM estimate. Then predict
the *next* beat and drive anticipatory animations.

```java
// Rough BPM from last 8 beats
long[] beatTimes = new long[8];
float estimatedBPM = 60000.0 / averageInterval(beatTimes);
float nextBeatIn   = timeSinceLastBeat - (60000.0 / estimatedBPM);
```

If you know a beat is ~200ms away, you can start ramping up an animation 200ms early, so the
peak lands exactly on the beat rather than reacting after it. This makes the visualizer feel
less like it's "responding to" the music and more like it's "part of" the music.

---

## 6. Config file for per-song settings (medium impact, low effort)

**Problem:** Each song sounds different. The beat sensitivity, frequency ranges, and visual
intensity that look great on one track look wrong on another. Currently you hand-tune scenes
while the song plays.

**Solution:** A simple key-value text file next to each audio file:

```
# song_settings.txt
beat_sensitivity=0.45
bass_scale=1.2
default_scene=3
```

At load time, `Config.pde` looks for `songname_settings.txt` in the data folder and applies
any overrides it finds. Per-song settings get saved when you adjust them via controller.

This lets you build a "library" of tuned configurations for your favourite tracks.

---

## 7. Joystick input recording and playback (fun, medium effort)

**Problem:** When you're watching the visualizer, you want to drive it with the controller —
but if you want to screen-record a clean take, you have to play the controller perfectly every
time.

**Solution:** Record a sequence of controller states and play it back on demand.

```java
// On record start: ArrayList<ControllerSnapshot> recording = new ArrayList()
// Each frame while recording: recording.add(new ControllerSnapshot(c))
// On playback: read from recording[frameIndex] instead of real controller
```

A `ControllerSnapshot` is just the struct of stick positions and button states at one frame.
At 60fps for 3 minutes, that's 10,800 snapshots — trivial memory.

This was suggested earlier and is worth doing. It's the feature that turns this visualizer
into a performable, repeatable show piece.

---

## 8. Controller deadzone calibration

**Problem:** Analog sticks have hardware variation. A "neutral" stick on one controller might
report 0.05 or -0.08 instead of 0.0. The current code uses a hardcoded threshold of `0.18`
which mostly works but occasionally causes drift.

**Better:** calibrate on startup. During the first 60 frames, sample the stick at rest and
record the neutral position. Subtract it from all subsequent readings.

```java
// In Controller.pde setup:
void calibrate() {
  lxNeutral = currentLX;
  lyNeutral = currentLY;
  // etc.
}

float normalisedLX() {
  float raw = (lx - lxNeutral) / width;
  return abs(raw) < DEADZONE ? 0 : raw;
}
```

This is a 20-line change that eliminates the entire class of "worms drift slowly even when
I'm not touching the stick" problems.

---

## 9. Hot-reload friendly scene architecture

**Problem:** Every code change requires restarting Processing and waiting 5–10 seconds for
recompilation. The `watch.sh` script automates this but the feedback loop is still slow.

**Partial solution:** Keep scene parameters in the Config class and expose them via the HUD.
Changing a float in `Config.pde` only requires recompiling Config, not the whole sketch —
Processing is smart about incremental compilation.

**Better solution (requires work):** Extract scene parameters into a JSON file that's
re-read each draw loop (or on key press). No recompile needed to tweak values. This is how
professional shader tools (e.g. ShaderToy, TouchDesigner) handle it.

```java
// data/scene_params.json
// { "worm_speed": 1.2, "worm_glow": 0.4, ... }
// In draw(): if file modified since last read, reload params
```
