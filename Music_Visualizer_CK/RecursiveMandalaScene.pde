// RecursiveMandalaScene — Scene 23
//
// A fractal mandala: N arms radiate from a drifting centre; each arm recurses
// at its tip spawning three sub-arms (centre + ±spreadAngle), producing nested
// petal rings.  All geometry is rendered with ADD blending to an off-screen
// buffer, then composited through mandala_glow.glsl for a soft halo.
//
// Performance note:
//   Each arm spawns 3 sub-arms → O(3^depth) shapes per initial arm.
//   depth 3 = 8 × 39  = 312 shapes  (~fast)
//   depth 4 = 8 × 120 = 960 shapes  (default)
//   depth 5 = 8 × 363 = 2904 shapes (heavy — use on fast hardware)
//   Hard cap enforced at depth 5.  beatBoost is limited to +1.
//
// Audio mapping:
//   Bass  → arm length pulse + core scale
//   Mid   → rotation speed, spread angle, petal width, drift speed
//   High  → glow radius + colour saturation
//   Beat  → +1 depth burst (1 frame) + white flash
//
// Movement:
//   The mandala centre drifts via Perlin-noise Lissajous — the whole flower
//   floats gently around the screen, faster with mid frequency energy.
//   A slow "breathe" scale adds organic pulsing independent of beat.
//
// Controller:
//   L Stick X   → add manual rotation
//   L Stick Y   → zoom
//   R Stick X   → spread angle between sub-arms
//   R Stick Y   → shrink factor per recursion level
//   LT / RT     → slow / fast auto-rotation
//   A           → cycle arm count (3 → 14)
//   B           → cycle recursion depth (2 → 5)
//   Y           → cycle colour palette
//   X           → reset zoom, rotation, speed
//
// Keys:
//   a/A   → cycle arm count
//   d/D   → depth +1 / -1  (capped 2–5)
//   [/]   → shrink factor −/+
//   -/=   → rotation speed −/+
//   c/C   → cycle colour palette
//   r/R   → reset all to defaults
//   z/Z   → zoom out / in
//   m/M   → drift amplitude −/+

class RecursiveMandalaScene implements IScene {

  // ── Tuneable parameters ────────────────────────────────────────────────────
  int   symmetry    = 8;
  int   maxDepth    = 4;          // user-set depth (capped to HARD_MAX in drawScene)
  float shrink      = 0.48;
  float spreadAngle = PI / 3.0;
  float rotSpeed    = 0.005;
  int   paletteIdx  = 0;
  float driftAmp    = 0.08;       // fraction of screen the centre may wander

  static final int HARD_MAX_DEPTH = 5;   // absolute cap — prevents slideshow

  // ── Palette definitions — add more rows freely ─────────────────────────────
  final String[] paletteNames = { "Aurora", "Crimson", "Ocean",  "Solar"  };
  final float[]  paletteHues  = { 160,       0,         200,      45      };

  // ── Smoothed audio ─────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0;

  // ── Runtime state ──────────────────────────────────────────────────────────
  float globalRot      = 0;
  float zoom           = 1.0;
  float manualRotDelta = 0;
  float beatFlash      = 0;
  int   beatBoost      = 0;       // +1 depth for exactly 1 frame per beat
  float lt = 0, rt     = 0;

  // Organic movement — noise target + lerped actual position (prevents jitter)
  float driftPhase   = 0;
  float breathePhase = 0;
  float driftX       = 0, driftY = 0;   // current smoothed position

  // ── Off-screen render + shader ─────────────────────────────────────────────
  PShader   glowShader;
  PGraphics glowBuf;

  RecursiveMandalaScene() {}

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  void onEnter() {
    globalRot = 0; zoom = 1.0; beatFlash = 0;
    beatBoost = 0; manualRotDelta = 0;
    driftPhase = random(100); breathePhase = 0; driftX = 0; driftY = 0;
    glowShader = loadShader("mandala_glow.glsl");
    glowBuf    = createGraphics(width, height, P3D);
    glowBuf.beginDraw(); glowBuf.background(0); glowBuf.endDraw();
  }

  void onExit() {}

  // ── Main render ─────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    if (glowBuf == null || glowBuf.width != pg.width || glowBuf.height != pg.height) {
      glowBuf = createGraphics(pg.width, pg.height, P3D);
    }
    if (glowShader == null) glowShader = loadShader("mandala_glow.glsl");

    // Smooth audio
    sBass  = lerp(sBass,  analyzer.bass,  0.15);
    sMid   = lerp(sMid,   analyzer.mid,   0.12);
    sHigh  = lerp(sHigh,  analyzer.high,  0.20);

    // Beat — +1 depth, last exactly 1 frame
    if (analyzer.isBeat) { beatFlash = 1.0; beatBoost = 1; }
    beatFlash = max(0, beatFlash - 0.055);
    if (beatBoost > 0) beatBoost--;

    // Hard-cap effective depth to prevent exponential blowup
    int depth = min(maxDepth + beatBoost, HARD_MAX_DEPTH);

    // Rotation — mid + triggers
    float speedMod = 1.0 + sMid * 0.5 + (rt - lt) * 1.2;
    globalRot += rotSpeed * speedMod;

    // Organic drift — noise target lerped very slowly into actual position
    // Lerp factor 0.012 means it takes ~80 frames to close half the gap → butter smooth
    float driftSpeed = 0.0012 + sMid * 0.0010;
    driftPhase   += driftSpeed;
    breathePhase += 0.014;

    float targetX = (noise(driftPhase, 0.0)   - 0.5) * 2.0 * driftAmp * pg.width;
    float targetY = (noise(driftPhase, 100.0)  - 0.5) * 2.0 * driftAmp * pg.height;
    driftX = lerp(driftX, targetX, 0.012);
    driftY = lerp(driftY, targetY, 0.012);
    float breathe = 1.0 + sin(breathePhase) * 0.06; // ±6% slow scale breathe

    // ── Draw mandala into off-screen buffer ─────────────────────────────────
    glowBuf.beginDraw();
    glowBuf.background(0);
    glowBuf.colorMode(HSB, 360, 255, 255, 255);
    glowBuf.blendMode(ADD);

    float baseLen = glowBuf.height * 0.20 + sBass * glowBuf.height * 0.045;
    float scl     = zoom * (1.0 + sBass * 0.06) * breathe;

    glowBuf.pushMatrix();
    glowBuf.translate(glowBuf.width * 0.5 + driftX, glowBuf.height * 0.5 + driftY);
    glowBuf.scale(scl);
    glowBuf.rotate(globalRot + manualRotDelta);

    for (int i = 0; i < symmetry; i++) {
      glowBuf.pushMatrix();
      glowBuf.rotate(TWO_PI * i / symmetry);
      drawArm(glowBuf, baseLen, depth, 0);
      glowBuf.popMatrix();
    }

    glowBuf.colorMode(RGB, 255);
    glowBuf.blendMode(BLEND);
    glowBuf.popMatrix();
    glowBuf.endDraw();

    // ── Apply glow shader ────────────────────────────────────────────────────
    glowShader.set("glowStrength", 0.55 + sHigh * 1.5 + beatFlash * 1.2);
    glowShader.set("glowRadius",   2.2  + sMid  * 4.0);

    pg.background(0);
    pg.shader(glowShader);
    pg.image(glowBuf, 0, 0);
    pg.resetShader();

    // Beat flash
    if (beatFlash > 0.05) {
      pg.blendMode(ADD);
      pg.noStroke(); pg.fill(255, 255, 255, beatFlash * 35);
      pg.rect(0, 0, pg.width, pg.height);
      pg.blendMode(BLEND);
    }

    drawHUD(pg);
    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width * 0.5, pg.height - 8);
  }

  // ── Recursive arm ───────────────────────────────────────────────────────────
  // Draws one petal arm pointing toward (0, −len), then recurses with three
  // sub-arms at the tip.  To extend: add sub-arm angles, change petal shape,
  // add joint ornaments.

  void drawArm(PGraphics pg, float len, int depth, int level) {
    if (depth <= 0 || len < 2.5) return;

    float t      = (float)level / max(1, maxDepth - 1);
    float hue    = (paletteHues[paletteIdx] + level * 34 + sHigh * 75) % 360;
    float sat    = lerp(235, 140, t);
    float bri    = 255;
    float alpha  = lerp(220, 85, t);
    float sw     = lerp(3.2, 0.5, t);
    float petalW = len * 0.30 * (1.0 + sMid * 0.40);

    // Filled petal — low alpha; ADD mode makes overlaps glow naturally
    pg.noStroke();
    pg.fill(hue, sat, bri * 0.65, alpha * 0.35);
    pg.beginShape();
    pg.vertex(0, 0);
    pg.bezierVertex( petalW, -len * 0.38,  petalW, -len * 0.78,  0, -len);
    pg.bezierVertex(-petalW, -len * 0.78, -petalW, -len * 0.38,  0,    0);
    pg.endShape(CLOSE);

    // Central vein line
    pg.noFill();
    pg.stroke(hue, sat * 0.65, 255, min(255, alpha * 1.3));
    pg.strokeWeight(sw);
    pg.line(0, 0, 0, -len);

    // Sparkle dot at tip
    float dotR = sw * 3.0 + sHigh * sw * 2.0;
    pg.noStroke();
    pg.fill(hue, sat * 0.5, 255, alpha);
    pg.ellipse(0, -len, dotR, dotR);

    // ── Recurse at tip ──────────────────────────────────────────────────────
    pg.pushMatrix();
    pg.translate(0, -len);

    float newLen = len * shrink;
    float dyn    = spreadAngle * (0.75 + sMid * 0.45);

    pg.pushMatrix();
    drawArm(pg, newLen, depth - 1, level + 1);
    pg.popMatrix();

    pg.pushMatrix();
    pg.rotate(-dyn);
    drawArm(pg, newLen * 0.78, depth - 1, level + 1);
    pg.popMatrix();

    pg.pushMatrix();
    pg.rotate(dyn);
    drawArm(pg, newLen * 0.78, depth - 1, level + 1);
    pg.popMatrix();

    pg.popMatrix();
  }

  // ── HUD ─────────────────────────────────────────────────────────────────────

  void drawHUD(PGraphics pg) {
    pg.pushStyle();
    float ts = 11 * uiScale(), lh = ts * 1.35;
    pg.noStroke(); pg.rectMode(CORNER);
    pg.fill(0, 150);
    pg.rect(8, 8, 420 * uiScale(), 8 + lh * 8.5);
    pg.textSize(ts); pg.textAlign(LEFT, TOP);
    pg.fill(100, 255, 160);
    pg.text("=== Recursive Mandala ===", 12, 12);
    pg.fill(180, 255, 200);
    pg.text("Bass:" + nf(sBass,1,2) + "  Mid:" + nf(sMid,1,2) + "  High:" + nf(sHigh,1,2),
            12, 12 + lh);
    pg.text("Arms:" + symmetry +
            "  Depth:" + maxDepth + " (hard cap " + HARD_MAX_DEPTH + ")" +
            "  Shrink:" + nf(shrink,1,2),
            12, 12 + lh * 2);
    pg.text("Spread:" + nf(degrees(spreadAngle),1,0) + "°" +
            "  RotSpd:" + nf(rotSpeed,1,3) +
            "  Zoom:" + nf(zoom,1,2) +
            "  Drift:" + nf(driftAmp,1,2),
            12, 12 + lh * 3);
    pg.text("Palette:" + paletteNames[paletteIdx], 12, 12 + lh * 4);
    pg.fill(120, 200, 140);
    pg.text("A arms  B depth  Y palette  X reset", 12, 12 + lh * 5.5);
    pg.text("L-stick zoom/rot  R-stick spread/shrink  LT slow  RT fast",
            12, 12 + lh * 6.5);
    pg.text("d/D depth  [/] shrink  -/= speed  z/Z zoom  m/M drift  c palette",
            12, 12 + lh * 7.5);
    pg.popStyle();
  }

  // ── Controller ──────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    if (abs(lx) > 0.12) manualRotDelta += lx * 0.025;
    if (abs(ly) > 0.12) zoom = constrain(zoom - ly * 0.018, 0.25, 3.5);

    float rx = map(c.rx, 0, width,  -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);
    if (abs(rx) > 0.12) spreadAngle = constrain(spreadAngle + rx * 0.018, PI/10, PI * 0.72);
    if (abs(ry) > 0.12) shrink      = constrain(shrink - ry * 0.007, 0.18, 0.78);

    try {
      float z = c.stick.getSlider("z").getValue();
      lt = max(0, -z); rt = max(0, z);
    } catch (Exception e) { lt = 0; rt = 0; }

    if (c.a_just_pressed) symmetry   = (symmetry % 12) + 3;
    if (c.b_just_pressed) maxDepth   = constrain((maxDepth % HARD_MAX_DEPTH) + 2, 2, HARD_MAX_DEPTH);
    if (c.y_just_pressed) paletteIdx = (paletteIdx + 1) % paletteNames.length;
    if (c.x_just_pressed) { zoom = 1.0; manualRotDelta = 0; rotSpeed = 0.005; }
  }

  // ── Keyboard ────────────────────────────────────────────────────────────────

  void handleKey(char k) {
    if      (k == 'a' || k == 'A') symmetry    = (symmetry % 12) + 3;
    else if (k == 'd')             maxDepth    = min(maxDepth + 1, HARD_MAX_DEPTH);
    else if (k == 'D')             maxDepth    = max(maxDepth - 1, 2);
    else if (k == '[')             shrink      = constrain(shrink - 0.04, 0.18, 0.78);
    else if (k == ']')             shrink      = constrain(shrink + 0.04, 0.18, 0.78);
    else if (k == '-' || k == '_') rotSpeed   -= 0.002;
    else if (k == '=' || k == '+') rotSpeed   += 0.002;
    else if (k == 'c' || k == 'C') paletteIdx  = (paletteIdx + 1) % paletteNames.length;
    else if (k == 'r' || k == 'R') { zoom = 1.0; manualRotDelta = 0; rotSpeed = 0.005; }
    else if (k == 'z')             zoom        = constrain(zoom - 0.12, 0.25, 3.5);
    else if (k == 'Z')             zoom        = constrain(zoom + 0.12, 0.25, 3.5);
    else if (k == 'm')             driftAmp    = constrain(driftAmp - 0.03, 0, 0.45);
    else if (k == 'M')             driftAmp    = constrain(driftAmp + 0.03, 0, 0.45);
  }

  // ── Code overlay ────────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Recursive Mandala ===",
      "// " + symmetry + "-fold, depth " + maxDepth + " (cap " + HARD_MAX_DEPTH + "), shrink " + nf(shrink,1,2),
      "arm(len, depth) → bezier petal + 3 sub-arms at tip",
      "cost: symmetry × 3^depth shapes per frame",
      "drift: Perlin noise Lissajous on (driftPhase, 0/100)",
      "bass  → baseLen * (1 + bass * 0.22)",
      "mid   → driftSpeed + spreadAngle + rotSpeed",
      "beat  → depth+1 for 1 frame + flash"
    };
  }
}
