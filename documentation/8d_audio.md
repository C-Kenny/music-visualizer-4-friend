# 8D Audio Tracking (`SpatialAudio`)

"8D audio" mixes pan the music in circles around the listener's head.
`src/core/SpatialAudio.pde` detects this from the stereo signal and exposes
the sound's position so scenes can move with it.

## How detection works

1. **Loudness pan** — compare left/right channel loudness → pan (-1..+1).
2. **Arrival-time pan** — cross-correlate the channels over ±0.9 ms of lag
   (the time sound needs to cross a head). Catches delay-based 8D mixes.
3. **Orbit detection (rhythm check)** — keep the last 25 s of pan in a ring
   buffer (12 Hz) and slide the curve over its own past (normalized
   autocorrelation, lags 1.5–15 s). Real 8D pan repeats itself one lap later
   (score → 1); ordinary stereo wanders and never matches (score → 0).
   `orbitStrength` = ramp(score, 0.45→0.70) × ramp(pan sway, 0.06→0.12).
   The best-matching lag is the lap period. Note the 25 s warm-up: the first
   half-minute of any track reads as flat.
4. **Full 360° angle** — pan alone can't tell front from behind. While
   orbiting, pan traces a sine wave; the *direction* pan is moving recovers
   the full angle via `atan2(pan, panSpeed/lapSpeed)`. Without an orbit,
   azimuth falls back to the front half (`asin(pan)`).

Validated offline (`tools/probe_8d_audio.py`, same math against decoded
files): a real 8D track (Huntrix 8D) is orbit-active 90% of its runtime with
a ~12 s lap; five ordinary controls (hardstyle remix of the *same song*,
slowed+reverb, live KEXP session, OST, city-pop playlist) all read 0%. A
"16D" mix (many stems panning at different rates at once) reads ~3% — its
global pan is genuinely not one repeating orbit. Earlier designs gated on pan
swing thresholds alone and could not separate these cases; the rhythm check
is what makes the detector reliable, keep it if tuning.

Everything is a ratio between channels, so it works in FILE and DEVICE input
modes regardless of gain. Updated once per 60 Hz logic tick in `draw()`,
right after `analyzer.update()`.

## What scenes read

| Field | Meaning |
|-------|---------|
| `spatial.pan` | -1 hard left .. +1 hard right, smoothed |
| `spatial.azimuth` | radians around the head: 0 front, +HALF_PI right, PI behind. Continuous across laps — feed straight into `rotate()` |
| `spatial.angularVelocity` | radians per logic frame the azimuth moves |
| `spatial.orbitStrength` | 0..1 confidence an 8D orbit is active — **always scale your effect by this** so normal stereo doesn't wobble |
| `spatial.orbitPeriodSeconds` | seconds per lap while orbiting |
| `spatial.width` | stereo width: 0 mono .. 1 fully decorrelated |
| `spatial.debugLine()` | one-line HUD readout ("8D: orbit 80% lap 8.0s angle 135°") |

## Scenes wired so far

- **Spatial Orbit (state 56, `SpatialOrbitScene.pde`)** — the showcase scene,
  in rotation after Fable Murmuration. Top-down view of the listener's head;
  a comet marks where the tracker hears the sound. Normal stereo: comet sways
  along the front arc with pan. 8D detected: comet ignites and laps the head
  at the song's lap rate with a fading trail. FFT bar ring (bass front, highs
  behind) + beat shockwaves keep it audio-reactive without 8D. Knobs:
  ring/trail/glow/tilt/bars.
- **Deep Space** — vanishing point slides toward the sound; behind-the-head
  shifts it vertically. HUD shows the 8D readout while an orbit is active.
- **Fable Murmuration** — camera orbit hands over to the sound's lap rate
  (`lerp(ownSpin, spatial.angularVelocity, spatial.orbitStrength)`).

## Adopting in a new scene

```java
// Position something where the sound is (orbit radius r around center):
float x = sin(spatial.azimuth) * r;             // left/right
float z = cos(spatial.azimuth) * r;             // front/behind (3D scenes)
// Always gate by detection confidence:
offset = lerp(offset, x, 0.1) * spatial.orbitStrength;
```

Rules of thumb:
- Multiply by `orbitStrength` (or `lerp` between normal and 8D behavior with
  it) — silence and plain stereo must look unchanged.
- `azimuth` grows without bound; wrap only for display, never for rotation.
- Test with any "8D audio" track from YouTube (download or play via DEVICE
  input); pan-static tracks should show `8D: flat` in the HUD.
