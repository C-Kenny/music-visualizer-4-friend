# Architecture Overview

## Technology

- **Processing 4** — Java-based creative coding environment
- **GameControlPlus (GCP) v1.2.2** — controller input library (`ControlIO`, `ControlDevice`)
- **Minim** — audio analysis library (FFT, beat detection)
- All `.pde` files in the same sketch folder are compiled together as a single unit

## File structure

```
Music_Visualizer_CK/
  Music_Visualizer_CK.pde   Main sketch: setup(), draw(), input, crossfade, globals
  Config.pde                 Config class: SONG_NAME, STATE, SHOW_CODE, etc.
  Audio.pde                  Audio wrapper: FFT, beat detection, player
  Controller.pde             Controller wrapper: stick/button state, just_pressed logic
  WormScene.pde              Scene 3 — Worm Colony
  FFTWormScene.pde           Scene 9 — FFT Worm
  TableTennisScene.pde       Scene 6 — Table Tennis ball physics
  CatsCradleScene.pde        Scene 4 — String/anchor rotation
  OscilloscopeScene.pde      Scene 5 — Audio waveform
  PrismCodexScene.pde        Scene 7 — Rotating prism geometry
  ParticleFountainScene.pde  Scene 8 — Particle fountain
  Halo2LogoScene.pde         Scene (unused in SCENE_ORDER) — Logo mask
  data/
    images/                  Logo assets (halo2_logo.gif, etc.)
    fonts/                   Mono font for HUD overlays
```

## Scene state machine

`config.STATE` is the active scene integer. The `draw()` function is a `switch(config.STATE)` block.

Scene cycling uses `SCENE_ORDER`:
```java
final int[] SCENE_ORDER = {1, 3, 9, 8, 2, 4, 5, 6, 7};
```
- `LB` → `prevActiveScene()` — steps backward through SCENE_ORDER
- `RB` → `nextActiveScene()` — steps forward through SCENE_ORDER
- Number keys 1–9 → `SCENE_ORDER[key - 1]`

## Controls overlay (HUD)

Two HUD systems exist:

1. **`drawCodeOverlay(String[] lines)`** — left-side dark panel, used by most scenes when `SHOW_CODE` is true. Each scene provides `getCodeLines()`.
2. **`drawSceneControlsHUD(String[] lines)`** — right-side terminal-style green panel. Used by WormScene and FFTWormScene (which own their own internal left-side HUD already).

**Important:** Scenes 3 and 9 must NOT call `drawCodeOverlay()` inside their switch case — they have their own internal HUD in `drawScene()` and use `drawSceneControlsHUD()` after the switch block instead. Mixing both causes a double-HUD bug.

## Crossfade

When switching scenes, a snapshot (`get()`) of the old scene is stored. For N frames, the old scene image is composited over the new scene using `tint(255, alpha); image(crossfadeSnapshot, 0, 0)`.

**Critical:** call `blendMode(BLEND)` before the tint/image call. Scenes that use `blendMode(ADD)` or other modes will cause crossfade artifacts (flickering or wrong compositing) if the blend mode is not reset first.

## Performance tips

- Halo2LogoScene uses `RENDER_SCALE = 4`: renders at 1/4 resolution then scales up. This avoids per-pixel Java loops at full resolution (which caused ~25fps on a decent PC).
- FFT band mapping: `band = (int) map(i, 0, N-1, 0, fftSize-1)` distributes N segments across the full FFT spectrum.

## Dev shortcuts

These files in the project root are gitignored and used for local dev:

| File | Effect |
|------|--------|
| `.devscene` | Contains a number — overrides starting STATE |
| `.devsong`  | Contains a path — overrides SONG_NAME |
| `.devmode`  | Enables dev-specific behaviour |
