// Radial FFT Scene — state 11
//
// The full FFT spectrum arranged as a circle of tapered spikes.
// Each bar is a filled triangle — wide at the inner ring, pointing outward —
// so high-energy bands look like sunbeams or teeth rather than rectangles.
// A mirror ring on the inside creates a symmetrical sun/eye shape.
// The whole disc rotates slowly; on beat it pulses outward and snaps back.
//
// Audio mapping:
//   Each FFT band     → its bar's length and brightness
//   Bass (inner bars) → overall scale pulse on beat
//   Mid               → rotation speed
//   High              → glow halo intensity
//   Beat              → outward scale burst + hue snap
//
// Controller:
//   L Stick ↕   → bar scale multiplier
//   R Stick ↕   → rotation speed
//   R Stick ↔   → inner/outer ring gap (spread)
//   A           → manual beat burst
//   Y           → cycle colour palette

class RadialFFTScene implements IScene {

  float rotation   = 0.0;
  float rotSpeed   = 0.001;   // signed: positive=CW, negative=CCW
  float scaleMult  = 1.0;
  float beatPulse  = 0.0;   // decaying outward burst on beat
  float spread     = 1.0;   // inner/outer ring gap multiplier
  float hueShift   = 0.0;
  int   palette    = 0;     // 0=spectrum, 1=heat, 2=ice, 3=mono

  // Smoothed per-band amplitudes to avoid flicker
  float[] smoothAmp;
  boolean initialised = false;

  RadialFFTScene() {}

  void drawScene(PGraphics pg) {
    // ── Init smoothed array on first call ──
    if (!initialised) {
      smoothAmp = new float[analyzer.spectrum.length];
      initialised = true;
    }

    // ── Audio ──────────────────────────────────────────────────────────────
    int   N       = analyzer.spectrum.length;
    float rawBass = analyzer.bass;
    float rawMid  = analyzer.mid;
    float rawHigh = analyzer.high;

    for (int i = 0; i < N; i++) {
      float raw = analyzer.spectrum[i];
      smoothAmp[i] = lerp(smoothAmp[i], raw * scaleMult, 0.25);
    }

    boolean isBeat = analyzer.isBeat;
    if (isBeat) {
      beatPulse = 1.0;
      hueShift  = (hueShift + random(40, 90)) % 360;
    }
    beatPulse *= 0.88;

    rotation += rotSpeed + (rotSpeed >= 0 ? 1 : -1) * rawMid * 0.00008;

    // ── Background ─────────────────────────────────────────────────────────
    pg.background(4, 6, 16);

    // Dark radial gradient from center
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();
    float cx = pg.width / 2.0, cy = pg.height / 2.0;
    float maxR = min(pg.width, pg.height) * 0.62;
    for (int r = 5; r >= 1; r--) {
      float rad = maxR * r * 0.22;
      pg.fill(240, 180, 30, 8 + r * 3 + rawBass * 2);
      pg.ellipse(cx, cy, rad * 2, rad * 2);
    }

    // ── Draw bars ──────────────────────────────────────────────────────────
    float innerR = min(pg.width, pg.height) * (0.12 * spread);
    float outerR = min(pg.width, pg.height) * 0.46;
    float burstOff = beatPulse * min(pg.width, pg.height) * 0.04;

    pg.pushMatrix();
    pg.translate(cx, cy);

    for (int i = 0; i < N; i++) {
      float ang    = TWO_PI * i / N + rotation;
      float amp    = constrain(smoothAmp[i], 0, 28);
      float barLen = map(amp, 0, 14, 0, outerR - innerR);
      float inner  = innerR + burstOff;
      float outer  = inner + barLen;

      // Half-width angle of the base of the spike
      float halfW  = (TWO_PI / N) * 0.42;

      // Hue based on position in spectrum
      float t = (float)i / (N - 1);
      float hue = getBarHue(t, amp);
      float sat = 200 + rawHigh * 5;
      float bri = 180 + amp * 3.5;
      float alpha = 180 + amp * 4;

      pg.fill(hue, constrain(sat, 0, 255), constrain(bri, 0, 255), constrain(alpha, 0, 255));

      // Outer spike (tapered triangle pointing outward)
      pg.beginShape(TRIANGLES);
        pg.vertex(cos(ang - halfW) * inner, sin(ang - halfW) * inner);
        pg.vertex(cos(ang + halfW) * inner, sin(ang + halfW) * inner);
        pg.vertex(cos(ang)         * outer, sin(ang)         * outer);
      pg.endShape();

      // Mirror spike pointing inward (inner ring)
      float mirrorLen = barLen * 0.45;
      float mirrorInner = inner - mirrorLen;
      if (mirrorInner > 0) {
        float mAlpha = alpha * 0.5;
        pg.fill(hue, sat, constrain(bri * 0.7, 0, 255), constrain(mAlpha, 0, 255));
        pg.beginShape(TRIANGLES);
          pg.vertex(cos(ang - halfW) * inner,       sin(ang - halfW) * inner);
          pg.vertex(cos(ang + halfW) * inner,       sin(ang + halfW) * inner);
          pg.vertex(cos(ang)         * mirrorInner, sin(ang)         * mirrorInner);
        pg.endShape();
      }
    }

    // ── Central glow disc ──────────────────────────────────────────────────
    float glowR = innerR * 0.7 + rawBass * 1.2 + beatPulse * innerR * 0.12;
    // Outer glow halo (soft, barely visible)
    pg.fill((hueShift + 20) % 360, 140, 255, 10 + beatPulse * 28);
    pg.ellipse(0, 0, glowR * 2.4, glowR * 2.4);
    // Core disc (toned down, less opaque on beat)
    pg.fill((hueShift) % 360, 180, 255, 55 + beatPulse * 35);
    pg.ellipse(0, 0, glowR * 1.4, glowR * 1.4);
    // Bright centre (small pinpoint)
    pg.fill(0, 0, 255, 130 + beatPulse * 50);
    pg.ellipse(0, 0, glowR * 0.45, glowR * 0.45);

    pg.popMatrix();

    pg.colorMode(RGB, 255);

    // ── HUD ────────────────────────────────────────────────────────────────
    String[] palNames = {"Spectrum", "Heat", "Ice", "Mono"};
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      pg.fill(0, 160); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 310 * uiScale(), mg + lh * 5);
      pg.fill(255, 180, 80); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Radial FFT  (" + N + " bands)",                          12, 8 + mg);
      pg.fill(255, 220, 180);
      pg.text("Palette: " + palNames[palette] + "  (Y cycle)",          12, 8 + mg + lh);
      pg.text("Scale: "   + nf(scaleMult, 1, 2) + "  (L ↕)",           12, 8 + mg + lh * 2);
      pg.text("Spin: "    + nf(rotSpeed, 1, 4)  + "  (R ↕ | r=reverse)", 12, 8 + mg + lh * 3);
      pg.text("Spread: "  + nf(spread, 1, 2)    + "  (R ↔)   A=burst", 12, 8 + mg + lh * 4);
    pg.popStyle();

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  float getBarHue(float t, float amp) {
    switch (palette) {
      case 1:  return map(t, 0, 1, 0,   55);   // heat: red→yellow
      case 2:  return map(t, 0, 1, 175, 255);  // ice: cyan→violet
      case 3:  return 160;                       // mono: blue-green
      default: return (hueShift + t * 270) % 360; // spectrum sweep
    }
  }

  void reverseDirection() {
    rotSpeed = -rotSpeed;
  }

  void adjustSpeed(float delta) {
    rotSpeed = constrain(rotSpeed + delta, -0.015, 0.015);
  }

  // ── Controller ─────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // L stick ↕ = scale multiplier
    float ly = map(c.ly, 0, height, -1, 1);
    scaleMult = map(ly, -1, 1, 3.0, 0.3);

    // R stick ↕ = rotation speed (center=stop, up=CW, down=CCW), ↔ = spread
    float ry = map(c.ry, 0, height, -1, 1);
    float rx = map(c.rx, 0, width,  -1, 1);
    if (abs(ry) < 0.12) {
      rotSpeed = 0;
    } else {
      rotSpeed = map(ry, -1, 1, -0.012, 0.012);
    }
    spread = map(rx, -1, 1, 0.6, 1.6);

    if (c.aJustPressed) beatPulse = 1.0;
    if (c.yJustPressed) palette = (palette + 1) % 4;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Radial FFT Controls ===",
      "",
      "L Stick ↕    bar scale",
      "R Stick ↕    rotation speed + direction (center=stop)",
      "r            reverse spin direction",
      "R Stick ↔    inner ring spread",
      "",
      "A            manual beat burst",
      "Y            cycle palette",
      "             (Spectrum/Heat/Ice/Mono)",
      "",
      "LB / RB      prev / next scene",
      "` (backtick) toggle this overlay",
      "",
      "=== Audio ===",
      "Each band    its spike length",
      "Bass         scale pulse on beat",
      "Mid          rotation speed",
      "High         glow halo",
      "Beat         outward burst + hue snap",
    };
  }

  void onEnter() {
    background(4, 6, 16);
  }

  void onExit() {}

  void handleKey(char k) {
    if (k == 'r' || k == 'R') reverseDirection();
    else if (k == '[') adjustSpeed(-0.001);
    else if (k == ']') adjustSpeed(0.001);
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
