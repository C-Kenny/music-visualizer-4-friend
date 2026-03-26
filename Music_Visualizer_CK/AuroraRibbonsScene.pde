// Aurora Ribbons Scene — state 10
// Atmospheric triangle-strip curtains driven by low/mid/high energy.

class AuroraRibbonsScene {
  float drift = 0.0;
  float wind = 0.35;
  float ribbonLengthScale = 1.0;
  float hueOffset = 190;
  float turbulence = 1.0;
  float beatFlash = 0.0;
  float beatSplit = 0.0;

  // Adaptive band normalization (auto-gain): keeps the scene expressive
  // across songs with very different loudness/arrangement.
  float lowFloor = 0.4, lowCeil = 7.0;
  float midFloor = 0.3, midCeil = 6.0;
  float highFloor = 0.2, highCeil = 5.0;

  // Curated palette presets: hue shift + sat/bri scaling
  int paletteIndex = 0;
  String[] paletteNames = {"Arctic", "Neon", "Sunset", "Void"};
  float[] paletteHueShift = {0, 28, -32, 180};
  float[] paletteSatMult  = {0.70, 1.15, 0.95, 0.55};
  float[] paletteBriMult  = {1.05, 1.20, 1.10, 0.78};

  AuroraRibbonsScene() {}

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width, -1, 1);
    float rx = map(c.rx, 0, width, -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);

    // L stick ↔ controls wind advection
    wind = map(lx, -1, 1, -2.2, 2.2);
    // R stick ↕ controls vertical ribbon length
    ribbonLengthScale = constrain(map(ry, -1, 1, 1.65, 0.55), 0.45, 2.2);
    // R stick ↔ controls turbulence/detail
    turbulence = constrain(map(rx, -1, 1, 0.35, 2.2), 0.2, 2.4);

    if (c.a_just_pressed) triggerFlash();
    if (c.y_just_pressed) hueOffset = (hueOffset + 24) % 360;
  }

  void triggerFlash() {
    beatFlash = 1.0;
    beatSplit = 1.0;
  }

  void cyclePalette() {
    paletteIndex = (paletteIndex + 1) % paletteNames.length;
  }

  void adjustLength(float delta) {
    ribbonLengthScale = constrain(ribbonLengthScale + delta, 0.45, 2.2);
  }

  void adjustTurbulence(float delta) {
    turbulence = constrain(turbulence + delta, 0.2, 2.4);
  }

  void adjustHue(float delta) {
    hueOffset = (hueOffset + delta + 360) % 360;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Aurora Ribbons ===",
      "",
      "// Layered TRIANGLE_STRIP curtains with noise-driven sway",
      "sway = (noise(x*freq + drift, t*speed) - 0.5) * width",
      "length = base_len * ribbon_length_scale * (1 + low_norm*0.32)",
      "",
      "// Adaptive normalizer tracks each song's dynamic range",
      "norm = clamp((raw - floor) / max(0.001, ceil-floor), 0, 1)",
      "",
      "// Beat onset -> flash + curtain split from center",
      "x += sign(x-center) * beat_split * split_strength",
      "beat_flash *= 0.90, beat_split *= 0.86"
    };
  }

  void drawScene() {
    float lowRaw = bandEnergy(0.00, 0.20);
    float midRaw = bandEnergy(0.20, 0.55);
    float highRaw = bandEnergy(0.55, 1.00);

    float low = normalizeAdaptive(lowRaw,  0);
    float mid = normalizeAdaptive(midRaw,  1);
    float high = normalizeAdaptive(highRaw, 2);

    if (audio.beat.isOnset()) {
      triggerFlash();
      drift += 0.35;
    }
    beatFlash *= 0.90;
    beatSplit *= 0.86;

    drift += 0.0035 * wind * (1.0 + high * 0.9);

    colorMode(HSB, 360, 255, 255, 255);
    noStroke();

    float pSat = paletteSatMult[paletteIndex];
    float pBri = paletteBriMult[paletteIndex];
    float pHue = paletteHueShift[paletteIndex];

    // dark sky gradient-ish wash
    for (int i = 0; i < 7; i++) {
      float yy = map(i, 0, 6, 0, height);
      float bgHue = (hueOffset + pHue + 220 + i * 2) % 360;
      float bgSat = constrain((170 - i * 18) * pSat * 0.8, 0, 255);
      float bgBri = constrain((20 + i * 8) * pBri, 0, 255);
      fill(bgHue, bgSat, bgBri, 255);
      rect(0, yy, width, height / 7.0 + 1);
    }

    blendMode(ADD);
    int layers = 6;
    for (int layer = 0; layer < layers; layer++) {
      float layerMix = layer / float(max(1, layers - 1));
      float len = (height * (0.22 + layerMix * 0.12)) * ribbonLengthScale * (1.0 + low * 0.32);
      float spacing = max(8, width / 70.0);
      float freq = (0.004 + layerMix * 0.003) * turbulence;
      float speed = 0.35 + layerMix * 0.6 + high * 0.35;
      float swayAmp = (34 + layer * 12 + high * 22) * turbulence;
      float splitStrength = (10 + layer * 8) * beatSplit;

      beginShape(TRIANGLE_STRIP);
      for (float x = 0; x <= width + spacing; x += spacing) {
        float nx = x * freq;
        float n1 = noise(nx + drift * speed, frameCount * 0.0035 + layer * 13.0);
        float n2 = noise(nx + drift * speed + 33.0, frameCount * 0.0045 + layer * 19.0);
        float sway = (n1 - 0.5) * swayAmp;
        float centerSide = (x < width * 0.5) ? -1.0 : 1.0;

        float topY = map(n2, 0, 1, -20, 45 + layer * 14);
        float bottomY = topY + len + (n1 - 0.5) * (65 + low * 35.0);

        float hue = (hueOffset + pHue + layer * 17 + sin(frameCount * 0.01 + x * 0.015) * 16 + mid * 26) % 360;
        float sat = constrain((170 + 65 * (1.0 - layerMix)) * pSat, 0, 255);
        float bri = constrain((145 + layer * 14 + high * 90) * pBri, 0, 255);
        float aTop = 42 + layer * 10 + beatFlash * 65;
        float aBot = 8 + layer * 3 + beatFlash * 20;

        float split = centerSide * splitStrength;

        fill(hue, sat, bri, aTop);
        vertex(x + sway + split, topY);
        fill(hue, sat * 0.8, bri * 0.8, aBot);
        vertex(x + sway * 0.35 + split * 0.38, bottomY);
      }
      endShape();
    }

    drawMist(high, pHue, pSat, pBri);

    // beat veil
    if (beatFlash > 0.01) {
      blendMode(SCREEN);
      fill((hueOffset + pHue + 120) % 360, 40, 255, 80 * beatFlash);
      rect(0, 0, width, height);
    }

    blendMode(BLEND);
    colorMode(RGB, 255);

    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
    drawHud(low, mid, high);
  }

  void drawMist(float highNorm, float pHue, float pSat, float pBri) {
    int pCount = int(24 + highNorm * 42);
    for (int i = 0; i < pCount; i++) {
      float t = frameCount * 0.004 + i * 0.17;
      float x = noise(i * 2.7, t + drift * 0.2) * width;
      float y = height * (0.22 + noise(i * 5.1, t * 0.9) * 0.72);
      float r = 1.2 + noise(i * 7.3, t * 1.1) * (2.0 + highNorm * 5.5);
      float hue = (hueOffset + pHue + 170 + noise(i * 9.7, t * 0.6) * 45) % 360;
      float sat = constrain((90 + highNorm * 120) * pSat, 0, 255);
      float bri = constrain((130 + highNorm * 105) * pBri, 0, 255);
      float a = 10 + highNorm * 45;
      fill(hue, sat, bri, a);
      ellipse(x, y, r * 2.0, r * 2.0);
    }
  }

  float normalizeAdaptive(float raw, int band) {
    float floor, ceil;
    if (band == 0) {
      lowFloor = lerp(lowFloor, min(lowFloor, raw), 0.035);
      lowCeil  = lerp(lowCeil,  max(lowCeil * 0.997, raw), 0.04);
      floor = lowFloor;
      ceil = lowCeil;
    } else if (band == 1) {
      midFloor = lerp(midFloor, min(midFloor, raw), 0.035);
      midCeil  = lerp(midCeil,  max(midCeil * 0.997, raw), 0.04);
      floor = midFloor;
      ceil = midCeil;
    } else {
      highFloor = lerp(highFloor, min(highFloor, raw), 0.035);
      highCeil  = lerp(highCeil,  max(highCeil * 0.997, raw), 0.04);
      floor = highFloor;
      ceil = highCeil;
    }

    float n = (raw - floor) / max(0.001, ceil - floor);
    return constrain(n, 0, 1);
  }

  float bandEnergy(float startNorm, float endNorm) {
    int n = max(1, audio.fft.avgSize());
    int s = constrain(int(n * startNorm), 0, n - 1);
    int e = constrain(int(n * endNorm), s + 1, n);
    float total = 0;
    for (int i = s; i < e; i++) total += audio.fft.getAvg(i);
    return total / max(1, e - s);
  }

  void drawHud(float low, float mid, float high) {
    pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      fill(0, 125);
      noStroke();
      rectMode(CORNER);
      rect(8, 8, 390 * uiScale(), 8 + lh * 6.2);
      fill(255);
      textSize(ts);
      textAlign(LEFT, TOP);
      text("Scene: Aurora Ribbons", 12, 12);
      text("low / mid / high (norm): " + nf(low, 1, 2) + " / " + nf(mid, 1, 2) + " / " + nf(high, 1, 2), 12, 12 + lh);
      text("wind: " + nf(wind, 1, 2) + "  len: " + nf(ribbonLengthScale, 1, 2) + "x", 12, 12 + lh * 2);
      text("turbulence: " + nf(turbulence, 1, 2) + "  hue: " + nf(hueOffset, 1, 1), 12, 12 + lh * 3);
      text("palette: " + paletteNames[paletteIndex] + "  split: " + nf(beatSplit, 1, 2), 12, 12 + lh * 4);
      text("A flash  Y hue step  K palette  [ ] turbulence  -/= length", 12, 12 + lh * 5);
    popStyle();
  }
}
