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

class RadialFFTScene {

  float rotation   = 0.0;
  float rotSpeed   = 0.004;
  float scaleMult  = 1.0;
  float beatPulse  = 0.0;   // decaying outward burst on beat
  float spread     = 1.0;   // inner/outer ring gap multiplier
  float hueShift   = 0.0;
  int   palette    = 0;     // 0=spectrum, 1=heat, 2=ice, 3=mono

  // Smoothed per-band amplitudes to avoid flicker
  float[] smoothAmp;
  boolean initialised = false;

  RadialFFTScene() {}

  void drawScene() {
    // ── Init smoothed array on first call (fftSize not available in constructor) ──
    if (!initialised) {
      smoothAmp = new float[audio.fft.avgSize()];
      initialised = true;
    }

    // ── Audio ──────────────────────────────────────────────────────────────
    int   N       = audio.fft.avgSize();
    float rawBass = 0, rawMid = 0, rawHigh = 0;
    int   bassEnd = max(1, N / 6);
    int   midEnd  = max(bassEnd + 1, N / 2);

    for (int i = 0; i < N; i++) {
      float raw = audio.fft.getAvg(i);
      smoothAmp[i] = lerp(smoothAmp[i], raw * scaleMult, 0.25);
    }
    for (int i = 0;       i < bassEnd; i++) rawBass += smoothAmp[i];
    for (int i = bassEnd; i < midEnd;  i++) rawMid  += smoothAmp[i];
    for (int i = midEnd;  i < N;       i++) rawHigh += smoothAmp[i];
    rawBass /= bassEnd;
    rawMid  /= max(1, midEnd - bassEnd);
    rawHigh /= max(1, N - midEnd);

    boolean isBeat = audio.beat.isOnset();
    if (isBeat) {
      beatPulse = 1.0;
      hueShift  = (hueShift + random(40, 90)) % 360;
    }
    beatPulse *= 0.88;

    rotation += (rotSpeed + rawMid * 0.0003);

    // ── Background ─────────────────────────────────────────────────────────
    background(4, 6, 16);

    // Dark radial gradient from center
    colorMode(HSB, 360, 255, 255, 255);
    noStroke();
    float cx = width / 2.0, cy = height / 2.0;
    float maxR = min(width, height) * 0.62;
    for (int r = 5; r >= 1; r--) {
      float rad = maxR * r * 0.22;
      fill(240, 180, 30, 8 + r * 3 + rawBass * 2);
      ellipse(cx, cy, rad * 2, rad * 2);
    }

    // ── Draw bars ──────────────────────────────────────────────────────────
    float innerR = min(width, height) * (0.12 * spread);
    float outerR = min(width, height) * 0.46;
    float burstOff = beatPulse * min(width, height) * 0.04;

    pushMatrix();
    translate(cx, cy);

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

      fill(hue, constrain(sat, 0, 255), constrain(bri, 0, 255), constrain(alpha, 0, 255));

      // Outer spike (tapered triangle pointing outward)
      beginShape(TRIANGLES);
        vertex(cos(ang - halfW) * inner, sin(ang - halfW) * inner);
        vertex(cos(ang + halfW) * inner, sin(ang + halfW) * inner);
        vertex(cos(ang)         * outer, sin(ang)         * outer);
      endShape();

      // Mirror spike pointing inward (inner ring)
      float mirrorLen = barLen * 0.45;
      float mirrorInner = inner - mirrorLen;
      if (mirrorInner > 0) {
        float mAlpha = alpha * 0.5;
        fill(hue, sat, constrain(bri * 0.7, 0, 255), constrain(mAlpha, 0, 255));
        beginShape(TRIANGLES);
          vertex(cos(ang - halfW) * inner,       sin(ang - halfW) * inner);
          vertex(cos(ang + halfW) * inner,       sin(ang + halfW) * inner);
          vertex(cos(ang)         * mirrorInner, sin(ang)         * mirrorInner);
        endShape();
      }
    }

    // ── Central glow disc ──────────────────────────────────────────────────
    float glowR = innerR * 0.85 + rawBass * 2 + beatPulse * innerR * 0.3;
    // Outer glow halo
    fill((hueShift + 20) % 360, 160, 255, 18 + beatPulse * 60);
    ellipse(0, 0, glowR * 3.2, glowR * 3.2);
    // Core disc
    fill((hueShift) % 360, 200, 255, 120 + beatPulse * 80);
    ellipse(0, 0, glowR * 2, glowR * 2);
    // Bright centre
    fill(0, 0, 255, 160 + beatPulse * 70);
    ellipse(0, 0, glowR * 0.55, glowR * 0.55);

    popMatrix();

    colorMode(RGB, 255);

    // ── HUD ────────────────────────────────────────────────────────────────
    String[] palNames = {"Spectrum", "Heat", "Ice", "Mono"};
    pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      fill(0, 160); noStroke(); rectMode(CORNER);
      rect(8, 8, 310 * uiScale(), mg + lh * 5);
      fill(255, 180, 80); textSize(ts); textAlign(LEFT, TOP);
      text("Radial FFT  (" + N + " bands)",                          12, 8 + mg);
      fill(255, 220, 180);
      text("Palette: " + palNames[palette] + "  (Y cycle)",          12, 8 + mg + lh);
      text("Scale: "   + nf(scaleMult, 1, 2) + "  (L ↕)",           12, 8 + mg + lh * 2);
      text("Spin: "    + nf(rotSpeed, 1, 4)  + "  (R ↕)",           12, 8 + mg + lh * 3);
      text("Spread: "  + nf(spread, 1, 2)    + "  (R ↔)   A=burst", 12, 8 + mg + lh * 4);
    popStyle();

    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
  }

  float getBarHue(float t, float amp) {
    switch (palette) {
      case 1:  return map(t, 0, 1, 0,   55);   // heat: red→yellow
      case 2:  return map(t, 0, 1, 175, 255);  // ice: cyan→violet
      case 3:  return 160;                       // mono: blue-green
      default: return (hueShift + t * 270) % 360; // spectrum sweep
    }
  }

  // ── Controller ─────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // L stick ↕ = scale multiplier
    float ly = map(c.ly, 0, height, -1, 1);
    scaleMult = map(ly, -1, 1, 3.0, 0.3);

    // R stick ↕ = rotation speed, ↔ = spread
    float ry = map(c.ry, 0, height, -1, 1);
    float rx = map(c.rx, 0, width,  -1, 1);
    rotSpeed = map(ry, -1, 1, 0.020, 0.0002);
    spread   = map(rx, -1, 1, 0.6,  1.6);

    if (c.a_just_pressed) beatPulse = 1.0;
    if (c.y_just_pressed) palette = (palette + 1) % 4;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Radial FFT Controls ===",
      "",
      "L Stick ↕    bar scale",
      "R Stick ↕    rotation speed",
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
}
