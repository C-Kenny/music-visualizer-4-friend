// Shoal Lumina — state 15
// Night sea: stacked FFT wave trains (bioluminescent ADD), starfield twinkles with highs,
// beat surge, foam sparks on mids. LT/RT = glow vs sparkle; sticks = drift, tide, hue, density.

class ShoalLuminaScene {

  static final int NUM_STARS = 160;
  static final int NUM_SPARKS = 48;

  float[] starX, starY, starPhase;
  float[] sparkX, sparkY, sparkV;

  float[] smoothAmp;
  boolean initialised = false;

  float phase      = 0;
  float phaseSpeed = 0.014;
  float tideShift  = 0;
  float hueBase    = 188;
  float layerScale = 1.0;
  float glow       = 0.45;
  float sparkle    = 0.5;
  int   waveLayers = 26;
  int   palette    = 0;

  float beatSurge = 0;
  float surge     = 0;

  ShoalLuminaScene() {
    starX = new float[NUM_STARS];
    starY = new float[NUM_STARS];
    starPhase = new float[NUM_STARS];
    sparkX = new float[NUM_SPARKS];
    sparkY = new float[NUM_SPARKS];
    sparkV = new float[NUM_SPARKS];
    for (int i = 0; i < NUM_STARS; i++) {
      starX[i] = random(1.0);
      starY[i] = random(0.38);
      starPhase[i] = random(TWO_PI);
    }
    for (int i = 0; i < NUM_SPARKS; i++) {
      sparkX[i] = random(1.0);
      sparkY[i] = random(0.55, 1.0);
      sparkV[i] = random(0.15, 0.55);
    }
  }

  void ensureAudio() {
    int N = audio.fft.avgSize();
    if (!initialised || smoothAmp == null || smoothAmp.length != N) {
      smoothAmp = new float[N];
      for (int i = 0; i < N; i++) smoothAmp[i] = 0;
      initialised = true;
    }
    for (int i = 0; i < N; i++) {
      smoothAmp[i] = lerp(smoothAmp[i], audio.normalisedAvg(i), 0.22);
    }
  }

  float paletteHue(float t, float amp) {
    float h;
    switch (palette) {
      case 1:
        h = map(t, 0, 1, 130, 210);
        break;
      case 2:
        h = map(t, 0, 1, 280, 340);
        break;
      default:
        h = (hueBase + t * 70 + amp * 55) % 360;
        break;
    }
    return h;
  }

  void drawScene() {
    ensureAudio();
    int N = audio.fft.avgSize();
    int bassEnd = max(1, N / 6);
    int midEnd  = max(bassEnd + 1, N / 2);

    float bass = 0, mid = 0, high = 0;
    for (int i = 0;       i < bassEnd; i++) bass += smoothAmp[i];
    for (int i = bassEnd; i < midEnd;  i++) mid  += smoothAmp[i];
    for (int i = midEnd;  i < N;       i++) high += smoothAmp[i];
    bass /= bassEnd;
    mid  /= max(1, midEnd - bassEnd);
    high /= max(1, N - midEnd);

    if (audio.beat.isOnset()) {
      beatSurge = 1.0;
    }
    beatSurge *= 0.88;
    surge = max(surge * 0.86, beatSurge);

    phase += phaseSpeed * (0.85 + mid * 0.5);

    colorMode(HSB, 360, 255, 255, 255);
    float skyB = 8 + bass * 18 + surge * 22;
    background(240, 55 + (int)(glow * 40), skyB);

    float horizon = height * (0.30 + tideShift + bass * 0.04);

    // Stars (highs twinkle)
    noStroke();
    for (int i = 0; i < NUM_STARS; i++) {
      float sx = starX[i] * width;
      float sy = starY[i] * height * 0.46;
      float tw = 0.35 + high * 0.95 + sin(frameCount * 0.04 + starPhase[i]) * 0.25;
      float br = 90 + high * 155 * tw;
      fill(40, 30, br, 40 + high * 200);
      ellipse(sx, sy, 2.2 + high * 3, 2.2 + high * 3);
    }

    blendMode(ADD);

    // Wave stacks — each layer samples a band; deeper layers = lower bands
    int layers = constrain(waveLayers, 14, 44);
    float layerBoost = layerScale * (0.92 + glow * 0.35 + surge * 0.4);
    for (int layer = 0; layer < layers; layer++) {
      float t = (layers > 1) ? (float)layer / (layers - 1) : 0;
      int bi = constrain((int)(t * (N - 1)), 0, N - 1);
      float amp = smoothAmp[bi] * (14 + layer * 1.1) * layerBoost;
      float wlen = 0.0028 + t * 0.006 + bass * 0.0015;
      float h = paletteHue(t, smoothAmp[bi]);
      float al = (8 + amp * 2.2 + mid * 18) * (0.45 + sparkle * 0.55);
      stroke(h, 185 + (int)(sparkle * 40), 255, constrain(al, 4, 120));
      strokeWeight(0.6 + amp * 0.35 + surge * 0.5);
      noFill();
      beginShape(LINE_STRIP);
      for (int x = 0; x <= width; x += 4) {
        float u = x * wlen + phase * (1.0 + t * 0.7);
        float y = horizon + layer * (5.2 * uiScale())
                + sin(u) * amp
                + sin(u * 2.17 + layer * 0.3) * amp * 0.45
                + sin(x * 0.001 + frameCount * 0.02) * amp * 0.15;
        vertex(x, y);
      }
      endShape();
    }

    // Horizon ribbon
    stroke(paletteHue(0.5, bass), 120, 255, 40 + bass * 120 + surge * 80);
    strokeWeight(1 + bass * 3);
    line(0, horizon, width, horizon);

    // Foam sparks — drift with mids
    for (int i = 0; i < NUM_SPARKS; i++) {
      float sx = sparkX[i] * width;
      float baseY = horizon + sparkY[i] * (height - horizon) * 0.92;
      float bob = sin(phase * 3 + i * 0.7) * mid * 12;
      float sy = baseY + bob;
      sparkX[i] += sparkV[i] * 0.0004 * (1 + mid);
      if (sparkX[i] >= 1.0) sparkX[i] -= 1.0;
      int bi = (i * 7) % N;
      float a = smoothAmp[bi] * mid * (40 + sparkle * 80);
      fill(paletteHue((float)i / NUM_SPARKS, smoothAmp[bi]), 140, 255, constrain(a, 0, 200));
      ellipse(sx, sy, 2 + smoothAmp[bi] * 5, 2 + smoothAmp[bi] * 5);
    }

    blendMode(BLEND);
    colorMode(RGB, 255);

    drawSongNameOnScreen(config.SONG_NAME, width * 0.5, height - 5);

    pushStyle();
    float ts = 11 * uiScale(), lh = ts * 1.28, mg = 5 * uiScale();
    fill(0, 150);
    noStroke();
    rectMode(CORNER);
    rect(8, 8, 340 * uiScale(), mg + lh * 6);
    fill(160, 235, 255);
    textSize(ts);
    textAlign(LEFT, TOP);
    text("Shoal Lumina  —  bioluminescent wave shoals", 12, 8 + mg);
    fill(190, 210, 225);
    text("Layers " + layers + "   [`] adjust   - / = speed", 12, 8 + mg + lh);
    text("LT glow " + nf(glow, 1, 2) + "   RT sparkle " + nf(sparkle, 1, 2), 12, 8 + mg + lh * 2);
    text("L drift   R tide / hue / density   Y palette", 12, 8 + mg + lh * 3);
    text("A surge   beat " + nf(beatSurge, 1, 2), 12, 8 + mg + lh * 4);
    text("Palette " + palette + "   `  HUD", 12, 8 + mg + lh * 5);
    popStyle();
  }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width, -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    float rx = map(c.rx, 0, width, -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);

    phaseSpeed = lerp(phaseSpeed, map(lx, -1, 1, 0.006, 0.032), 0.08);
    tideShift = lerp(tideShift, ly * 0.09, 0.1);
    hueBase = lerp(hueBase, map(rx, -1, 1, 150, 245), 0.06);
    layerScale = lerp(layerScale, map(ry, -1, 1, 0.7, 1.45), 0.08);

    glow = lerp(glow, c.lt, 0.11);
    sparkle = lerp(sparkle, c.rt, 0.11);

    if (c.y_just_pressed) palette = (palette + 1) % 3;
    if (c.a_just_pressed) surge = 1.0;
  }

  void adjustLayers(int d) {
    waveLayers = constrain(waveLayers + d, 14, 44);
  }

  void adjustSpeed(float d) {
    phaseSpeed = constrain(phaseSpeed + d, 0.004, 0.045);
  }

  void triggerSurge() {
    surge = 1.0;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Shoal Lumina ===",
      "",
      "// Stacked LINE_STRIP waves; band index from layer depth",
      "// y = horizon + layer * step + sin(u) * amp * norm[i]",
      "// ADD blend + highs -> star twinkle + foam sparks",
      "",
      "L Stick     drift speed (phase)",
      "R Stick     tide, hue, layer density",
      "LT / RT     sky glow vs water sparkle",
      "A           manual surge",
      "Y / pad Y   palette (3)",
      "`  HUD   [ ] layers   - = speed",
    };
  }
}
