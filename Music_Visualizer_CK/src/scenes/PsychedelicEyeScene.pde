/**
 * PsychedelicEyeScene (scene 38) — Alex Grey "Psychedelic Eye"
 *
 * A single massive all-seeing eye dominates the screen. The iris is built
 * from concentric rings of sacred geometry (hexagons, triangles, circles).
 * The pupil dilates/contracts with bass. Radial fractal-like filaments
 * emanate from the iris edge. The whole eye is enveloped in a luminous
 * aura field that flashes on beat.
 *
 * Inspired by Grey's "Oversoul", "Theologue" eye motifs, and the
 * characteristic refulgent glow of his anatomical light paintings.
 *
 * Controller:
 *   LStick ↕    — iris detail level
 *   RStick ↔    — hue rotation
 *   RStick ↕    — pupil size manual override
 *   LB / RB     — color scheme
 *   A           — reset
 *   B           — toggle geometry mode (hex/tri/circle)
 */
class PsychedelicEyeScene implements IScene {

  // ── Config ────────────────────────────────────────────────────────────────
  int   geoMode    = 0;   // 0 hex, 1 triangle, 2 circle mandala
  int   colorMode_ = 0;
  float hueShift   = 0;
  float targetHue  = 0;
  float detailLevel = 1.0;
  float targetDetail = 1.0;
  float pupilOverride = -1;  // -1 = auto (bass-driven)

  float[][] colorSchemes = {
    {200, 280, 50},    // Blue-violet-gold (classic Grey)
    {25,  350, 170},   // Amber-crimson-teal
    {300, 200, 60},    // Purple-blue-orange
    {120, 60,  300},   // Green-yellow-magenta
    {0,   180, 270},   // Red-cyan-indigo
  };

  // ── Animation ─────────────────────────────────────────────────────────────
  float phase      = 0;
  float pulsePhase = 0;
  float beatFlash  = 0;

  // ── Audio ─────────────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;

  // ── IScene lifecycle ──────────────────────────────────────────────────────
  void onEnter() {}
  void onExit()  {}

  void applyController(Controller c) {
    float ly = 1.0 - (c.ly / (float) height);
    targetDetail = lerp(0.4, 2.0, ly);

    float rx = (c.rx - width * 0.5f) / (width * 0.5f);
    float ry = (c.ry - height * 0.5f) / (height * 0.5f);
    if (abs(rx) > 0.08) targetHue = (targetHue + rx * 2.5 + 360) % 360;

    if (c.lbJustPressed) { colorMode_ = (colorMode_ - 1 + colorSchemes.length) % colorSchemes.length; }
    if (c.rbJustPressed) { colorMode_ = (colorMode_ + 1) % colorSchemes.length; }
    if (c.bJustPressed)  { geoMode = (geoMode + 1) % 3; }
    if (c.aJustPressed)  { colorMode_ = 0; targetHue = 0; targetDetail = 1.0; geoMode = 0; }
  }

  void handleKey(char k) {
    switch (k) {
      case '[': colorMode_ = (colorMode_ - 1 + colorSchemes.length) % colorSchemes.length; break;
      case ']': colorMode_ = (colorMode_ + 1) % colorSchemes.length; break;
      case 'g': case 'G': geoMode = (geoMode + 1) % 3; break;
    }
  }

  // ── Draw ──────────────────────────────────────────────────────────────────
  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.10);
    sMid  = lerp(sMid,  analyzer.mid,  0.10);
    sHigh = lerp(sHigh, analyzer.high, 0.10);
    if (audio.beat.isOnset()) { sBeat = 1.0; beatFlash = 1.0; }
    sBeat     = lerp(sBeat, 0, 0.06);
    beatFlash = lerp(beatFlash, 0, 0.04);

    hueShift    = lerpAngle(hueShift, targetHue, 0.03);
    detailLevel = lerp(detailLevel, targetDetail, 0.04);

    phase      += 0.006 + sMid * 0.015;
    pulsePhase += 0.02 + sBass * 0.04;

    float ts = uiScale();
    float cx = pg.width * 0.5;
    float cy = pg.height * 0.5;
    float eyeR = min(pg.width, pg.height) * 0.42;

    float hue1 = (colorSchemes[colorMode_][0] + hueShift) % 360;
    float hue2 = (colorSchemes[colorMode_][1] + hueShift) % 360;
    float hue3 = (colorSchemes[colorMode_][2] + hueShift) % 360;

    // Pupil size: bass-driven dilation
    float pupilFrac = 0.15 + sBass * 0.25 + sin(pulsePhase) * 0.03;
    pupilFrac = constrain(pupilFrac, 0.08, 0.50);
    float pupilR = eyeR * pupilFrac;
    float irisR  = eyeR * 0.65;

    pg.beginDraw();
    pg.hint(DISABLE_DEPTH_TEST);
    pg.background(2, 2, 6);
    pg.colorMode(HSB, 360, 100, 100, 100);

    // ── Outer aura field ────────────────────────────────────────────────
    pg.blendMode(ADD);
    pg.noStroke();
    int auraLayers = 6;
    for (int i = auraLayers; i >= 0; i--) {
      float frac = (float) i / auraLayers;
      float ar = eyeR * (1.1 + frac * 0.8 + beatFlash * 0.3);
      float aHue = (hue1 + frac * 40) % 360;
      float aAlpha = (3 + beatFlash * 12) * (1.0 - frac);
      pg.fill(aHue, 30, 40 + beatFlash * 30, aAlpha);
      pg.ellipse(cx, cy, ar * 2, ar * 2);
    }

    // ── Eye outline (almond shape) ──────────────────────────────────────
    pg.blendMode(BLEND);
    pg.noFill();
    pg.strokeWeight((1.5 + sHigh * 1.0) * ts);
    pg.stroke(hue1, 50, 70, 60);
    drawEyeShape(pg, cx, cy, eyeR * 1.15, eyeR * 0.55);

    // ── Iris: sacred geometry rings ─────────────────────────────────────
    int ringCount = (int)(8 + 12 * detailLevel);
    for (int ring = ringCount; ring >= 1; ring--) {
      float frac = (float) ring / ringCount;
      float rr   = lerp(pupilR, irisR, frac);
      float ringHue = (hue1 + frac * (hue2 - hue1 + 360) % 360 * 0.5 + phase * 15) % 360;
      float sat  = 55 + sHigh * 35;
      float bri  = 40 + frac * 35 + sHigh * 15;
      float alpha = 40 + frac * 35;

      pg.strokeWeight((0.5 + frac * 0.8 + sHigh * 0.4) * ts);
      pg.stroke(ringHue, sat, bri, alpha);
      pg.noFill();

      if (geoMode == 0) {
        drawHexRing(pg, cx, cy, rr, ring, frac);
      } else if (geoMode == 1) {
        drawTriRing(pg, cx, cy, rr, ring, frac);
      } else {
        drawMandalaRing(pg, cx, cy, rr, ring, frac);
      }
    }

    // ── Radial filaments (iris striations) ──────────────────────────────
    int filaments = (int)(24 + 36 * detailLevel);
    pg.blendMode(ADD);
    for (int i = 0; i < filaments; i++) {
      float angle = TWO_PI * i / filaments + phase * 0.2;
      float len = irisR - pupilR;
      float wavyR = len * (0.6 + 0.4 * sin(phase * 2 + i * 0.8));

      float x1 = cx + cos(angle) * (pupilR + 2);
      float y1 = cy + sin(angle) * (pupilR + 2);
      float x2 = cx + cos(angle) * (pupilR + wavyR);
      float y2 = cy + sin(angle) * (pupilR + wavyR);

      float fHue = (hue2 + i * (360.0 / filaments)) % 360;
      pg.strokeWeight(0.4 * ts);
      pg.stroke(fHue, 40 + sHigh * 30, 30 + sHigh * 20, 12 + sHigh * 10);
      pg.line(x1, y1, x2, y2);
    }

    // ── Outer radial rays ───────────────────────────────────────────────
    int outerRays = (int)(16 + 20 * detailLevel);
    for (int i = 0; i < outerRays; i++) {
      float angle = TWO_PI * i / outerRays + phase * 0.1;
      float innerD = irisR * 1.02;
      float outerD = eyeR * (1.05 + sBeat * 0.15);

      float x1 = cx + cos(angle) * innerD;
      float y1 = cy + sin(angle) * innerD;
      float x2 = cx + cos(angle) * outerD;
      float y2 = cy + sin(angle) * outerD;

      float rHue = (hue3 + i * (180.0 / outerRays) + phase * 8) % 360;
      pg.strokeWeight((0.6 + sMid * 0.8) * ts);
      pg.stroke(rHue, 50, 35 + sMid * 25, 10 + sMid * 12);
      pg.line(x1, y1, x2, y2);
    }

    // ── Pupil ───────────────────────────────────────────────────────────
    pg.blendMode(BLEND);
    pg.noStroke();
    // Gradient pupil: dark center fading out
    for (int i = 3; i >= 0; i--) {
      float frac = (float) i / 3;
      float pr = pupilR * (0.5 + frac * 0.5);
      pg.fill(0, 0, 2 + frac * 5, 90 - frac * 20);
      pg.ellipse(cx, cy, pr * 2, pr * 2);
    }

    // ── Pupil inner light (deep within) ─────────────────────────────────
    pg.blendMode(ADD);
    pg.noStroke();
    float innerGlow = pupilR * 0.3;
    pg.fill(hue1, 40, 20 + sBeat * 30, 8 + sBeat * 15);
    pg.ellipse(cx, cy, innerGlow * 2, innerGlow * 2);

    // ── Specular highlight ──────────────────────────────────────────────
    pg.blendMode(BLEND);
    float hlR = pupilR * 0.20;
    pg.noStroke();
    pg.fill(0, 0, 100, 30 + sBeat * 25);
    pg.ellipse(cx - eyeR * 0.12, cy - eyeR * 0.10, hlR, hlR * 0.7);
    // Smaller secondary highlight
    pg.fill(0, 0, 100, 15);
    pg.ellipse(cx + eyeR * 0.08, cy + eyeR * 0.12, hlR * 0.4, hlR * 0.3);

    // ── HUD ─────────────────────────────────────────────────────────────
    pg.blendMode(BLEND);
    pg.colorMode(RGB, 255);
    pg.textFont(monoFont);
    pg.textAlign(LEFT, TOP);
    pg.fill(255, 255, 255, 150);
    pg.textSize(16 * ts);
    pg.text("Psychedelic Eye", 18 * ts, 14 * ts);
    pg.fill(255, 255, 255, 70);
    pg.textSize(10 * ts);
    String gName = geoMode == 0 ? "hexagonal" : (geoMode == 1 ? "triangular" : "mandala");
    pg.text("iris: " + gName + "  scheme " + (colorMode_ + 1) + "/" + colorSchemes.length,
            18 * ts, 36 * ts);

    pg.textAlign(RIGHT, TOP);
    pg.fill(255, 255, 255, 60);
    pg.text("[ ] scheme  G geo mode", pg.width - 14 * ts, 14 * ts);

    pg.endDraw();
  }

  // ── Eye almond shape ──────────────────────────────────────────────────────
  void drawEyeShape(PGraphics pg, float cx, float cy, float w, float h) {
    pg.beginShape();
    for (int i = 0; i <= 60; i++) {
      float t = TWO_PI * i / 60.0;
      // Almond: parametric with sharpened ends
      float ex = cos(t);
      float ey = sin(t) * (1.0 - 0.3 * cos(t) * cos(t));
      pg.vertex(cx + ex * w, cy + ey * h);
    }
    pg.endShape(CLOSE);
  }

  // ── Hex ring ──────────────────────────────────────────────────────────────
  void drawHexRing(PGraphics pg, float cx, float cy, float r, int ring, float frac) {
    int sides = 6;
    float rotOff = phase * 0.3 * (ring % 2 == 0 ? 1 : -1);
    pg.beginShape();
    for (int i = 0; i <= sides; i++) {
      float angle = TWO_PI * i / sides + rotOff;
      pg.vertex(cx + cos(angle) * r, cy + sin(angle) * r);
    }
    pg.endShape();
  }

  // ── Triangle ring ─────────────────────────────────────────────────────────
  void drawTriRing(PGraphics pg, float cx, float cy, float r, int ring, float frac) {
    int sides = 3;
    float rotOff = phase * 0.4 * (ring % 2 == 0 ? 1 : -1) + (ring % 2) * (PI / 3);
    pg.beginShape();
    for (int i = 0; i <= sides; i++) {
      float angle = TWO_PI * i / sides + rotOff;
      pg.vertex(cx + cos(angle) * r, cy + sin(angle) * r);
    }
    pg.endShape();
  }

  // ── Mandala ring ──────────────────────────────────────────────────────────
  void drawMandalaRing(PGraphics pg, float cx, float cy, float r, int ring, float frac) {
    int petals = 6 + (ring % 4) * 2;
    float rotOff = phase * 0.25 * (ring % 2 == 0 ? 1 : -1);
    pg.beginShape();
    for (int i = 0; i <= petals * 4; i++) {
      float t = TWO_PI * i / (petals * 4.0) + rotOff;
      float modR = r * (1.0 + 0.08 * sin(petals * t + phase));
      pg.vertex(cx + cos(t) * modR, cy + sin(t) * modR);
    }
    pg.endShape();
  }

  // ── Angle lerp ────────────────────────────────────────────────────────────
  float lerpAngle(float a, float b, float t) {
    float diff = ((b - a + 540) % 360) - 180;
    return (a + diff * t + 360) % 360;
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────
  String[] getCodeLines() {
    return new String[]{
      "=== Psychedelic Eye ===",
      "  (after Alex Grey)",
      "",
      "The All-Seeing Eye built from",
      "sacred geometry iris patterns:",
      "  hex / triangle / mandala",
      "",
      "Pupil dilates with bass.",
      "Iris rings of sacred shapes",
      "rotate in alternating dirs.",
      "",
      "Radial filaments + outer rays",
      "create Grey's 'refulgent'",
      "luminous quality.",
      "",
      "Audio mapping:",
      "  Bass \u2192 pupil dilation",
      "  Mid  \u2192 outer ray glow",
      "  High \u2192 iris detail + sat",
      "  Beat \u2192 aura flash",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LB / RB",       "Color scheme"),
      new ControllerLayout("LStick \u2195", "Iris detail"),
      new ControllerLayout("RStick \u2194", "Hue rotation"),
      new ControllerLayout("A",             "Reset"),
      new ControllerLayout("B",             "Geometry mode"),
    };
  }
}
