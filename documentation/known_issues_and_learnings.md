# Known Issues & Learnings

## Controller axis naming (GameControlPlus on Linux)

**Problem:** Calling `c.stick.getSlider("lt").getValue()` or `"rt"` throws a `NullPointerException` — these named sliders don't exist on the Xbox controller config on Linux.

**Fix:** Use `"z"` for the combined trigger axis. LT and RT share one axis: `-1.0` = LT fully pressed, `+1.0` = RT fully pressed.

```java
try {
  float z = c.stick.getSlider("z").getValue();
  speedScale = map(z, -1, 1, 0.3, 2.2);  // LT=slow, RT=turbo (or invert as needed)
} catch (Exception e) { /* no trigger axis */ }
```

Always wrap in try/catch in case the axis doesn't exist on a different controller setup.

## Crossfade blend mode artifact

**Problem:** During crossfades between scenes, if the previous scene left the blend mode set to `ADD`, `EXCLUSION`, etc., the crossfade snapshot drawn with `tint()` + `image()` would composite incorrectly (flickering, wrong colours).

**Fix:** Explicitly call `blendMode(BLEND)` before the crossfade `image()` call.

## Double HUD on worm scenes

**Problem:** Scenes 3 (Worm Colony) and 9 (FFT Worm) have their own internal left-side HUD inside `drawScene()`. If `drawCodeOverlay()` is also called inside the switch case, two overlapping HUDs appear.

**Fix:** Remove `if (config.SHOW_CODE) drawCodeOverlay(scene.getCodeLines())` from case 3 and case 9. These scenes use `drawSceneControlsHUD()` (right-side panel) after the switch block instead.

## FFT Worm radius formula — "big circles" bug

**Problem:** Using `r = lerp(14, 3, t) + amp * 2.2` caused head segments to expand to 70+ px radius at high bass, merging the worm into a blob of overlapping circles.

**Fix:** Cap the radius and reduce the amplitude contribution:
```java
float r = constrain(lerp(14, 3, t) + amp * 0.5 + rip * 5, 3, 24);
```
Similarly, perpendicular wiggle amplitude should be small (`amp * 0.45`) to keep the worm silhouette intact.

## Scene accessibility — state numbers vs keyboard keys

**Problem:** States 10 and 11 can't be reached by number keys (only 1–9 supported) and were at the end of SCENE_ORDER where LB/RB cycling is awkward.

**Fix:** Use unused/lower state slots. Worm Colony moved to state 3, FFT Worm to state 9. SCENE_ORDER updated accordingly.

## Two watch.sh instances

**Problem:** Running `watch.sh` in a terminal tab AND having Claude spawn a background `watch.sh` simultaneously caused two Processing instances to launch on each file save.

**Fix:** Always kill all existing watch.sh instances before starting a new one. Only one should run at a time.

## pushStyle() does NOT save blend mode

Processing's `pushStyle()` / `popStyle()` saves most style attributes but **not** `blendMode()`. If a scene sets a non-standard blend mode, it must manually call `blendMode(BLEND)` to reset it before returning control.

## Halo2LogoScene performance

**Problem:** Per-pixel loops iterating `width × height` (e.g. 2560×1440 = ~3.7M pixels) in Java cause severe frame rate drops (~25fps).

**Fix:** Render at `1/RENDER_SCALE` resolution (RENDER_SCALE=4 → 1/16th pixels), then scale up with `image(frame, 0, 0, width, height)`. Adjust spatial frequencies in the shader-style loops by multiplying by RENDER_SCALE to compensate.

## Worm Colony — intensity tuning

Several beat effects were too intense and were removed/reduced:
- Full-screen vignette on beat → **removed**
- Radial burst ring (`beatRing`) → **removed**
- Head flash on beat → **removed**
- Glow aura: kept but very faint (`glowR = r * 1.7 + high * 0.4`, alpha `lerp(20, 5, t) + high * 0.6`)
- Beat response: only body thickness pulse + hue jolt remain
