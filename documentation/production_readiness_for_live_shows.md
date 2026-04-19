# Production Readiness for Live Shows

Gap analysis for deploying the visualizer at raves, festivals, and other live
events. Ranked by blast radius — the top items are what turns a "cool demo"
into "I can book this."

Note: **live audio input (DJ mixer line-in / loopback) is excluded** from this
list for now — dev machine has no mixer. It remains the single biggest gap for
a real gig and must be addressed before the first booking. Track separately.

---

## Critical — will ruin the set if missing

### 1. Crash resilience
Any uncaught exception inside a scene currently kills the whole sketch. Mid-set
crash = black screen + audience sees you restart the laptop.

**Fix sketch:**
- Wrap each `scene.drawScene(pg)` call in `try/catch`.
- On exception: log full stack trace to a rotating log file, render a clean
  "scene N unavailable" black card for a few seconds, then auto-cycle to the
  next scene in `SCENE_ORDER`.
- Optional: freeze the offending scene ID for the rest of the session so it
  isn't re-entered by accident.
- Add a watchdog thread that detects >2s frame stalls and force-resets to a
  safe scene.

### 2. Fullscreen + display selection hotkey
Currently windowed. At a venue you plug into a projector/LED wall as a second
display and want output there, not on the laptop.

**Fix sketch:**
- `F11` — toggle fullscreen on current display.
- `Ctrl+1` / `Ctrl+2` / `Ctrl+3` — move the sketch window to display 1/2/3.
- Persist the last-used display index in a settings file.
- Remember to hide the OS cursor when fullscreen on the output display.

### 3. Emergency kill switch (fade-to-black)
Venues demand an instant way to black the screen (wardrobe malfunction,
technical issue, house lights need to come up, etc.).

**Fix sketch:**
- `Esc` — smooth 300 ms fade-to-black and hold. Re-press to fade back.
- Also exposable via MIDI cue button and controller combo (e.g. Back+Start).
- Critically: this must bypass any scene logic — draw black directly over the
  final `sceneBuffer` composite.

### 4. Strobe / flash safety cap
Many venues (UK, EU, parts of US) require epilepsy-safe output. Photosensitive
seizure thresholds are roughly: no more than 3 full flashes per second, and
brightness delta capped over a 100 ms window.

**Fix sketch:**
- Global `StrobeSafety` filter applied to the final composite. Track luminance
  delta over a 100 ms sliding window; if it exceeds threshold, blend in a
  damped version of the previous frame to flatten the spike.
- Toggleable per-venue via HUD / settings. Off for private/home use, on by
  default when fullscreen is engaged.

---

## Important — looks amateur without these

### 5. BPM lock + tap tempo
Minim's beat detector drifts on four-on-the-floor house/techno. Beat-synced
scenes (crossfades, TriggerEngine drops) go off-grid, which reads as broken.

**Fix sketch:**
- `T` — tap tempo. Four taps → average BPM. Ten taps → lock.
- While locked, replace onset-based beat detection with a metronome seeded
  from the lock moment. Onsets can still kick the visual pulse but timing grid
  is authoritative.
- HUD shows current BPM + "locked / following" status.
- `Shift+T` — clear lock.

### 6. MIDI controller support
Xbox pad is fine for you, but industry-standard VJ rigs use Launchpad /
APC40 / Ableton Push. A gig operator may want to run your visualizer without
learning a gamepad.

**Fix sketch:**
- Add MIDI input via `themidibus` or `javax.sound.midi`.
- Pad grid → scene select (8×8 = 64 scene slots, with color feedback).
- Faders → per-scene macro params (density, zoom, threadWarp, etc.).
- Encoder knobs → hue shift, BPM nudge, strobe-cap threshold.
- Config file maps MIDI CC to logical parameter name so any device can be
  mapped without code edits.

### 7. Operator-only HUD on secondary display
Audience sees clean visuals. Operator sees BPM, scene queue, FPS, audio level,
active TriggerEngine values, next-up scene, controller state, strobe-cap
warnings.

**Fix sketch:**
- A second `PGraphics` window (or overlay on operator display only) rendering
  the control panel.
- Main `sceneBuffer` stays pure.
- When fullscreen is on display 2 (projector), display 1 (laptop) becomes the
  operator HUD automatically.

### 8. Setlist / scene queue
At a gig you pre-plan the scene arc: opener, build, peak, breakdown, cooldown.
Manual scene jumping during peak time is error-prone.

**Fix sketch:**
- Plain-text setlist file: `setlist.txt` with one scene ID or scene name per
  line, optional `@BPM` and `@duration` annotations.
- `N` advances the queue to the next entry with crossfade.
- Auto-advance option: when annotated with `@duration 90s` or `@bars 32`.
- HUD shows now / next / next-next.

---

## Polish — makes everything feel pro

### 9. Live text overlay
DJ name, track title, gig name, sponsor logo. Fade in/out on hotkey so the
overlay doesn't distract during peaks.

**Fix sketch:**
- Overlay layer composited after scene render but before strobe safety.
- Source: `text_overlay.json` reloaded on change (live edit during set).
- `O` toggles; `Shift+O` cycles layouts (top-left, bottom-center, ticker).

### 10. Preset snapshots
Per-scene knob state (density, hue, warp, figure style, blend mode, etc.)
saved to named slots. Recall instantly without rebuilding by hand.

**Fix sketch:**
- Each scene exposes `getPreset()` / `applyPreset(Map)` returning its own
  parameter state.
- `Ctrl+S` saves the current scene's state to a slot; `1–9` recalls.
- Presets stored per-scene in `presets/scene_NN.json`.

### 11. Output recording to mp4
Capture the final composite to disk for highlight reels and social posts.

**Fix sketch:**
- Processing's `VideoExport` library or a ffmpeg pipe from `sceneBuffer.save()`
  frames.
- `R` starts/stops, HUD shows red dot + elapsed time.
- Write at half-resolution, 30 fps, so the recorder doesn't starve the render
  loop.

### 12. Session settings file
One place for all the above: preferred display, locked BPM, strobe cap
threshold, MIDI device name, operator HUD toggle. Not committed — lives
alongside `.devmode` and friends.

---

## Suggested work order

1. Crash resilience (#1) — underpins everything else; we should not ship new
   features on top of a sketch that can crash mid-scene.
2. Emergency kill switch (#3) — cheapest to add, massive safety win.
3. Fullscreen + display selection (#2) — unlocks actual projector testing.
4. Strobe safety cap (#4) — required before any public show.
5. Tap tempo / BPM lock (#5) — beat-sync work compounds once the grid is
   reliable.
6. Operator HUD + setlist (#7, #8) — together these turn the visualizer into a
   real instrument.
7. MIDI (#6), overlays (#9), presets (#10), recording (#11) — rolling polish.

Live audio input (excluded above) should be tackled the moment a DJ mixer or
loopback device is available for dev — it is non-negotiable for an actual
booking.
