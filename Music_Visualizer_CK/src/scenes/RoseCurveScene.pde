/**
 * RoseCurveScene (scene 35) — Spirograph Sacred Geometry
 *
 * Hypotrochoid / epitrochoid parametric curves with rainbow-gradient strokes,
 * layered at different scales with audio-reactive breathing and rotation.
 *
 * Math:
 *   Hypotrochoid: x = (R-r)cos(t) + d·cos((R-r)/r · t)
 *                 y = (R-r)sin(t) - d·sin((R-r)/r · t)
 *
 *   k = R/r ratio controls lobes.  d controls inner/outer pen distance.
 *   Presets pick visually striking (R, r, d) combos.
 *
 * Controller:
 *   LB / RB      — prev / next preset
 *   X  / Y       — d (pen distance) ±0.1
 *   LStick ↕     — overall scale
 *   RStick ↔     — hue offset
 *   RStick ↕     — rotation speed multiplier
 *   A            — reset to default preset
 *   B            — next preset (same as RB)
 *
 * Audio:
 *   Bass  — scale breathing + stroke weight
 *   Mid   — rotation speed
 *   High  — saturation + brightness
 *   Beat  — rotation snap + flash
 */
class RoseCurveScene implements IScene {

  // ── Spirograph parameters ─────────────────────────────────────────────────
  // Hypotrochoid: outer radius R, inner radius r, pen distance d
  float spiroR = 5, spiror = 3, spirod = 3;

  // Presets: { R, r, d } — visually striking combos
  float[][] presets = {
    {5, 3, 3},       // classic 5-lobe star
    {7, 4, 2.5f},    // 7-lobe weave
    {10, 7, 5},      // dense 10-petal
    {8, 5, 3},       // 8-lobe flower
    {6, 3.5f, 2},    // asymmetric bloom
    {11, 7, 4},      // 11-fold symmetry
    {9, 5, 4},       // 9-lobe spiral
    {7, 2, 4},       // tight pentagonal
    {12, 7, 6},      // dense overlay
    {5, 2, 3.5f},    // 5-fold with extended pen
    {8, 3, 5},       // wild 8-arm
    {13, 8, 5},      // 13-fold sacred
  };
  int presetIdx = 0;

  // ── Curve resolution ──────────────────────────────────────────────────────
  static final int CURVE_PTS = 1800;  // high resolution for smooth curves

  // ── Visual state ──────────────────────────────────────────────────────────
  float   masterRot       = 0;
  float   baseRotSpeed    = 0.003f;
  float   userScale       = 1.0;
  float   targetScale     = 1.0;
  float   hueOffset       = 0;
  float   targetHue       = 0;
  float   speedMult       = 1.0;
  float   targetSpeedMult = 1.0;

  // ── Audio smoothing ────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;

  // ── Layers: [scale, hue shift, alpha fraction, rotation offset] ──────────
  // Each layer draws the same spirograph at different scale/hue for depth.
  float[][] layers = {
    {1.00f,   0f, 1.00f,  0f},        // primary
    {0.72f, 120f, 0.60f,  0.4f},      // inner echo, shifted hue
    {1.18f, 240f, 0.40f, -0.25f},     // outer echo, shifted hue
  };

  // ── IScene lifecycle ──────────────────────────────────────────────────────

  void onEnter() {
    applyPreset(presetIdx);
  }

  void onExit() {}

  void applyPreset(int idx) {
    presetIdx = idx % presets.length;
    spiroR = presets[presetIdx][0];
    spiror = presets[presetIdx][1];
    spirod = presets[presetIdx][2];
  }

  // ── Controller ────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    if (c.lbJustPressed) { applyPreset((presetIdx - 1 + presets.length) % presets.length); }
    if (c.rbJustPressed) { applyPreset((presetIdx + 1) % presets.length); }
    if (c.xJustPressed)  { spirod = max(0.5, spirod - 0.3); }
    if (c.yJustPressed)  { spirod = min(spiroR, spirod + 0.3); }
    if (c.aJustPressed)  { applyPreset(0); }
    if (c.bJustPressed)  { applyPreset((presetIdx + 1) % presets.length); }

    // LStick Y: scale
    float ly = 1.0 - (c.ly / (float) height);
    targetScale = lerp(0.4, 1.6, ly);

    // RStick: hue offset (X) + speed multiplier (Y)
    float rx = (c.rx - width  * 0.5f) / (width  * 0.5f);
    float ry = (c.ry - height * 0.5f) / (height * 0.5f);
    if (abs(rx) > 0.08) targetHue = (targetHue + rx * 3.0 + 360) % 360;
    if (abs(ry) > 0.08) targetSpeedMult = constrain(targetSpeedMult - ry * 0.05, 0.1, 5.0);
  }

  void handleKey(char k) {
    switch (k) {
      case '[': applyPreset((presetIdx - 1 + presets.length) % presets.length); break;
      case ']': applyPreset((presetIdx + 1) % presets.length); break;
      case '-': spirod = max(0.5, spirod - 0.3); break;
      case '=': spirod = min(spiroR, spirod + 0.3); break;
      case 'r': case 'R':
        applyPreset((presetIdx + 1) % presets.length); break;
    }
  }

  // ── Draw ──────────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    // Audio smoothing
    sBass = lerp(sBass, analyzer.bass, 0.08);
    sMid  = lerp(sMid,  analyzer.mid,  0.08);
    sHigh = lerp(sHigh, analyzer.high, 0.08);
    if (audio.beat.isOnset()) sBeat = 1.0;
    sBeat = lerp(sBeat, 0, 0.08);

    // Smooth user inputs
    userScale = lerp(userScale, targetScale,     0.05);
    hueOffset = lerp(hueOffset, targetHue,       0.04);
    speedMult = lerp(speedMult, targetSpeedMult, 0.05);

    // Rotation
    float midBoost = 1.0 + sMid * 2.5;
    masterRot += baseRotSpeed * speedMult * midBoost;

    // Compute base radius and audio-reactive values
    float baseR      = min(pg.width, pg.height) * 0.30 * userScale;
    float bassPulse  = 1.0 + sBass * 0.20;
    float coreWeight = 1.4 + sBass * 0.5;
    float glowWeight = coreWeight * 3.0;
    float ts         = uiScale();

    // Total angle needed for the curve to close
    // GCD-based period: curve closes after lcm(R, r) / R full turns
    float totalAngle = computeTotalAngle(spiroR, spiror);

    pg.beginDraw();
    pg.hint(DISABLE_DEPTH_TEST);
    pg.background(4, 4, 12);
    pg.translate(pg.width * 0.5, pg.height * 0.5);
    pg.noFill();
    pg.colorMode(HSB, 360, 100, 100, 100);

    // Draw layers back-to-front
    for (int li = layers.length - 1; li >= 0; li--) {
      float scl      = layers[li][0];
      float hueShift = layers[li][1];
      float aFrac    = layers[li][2];
      float rotOff   = layers[li][3];
      float R        = baseR * scl * bassPulse;

      float sat    = constrain(65 + sHigh * 30, 0, 100);
      float bright = constrain(70 + sBass * 15 + sBeat * 12, 0, 100);
      float coreA  = constrain(aFrac * (75 + sBass * 15 + sBeat * 10), 0, 100);
      float glowA  = constrain(aFrac * (10 + sBass * 8 + sBeat * 5), 0, 35);

      pg.pushMatrix();
      pg.rotate(masterRot + rotOff);

      // Pass 1: glow halo
      pg.blendMode(ADD);
      pg.strokeWeight(glowWeight * ts * scl);
      drawSpirograph(pg, R, totalAngle, hueShift + hueOffset, sat * 0.5f, bright * 0.6f, glowA);

      // Pass 2: crisp core with rainbow gradient
      pg.blendMode(BLEND);
      pg.strokeWeight(coreWeight * ts * scl);
      drawSpirograph(pg, R, totalAngle, hueShift + hueOffset, sat, bright, coreA);

      pg.popMatrix();
    }

    pg.colorMode(RGB, 255);
    pg.blendMode(BLEND);

    // ── HUD ────────────────────────────────────────────────────────────────
    pg.textFont(monoFont);
    pg.fill(255, 255, 255, 170 + (int)(sBeat * 85));
    pg.textSize(18 * ts);
    pg.textAlign(LEFT, TOP);
    pg.text("R=" + nf(spiroR,1,0) + "  r=" + nf(spiror,1,1) + "  d=" + nf(spirod,1,1),
            -pg.width/2 + 18*ts, -pg.height/2 + 14*ts);

    pg.fill(255, 255, 255, 80);
    pg.textSize(11 * ts);
    pg.text("preset " + (presetIdx + 1) + "/" + presets.length,
            -pg.width/2 + 18*ts, -pg.height/2 + 38*ts);

    pg.fill(255, 255, 255, 60);
    pg.textSize(10 * ts);
    pg.textAlign(RIGHT, TOP);
    pg.text("[ ] preset   -/= pen dist", pg.width/2 - 14*ts, -pg.height/2 + 14*ts);
    pg.text("spd \u00d7" + nf(speedMult, 1, 1), pg.width/2 - 14*ts, -pg.height/2 + 28*ts);

    pg.endDraw();
  }

  // ── Spirograph drawing with per-vertex rainbow hue ────────────────────────

  void drawSpirograph(PGraphics pg, float R, float totalAngle,
                      float baseHue, float sat, float bright, float alpha) {
    // Normalise params so the largest dimension maps to R
    float maxExtent = abs(spiroR - spiror) + abs(spirod);
    if (maxExtent < 0.001) maxExtent = 1;
    float scale = R / maxExtent;

    float bigR = spiroR;
    float smr  = spiror;
    float pen  = spirod;
    float diff = bigR - smr;
    float ratio = diff / smr;

    // Draw as line segments with per-segment hue cycling
    float prevX = 0, prevY = 0;
    for (int i = 0; i <= CURVE_PTS; i++) {
      float t = totalAngle * i / CURVE_PTS;
      float x = (diff * cos(t) + pen * cos(ratio * t)) * scale;
      float y = (diff * sin(t) - pen * sin(ratio * t)) * scale;

      if (i > 0) {
        // Rainbow hue cycles once per full curve
        float hue = (baseHue + 360.0f * i / CURVE_PTS) % 360;
        pg.stroke(hue, sat, bright, alpha);
        pg.line(prevX, prevY, x, y);
      }
      prevX = x;
      prevY = y;
    }
  }

  // ── Compute total angle for curve to close ────────────────────────────────
  // The hypotrochoid closes when t goes from 0 to 2π * (r / gcd(R,r)).
  // For float params we approximate by rounding to nearest 0.5 and using lcm.

  float computeTotalAngle(float bigR, float smr) {
    // Convert to half-integer scale to handle x.5 values
    int iR = round(bigR * 2);
    int ir = round(smr * 2);
    int g  = gcdInt(iR, ir);
    int lobes = ir / g;
    return TWO_PI * lobes;
  }

  int gcdInt(int a, int b) {
    a = abs(a); b = abs(b);
    while (b != 0) { int t = b; b = a % b; a = t; }
    return a;
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Spirograph Sacred Geometry ===",
      "",
      "Hypotrochoid curve:",
      "  x = (R-r)cos(t) + d\u00b7cos((R-r)/r \u00b7 t)",
      "  y = (R-r)sin(t) - d\u00b7sin((R-r)/r \u00b7 t)",
      "",
      "R = outer ring radius",
      "r = inner wheel radius",
      "d = pen distance from center",
      "",
      "k = R/r controls lobe count.",
      "Three layers at different scales",
      "and 120\u00b0 hue offsets create depth.",
      "",
      "Rainbow gradient along the path",
      "cycles hue once per full curve.",
      "",
      "Audio:",
      "  Bass \u2192 breathing + weight",
      "  Mid  \u2192 rotation speed",
      "  High \u2192 saturation",
      "  Beat \u2192 flash + snap",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LB / RB",       "Prev / next preset"),
      new ControllerLayout("X / Y",         "Pen distance \u00b10.3"),
      new ControllerLayout("LStick \u2195", "Scale"),
      new ControllerLayout("RStick \u2194", "Hue offset"),
      new ControllerLayout("RStick \u2195", "Rotation speed"),
      new ControllerLayout("A",             "Reset to default"),
      new ControllerLayout("B",             "Next preset"),
    };
  }
}
