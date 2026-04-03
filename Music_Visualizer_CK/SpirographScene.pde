// Spirograph Scene — state 12
//
// A hypotrochoid drawn incrementally — one point per frame — so you watch
// the pattern emerge in real time. When the curve closes it fades out and
// a new one begins with different parameters.
//
// Hypotrochoid:   x = (R-r)*cos(t) + d*cos((R-r)/r * t)
//                 y = (R-r)*sin(t) - d*sin((R-r)/r * t)
//
// R = outer radius (fixed), r = rolling circle radius, d = pen offset.
// Integer ratios of R/r produce closed curves with R/gcd(R,r) petals.
//
// Audio mapping:
//   Bass   → pen offset d wobble (distorts the curve with the kick)
//   Mid    → trace speed (busy groove = faster drawing)
//   High   → line brightness / glow
//   Beat   → snap immediately to next curve preset
//
// Controller:
//   L Stick ↕   → trace speed
//   R Stick ↔   → nudge d (pen offset) — thickens/thins the curve
//   R Stick ↕   → scale
//   A           → force new curve now
//   Y           → cycle colour palette

class SpirographScene implements IScene {

  // Curve state
  float t        = 0;       // current angle parameter
  float tSpeed   = 0.04;    // angle increment per frame (base)
  float curveR;             // outer radius (world units)
  float curveScale = 1.0;   // controller scale

  // Current integer ratio pair
  int   bigR     = 5;
  int   smallR   = 3;
  float penD;               // d = pen offset from center of rolling circle

  // Preset ratios — chosen for beautiful closed curves
  int[][] presets = {
    {5, 3}, {7, 3}, {8, 3}, {7, 4}, {9, 4},
    {11, 4}, {7, 5}, {9, 5}, {11, 6}, {13, 5},
    {8, 5}, {10, 3}, {12, 5}, {13, 7}, {6, 5}
  };
  int presetIdx = 0;

  // Trail — store the last MAX_TRAIL points
  final int MAX_TRAIL = 8000;
  float[]  trailX  = new float[MAX_TRAIL];
  float[]  trailY  = new float[MAX_TRAIL];
  int      trailHead = 0;
  int      trailLen  = 0;

  // Fade-out state when switching curves
  float    fadeAlpha = 1.0;   // 1=fully visible, 0=gone
  boolean  fading    = false;

  // Per-frame audio
  float smoothBass  = 0;
  float smoothMid   = 0;
  float smoothHigh  = 0;

  // Controller
  float dNudge      = 0.0;
  float speedMult   = 1.0;
  float hueShift    = 0.0;
  int   palette     = 0;     // 0=cycle, 1=warm, 2=cool, 3=mono

  SpirographScene() {
    loadPreset(0, 1280, 720);
  }

  void loadPreset(int idx, float w, float h) {
    presetIdx = idx % presets.length;
    bigR   = presets[presetIdx][0];
    smallR = presets[presetIdx][1];
    curveR = min(w, h) * 0.38;
    penD   = curveR * (float)smallR / bigR * random(0.75, 1.15);
    t      = 0;
    trailHead = 0;
    trailLen  = 0;
    fading    = false;
    fadeAlpha = 1.0;
  }

  // How many full rotations until this hypotrochoid closes?
  // It closes after lcm(R,r)/r full outer rotations = R/gcd(R,r) inner ones.
  float closingT() {
    int g = gcd(bigR, smallR);
    return TWO_PI * (bigR / g);
  }

  int gcd(int a, int b) {
    while (b != 0) {
      int tmp = b;
      b = a % b;
      a = tmp;
    }
    return a;
  }

  void drawScene(PGraphics pg) {
    // ── Audio ──────────────────────────────────────────────────────────────
    float rawBass = analyzer.bass;
    float rawMid  = analyzer.mid;
    float rawHigh = analyzer.high;

    smoothBass = lerp(smoothBass, rawBass, 0.18);
    smoothMid  = lerp(smoothMid,  rawMid,  0.12);
    smoothHigh = lerp(smoothHigh, rawHigh, 0.22);

    hueShift = (hueShift + 0.12 + smoothMid * 0.06) % 360;

    // Beat → skip to next curve
    if (analyzer.isBeat) {
      fading = true;
    }

    // ── Advance curve ──────────────────────────────────────────────────────
    if (!fading) {
      float speed = (tSpeed + smoothMid * 0.003) * speedMult;
      // Add a few steps per frame so the curve draws at a visible rate
      int steps = max(1, (int)(speed / 0.01));
      float dt  = speed / steps;
      for (int s = 0; s < steps; s++) {
        t += dt;
        float d = penD + dNudge + smoothBass * (curveR * 0.025);
        float x = (curveR - curveR * smallR / bigR) * cos(t)
                  + d * cos((float)(bigR - smallR) / smallR * t);
        float y = (curveR - curveR * smallR / bigR) * sin(t)
                  - d * sin((float)(bigR - smallR) / smallR * t);
        trailX[trailHead] = x;
        trailY[trailHead] = y;
        trailHead = (trailHead + 1) % MAX_TRAIL;
        trailLen  = min(trailLen + 1, MAX_TRAIL);
      }

      // Curve complete → begin fade
      if (t >= closingT() + 0.05) {
        fading = true;
      }
    }

    // Fade out old curve, load next
    if (fading) {
      fadeAlpha -= 0.025;
      if (fadeAlpha <= 0) {
        loadPreset(presetIdx + 1, pg.width, pg.height);
      }
    }

    // ── Background ─────────────────────────────────────────────────────────
    // Phosphor persistence: semi-transparent fill each frame gives a trail.
    // Decay faster while fading so old curves clear before the new one starts.
    pg.noStroke();
    pg.fill(0, 0, 0, fading ? 80 : 45);
    pg.rectMode(CORNER);
    pg.rect(0, 0, pg.width, pg.height);

    // ── Draw trail ─────────────────────────────────────────────────────────
    pg.colorMode(HSB, 360, 255, 255, 255);
    float cx = pg.width / 2.0, cy = pg.height / 2.0;

    // Draw as a polyline, colouring by position in trail (head = bright)
    pg.strokeWeight(1.5 + smoothHigh * 0.08);
    pg.noFill();

    // Walk trail from oldest to newest
    int startIdx = (trailHead - trailLen + MAX_TRAIL) % MAX_TRAIL;
    float prevX = 0, prevY = 0;
    for (int i = 0; i < trailLen; i++) {
      int idx = (startIdx + i) % MAX_TRAIL;
      float age  = (float)i / max(1, trailLen - 1); // 0=oldest, 1=newest
      float px   = cx + trailX[idx] * curveScale;
      float py   = cy + trailY[idx] * curveScale;

      if (i == 0) { prevX = px; prevY = py; continue; }

      float hue   = getTrailHue(age, i);
      float sat   = 200 + smoothHigh * 8;
      float bri   = 160 + age * 90 + smoothHigh * 6;
      float alpha = constrain((age * 200 + 30) * fadeAlpha, 0, 255);

      pg.stroke(hue, constrain(sat, 0, 255), constrain(bri, 0, 255), alpha);
      pg.line(prevX, prevY, px, py);
      prevX = px; prevY = py;
    }

    // Bright dot at pen tip
    if (trailLen > 0 && !fading) {
      int tipIdx = (trailHead - 1 + MAX_TRAIL) % MAX_TRAIL;
      float tx = cx + trailX[tipIdx] * curveScale;
      float ty = cy + trailY[tipIdx] * curveScale;
      pg.noStroke();
      pg.fill(hueShift, 100, 255, 200);
      pg.ellipse(tx, ty, 8 + smoothHigh, 8 + smoothHigh);
      pg.fill(0, 0, 255, 220);
      pg.ellipse(tx, ty, 4, 4);
    }

    pg.colorMode(RGB, 255);

    // ── HUD ────────────────────────────────────────────────────────────────
    String[] palNames = {"Cycle", "Warm", "Cool", "Mono"};
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      pg.fill(0, 160); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 320 * uiScale(), mg + lh * 6);
      pg.fill(200, 180, 255); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Spirograph  R=" + bigR + " r=" + smallR,                    12, 8 + mg);
      pg.fill(220, 210, 255);
      pg.text("Palette: " + palNames[palette] + "  (Y cycle)",             12, 8 + mg + lh);
      pg.text("Speed: "  + nf(speedMult, 1, 2) + "  (L ↕)",               12, 8 + mg + lh * 2);
      pg.text("Pen: "    + nf(penD + dNudge, 1, 1) + "  (R ↔)",           12, 8 + mg + lh * 3);
      pg.text("Scale: "  + nf(curveScale, 1, 2) + "  (R ↕)",              12, 8 + mg + lh * 4);
      pg.text("A=new curve   progress: " + nf(t / closingT() * 100, 1, 0) + "%",
                                                                          12, 8 + mg + lh * 5);
    pg.popStyle();

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  float getTrailHue(float age, int i) {
    switch (palette) {
      case 1:  return map(age, 0, 1, 10, 60);    // warm: red→yellow
      case 2:  return map(age, 0, 1, 180, 260);  // cool: cyan→violet
      case 3:  return 270;                         // mono: violet
      default: return (hueShift + age * 180) % 360; // cycle
    }
  }

  // ── Controller ─────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // L stick ↕ = trace speed
    float ly = map(c.ly, 0, height, -1, 1);
    speedMult = map(ly, -1, 1, 3.0, 0.2);

    // R stick ↔ = pen offset nudge, ↕ = scale
    float rx = map(c.rx, 0, width,  -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);
    if (abs(rx) > 0.12) dNudge = constrain(dNudge + rx * 1.5, -curveR * 0.4, curveR * 0.4);
    curveScale = map(ry, -1, 1, 1.6, 0.5);

    if (c.a_just_pressed) fading = true;
    if (c.y_just_pressed) palette = (palette + 1) % 4;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Spirograph Controls ===",
      "",
      "L Stick ↕    trace speed",
      "R Stick ↔    pen offset (d)",
      "R Stick ↕    scale",
      "",
      "A            force next curve",
      "Y            cycle palette",
      "             (Cycle/Warm/Cool/Mono)",
      "",
      "LB / RB      prev / next scene",
      "` (backtick) toggle this overlay",
      "",
      "=== Audio ===",
      "Bass   pen wobble (distorts curve)",
      "Mid    trace speed",
      "High   line brightness",
      "Beat   skip to next curve",
    };
  }

  void onEnter() {
    background(0);
    loadPreset(presetIdx, width, height);
  }

  void onExit() {}

  void handleKey(char k) {}
}
