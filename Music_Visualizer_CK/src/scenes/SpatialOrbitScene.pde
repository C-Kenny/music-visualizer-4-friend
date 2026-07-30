/**
 * SpatialOrbitScene — the showcase for the 8D-audio tracker (SpatialAudio).
 *
 * You are looking DOWN at the listener's head from above. Front is up.
 * A comet marks where the sound currently sits around the head, exactly as
 * the tracker hears it: on a normal stereo track it sways along the front
 * arc with the pan; when an 8D orbit is detected it breaks loose, ignites,
 * and laps the head at the song's own lap rate, leaving a fading trail.
 *
 * Always audio-reactive even without 8D: a ring of FFT bars breathes around
 * the orbit path, the head pulses with loudness, and beats fire shockwaves.
 *
 * Knobs (controller sticks / web sliders / autopilot):
 *   ring   — orbit radius
 *   trail  — comet trail length
 *   glow   — overall brightness of comet + bars
 *   tilt   — camera tilt: 0 flat top-down, 1 leaned-back 3D disc
 *   bars   — FFT bar height
 */
class SpatialOrbitScene implements IScene {

  // ── Tuning ────────────────────────────────────────────────────────────────
  final int   TRAIL_LENGTH        = 150;   // stored comet positions (2.5 s at 60 fps)
  final int   SPECTRUM_BARS       = 48;    // matches analyzer.spectrum
  final float BASE_RADIUS_FRACTION = 0.30; // orbit radius as fraction of screen
  final float HEAD_RADIUS_FRACTION = 0.30; // head size as fraction of orbit radius
  final float SHOCK_DECAY         = 0.92;  // beat shockwave fade per frame

  // Live knobs — driven by controller sticks, keyboard, web sliders, or the
  // idle autopilot via the ParamRouter spine.
  SceneParam pRing  = new SceneParam("ring",  "Orbit Radius", 0.6, 1.4, 1);
  SceneParam pTrail = new SceneParam("trail", "Comet Trail",  0,   2.5, 1.2);
  SceneParam pGlow  = new SceneParam("glow",  "Glow",         0.4, 2.5, 1);
  SceneParam pTilt  = new SceneParam("tilt",  "Camera Tilt",  0,   1,   0.35);
  SceneParam pBars  = new SceneParam("bars",  "Bar Height",   0,   2.5, 1);
  SceneParam[] params = { pRing, pTrail, pGlow, pTilt, pBars };

  // ── State ─────────────────────────────────────────────────────────────────
  float[] trailAngle  = new float[TRAIL_LENGTH];  // comet path history (azimuth)
  float[] trailRadius = new float[TRAIL_LENGTH];  // 1 = on the ring (allows beat kicks)
  int     trailIndex  = 0;
  int     trailFilled = 0;
  float[] smoothBars  = new float[SPECTRUM_BARS];
  float   smoothMaster = 0;
  float   smoothBass   = 0;
  float   beatShock    = 0;   // expanding shockwave, 0 = none
  float   shockRadius  = 0;
  float   cometHeat    = 0;   // eased orbitStrength for colours

  void drawScene(PGraphics pg) {
    // ── Audio follow ────────────────────────────────────────────────────────
    smoothMaster = lerp(smoothMaster, analyzer.master, 0.1);
    smoothBass   = lerp(smoothBass,   analyzer.bass,   0.15);
    for (int i = 0; i < SPECTRUM_BARS; i++) {
      smoothBars[i] = lerp(smoothBars[i], analyzer.spectrum[i], 0.25);
    }
    if (analyzer.isBeat) { beatShock = 1; shockRadius = 0; }
    beatShock  *= SHOCK_DECAY;
    shockRadius += 14;
    cometHeat = lerp(cometHeat, spatial.orbitStrength, 0.05);

    // Comet rides the tracker's angle; a beat nudges it off the ring a touch.
    float cometAngle = spatial.azimuth;
    trailAngle[trailIndex]  = cometAngle;
    trailRadius[trailIndex] = 1 + smoothBass * 0.08;
    trailIndex  = (trailIndex + 1) % TRAIL_LENGTH;
    trailFilled = min(trailFilled + 1, TRAIL_LENGTH);

    // ── Render ──────────────────────────────────────────────────────────────
    pg.background(3, 4, 10);
    pg.pushStyle();
    pg.pushMatrix();
    pg.translate(pg.width * 0.5, pg.height * 0.5);
    pg.rotateX(pTilt.value * 0.9);   // lean the whole disc back

    float orbitRadius = min(pg.width, pg.height) * BASE_RADIUS_FRACTION * pRing.value;
    float headRadius  = orbitRadius * HEAD_RADIUS_FRACTION * (1 + smoothMaster * 0.12);
    float glow        = pGlow.value;

    pg.blendMode(ADD);
    pg.noFill();

    // Orbit ring — brightens as the tracker gains confidence.
    pg.stroke(60 + 120 * cometHeat, 90 + 80 * cometHeat, 140, 90 * glow);
    pg.strokeWeight(max(1, 1.5 * uiScale()));
    pg.ellipse(0, 0, orbitRadius * 2, orbitRadius * 2);

    // FFT bars radiating outward from the ring. Mirrored left/right so the
    // picture stays symmetric: band 0 (deep bass) at the front, highs behind.
    pg.strokeWeight(max(1, 2.2 * uiScale()));
    for (int i = 0; i < SPECTRUM_BARS; i++) {
      float around = map(i, 0, SPECTRUM_BARS, 0, PI);  // front → back
      float h = smoothBars[i] * orbitRadius * 0.35 * pBars.value;
      float inner = orbitRadius * 1.04;
      // hue: bass red-orange → highs blue, brightness rides the band level
      pg.stroke(120 + 130 * (1 - (float) i / SPECTRUM_BARS),
                70 + 80 * smoothBars[i],
                120 + 130 * ((float) i / SPECTRUM_BARS),
                (40 + 160 * smoothBars[i]) * glow * 0.6);
      // right side
      pg.line(sin(around) * inner, -cos(around) * inner,
              sin(around) * (inner + h), -cos(around) * (inner + h));
      // mirrored left side
      pg.line(-sin(around) * inner, -cos(around) * inner,
              -sin(around) * (inner + h), -cos(around) * (inner + h));
    }

    // Beat shockwave from the head.
    if (beatShock > 0.03 && shockRadius < orbitRadius * 2.2) {
      pg.stroke(255, 255, 255, 120 * beatShock * glow);
      pg.strokeWeight(max(1, (1 + 4 * beatShock) * uiScale()));
      pg.ellipse(0, 0, shockRadius * 2, shockRadius * 2);
    }

    // Listener's head, seen from above: circle + nose pointing front (up).
    pg.stroke(140, 200, 220, 170);
    pg.strokeWeight(max(1, 2 * uiScale()));
    pg.ellipse(0, 0, headRadius * 2, headRadius * 2);
    pg.line(-headRadius * 0.25, -headRadius * 0.95, 0, -headRadius * 1.35);
    pg.line( headRadius * 0.25, -headRadius * 0.95, 0, -headRadius * 1.35);
    // ears — they're the two microphones this whole system listens with
    pg.line(-headRadius, -headRadius * 0.2, -headRadius * 1.15, 0);
    pg.line(-headRadius * 1.15, 0, -headRadius, headRadius * 0.2);
    pg.line( headRadius, -headRadius * 0.2,  headRadius * 1.15, 0);
    pg.line( headRadius * 1.15, 0,  headRadius, headRadius * 0.2);

    // Comet trail — newest segments brightest. Cold blue when just panning,
    // igniting to white-orange as orbit confidence rises.
    int segments = (int) (trailFilled * constrain(pTrail.value / 2.5, 0, 1));
    if (segments > 2) {
      pg.strokeWeight(max(1, 2.5 * uiScale()));
      pg.beginShape(LINES);
      for (int s = 1; s < segments; s++) {
        // walk backwards from the newest sample
        int a = (trailIndex - s     + TRAIL_LENGTH * 2) % TRAIL_LENGTH;
        int b = (trailIndex - s - 1 + TRAIL_LENGTH * 2) % TRAIL_LENGTH;
        float age = (float) s / segments;            // 0 new → 1 old
        float fade = (1 - age) * (1 - age);
        pg.stroke(120 + 135 * cometHeat,
                  140 + 60 * cometHeat,
                  255 - 120 * cometHeat,
                  200 * fade * glow);
        float ra = orbitRadius * trailRadius[a], rb = orbitRadius * trailRadius[b];
        pg.vertex(sin(trailAngle[a]) * ra, -cos(trailAngle[a]) * ra);
        pg.vertex(sin(trailAngle[b]) * rb, -cos(trailAngle[b]) * rb);
      }
      pg.endShape();
    }

    // The comet itself — layered discs for a soft glow.
    float cx = sin(cometAngle) * orbitRadius * (1 + smoothBass * 0.08);
    float cy = -cos(cometAngle) * orbitRadius * (1 + smoothBass * 0.08);
    float cometSize = orbitRadius * (0.10 + 0.10 * smoothMaster + 0.06 * beatShock);
    pg.noStroke();
    for (int layer = 3; layer >= 1; layer--) {
      float spread = layer * 1.6;
      pg.fill(160 + 95 * cometHeat,
              170 + 30 * cometHeat,
              255 - 105 * cometHeat,
              (30 + 60.0 / layer) * glow);
      pg.ellipse(cx, cy, cometSize * spread, cometSize * spread);
    }
    pg.fill(255, 255, 255, 230);
    pg.ellipse(cx, cy, cometSize * 0.5, cometSize * 0.5);

    pg.blendMode(BLEND); // never leak ADD into crossfade/HUD compositing
    pg.popMatrix();
    pg.popStyle();

    // ── top-left HUD ────────────────────────────────────────────────────────
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 6 * uiScale();
      pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 300 * uiScale(), mg * 2 + lh * 3);
      pg.fill(255, 220, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Spatial Orbit  (top-down listener view)", 12, 8 + mg);
      pg.fill(200, 200, 200);
      pg.text("comet = where the sound sits around your head", 12, 8 + mg + lh);
      if (spatial.orbitStrength > 0.05) pg.fill(140, 220, 255);
      else                              pg.fill(150, 150, 150);
      pg.text(spatial.debugLine(), 12, 8 + mg + lh * 2);
    pg.popStyle();
  }

  void onEnter() {
    trailFilled = 0;
    trailIndex  = 0;
    beatShock   = 0;
  }

  void onExit() {}

  void applyController(Controller c) {
    // Spine mapping: LX=ring, LY=trail, RX=glow, RY=tilt, LT/RT=bars, A=reset.
    routeParamsToSticks(c, params);
  }

  void handleKey(char k) {
    handleParamKey(k);   // < > select knob, - + nudge
  }

  SceneParam[] getParams() { return params; }

  String[] getCodeLines() {
    return new String[] {
      "=== Spatial Orbit (8D audio) ===",
      "// looking down at the listener's head, front is up",
      "pan = loudness(R-L)/(R+L) * 0.7 + arrivalTime(L,R) * 0.3",
      "rhythm = autocorrelate(pan history, lag 1.5..15s)",
      "orbitStrength = ramp(rhythm) * ramp(pan sway)",
      "// pan rising through center = passing in FRONT,",
      "// falling through center = passing BEHIND:",
      "azimuth = atan2(pan, panSpeed / lapSpeed)",
      "comet = (sin(azimuth), -cos(azimuth)) * ring",
      "bars[i] = fft band i, bass at front, highs behind"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
