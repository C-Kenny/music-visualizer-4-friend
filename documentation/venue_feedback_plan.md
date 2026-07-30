# Venue Feedback Plan

Source: demo went well, venue near-booked. Three improvement areas from venue.

---

## 1. Web stream laggy / chopped

**Current state (`src/core/Streamer.pde`):** already has 30fps throttle, 0.6
render scale, dedicated writer thread, queue depth 12, x264 ultrafast +
zerolatency, 4000k CBR, RTSP→MediaMTX→WebRTC(+HLS) fallback. Architecture is
sound, so chop is from two remaining causes:

**Root causes**
- **Render-thread stall.** `tick()` does `scaleBuf.loadPixels()` (full GPU→CPU
  `glReadPixels`) + `scaleBuf.pixels.clone()` every stream frame on the render
  thread. At 0.6×1080p that's ~3MB readback+copy 30×/s — visible sketch
  stutter AND it caps how fast frames reach ffmpeg.
- **Bitrate vs venue WiFi.** 4000k CBR is fat. On congested/weak venue WiFi the
  WebRTC path drops packets → the chop the viewer sees. Encode is fine; the
  network is the bottleneck.

**Fixes (ordered by payoff)**
1. **Network profile / "venue mode".** Add low-bandwidth preset: scale 0.45,
   bitrate ~1500k maxrate 1800k, fps 24. Hotkey or `.devstream` / config flag.
   Biggest real-world win on bad WiFi.
2. **Double-buffer the snapshot** to kill per-frame `clone()` GC churn: keep two
   reusable int[] buffers, copy into the idle one, hand reference to queue.
3. **Adaptive drop.** When `framesDropped` climbs (writer can't keep up / pipe
   blocking), auto-step fps down 30→24→20 instead of dropping randomly — smooth
   degradation beats jitter.
4. **Prefer HLS for "just watching" screens.** WebRTC for low-latency operator
   view; passive TVs tolerate 1-3s HLS lag and it survives packet loss better.
5. Verify on the ACTUAL venue network before tuning further — most chop is the
   link, not the code.

**Risk:** low. All in Streamer.pde + config. No scene changes.

---

## 2. Scenes not interactive enough

**Reality check:** nearly every real scene already implements
`applyController`. Only backgrounds/helpers lack it (Plasma, Tunnel, Starfield,
Skybox*, BezierHeart). So the gap is **shallow hooks + not surfaced to keyboard
/ web UI**, not missing hooks.

**Depth tiers** (by controller touchpoints — `c.lx`/buttons/triggers refs):
- **Zero input despite being a scene (fix first):** CyberGrid, DeepSpace, RIP,
  TheyDontKnow, TunnelYantra, VisualizerExplainer.
- **Thin (1-3):** LiveCode, SacredGeometry, CircuitMaze, FluidSim, Halo2Logo,
  HeartGrid, SriYantra.
- **Rich (8+) — use as the template:** PentagonalVortex(13), TorusKnot(12),
  MerkabaStar(11), Worm/NeuralWeave/Lissajous/HyperspaceBloom(10).

**Plan — three layers**
1. **Audit depth per scene.** For each scene, list what params exist vs what's
   wired to input. Most map only camera or 1 knob; the rest are audio-only.
   Target: every scene exposes 3-4 live params (e.g. color/palette, density,
   speed, shape morph).
2. **Standardize a param interface.** Add a light contract so a scene can
   declare named params (name, range, current). Lets ONE code path drive them
   from controller, keyboard, AND web — instead of bespoke `applyController`
   each time. Reduces per-scene work for the ~28 audio-only scenes.
3. **Wire web UI sliders.** Extend `WebController` / `ControllerWebSocket` to
   send generic `setParam(scene, name, value)` → router applies to active
   scene. Web UI renders sliders from the scene's declared params. This is the
   feature the venue/audience actually touches.

**Sweep scope:** all audio-only scenes (~28). Do in waves: flagship scenes
first (most-shown), then long tail. Each scene: pick 3-4 meaningful knobs, map
to sticks/triggers + key bindings + web params.

**Watch out (from CLAUDE.md):** held-state vs rising-edge button rules — lerp
continuous modifiers, JustPressed only for one-frame events. Scene 14 has
special global-key exclusions.

**Risk:** medium. Touches many files; the param-interface refactor is the
de-risking move — build it once, apply mechanically.

---

## 3. Some scenes feel "basic" / 2D, no skyboxes

(User note: basic is good *sometimes* — this is selective polish, not a mandate
to 3D-ify everything.)

**State:** most scenes are pure 2D. 3D already exists in Hourglass, Lissajous,
Merkaba, Original3D, Pentagon, TorusKnot, HyperspaceBloom, Chladni,
StrangeAttractor. Skybox infra exists (`SkyboxBackground`, `SkyboxPicker`,
`Skybox.pde`) but the cubemap assets are gitignored (see packaging memory).

**Plan**
1. **Pick 3-5 flagship 2D scenes** to elevate (highest visual impact, most
   shown). Don't touch the ones where flat is the aesthetic.
2. **Add optional skybox/depth backdrop.** Reuse `SkyboxBackground` so a 2D
   scene renders over a parallax cubemap → instant depth. Toggle per-scene so
   "basic" remains available.
3. **Ship skybox assets.** They're gitignored + missing from the .deb (per
   project_packaging_followups). Resolve asset delivery before relying on
   skyboxes live, or they'll be blank at the venue.
4. **Cheap depth tricks for true-2D scenes** that shouldn't go 3D: layered
   parallax, fake fog/vignette via PostFX, additive bloom — adds richness
   without a renderer change.

**Risk:** medium. P3D + skybox can cost FPS; gate behind LOW_POWER awareness.
Asset gitignore/packaging is a blocker to flag early.

---

## 4. Web-UI control queue (fairness + anti-troll)

Venue ask: too many web users grabbing control at once. Need a queue so only
**one web user drives at a time**, with rotation + crowd moderation.

**Hard rule:** Xbox controller + keyboard ALWAYS allowed, never queued. The
queue gates web-UI input only. Local operator stays god-mode.

**Existing infra to build on:** `ClientRegistry`, `PinManager`, `KillSwitch`,
`ControllerWebSocket`, `WebController`, admin/lockdown work (per phone-admin
backlog memory). The queue is a layer over ClientRegistry, not new from zero.

**Design**
1. **Queue model (server side).** Ordered list of connected web clients. One
   `activeDriver` slot. Others are `waiting` with a position index. New web
   client → appended to queue; disconnect → removed, positions shift.
2. **Rotation.** Active driver holds for a turn window (~5 min ≈ 1 song;
   configurable). On expiry → driver moves to back, next in line promoted.
   - Optional: align rotation to song boundary instead of raw timer (hook into
     beat/track change if available) so handoff feels musical.
   - Grace: if queue has only 1 web user, they just keep control (no pointless
     rotation).
3. **Input gating.** `WebController.applyTo()` only forwards input from the
   `activeDriver` connection. Waiting clients' inputs are ignored server-side
   (don't trust client to self-mute).
4. **Feedback to web UI** (push over WS):
   - "You're driving — 4:12 left" with countdown.
   - "You're #3 in queue — ~10 min wait." Live position updates.
   - Toast on promotion: "You're in control!"
5. **Like / dislike (troll-finding).** While someone drives, other web users can
   👍/👎 the *current driver*. Aggregate per session/client id.
   - Show live tally on everyone's screen ("crowd: +12 / -3").
   - Use for moderation signal: heavy 👎 → auto-shorten their turn, auto-skip
     next turn, or flag to operator dashboard for manual kick (KillSwitch).
   - Guard against vote spam: one vote per client per driver-turn; rate-limit.
6. **Operator controls.** Dashboard shows queue + vote tallies; operator can
   kick/ban (PinManager/KillSwitch), pin a driver, or pause rotation.

**Open questions for you**
- Identify web users by what? (random session id, nickname entry, PIN?) Needed
  for queue position + per-user vote dedup.
- Turn length fixed 5 min, or song-aligned?
- Dislike behavior: just signal to operator, or auto-act (shorten/skip)?

**Risk:** medium. Server-side state + WS protocol additions + web UI work. The
input-gating change is small and high-value; the UI/voting is the bulk.

## Status (2026-06-10)

- #1 stream venue-mode + adaptive fps — **SHIPPED** (2.5.10)
- #4 web control queue + voting — **SHIPPED** (2.5.10)
- #2 param spine — **SHIPPED**; zero-input scene wave swept (DeepSpace, RIP,
  TheyDontKnow, TunnelYantra, Explainer) + **ParamAutoPilot** added (`:` —
  drifts knobs to the music when all input idle 30s, for sit-back viewing).
  New flagships: **Fable Murmuration** (state 55), **Spatial Orbit** (state 56),
  **Paralyzed** (state 57, ships its own scene-local 10s idle autopilot on top
  of the spine — see `ParalyzedScene.pde`). Thin-scene wave **SHIPPED**:
  LiveCode, SacredGeometry, CircuitMaze, FluidSim, Halo2Logo, HeartGrid,
  SriYantra all now expose 2-4 real SceneParam knobs (controller+keyboard+web),
  each mapped around whatever buttons/sticks the scene already used (custom
  hand-mapping where A/B/X/Y were taken, `routeParamsToSticks` where free).
  Next: long-tail audio-only scenes (~20 remaining, lower priority — least
  shown).
- #3 skyboxes — **RESOLVED via BYO**: no assets ship (copyright); venue drops
  own packs in user dir, procedural `auto_*` skyboxes always available.
  See `skybox_assets.md`. Flagship 2D depth-polish still open, deprioritised.

## Suggested sequencing

1. **Stream venue-mode + double-buffer** — small, high impact, de-risks the
   booking. Do first.
2. **Param interface + web sliders** — the reusable spine for interactivity.
   Build before the per-scene sweep.
3. **Web control queue** — input-gating first (small, fixes the "too many
   drivers" complaint immediately), then queue UI + voting.
4. **Per-scene interactivity sweep** (waves: zero-input scenes → thin → rest).
5. **Skybox assets + flagship 3D polish** — parallel track; gated on asset
   delivery.
