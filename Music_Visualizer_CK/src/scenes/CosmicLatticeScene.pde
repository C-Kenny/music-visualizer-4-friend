/**
 * CosmicLatticeScene (scene 39) — Alex Grey "Cosmic Lattice"
 *
 * Infinite recursive grid of interconnected human-like energy silhouettes,
 * all connected by glowing threads. Zoom drifts in and out with audio.
 * Inspired by Grey's paintings of universal interconnectedness — figures
 * rendered as translucent energy bodies in a vast geometric web.
 *
 * Visual layers:
 *   1. Deep background grid (faint receding lattice)
 *   2. Human silhouette nodes at grid intersections
 *   3. Energy channels connecting each figure (nervous system threads)
 *   4. Chakra points on each figure (colored dots at energy centers)
 *   5. Luminous aura around each figure
 *
 * Audio:
 *   Bass  — zoom breathing + silhouette glow
 *   Mid   — thread brightness + energy flow
 *   High  — chakra intensity + detail
 *   Beat  — pulse wave through lattice
 *
 * Controller:
 *   LStick ↕    — zoom
 *   LStick ↔    — horizontal drift
 *   RStick ↔    — hue shift
 *   LB / RB     — figure style (outline/skeleton/chakra)
 *   A           — reset
 */
class CosmicLatticeScene implements IScene {

  // ── Config ────────────────────────────────────────────────────────────────
  float gridSpacing  = 220;
  float zoom         = 1.0;
  float targetZoom   = 1.0;
  float driftX       = 0;
  float targetDriftX = 0;
  float hueBase      = 210;
  float targetHue    = 210;
  int   figureStyle  = 0;  // 0: outline, 1: skeleton/nervous, 2: chakra body

  // ── Animation ─────────────────────────────────────────────────────────────
  float phase     = 0;
  float flowPhase = 0;
  float pulseWave = -999;   // distance of pulse ripple from center
  float pulseAlpha = 0;

  // ── Audio ─────────────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;

  // ── Chakra colors (7 centers, bottom to top) ──────────────────────────────
  float[] chakraHues = { 0, 25, 55, 120, 200, 260, 300 };  // R,O,Y,G,B,I,V

  void onEnter() {}
  void onExit()  {}

  void applyController(Controller c) {
    float ly = 1.0 - (c.ly / (float) height);
    float lx = (c.lx - width * 0.5f) / (width * 0.5f);
    targetZoom = lerp(0.4, 2.0, ly);
    if (abs(lx) > 0.08) targetDriftX += lx * 3.0;

    float rx = (c.rx - width * 0.5f) / (width * 0.5f);
    if (abs(rx) > 0.08) targetHue = (targetHue + rx * 2.0 + 360) % 360;

    if (c.lbJustPressed) { figureStyle = (figureStyle - 1 + 3) % 3; }
    if (c.rbJustPressed) { figureStyle = (figureStyle + 1) % 3; }
    if (c.aJustPressed)  { targetZoom = 1.0; targetDriftX = 0; targetHue = 210; figureStyle = 0; }
  }

  void handleKey(char k) {
    switch (k) {
      case '[': figureStyle = (figureStyle - 1 + 3) % 3; break;
      case ']': figureStyle = (figureStyle + 1) % 3; break;
    }
  }

  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.10);
    sMid  = lerp(sMid,  analyzer.mid,  0.10);
    sHigh = lerp(sHigh, analyzer.high, 0.10);
    if (audio.beat.isOnset()) { sBeat = 1.0; pulseWave = 0; pulseAlpha = 1.0; }
    sBeat     = lerp(sBeat, 0, 0.06);
    pulseWave += 5.0 + sBass * 8.0;
    pulseAlpha = lerp(pulseAlpha, 0, 0.02);

    zoom    = lerp(zoom,    targetZoom,   0.04);
    driftX  = lerp(driftX,  targetDriftX, 0.03);
    hueBase = lerpAngle(hueBase, targetHue, 0.03);

    phase     += 0.005 + sMid * 0.015;
    flowPhase += 0.02 + sMid * 0.04;

    float ts = uiScale();
    float gs = gridSpacing * zoom;

    pg.beginDraw();
    pg.hint(DISABLE_DEPTH_TEST);
    pg.background(2, 2, 8);
    pg.colorMode(HSB, 360, 100, 100, 100);

    float centerX = pg.width * 0.5 + driftX;
    float centerY = pg.height * 0.5;

    int cols = (int)(pg.width / gs) + 4;
    int rows = (int)(pg.height / gs) + 4;

    // Grid offset so center figure is centered
    float offX = centerX - (cols / 2) * gs;
    float offY = centerY - (rows / 2) * gs;

    // Breathe offset
    float breathe = sin(phase * 2) * gs * 0.03 * (1 + sBass);

    // ── Pass 1: Connecting threads ──────────────────────────────────────
    pg.blendMode(ADD);
    pg.noFill();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        float fx = offX + col * gs + breathe * sin(phase + row * 0.5);
        float fy = offY + row * gs + breathe * cos(phase + col * 0.5);

        float distC = dist(fx, fy, centerX, centerY);
        float maxD  = dist(0, 0, pg.width * 0.5, pg.height * 0.5) * 1.2;
        float falloff = 1.0 - constrain(distC / maxD, 0, 1);
        if (falloff < 0.05) continue;

        // Right neighbour
        float nx = offX + (col + 1) * gs + breathe * sin(phase + row * 0.5 + 0.5);
        float ny = fy;
        float tHue = (hueBase + distC * 0.06 + flowPhase * 12) % 360;
        float tAlpha = (8 + sMid * 18) * falloff;
        pg.strokeWeight((0.5 + sMid * 0.8) * ts);
        pg.stroke(tHue, 40 + sHigh * 20, 30 + sMid * 25, tAlpha);
        drawEnergyThread(pg, fx, fy, nx, ny);

        // Down neighbour
        float dx = fx;
        float dy = offY + (row + 1) * gs + breathe * cos(phase + col * 0.5 + 0.5);
        pg.stroke((tHue + 30) % 360, 40 + sHigh * 20, 30 + sMid * 25, tAlpha);
        drawEnergyThread(pg, fx, fy, dx, dy);
      }
    }

    // ── Pass 2: Figure nodes ────────────────────────────────────────────
    pg.blendMode(BLEND);
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        float fx = offX + col * gs + breathe * sin(phase + row * 0.5);
        float fy = offY + row * gs + breathe * cos(phase + col * 0.5);

        if (fx < -gs || fx > pg.width + gs || fy < -gs || fy > pg.height + gs) continue;

        float distC = dist(fx, fy, centerX, centerY);
        float maxD  = dist(0, 0, pg.width * 0.5, pg.height * 0.5) * 1.2;
        float falloff = 1.0 - constrain(distC / maxD, 0, 1);
        if (falloff < 0.05) continue;

        float figH = gs * 0.55;
        float figAlpha = falloff;

        // Pulse highlight
        float pulseBri = 0;
        if (pulseAlpha > 0.01) {
          float pd = abs(distC - pulseWave);
          if (pd < gs * 0.5) {
            pulseBri = (1.0 - pd / (gs * 0.5)) * pulseAlpha;
          }
        }

        drawFigure(pg, fx, fy, figH, figAlpha, pulseBri, distC, ts);
      }
    }

    // ── HUD ─────────────────────────────────────────────────────────────
    pg.blendMode(BLEND);
    pg.colorMode(RGB, 255);
    pg.textFont(monoFont);
    pg.textAlign(LEFT, TOP);
    pg.fill(255, 255, 255, 150);
    pg.textSize(16 * ts);
    pg.text("Cosmic Lattice", 18 * ts, 14 * ts);
    pg.fill(255, 255, 255, 70);
    pg.textSize(10 * ts);
    String styleName = figureStyle == 0 ? "round buddy" : (figureStyle == 1 ? "star buddy" : "flower buddy");
    pg.text("style: " + styleName, 18 * ts, 36 * ts);

    pg.textAlign(RIGHT, TOP);
    pg.fill(255, 255, 255, 60);
    pg.text("[ ] figure style", pg.width - 14 * ts, 14 * ts);

    pg.endDraw();
  }

  // ── Draw energy thread with subtle wave ───────────────────────────────────
  void drawEnergyThread(PGraphics pg, float x1, float y1, float x2, float y2) {
    int segs = 8;
    float dx = x2 - x1, dy = y2 - y1;
    float len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    float nx = -dy / len, ny = dx / len;  // perpendicular

    float prevX = x1, prevY = y1;
    for (int i = 1; i <= segs; i++) {
      float t = (float) i / segs;
      float mx = lerp(x1, x2, t);
      float my = lerp(y1, y2, t);
      float wave = sin(flowPhase + t * PI * 2 + len * 0.02) * len * 0.03;
      mx += nx * wave;
      my += ny * wave;
      pg.line(prevX, prevY, mx, my);
      prevX = mx;
      prevY = my;
    }
  }

  // ── Draw figure node ──────────────────────────────────────────────────────
  void drawFigure(PGraphics pg, float cx, float cy, float h, float alphaFrac,
                  float pulseBri, float distC, float ts) {
    float halfH = h * 0.5;

    // Aura glow
    pg.blendMode(ADD);
    pg.noStroke();
    float auraR = h * (0.5 + sBeat * 0.3 + pulseBri * 0.4);
    float aAlpha = (4 + sBeat * 12 + pulseBri * 15) * alphaFrac;
    float aHue = (hueBase + distC * 0.05) % 360;
    pg.fill(aHue, 30, 40, aAlpha);
    pg.ellipse(cx, cy, auraR * 2, auraR * 1.3);

    pg.blendMode(BLEND);

    if (figureStyle == 0) {
      drawFigureOutline(pg, cx, cy, halfH, alphaFrac, distC, ts);
    } else if (figureStyle == 1) {
      drawFigureNervous(pg, cx, cy, halfH, alphaFrac, distC, ts);
    } else {
      drawFigureChakra(pg, cx, cy, halfH, alphaFrac, distC, ts);
    }
  }

  // ── Style 0: Friendly round buddy with smiley face ─────────────────────────
  void drawFigureOutline(PGraphics pg, float cx, float cy, float halfH,
                         float alphaFrac, float distC, float ts) {
    float figHue = (hueBase + 20 + distC * 0.04) % 360;
    float alpha = (55 + sHigh * 25) * alphaFrac;

    // Round body
    float bodyR = halfH * 0.35;
    float headR = halfH * 0.22;
    float headY = cy - halfH * 0.25;
    float bodyY = cy + halfH * 0.15;

    pg.stroke(figHue, 50, 70, alpha);
    pg.strokeWeight((0.8 + sHigh * 0.4) * ts);
    pg.noFill();
    pg.ellipse(cx, bodyY, bodyR * 2, bodyR * 1.8);  // chubby body
    pg.ellipse(cx, headY, headR * 2, headR * 2);     // round head

    // Stubby arms (waving!)
    float armAngle = sin(phase * 2 + distC * 0.01) * 0.4;
    float armLen = halfH * 0.22;
    // Left arm
    float laX = cx - bodyR * 0.85;
    float laY = bodyY - bodyR * 0.3;
    pg.line(laX, laY, laX - cos(armAngle) * armLen, laY - sin(armAngle + 0.8) * armLen);
    // Right arm
    float raX = cx + bodyR * 0.85;
    float raY = bodyY - bodyR * 0.3;
    pg.line(raX, raY, raX + cos(-armAngle) * armLen, raY - sin(-armAngle + 0.8) * armLen);

    // Stubby legs
    float legY = bodyY + bodyR * 0.7;
    float legW = halfH * 0.12;
    pg.line(cx - legW, legY, cx - legW, legY + halfH * 0.15);
    pg.line(cx + legW, legY, cx + legW, legY + halfH * 0.15);

    // Smiley face!
    drawSmileyFace(pg, cx, headY, headR, figHue, alpha, distC, ts);
  }

  // ── Style 1: Star buddy (friendly star-shaped character) ────────────────────
  void drawFigureNervous(PGraphics pg, float cx, float cy, float halfH,
                         float alphaFrac, float distC, float ts) {
    float figHue = (hueBase + distC * 0.04) % 360;
    float alpha = (45 + sHigh * 30) * alphaFrac;

    // Draw a little star shape as the body
    float starR = halfH * 0.4;
    int points = 5;
    float rot = phase + distC * 0.003;

    pg.stroke(figHue, 55, 65, alpha);
    pg.strokeWeight((0.7 + sMid * 0.4) * ts);
    pg.noFill();
    pg.beginShape();
    for (int i = 0; i <= points * 2; i++) {
      float angle = TWO_PI * i / (points * 2) + rot;
      float r = (i % 2 == 0) ? starR : starR * 0.45;
      pg.vertex(cx + cos(angle) * r, cy + sin(angle) * r);
    }
    pg.endShape(CLOSE);

    // Face in center of star
    float faceR = starR * 0.35;
    drawSmileyFace(pg, cx, cy, faceR, figHue, alpha, distC, ts);
  }

  // ── Style 2: Flower buddy (petals around a smiley center) ──────────────────
  void drawFigureChakra(PGraphics pg, float cx, float cy, float halfH,
                        float alphaFrac, float distC, float ts) {
    float figHue = (hueBase + distC * 0.04) % 360;

    // Petals around center
    int petals = 6;
    float petalR = halfH * 0.3;
    float centerR = halfH * 0.22;
    float rot = phase * 0.5 + distC * 0.003;

    pg.blendMode(ADD);
    for (int i = 0; i < petals; i++) {
      float angle = TWO_PI * i / petals + rot;
      float px = cx + cos(angle) * petalR;
      float py = cy + sin(angle) * petalR;
      float pHue = (figHue + i * (360.0 / petals)) % 360;

      float intensity = 0.5;
      if (analyzer.spectrum != null && analyzer.spectrum.length > petals) {
        intensity = analyzer.spectrum[i * 6];
      }

      float pAlpha = (10 + intensity * 20 + sHigh * 10) * alphaFrac;
      pg.noStroke();
      pg.fill(pHue, 60, 55 + intensity * 25, pAlpha);
      pg.ellipse(px, py, centerR * 1.4, centerR * 1.4);
    }

    // Center circle
    pg.blendMode(BLEND);
    float alpha = (50 + sHigh * 25) * alphaFrac;
    pg.noStroke();
    pg.fill(figHue, 30, 15, alpha * 0.5);
    pg.ellipse(cx, cy, centerR * 2, centerR * 2);

    // Smiley on center
    drawSmileyFace(pg, cx, cy, centerR, figHue, alpha, distC, ts);
  }

  // ── Shared smiley face helper ─────────────────────────────────────────────
  void drawSmileyFace(PGraphics pg, float cx, float cy, float r,
                      float figHue, float alpha, float distC, float ts) {
    float facePhase = phase + distC * 0.005;

    // Eyes (two little dots with googly wobble)
    float eyeSpacing = r * 0.35;
    float eyeY = cy - r * 0.15;
    float eyeR = r * 0.18;
    float wobX = sin(facePhase * 1.5) * eyeR * 0.3;
    float wobY = cos(facePhase * 2.0) * eyeR * 0.3;

    // Eye whites
    pg.noStroke();
    pg.fill(0, 0, 90, alpha * 0.8);
    pg.ellipse(cx - eyeSpacing, eyeY, eyeR * 2.2, eyeR * 2.2);
    pg.ellipse(cx + eyeSpacing, eyeY, eyeR * 2.2, eyeR * 2.2);

    // Pupils (wobbling)
    pg.fill(0, 0, 5, alpha);
    pg.ellipse(cx - eyeSpacing + wobX, eyeY + wobY, eyeR * 1.2, eyeR * 1.2);
    pg.ellipse(cx + eyeSpacing + wobX, eyeY + wobY, eyeR * 1.2, eyeR * 1.2);

    // Smile arc
    pg.noFill();
    pg.stroke(figHue, 40, 60, alpha * 0.8);
    pg.strokeWeight(0.5 * ts);
    float smileW = r * 0.5;
    float smileY = cy + r * 0.2;
    pg.arc(cx, smileY, smileW, smileW * 0.6, 0.2, PI - 0.2);
  }

  // ── Angle lerp ────────────────────────────────────────────────────────────
  float lerpAngle(float a, float b, float t) {
    float diff = ((b - a + 540) % 360) - 180;
    return (a + diff * t + 360) % 360;
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────
  String[] getCodeLines() {
    return new String[]{
      "=== Cosmic Lattice ===",
      "  (after Alex Grey)",
      "",
      "Infinite grid of energy figures",
      "connected by luminous threads.",
      "",
      "Three figure styles:",
      "  0: round buddy (smiley)",
      "  1: star buddy",
      "  2: flower buddy",
      "",
      "Pulse wave ripples outward",
      "from center on each beat.",
      "",
      "Audio mapping:",
      "  Bass \u2192 zoom breathing",
      "  Mid  \u2192 thread energy flow",
      "  High \u2192 detail + chakras",
      "  Beat \u2192 lattice pulse wave",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LB / RB",       "Figure style"),
      new ControllerLayout("LStick \u2195", "Zoom"),
      new ControllerLayout("LStick \u2194", "Drift"),
      new ControllerLayout("RStick \u2194", "Hue shift"),
      new ControllerLayout("A",             "Reset"),
    };
  }
}
