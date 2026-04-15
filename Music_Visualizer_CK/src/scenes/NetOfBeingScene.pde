/**
 * NetOfBeingScene (scene 37) — Alex Grey "Net of Being"
 *
 * Tessellated grid of luminous eye/face nodes connected by glowing energy
 * threads. Inspired by Grey's dense decorative linear webs and his painting
 * "Net of Being" — an infinite lattice of interconnected consciousness.
 *
 * Visual layers:
 *   1. Background grid of hexagonal cells
 *   2. Eye-like nodes at each vertex that pulse with audio
 *   3. Luminous connecting threads that brighten with mid/high
 *   4. Radiating aura halos on beat
 *
 * Audio:
 *   Bass  — grid breathing (scale pulse) + node size
 *   Mid   — thread brightness + connection density
 *   High  — iris detail + color saturation
 *   Beat  — aura flash + ripple wave
 *
 * Controller:
 *   LStick ↕    — zoom
 *   RStick ↔    — hue shift
 *   RStick ↕    — grid density
 *   LB / RB     — palette cycle
 *   A           — reset
 */
class NetOfBeingScene implements IScene {

  // ── Grid config ───────────────────────────────────────────────────────────
  float cellSize     = 260;
  float targetCell   = 260;
  float zoom         = 1.0;
  float targetZoom   = 1.0;
  float hueBase      = 200;
  float targetHue    = 200;
  int   paletteIdx   = 0;

  // Palettes: [base hue, accent hue, thread hue]
  float[][] palettes = {
    {200, 280, 170},   // blue-violet-teal (classic Grey)
    {30,  50,  15},    // golden amber
    {300, 340, 260},   // magenta-pink-purple
    {140, 200, 100},   // green-cyan-emerald
    {0,   30,  330},   // red-orange-crimson
  };

  // ── Animation state ───────────────────────────────────────────────────────
  float phase        = 0;
  float breathPhase  = 0;
  float rippleCenter = 0;
  float rippleAlpha  = 0;

  // ── Audio smoothing ───────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;

  // ── IScene lifecycle ──────────────────────────────────────────────────────
  void onEnter() { paletteIdx = 0; applyPalette(); }
  void onExit()  {}

  void applyPalette() {
    targetHue = palettes[paletteIdx][0];
  }

  // ── Controller ────────────────────────────────────────────────────────────
  void applyController(Controller c) {
    float ly = 1.0 - (c.ly / (float) height);
    targetZoom = lerp(0.5, 2.0, ly);

    float rx = (c.rx - width * 0.5f) / (width * 0.5f);
    float ry = (c.ry - height * 0.5f) / (height * 0.5f);
    if (abs(rx) > 0.08) targetHue = (targetHue + rx * 2.0 + 360) % 360;
    if (abs(ry) > 0.08) targetCell = constrain(targetCell - ry * 4.0, 150, 400);

    if (c.lbJustPressed) { paletteIdx = (paletteIdx - 1 + palettes.length) % palettes.length; applyPalette(); }
    if (c.rbJustPressed) { paletteIdx = (paletteIdx + 1) % palettes.length; applyPalette(); }
    if (c.aJustPressed)  { targetZoom = 1.0; targetCell = 90; paletteIdx = 0; applyPalette(); }
  }

  void handleKey(char k) {
    switch (k) {
      case '[': paletteIdx = (paletteIdx - 1 + palettes.length) % palettes.length; applyPalette(); break;
      case ']': paletteIdx = (paletteIdx + 1) % palettes.length; applyPalette(); break;
      case '+': case '=': targetCell = min(400, targetCell + 20); break;
      case '-': targetCell = max(150, targetCell - 20); break;
    }
  }

  // ── Draw ──────────────────────────────────────────────────────────────────
  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.10);
    sMid  = lerp(sMid,  analyzer.mid,  0.10);
    sHigh = lerp(sHigh, analyzer.high, 0.10);
    if (audio.beat.isOnset()) { sBeat = 1.0; rippleCenter = 0; rippleAlpha = 1.0; }
    sBeat = lerp(sBeat, 0, 0.06);

    zoom     = lerp(zoom,     targetZoom, 0.04);
    cellSize = lerp(cellSize, targetCell,  0.04);
    hueBase  = lerpAngle(hueBase, targetHue, 0.03);

    phase       += 0.008 + sMid * 0.02;
    breathPhase += 0.015 + sBass * 0.03;
    rippleCenter += 4.0 + sBass * 6.0;
    rippleAlpha  = lerp(rippleAlpha, 0, 0.03);

    float accentHue = palettes[paletteIdx][1];
    float threadHue = palettes[paletteIdx][2];

    pg.beginDraw();
    pg.hint(DISABLE_DEPTH_TEST);
    pg.background(4, 3, 8);
    pg.colorMode(HSB, 360, 100, 100, 100);
    pg.noFill();

    float ts   = uiScale();
    float cs   = cellSize * zoom;
    float hexH = cs * sqrt(3) * 0.5;

    // How many cells to cover screen
    int cols = (int)(pg.width  / (cs * 1.5)) + 4;
    int rows = (int)(pg.height / hexH) + 4;

    float ox = pg.width  * 0.5 - cols * cs * 0.75;
    float oy = pg.height * 0.5 - rows * hexH * 0.5;

    // Breathing offset
    float breathAmt = sin(breathPhase) * cs * 0.06 * (1 + sBass * 0.8);

    // ── Pass 1: Connecting threads ──────────────────────────────────────
    pg.blendMode(ADD);
    float threadBright = 20 + sMid * 35 + sHigh * 15;
    float threadAlpha  = 12 + sMid * 20;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        float cx = ox + col * cs * 1.5;
        float cy = oy + row * hexH + ((col % 2 == 0) ? 0 : hexH * 0.5);
        cx += breathAmt * sin(phase + row * 0.3);
        cy += breathAmt * cos(phase + col * 0.3);

        // Connect to 3 neighbours (right, bottom-right, bottom-left)
        float[][] neighbours = {
          {cx + cs * 1.5, cy + ((col % 2 == 0) ? hexH * 0.5 : -hexH * 0.5)},
          {cx + cs * 1.5, cy + ((col % 2 == 0) ? -hexH * 0.5 : hexH * 0.5)},
          {cx, cy + hexH}
        };

        for (float[] nb : neighbours) {
          float nbx = nb[0] + breathAmt * sin(phase + row * 0.3 + 1);
          float nby = nb[1] + breathAmt * cos(phase + col * 0.3 + 1);
          float distToCenter = dist(cx, cy, pg.width * 0.5, pg.height * 0.5);
          float cHue = (threadHue + distToCenter * 0.08 + phase * 20) % 360;

          pg.strokeWeight((0.6 + sMid * 1.2) * ts);
          pg.stroke(cHue, 50 + sHigh * 30, threadBright, threadAlpha);
          pg.line(cx, cy, nbx, nby);
        }
      }
    }

    // ── Pass 2: Eye nodes ───────────────────────────────────────────────
    pg.blendMode(BLEND);
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        float cx = ox + col * cs * 1.5;
        float cy = oy + row * hexH + ((col % 2 == 0) ? 0 : hexH * 0.5);
        cx += breathAmt * sin(phase + row * 0.3);
        cy += breathAmt * cos(phase + col * 0.3);

        // Skip nodes outside screen with margin
        if (cx < -cs || cx > pg.width + cs || cy < -cs || cy > pg.height + cs) continue;

        float distToCenter = dist(cx, cy, pg.width * 0.5, pg.height * 0.5);
        float maxDist = dist(0, 0, pg.width * 0.5, pg.height * 0.5);
        float falloff = 1.0 - constrain(distToCenter / maxDist, 0, 1) * 0.4;

        drawEyeNode(pg, cx, cy, cs * 0.18 * falloff, distToCenter, ts);
      }
    }

    // ── Pass 3: Beat ripple ─────────────────────────────────────────────
    if (rippleAlpha > 0.01) {
      pg.blendMode(ADD);
      pg.noFill();
      float rr = rippleCenter;
      pg.strokeWeight(2.5 * ts);
      pg.stroke(hueBase, 40, 80, rippleAlpha * 30);
      pg.ellipse(pg.width * 0.5, pg.height * 0.5, rr * 2, rr * 2);
      pg.strokeWeight(1.2 * ts);
      pg.stroke((hueBase + 30) % 360, 50, 60, rippleAlpha * 20);
      pg.ellipse(pg.width * 0.5, pg.height * 0.5, rr * 2.3, rr * 2.3);
    }

    // ── HUD ─────────────────────────────────────────────────────────────
    pg.blendMode(BLEND);
    pg.colorMode(RGB, 255);
    pg.textFont(monoFont);
    pg.textAlign(LEFT, TOP);
    pg.fill(255, 255, 255, 150);
    pg.textSize(16 * ts);
    pg.text("Net of Being", 18 * ts, 14 * ts);
    pg.fill(255, 255, 255, 70);
    pg.textSize(10 * ts);
    pg.text("palette " + (paletteIdx + 1) + "/" + palettes.length, 18 * ts, 36 * ts);

    pg.textAlign(RIGHT, TOP);
    pg.fill(255, 255, 255, 60);
    pg.text("[ ] palette   -/= density", pg.width - 14 * ts, 14 * ts);

    pg.endDraw();
  }

  // ── Googly eye node ────────────────────────────────────────────────────────
  // Draws a cute googly eye at (cx, cy) with radius r. The pupil wobbles
  // around based on audio and phase — friendly, not creepy!
  void drawEyeNode(PGraphics pg, float cx, float cy, float r, float distC, float ts) {
    float nodePhase = phase + distC * 0.005;

    // Soft aura glow behind eye
    pg.blendMode(ADD);
    float auraR = r * (1.4 + sBeat * 0.8);
    float auraA = 5 + sBeat * 14;
    pg.noStroke();
    pg.fill(hueBase, 35, 50, auraA);
    pg.ellipse(cx, cy, auraR * 2, auraR * 2);

    // White of the eye (sclera)
    pg.blendMode(BLEND);
    pg.noStroke();
    pg.fill(0, 0, 95, 80);
    pg.ellipse(cx, cy, r * 2, r * 2);

    // Slight outline
    pg.noFill();
    pg.strokeWeight(0.6 * ts);
    pg.stroke(hueBase, 30, 60, 40);
    pg.ellipse(cx, cy, r * 2, r * 2);

    // Wobbling pupil — bounces around inside the eye
    float wobbleX = sin(nodePhase * 1.3 + sBass * 3) * r * 0.28;
    float wobbleY = cos(nodePhase * 1.7 + sMid * 2) * r * 0.28;
    float pupilR = r * (0.45 + sBass * 0.15);
    float px = cx + wobbleX;
    float py = cy + wobbleY;

    // Iris (colored ring)
    pg.noStroke();
    float irisHue = (hueBase + distC * 0.08 + nodePhase * 10) % 360;
    pg.fill(irisHue, 60 + sHigh * 25, 60 + sHigh * 20, 75);
    pg.ellipse(px, py, pupilR * 2, pupilR * 2);

    // Black pupil
    pg.fill(0, 0, 3, 90);
    pg.ellipse(px, py, pupilR * 1.1, pupilR * 1.1);

    // Specular highlight — makes it look glossy and alive
    pg.fill(0, 0, 100, 50 + sBeat * 25);
    float hlSize = pupilR * 0.35;
    pg.ellipse(px - pupilR * 0.25, py - pupilR * 0.25, hlSize, hlSize);
    // Tiny secondary highlight
    pg.fill(0, 0, 100, 25);
    pg.ellipse(px + pupilR * 0.15, py + pupilR * 0.2, hlSize * 0.4, hlSize * 0.4);
  }

  // ── Angle lerp ────────────────────────────────────────────────────────────
  float lerpAngle(float a, float b, float t) {
    float diff = ((b - a + 540) % 360) - 180;
    return (a + diff * t + 360) % 360;
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────
  String[] getCodeLines() {
    return new String[]{
      "=== Net of Being ===",
      "  (after Alex Grey)",
      "",
      "Hexagonal tessellation of",
      "luminous eye-nodes connected",
      "by glowing energy threads.",
      "",
      "Each eye: concentric iris",
      "rings + radial ray detail",
      "+ dark pupil + aura halo.",
      "",
      "Audio mapping:",
      "  Bass \u2192 breathing + pupils",
      "  Mid  \u2192 thread brightness",
      "  High \u2192 iris detail + sat",
      "  Beat \u2192 ripple + aura flash",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LB / RB",       "Palette cycle"),
      new ControllerLayout("LStick \u2195", "Zoom"),
      new ControllerLayout("RStick \u2194", "Hue shift"),
      new ControllerLayout("RStick \u2195", "Grid density"),
      new ControllerLayout("A",             "Reset"),
    };
  }
}
