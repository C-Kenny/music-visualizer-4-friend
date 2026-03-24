// Aurora Ribbons Scene — state 10
//
// Translucent curtains of colour hang from the top of the screen and sway
// like the northern lights. Each ribbon is an independent TRIANGLE_STRIP
// driven by Perlin noise. ADD blend mode creates the signature aurora glow
// where overlapping ribbons brighten each other.
//
// Audio mapping:
//   Bass   → ribbon length (how far they hang down)
//   Mid    → sway speed and energy
//   High   → brightness / shimmer intensity
//   Beat   → ripple pulse shoots down each ribbon
//
// Controller:
//   L Stick ↔   → horizontal wind drift (offset all ribbons sideways)
//   L Stick ↕   → ribbon count (2–8)
//   R Stick ↕   → length multiplier
//   A           → trigger a wave burst
//   Y           → cycle colour palette (aurora / fire / ice / mono)

class AuroraRibbonsScene {

  final int   COLS       = 48;   // horizontal control points per ribbon
  final int   MAX_R      = 8;
  final int   MIN_R      = 2;

  int   numRibbons  = 5;
  int   palette     = 0;         // 0=aurora, 1=fire, 2=ice, 3=mono

  // Per-ribbon state
  float[] noiseOff   = new float[MAX_R];
  float[] hueBase    = new float[MAX_R];
  float[] ripple     = new float[MAX_R];  // beat ripple per ribbon

  // Pre-generated star field (fixed positions, avoid re-seeding random each frame)
  final int NUM_STARS = 220;
  float[] starX    = new float[NUM_STARS];
  float[] starY    = new float[NUM_STARS];
  float[] starB    = new float[NUM_STARS];  // base brightness
  float[] starA    = new float[NUM_STARS];  // alpha
  float[] starSz   = new float[NUM_STARS];  // size

  // Controller state
  float windDrift    = 0.0;      // horizontal offset applied to all ribbons
  float lenMult      = 1.0;      // length multiplier
  boolean burst      = false;

  // Audio smoothing
  float smoothBass   = 0;
  float smoothMid    = 0;
  float smoothHigh   = 0;
  float hueShift     = 0;

  AuroraRibbonsScene() {
    for (int i = 0; i < MAX_R; i++) {
      noiseOff[i] = random(5000);
      hueBase[i]  = (i * 360.0 / MAX_R) % 360;
    }
    for (int s = 0; s < NUM_STARS; s++) {
      starX[s] = random(width);
      starY[s] = random(height * 0.85);
      starB[s] = random(60, 140);
      starA[s] = random(80, 180);
      starSz[s] = random(1.0, 2.2);
    }
  }

  void drawScene() {
    // ── Audio ──────────────────────────────────────────────────────────────
    int fftSize = audio.fft.avgSize();
    int bassEnd = max(1, fftSize / 6);
    int midEnd  = max(bassEnd + 1, fftSize / 2);

    float rawBass = 0, rawMid = 0, rawHigh = 0;
    for (int i = 0;       i < bassEnd; i++) rawBass += audio.fft.getAvg(i);
    for (int i = bassEnd; i < midEnd;  i++) rawMid  += audio.fft.getAvg(i);
    for (int i = midEnd;  i < fftSize; i++) rawHigh += audio.fft.getAvg(i);
    rawBass /= bassEnd;
    rawMid  /= max(1, midEnd - bassEnd);
    rawHigh /= max(1, fftSize - midEnd);

    smoothBass = lerp(smoothBass, rawBass, 0.15);
    smoothMid  = lerp(smoothMid,  rawMid,  0.12);
    smoothHigh = lerp(smoothHigh, rawHigh, 0.20);

    boolean isBeat = audio.beat.isOnset();
    if (isBeat || burst) {
      for (int i = 0; i < numRibbons; i++) ripple[i] = 1.0;
      burst = false;
    }
    for (int i = 0; i < numRibbons; i++) ripple[i] *= 0.88;

    hueShift = (hueShift + smoothMid * 0.15 + 0.08) % 360;

    // ── Background ─────────────────────────────────────────────────────────
    background(2, 4, 12);

    // Subtle star field — pre-generated fixed positions
    colorMode(RGB, 255);
    for (int s = 0; s < NUM_STARS; s++) {
      float sb = starB[s] + smoothHigh * 4;
      stroke(sb, sb, sb + 20, starA[s]);
      strokeWeight(starSz[s]);
      point(starX[s], starY[s]);
    }
    noStroke();

    // ── Ribbons ────────────────────────────────────────────────────────────
    blendMode(ADD);
    colorMode(HSB, 360, 255, 255, 255);
    noStroke();

    float spacing   = (width + 100) / (float)(numRibbons);
    float baseLen   = height * (0.45 + smoothBass * 0.05) * lenMult;
    float swaySpeed = frameCount * (0.003 + smoothMid * 0.0006);

    for (int ri = 0; ri < numRibbons; ri++) {
      float ribbonX = -50 + ri * spacing + windDrift;
      float rip     = ripple[ri];

      // Hue for this ribbon — spreads across palette based on index
      float hue = getRibbonHue(ri, rip);
      float sat = 200 + smoothHigh * 8;
      float topAlpha = constrain(55 + smoothHigh * 6 + rip * 90, 0, 180);

      // Build the TRIANGLE_STRIP across COLS columns
      beginShape(TRIANGLE_STRIP);
      for (int col = 0; col <= COLS; col++) {
        float tx = ribbonX + col * (spacing * 1.2 / COLS);

        // Perlin noise sway — slow for a dreamy feel
        float nx   = col * 0.06 + noiseOff[ri];
        float ny   = swaySpeed + noiseOff[ri] * 0.5;
        float sway = (noise(nx, ny) - 0.5) * (60 + smoothMid * 8);

        // Extra shimmer on high frequencies at tail
        float shimmer = sin(frameCount * 0.09 + col * 0.4 + ri * 1.2)
                        * smoothHigh * 4;

        float topX  = tx + sway;
        float botX  = tx + sway * 0.35 + shimmer;
        float botY  = baseLen * (0.6 + noise(nx * 0.5, ny * 0.3) * 0.5)
                      + rip * height * 0.08;

        // Fade alpha from bright at top to transparent at bottom
        float tAlpha = topAlpha;
        float bAlpha = topAlpha * 0.05;

        fill(hue, sat, 255, tAlpha);
        vertex(topX, 0);
        fill(hue, sat * 0.6, 200 + smoothHigh * 4, bAlpha);
        vertex(botX, botY);
      }
      endShape();

      // Soft glow at ribbon base — brightens on beat
      if (rip > 0.1) {
        float gx = ribbonX + spacing * 0.5;
        float glowA = rip * 60;
        fill(hue, 180, 255, glowA);
        ellipse(gx, baseLen * 0.5, spacing * 0.8, baseLen * 0.3);
      }
    }

    blendMode(BLEND);
    colorMode(RGB, 255);

    // ── Ground glow ────────────────────────────────────────────────────────
    // Soft horizon bloom where ribbons terminate
    colorMode(HSB, 360, 255, 255, 255);
    noStroke();
    float horizY = baseLen * 0.92;
    for (int r = 3; r >= 1; r--) {
      float a = (smoothBass * 8 + 12) * r * 0.4;
      fill((hueShift + 20) % 360, 160, 255, constrain(a, 0, 80));
      ellipse(width / 2.0, horizY, width * 1.1, height * 0.12 * r);
    }
    colorMode(RGB, 255);

    // ── HUD ────────────────────────────────────────────────────────────────
    String[] palNames = {"Aurora", "Fire", "Ice", "Mono"};
    pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      fill(0, 160); noStroke(); rectMode(CORNER);
      rect(8, 8, 310 * uiScale(), mg + lh * 5);
      fill(100, 220, 255); textSize(ts); textAlign(LEFT, TOP);
      text("Aurora Ribbons",                                         12, 8 + mg);
      fill(200, 235, 255);
      text("Palette: " + palNames[palette] + "  (Y cycle)",         12, 8 + mg + lh);
      text("Ribbons: " + numRibbons + "  (L ↕)",                    12, 8 + mg + lh * 2);
      text("Length: "  + nf(lenMult, 1, 2) + "x  (R ↕)",           12, 8 + mg + lh * 3);
      text("Wind: " + nf(windDrift, 1, 0) + "px  (L ↔)   A=burst", 12, 8 + mg + lh * 4);
    popStyle();

    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
  }

  // Returns hue for ribbon ri based on current palette and beat ripple
  float getRibbonHue(int ri, float rip) {
    float t = (float)ri / max(1, numRibbons - 1);
    float h;
    switch (palette) {
      case 1:  h = map(t, 0, 1, 0,   60);  break;  // fire: red→yellow
      case 2:  h = map(t, 0, 1, 170, 240); break;  // ice: cyan→blue
      case 3:  h = 140; break;                       // mono: teal
      default: h = (hueShift + t * 120) % 360; break; // aurora: green→purple sweep
    }
    // Beat ripple flashes toward white
    return h;
  }

  // ── Controller ─────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // L stick ↔ = wind drift
    float lx = map(c.lx, 0, width, -1, 1);
    if (abs(lx) > 0.12) windDrift = constrain(windDrift + lx * 4, -width * 0.3, width * 0.3);

    // L stick ↕ = ribbon count
    float ly = map(c.ly, 0, height, -1, 1);
    if (abs(ly) > 0.5) {
      numRibbons = constrain(numRibbons + (ly > 0 ? -1 : 1), MIN_R, MAX_R);
    }

    // R stick ↕ = length multiplier
    float ry = map(c.ry, 0, height, -1, 1);
    lenMult = map(ry, -1, 1, 2.0, 0.4);

    // Buttons
    if (c.a_just_pressed) burst = true;
    if (c.y_just_pressed) palette = (palette + 1) % 4;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Aurora Ribbons Controls ===",
      "",
      "L Stick ↔    horizontal wind drift",
      "L Stick ↕    ribbon count (2–8)",
      "R Stick ↕    ribbon length",
      "",
      "A            wave burst",
      "Y            cycle palette",
      "             (Aurora/Fire/Ice/Mono)",
      "",
      "LB / RB      prev / next scene",
      "` (backtick) toggle this overlay",
      "",
      "=== Audio ===",
      "Bass    ribbon length",
      "Mid     sway speed",
      "High    brightness / shimmer",
      "Beat    ripple down ribbons",
    };
  }
}
