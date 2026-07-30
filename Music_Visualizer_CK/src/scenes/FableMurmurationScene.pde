/**
 * FableMurmurationScene — Fable 5's signature scene.
 *
 * A murmuration of 2,400 points flying spring-flock physics between four
 * mathematical formations. Each particle owns a slot in every formation, so
 * the swarm never teleports — it FLIES from shape to shape, and the morph
 * knob can hold it mid-transformation indefinitely (half bloom, half galaxy).
 *
 *   0 BLOOM   — phyllotaxis sphere: the golden angle spread onto a sphere,
 *               the same packing sunflowers use.
 *   1 GALAXY  — three-arm logarithmic spiral disk with noise thickness.
 *   2 KNOT    — a (3,2) torus knot threaded as a particle ribbon.
 *   3 SPECTRA — a live FFT ridge: ring position = frequency band, height =
 *               that band's energy right now. The music sculpts the shape.
 *
 * Audio wiring: bass tightens the formation spring, mids feed the orbital
 * swirl field, highs ignite white-hot sparkle on the fastest particles, and
 * every beat fires a radial shockwave through the whole flock.
 *
 * Built spine-native: all five knobs are SceneParams, so controller sticks,
 * keyboard, web sliders, AND the idle autopilot all drive it. Left alone,
 * the autopilot slowly drags the morph knob and the swarm keeps reforming
 * itself to the music — designed to be watched hands-off.
 *
 * Perf: positions batched into one beginShape(POINTS) + one (LINES) pass
 * (see reference: per-point point() calls are a P3D bottleneck). No PeasyCam,
 * no per-frame allocation.
 */
class FableMurmurationScene implements IScene {

  // ── Flock ─────────────────────────────────────────────────────────────────
  final int   FLOCK_SIZE        = 2400;
  final float FORMATION_RADIUS  = 330;   // world units, before screen fit
  final float DAMPING           = 0.90;  // velocity kept per frame
  final float BASE_SPRING       = 0.012; // pull toward formation slot at knob=1
  final float SHOCK_KICK        = 11.0;  // beat shockwave velocity at full kick energy
  final float SHOCK_DECAY       = 0.86;
  final float HUE_DRIFT_PER_SEC = 0.012; // palette slowly walks the color wheel

  // Drop burst — the "spread across the whole scene" moment. Fires when bass
  // spikes well above its own slow-moving average (a drop, not just a beat):
  // the formation spring lets go, the flock blows outward, then reforms.
  final float BURST_TRIGGER_RATIO   = 1.55; // bass vs slow average to call it a drop
  final float BURST_MIN_BASS        = 0.45; // and it must be genuinely loud
  final float BURST_KICK            = 26.0; // initial outward velocity
  final float BURST_DECAY           = 0.94; // slower than beat shock — it blooms
  final int   BURST_COOLDOWN_FRAMES = 240;  // ≥4s apart so only real drops fire
  final float BURST_HUE_JUMP        = 0.09; // palette shifts on every drop

  // Breathing — the whole formation rides the track's loudness.
  final float BREATHE_MIN  = 0.74;  // radius scale in silence
  final float BREATHE_GAIN = 0.34;  // + this much at full loudness

  float[] px = new float[FLOCK_SIZE], py = new float[FLOCK_SIZE], pz = new float[FLOCK_SIZE];
  float[] vx = new float[FLOCK_SIZE], vy = new float[FLOCK_SIZE], vz = new float[FLOCK_SIZE];

  // Formation slots, recomputed cheaply each frame (pure math, no allocation).
  final int SHAPE_COUNT = 4;
  final String[] SHAPE_NAMES = { "BLOOM", "GALAXY", "KNOT", "SPECTRA" };

  float beatShock   = 0;   // 1 on beat, decays — radial kick + flash
  float burst       = 0;   // 1 on drop, decays slowly — full-scene scatter
  int   burstCooldown = 0;
  float orbitAngle  = 0;   // camera orbit
  float hueBase     = 0.62; // start in the blue-violet range
  float smoothBass  = 0, smoothMid = 0, smoothHigh = 0;
  float smoothLoud  = 0;   // overall level, breathing input
  float slowBass    = 0.2; // very slow bass average — drop detection baseline
  float[] smoothSpectrum = new float[48]; // per-band lerp — raw FFT flickers

  // ── Live knobs (ParamRouter spine: sticks, keyboard, web, autopilot) ──────
  SceneParam pMorph = new SceneParam("morph", "Shape Morph",    0,    SHAPE_COUNT - 1, 0);
  SceneParam pSwirl = new SceneParam("swirl", "Swirl Energy",   0,    2.5, 1);
  SceneParam pPull  = new SceneParam("pull",  "Formation Pull", 0.2,  3,   1);
  SceneParam pGlow  = new SceneParam("glow",  "Star Glow",      0.5,  3,   1.4);
  SceneParam pTrail = new SceneParam("trail", "Streak Length",  0,    2.5, 1);
  SceneParam[] params = { pMorph, pSwirl, pPull, pGlow, pTrail };

  FableMurmurationScene() {
    scatterFlock();
  }

  // Start as a loose cloud so the first formation visibly assembles itself.
  void scatterFlock() {
    for (int i = 0; i < FLOCK_SIZE; i++) {
      px[i] = random(-FORMATION_RADIUS, FORMATION_RADIUS) * 1.6;
      py[i] = random(-FORMATION_RADIUS, FORMATION_RADIUS) * 1.6;
      pz[i] = random(-FORMATION_RADIUS, FORMATION_RADIUS) * 1.6;
      vx[i] = vy[i] = vz[i] = 0;
    }
  }

  void onEnter() {
    scatterFlock();
    beatShock = 0;
    burst = 0;
    burstCooldown = 120; // no instant drop-fire while the intro assembles
  }

  void onExit() {}

  // ── Formation slot math ───────────────────────────────────────────────────
  // Slot i of shape s, written into slotOut[0..2]. Pure functions of (i, time,
  // live spectrum) — particles chase these, which is what makes morphs fly.
  float[] slotOut = new float[3];

  // (if/else, not switch — the Processing preprocessor chokes on declarations
  // inside switch-case bodies; see smoke-test notes.)
  void formationSlot(int shape, int i, float t) {
    float n = (float) i / FLOCK_SIZE;          // 0..1 along the flock
    float R = FORMATION_RADIUS;

    if (shape == 0) { // BLOOM — phyllotaxis sphere (golden angle 137.5°)
      float goldenAngle = PI * (3 - sqrt(5.0));
      float yLat  = 1 - 2 * n;                 // -1..1 pole to pole
      float ringR = sqrt(max(0, 1 - yLat * yLat));
      float a     = goldenAngle * i;
      slotOut[0] = cos(a) * ringR * R;
      slotOut[1] = yLat * R;
      slotOut[2] = sin(a) * ringR * R;

    } else if (shape == 1) { // GALAXY — three-arm logarithmic spiral disk
      int   arm      = i % 3;
      float along    = n;                       // 0 core → 1 rim
      float spiralA  = along * 4.2 + arm * TWO_PI / 3 + t * 0.05;
      float spiralR  = R * 0.15 * exp(1.9 * along);
      float thick    = (noise(i * 0.37, t * 0.2) - 0.5) * R * 0.22 * (1 - along * 0.6);
      slotOut[0] = cos(spiralA) * spiralR;
      slotOut[1] = thick;
      slotOut[2] = sin(spiralA) * spiralR;

    } else if (shape == 2) { // KNOT — (3,2) torus knot ribbon with tube width
      float a    = n * TWO_PI;
      float tube = R * 0.10;
      float wob  = i * 2.39996; // de-correlate tube offsets, golden-ish step
      float cx   = R * 0.62 + R * 0.28 * cos(2 * a);
      slotOut[0] = cx * cos(3 * a) + tube * cos(wob);
      slotOut[1] = R * 0.28 * sin(2 * a) + tube * sin(wob);
      slotOut[2] = cx * sin(3 * a) + tube * cos(wob * 1.7);

    } else { // SPECTRA — ring of FFT bands, height = live band energy
      int   bands  = smoothSpectrum.length;             // 48
      int   band   = (int) (n * bands) % bands;
      float a      = n * TWO_PI;
      float energy = smoothSpectrum[band];
      float ringR  = R * (0.75 + 0.1 * sin(a * 3 + t * 0.4));
      slotOut[0] = cos(a) * ringR;
      slotOut[1] = -energy * R * 0.9 + R * 0.25;         // loud bands rise
      slotOut[2] = sin(a) * ringR;
    }
  }

  void drawScene(PGraphics pg) {
    float t = millis() * 0.001;

    smoothBass = lerp(smoothBass, analyzer.bass,   0.15);
    smoothMid  = lerp(smoothMid,  analyzer.mid,    0.12);
    smoothHigh = lerp(smoothHigh, analyzer.high,   0.20);
    smoothLoud = lerp(smoothLoud, analyzer.master, 0.08);
    slowBass   = lerp(slowBass,   analyzer.bass,   0.01); // ~2s memory
    for (int b = 0; b < smoothSpectrum.length; b++) {
      smoothSpectrum[b] = lerp(smoothSpectrum[b], analyzer.spectrum[b], 0.25);
    }

    // Beat shock strength rides the actual kick energy — soft onsets nudge,
    // hard kicks slam. Stops dense tracks turning into constant mush.
    if (analyzer.isBeat) beatShock = max(beatShock, 0.25 + smoothBass * 0.75);

    // Drop detection: bass far above its own recent average = the drop hit.
    if (burstCooldown > 0) burstCooldown--;
    boolean dropHit = smoothBass > slowBass * BURST_TRIGGER_RATIO
                   && smoothBass > BURST_MIN_BASS
                   && burstCooldown == 0;
    if (dropHit) {
      burst = 1;
      burstCooldown = BURST_COOLDOWN_FRAMES;
      hueBase = (hueBase + BURST_HUE_JUMP) % 1.0; // new color chapter per drop
    }

    hueBase = (hueBase + HUE_DRIFT_PER_SEC / 60.0) % 1.0;

    // Morph endpoints: blend slot of floor(morph) with slot of ceil(morph).
    int   shapeA   = constrain((int) floor(pMorph.value), 0, SHAPE_COUNT - 1);
    int   shapeB   = constrain(shapeA + 1, 0, SHAPE_COUNT - 1);
    float shapeMix = pMorph.value - shapeA;

    // Quiet music = tight dim cloud, loud music = full bloom. During a drop
    // burst the spring nearly lets go, so the scatter fills the whole scene
    // before the formation pulls everyone home again.
    float breathe  = BREATHE_MIN + BREATHE_GAIN * smoothLoud;
    float spring   = BASE_SPRING * pPull.value * (1 + smoothBass * 1.6)
                   * (1 - 0.85 * burst);
    float swirl    = 0.05 * pSwirl.value * (0.20 + smoothMid * 2.2);
    float shockNow = beatShock * SHOCK_KICK;
    float burstNow = dropHit ? BURST_KICK : 0; // one-frame impulse, then free flight

    // ── Physics ─────────────────────────────────────────────────────────────
    for (int i = 0; i < FLOCK_SIZE; i++) {
      formationSlot(shapeA, i, t);
      float tx = slotOut[0], ty = slotOut[1], tz = slotOut[2];
      if (shapeMix > 0.001) {
        formationSlot(shapeB, i, t);
        tx = lerp(tx, slotOut[0], shapeMix);
        ty = lerp(ty, slotOut[1], shapeMix);
        tz = lerp(tz, slotOut[2], shapeMix);
      }
      tx *= breathe; ty *= breathe; tz *= breathe;

      // Spring toward the slot + orbital swirl around Y + beat shockwave.
      vx[i] += (tx - px[i]) * spring;
      vy[i] += (ty - py[i]) * spring;
      vz[i] += (tz - pz[i]) * spring;

      vx[i] += -pz[i] * swirl * 0.02;   // tangential push = orbit, not noise:
      vz[i] +=  px[i] * swirl * 0.02;   // keeps the flock turning as one body

      if (shockNow > 0.01 || burstNow > 0) {
        float r = sqrt(px[i]*px[i] + py[i]*py[i] + pz[i]*pz[i]) + 1;
        float kick = shockNow + burstNow * (0.7 + 0.6 * noise(i * 0.91)); // ragged edge
        vx[i] += px[i] / r * kick;
        vy[i] += py[i] / r * kick * 0.7;
        vz[i] += pz[i] / r * kick;
      }

      vx[i] *= DAMPING; vy[i] *= DAMPING; vz[i] *= DAMPING;
      px[i] += vx[i];   py[i] += vy[i];   pz[i] += vz[i];
    }
    beatShock *= SHOCK_DECAY;
    burst     *= BURST_DECAY;

    // ── Render ──────────────────────────────────────────────────────────────
    pg.background(2, 2, 8);
    pg.pushMatrix();
    pg.pushStyle();

    // Slow orbit camera; bass leans the orbit speed, beat punches a tiny zoom.
    // When 8D panning is detected, the camera lets go of its own drift and
    // circles the flock at the same rate the sound laps the listener's head.
    float ownSpin = (0.0024 + smoothBass * 0.004) * analyzer.rotDir;
    orbitAngle += lerp(ownSpin, spatial.angularVelocity, spatial.orbitStrength);
    float fit = min(pg.width, pg.height) / 900.0; // world→screen fit, baked into verts
    pg.translate(pg.width * 0.5, pg.height * 0.5,
                 (120 * beatShock + 200 * burst) * fit - 60); // dolly-in on hits
    pg.rotateY(orbitAngle);
    pg.rotateX(0.35 * sin(orbitAngle * 0.7) + 0.15);

    pg.colorMode(HSB, 1.0);
    pg.blendMode(ADD);

    // Pass 1 — velocity streaks: a line from just-behind to now. Reads as
    // motion blur and shows the flock's flow direction for free.
    float streak = pTrail.value * 2.2;
    if (streak > 0.05) {
      pg.strokeWeight(max(1, 1.2 * fit));
      pg.beginShape(LINES);
      for (int i = 0; i < FLOCK_SIZE; i++) {
        float hue = (hueBase + (float) i / FLOCK_SIZE * 0.22) % 1.0;
        pg.stroke(hue, 0.85, 0.55, 0.35);
        pg.vertex((px[i] - vx[i] * streak) * fit,
                  (py[i] - vy[i] * streak) * fit,
                  (pz[i] - vz[i] * streak) * fit);
        pg.vertex(px[i] * fit, py[i] * fit, pz[i] * fit);
      }
      pg.endShape();
    }

    // Pass 2 — the stars themselves. Fast movers go white-hot when the highs
    // bite, and every star flares during a drop burst.
    pg.strokeWeight(max(1.5, (2.2 + smoothBass * 2.5) * pGlow.value * fit));
    pg.beginShape(POINTS);
    for (int i = 0; i < FLOCK_SIZE; i++) {
      float speed2  = vx[i]*vx[i] + vy[i]*vy[i] + vz[i]*vz[i];
      float hue     = (hueBase + (float) i / FLOCK_SIZE * 0.22) % 1.0;
      boolean spark = (i % 7 == 0) && speed2 > 2.5 && smoothHigh > 0.18;
      if (spark) pg.stroke(hue, 0.10, 1.0, 0.95);
      else       pg.stroke(hue, 0.80 - 0.5 * burst, 0.85,
                           0.55 + 0.25 * smoothLoud + 0.3 * max(beatShock, burst));
      pg.vertex(px[i] * fit, py[i] * fit, pz[i] * fit);
    }
    pg.endShape();

    pg.blendMode(BLEND); // never leak ADD into crossfade/HUD compositing
    pg.popStyle();
    pg.popMatrix();

    // ── top-left HUD ────────────────────────────────────────────────────────
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 6 * uiScale();
      String form = (shapeMix < 0.02) ? SHAPE_NAMES[shapeA]
                  : SHAPE_NAMES[shapeA] + "→" + SHAPE_NAMES[shapeB]
                    + " " + round(shapeMix * 100) + "%";
      boolean show8d = spatial.orbitStrength > 0.05;
      pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 300 * uiScale(), mg * 2 + lh * (show8d ? 3 : 2));
      pg.fill(255, 220, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Fable Murmuration  [" + form + "]", 12, 8 + mg);
      pg.fill(200, 200, 200);
      pg.text("2400 boids · spring flock · beat shockwave", 12, 8 + mg + lh);
      if (show8d) {
        pg.fill(140, 220, 255);
        pg.text(spatial.debugLine(), 12, 8 + mg + lh * 2);
      }
    pg.popStyle();
  }

  void applyController(Controller c) {
    // Spine mapping: LX=morph, LY=swirl, RX=pull, RY=glow, LT/RT=streak, A=reset.
    routeParamsToSticks(c, params);
  }

  void handleKey(char k) {
    handleParamKey(k);
  }

  SceneParam[] getParams() { return params; }

  String[] getCodeLines() {
    return new String[] {
      "=== Fable Murmuration ===",
      "// one flock, four formations — it flies between them",
      "slot[i] = lerp(shapeA(i), shapeB(i), morph)",
      "vel += (slot - pos) * spring(bass)",
      "vel += tangent(pos) * swirl(mid)      // orbit as one body",
      "on beat: vel += normalize(pos) * shock(kick energy)",
      "on drop: spring lets go -> full-scene scatter, reform",
      "radius breathes with loudness (quiet=tight, loud=bloom)",
      "BLOOM   = golden-angle sphere (sunflower packing)",
      "GALAXY  = r = 0.15R * e^(1.9n), 3 arms",
      "KNOT    = (3,2) torus knot ribbon",
      "SPECTRA = ring of 48 FFT bands, height = energy"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("LStick ↔", "Shape morph"),
      new ControllerLayout("LStick ↕", "Swirl energy"),
      new ControllerLayout("RStick ↔", "Formation pull"),
      new ControllerLayout("RStick ↕", "Star glow"),
      new ControllerLayout("LT / RT",      "Streak length"),
      new ControllerLayout("A Button",     "Reset knobs"),
    };
  }
}
