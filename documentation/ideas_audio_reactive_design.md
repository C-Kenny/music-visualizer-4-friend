# Audio-Reactive Design Principles

These are lessons learned from building the scenes in this visualizer. They're not rules —
they're heuristics that explain *why* some things look great and others look like a screensaver.

---

## 1. Map to structure, not just loudness

The most common beginner mistake is mapping everything to volume. Volume goes up → thing gets
bigger. Volume goes down → thing gets smaller. This works, but it's shallow.

Better: map different *structural features* of the audio to different *visual dimensions*.

| Audio feature | Good visual mapping |
|--------------|---------------------|
| Bass energy  | Scale, thickness, weight — things that feel *heavy* |
| Mid energy   | Movement speed, number of elements, complexity |
| High energy  | Glow, sparkle, shimmer — things that feel *bright* |
| Beat onset   | Sudden positional change, burst, colour snap |
| Beat absence | Slow drift, fade, settle |

The FFT Worm scene does this well: the head (bass) is fat and slow, the tail (highs) is thin
and shimmers fast. You can *see* the frequency spectrum in the worm's shape.

---

## 2. Smooth it, then add a fast layer on top

Raw FFT values flicker too fast to read visually. `lerp(current, target, 0.3)` is the standard
smoothing tool — but if you smooth too much, beats look mushy.

The pattern that works best:

```java
// Slow-smoothed value — drives scale, colour
float smoothBass = lerp(smoothBass, rawBass, 0.15);

// Fast-decaying impulse — drives beat flash, particle burst
if (isBeat) beatImpulse = 1.0;
beatImpulse *= 0.85;  // decays to 0 within ~20 frames
```

Use `smoothBass` for continuous effects. Use `beatImpulse` for snap effects. Layering both
gives you groove + punch simultaneously.

This is exactly how the FFT Worm beat ripple works: `ripple[0] = 1.0` on beat, then decays
through the chain. The ripple is the fast layer on top of the slow bandAmp smoothing.

---

## 3. Beat detection is unreliable — design for it

Minim's beat detector has false positives and missed beats. This is not a bug to fix; it's
a constraint to design around.

**Don't:** use beat onset to trigger a one-shot expensive operation that looks wrong if it fires
twice in a row or is missed entirely.

**Do:** use beat onset to *nudge* continuous state. The worm colour jolt (`hue += random(40)`)
is a good example — if it fires twice, the colour shifts twice, which is fine. If it misses a
beat, the worm still moves. Nothing breaks.

Also: beat detection works much better on music with a clear kick drum. Ambient or complex
polyrhythmic music will feel unresponsive. Consider providing a manual beat trigger on a
controller button for live use.

---

## 4. The scene needs a resting state

Every scene should look interesting at silence or low volume, not just when the music is loud.

The Worm Colony at silence: worms still wander via Perlin noise. The FFT Worm at silence:
the worm still slithers around the screen.

If your scene collapses to a dot or blank screen at low energy, it looks broken. The wander
behaviour, rotation, or drift should always be running — the audio just *modulates* it.

---

## 5. One dominant effect per scene

The scenes that feel most cohesive each have one thing that's doing the heavy lifting visually:

- Worm Colony: the worm movement and eyes
- FFT Worm: the body IS the frequency spectrum
- Cats Cradle: the rotating string geometry
- Oscilloscope: the waveform line

Everything else in those scenes (glow, particles, colour) is supporting texture. When you add
too many effects at the same level of visual weight, the eye doesn't know what to follow and
the scene feels busy and chaotic.

A good test: describe the scene in one sentence. If you can't, it's probably trying to do too much.

---

## 6. Use HSB colour mode, not RGB

In `colorMode(HSB, 360, 255, 255, 255)`:

- Hue (0–360) cycles through the rainbow
- Saturation (0–255) goes grey → vivid
- Brightness (0–255) goes black → full colour

This is natural for audio-reactive work because:
- **Hue** can be driven by time/mids and will always look coherent (no ugly colour mixing)
- **Saturation** mapped to energy means quiet = pastel, loud = vivid — which feels right
- **Brightness** on beat creates a flash without changing the hue

RGB arithmetic creates colour mud. `lerp(red, blue, t)` goes through purple. In HSB,
`lerp(hue1, hue2, t)` glides cleanly around the colour wheel.

Always reset with `colorMode(RGB, 255)` at the end of your `draw()` — otherwise other scenes
will inherit your colour mode.

---

## 7. Perlin noise for organic motion

`noise(x, y, t)` returns a smooth pseudo-random value in [0, 1]. The key insight is that
nearby inputs give nearby outputs — so incrementing `t` each frame gives smooth temporal flow,
and using the position as spatial input ties the motion to place.

For worm wandering:
```java
float wander = noise(sx[0] * 0.004 + seed, sy[0] * 0.004, frameCount * 0.003) * TWO_PI * 2.5;
```

The `* 0.004` scales control the "zoom level" of the noise field:
- Too large (e.g. `* 0.05`): worm changes direction frantically
- Too small (e.g. `* 0.001`): worm barely turns, goes in long straight lines
- 0.003–0.006 is a good range for smooth organic wandering

The `seed` (a random offset per worm) ensures each worm has a unique path through the same
noise field — they won't clump together.

---

## 8. The "intensity dial" problem

Almost every effect has a range from "barely visible" to "overwhelming". Finding the right
value by hardcoding it is slow and fragile — it changes with the song, the room, the screen.

**Short-term fix:** controller knob (R stick or trigger) for intensity, shown in HUD.

**Better fix:** auto-calibrate. Track a rolling max of the FFT values and normalise against it:
```java
rollingMax = max(rollingMax * 0.995, currentValue);  // slow decay
float normalised = currentValue / max(1, rollingMax);
```
Now your visual effect is always using the full dynamic range of the current song, regardless
of how loud it is overall. The worm's body will pulse to the beat of a quiet ambient track the
same way it pulses to a loud banger.

This technique is sometimes called "soft normalisation" or "automatic gain control".

---

## 9. Don't fight the frame rate

Processing renders one `draw()` call per frame. Everything inside it is synchronous.
Expensive per-pixel operations (reaction-diffusion, pixel sorting, complex masks) must be
budgeted carefully.

Rules of thumb:
- Iterating over `width * height` pixels in Java: 1080p ≈ 2M pixels, too slow (see Halo2LogoScene fix)
- Iterating over 160×90 (reduced res): 14K pixels, fine
- Drawing 1000 ellipses: fine
- Drawing 50,000 points with `point()`: borderline
- A shader (PShader) running on the GPU: effectively free for per-pixel effects

If a scene idea requires per-pixel computation, plan it at reduced resolution from the start.
The `RENDER_SCALE` pattern (render at 1/N, draw scaled up) is the right tool.

Alternatively, look into PShader — Processing supports GLSL fragment shaders, and a reaction-
diffusion simulation or plasma effect on the GPU runs at 60fps even at 4K.
