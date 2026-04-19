/**
 * CosmicLatticeScene (scene 39) — Alex Grey "Cosmic Lattice"
 *
 * Undulating pseudo-3D grid of friendly energy figures holding hands across
 * a luminous web. Beats fire a shockwave ring that punches nodes forward in
 * depth. A rotating mandala yantra glows behind the lattice. Figures carry a
 * vertical chakra column that pulses to the spectrum, and their pupils
 * collectively gaze toward the center — hive-mind effect.
 *
 * Visual layers:
 *   1. Rotating mandala backdrop (concentric yantra + glow core)
 *   2. Undulating 3D lattice nodes (fake-projected, rings ripple forward on beat)
 *   3. Hand-linked energy threads (arm-to-arm, traveling data packets + trail)
 *   4. Figures (round/star/flower buddy) with 7-dot chakra column, gazing eyes
 *
 * Audio:
 *   Bass  — lattice breathing + mandala pulse + figure scale
 *   Mid   — thread turbulence + packet speed
 *   High  — orbital shimmer + chakra glow
 *   Beat  — shockwave ring + node flash
 *
 * Controller:
 *   LStick ↕    — zoom
 *   LStick ↔    — horizontal drift
 *   RStick ↔    — hue shift
 *   RStick ↕    — thread turbulence
 *   LT / RT     — lattice density
 *   LB / RB     — figure style (round / star / flower)
 *   A           — reset
 */
class CosmicLatticeScene implements IScene {

  // ── Config ────────────────────────────────────────────────────────────────
  float gridSpacing  = 220;
  float zoom         = 1.55;
  float targetZoom   = 1.55;
  float driftX       = 0;
  float targetDriftX = 0;
  float hueBase      = 210;
  float targetHue    = 210;
  int   figureStyle  = 0;
  float density      = 1.0;
  float targetDensity = 1.0;
  float threadWarp   = 1.0;
  float targetThreadWarp = 1.0;
  final float MIN_ZOOM = 0.95;
  final float MAX_ZOOM = 3.2;
  final float CENTER_FOCUS_RADIUS = 300;
  final float FOCAL_LEN  = 820;   // fake-perspective focal length
  final float Z_AMP      = 140;   // undulation depth
  final float SHOCK_PUSH = 220;   // how far beat shockwave pulls nodes toward camera

  // ── Animation ─────────────────────────────────────────────────────────────
  float phase         = 0;
  float flowPhase     = 0;
  float orbitPhase    = 0;
  float mandalaPhase  = 0;
  float pulseWave     = -999;
  float pulseAlpha    = 0;
  float sBeatFlash    = 0;

  // ── Audio ─────────────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;

  // ── Chakra colors (7 centers, root→crown) ─────────────────────────────────
  float[] chakraHues = { 0, 25, 55, 120, 200, 260, 300 };

  void onEnter() {}
  void onExit()  {}

  void applyController(Controller c) {
    float ly = 1.0 - (c.ly / (float) height);
    float lx = (c.lx - width * 0.5f) / (width * 0.5f);
    targetZoom = lerp(MIN_ZOOM, MAX_ZOOM, ly);
    if (abs(lx) > 0.08) targetDriftX += lx * 3.0;

    float rx = (c.rx - width * 0.5f) / (width * 0.5f);
    if (abs(rx) > 0.08) targetHue = (targetHue + rx * 2.0 + 360) % 360;
    float ry = 1.0 - (c.ry / (float) height);
    targetThreadWarp = lerp(0.55, 2.3, ry);
    targetDensity = constrain(0.75 + c.rt * 0.9 - c.lt * 0.45, 0.65, 1.9);

    if (c.lbJustPressed) { figureStyle = (figureStyle - 1 + 3) % 3; }
    if (c.rbJustPressed) { figureStyle = (figureStyle + 1) % 3; }
    if (c.aJustPressed)  {
      targetZoom = 1.55;
      targetDriftX = 0;
      targetHue = 210;
      targetDensity = 1.0;
      targetThreadWarp = 1.0;
      figureStyle = 0;
    }
  }

  void handleKey(char k) {
    switch (k) {
      case '[': figureStyle = (figureStyle - 1 + 3) % 3; break;
      case ']': figureStyle = (figureStyle + 1) % 3; break;
      case '-': targetDensity = max(0.65, targetDensity - 0.08); break;
      case '=': targetDensity = min(1.9, targetDensity + 0.08); break;
      case ',': targetThreadWarp = max(0.55, targetThreadWarp - 0.1); break;
      case '.': targetThreadWarp = min(2.3, targetThreadWarp + 0.1); break;
    }
  }

  // ── Projected-node record ─────────────────────────────────────────────────
  // Cached per (col,row) so threads and figures share identical screen coords.
  class Node {
    float sx, sy;      // screen position
    float scale;       // perspective scale (1.0 at z=0)
    float wx, wy;      // world position pre-projection
    float z;           // depth
    float flash;       // beat shock flash (0..1)
    float falloff;     // radial fade (1 at center → 0 at edge)
  }

  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.10);
    sMid  = lerp(sMid,  analyzer.mid,  0.10);
    sHigh = lerp(sHigh, analyzer.high, 0.10);
    if (audio.beat.isOnset()) { sBeat = 1.0; pulseWave = 0; pulseAlpha = 1.0; sBeatFlash = 1.0; }
    sBeat      = lerp(sBeat, 0, 0.06);
    sBeatFlash = lerp(sBeatFlash, 0, 0.08);
    pulseWave += 5.0 + sBass * 8.0;
    pulseAlpha = lerp(pulseAlpha, 0, 0.02);

    zoom    = lerp(zoom,    targetZoom,   0.04);
    driftX  = lerp(driftX,  targetDriftX, 0.03);
    hueBase = lerpAngle(hueBase, targetHue, 0.03);
    density = lerp(density, targetDensity, 0.07);
    threadWarp = lerp(threadWarp, targetThreadWarp, 0.08);

    phase        += 0.005 + sMid * 0.018 + sBass * 0.006;
    flowPhase    += 0.02  + sMid * 0.05;
    orbitPhase   += 0.004 + sHigh * 0.01;
    mandalaPhase += 0.0018 + sBass * 0.006;

    float ts = uiScale();
    float gs = (gridSpacing * zoom) / density;

    pg.beginDraw();
    pg.hint(DISABLE_DEPTH_TEST);
    pg.background(2, 2, 8);
    pg.colorMode(HSB, 360, 100, 100, 100);

    float centerX = pg.width * 0.5 + driftX;
    float centerY = pg.height * 0.5;

    // ── Pass 0: Mandala backdrop ────────────────────────────────────────
    drawMandalaBackdrop(pg, centerX, centerY, ts);

    // ── Pass 1a: far parallax lattice (background) ──────────────────────
    drawLatticeLayer(pg, centerX, centerY, gs * 1.7, driftX * 0.35, 0.32, 0.6, false, ts);

    // ── Pass 1b: main lattice with threads + figures ────────────────────
    drawLatticeLayer(pg, centerX, centerY, gs, driftX, 1.0, 1.0, true, ts);

    // ── Pass 1c: near parallax lattice (foreground) ─────────────────────
    drawLatticeLayer(pg, centerX, centerY, gs * 0.72, driftX * 1.55, 0.55, 1.35, false, ts);

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
    pg.text("density: " + nf(density, 1, 2) + "  warp: " + nf(threadWarp, 1, 2), 18 * ts, 50 * ts);

    pg.textAlign(RIGHT, TOP);
    pg.fill(255, 255, 255, 60);
    pg.text("[ ] style   -/= density   ,/. warp", pg.width - 14 * ts, 14 * ts);

    pg.endDraw();
  }

  // ── Mandala backdrop ─────────────────────────────────────────────────────
  void drawMandalaBackdrop(PGraphics pg, float centerX, float centerY, float ts) {
    pg.blendMode(ADD);
    pg.noStroke();

    // Inner glow core
    float coreR = min(pg.width, pg.height) * (0.08 + sBass * 0.04);
    pg.fill((hueBase + 20) % 360, 40, 22 + sBass * 18, 20);
    pg.ellipse(centerX, centerY, coreR * 8, coreR * 6);
    pg.fill((hueBase + 70) % 360, 35, 30 + sHigh * 18, 12);
    pg.ellipse(centerX + cos(orbitPhase) * coreR * 0.8,
               centerY + sin(orbitPhase * 0.7) * coreR * 0.5,
               coreR * 3.2, coreR * 2.4);

    // Counter-rotating yantra rings
    pg.noFill();
    for (int ring = 0; ring < 4; ring++) {
      int petals = 6 + ring * 2;
      float rOuter = min(pg.width, pg.height) * (0.18 + ring * 0.11) * (1.0 + sBass * 0.06);
      float rInner = rOuter * 0.55;
      float rot = mandalaPhase * (ring % 2 == 0 ? 1 : -1) * (0.6 + ring * 0.15);
      float hue = (hueBase + ring * 35) % 360;
      float alpha = 8 + sHigh * 8 - ring * 1.2;
      pg.stroke(hue, 45, 55, alpha);
      pg.strokeWeight((0.6 + ring * 0.2) * ts);
      pg.beginShape();
      for (int i = 0; i <= petals * 2; i++) {
        float a = TWO_PI * i / (petals * 2) + rot;
        float r = (i % 2 == 0) ? rOuter : rInner;
        pg.vertex(centerX + cos(a) * r, centerY + sin(a) * r);
      }
      pg.endShape(CLOSE);
    }

    // Radial spokes
    int spokes = 12;
    float spokeLen = min(pg.width, pg.height) * 0.45;
    pg.stroke((hueBase + 180) % 360, 25, 40, 6 + sHigh * 8);
    pg.strokeWeight(0.5 * ts);
    for (int i = 0; i < spokes; i++) {
      float a = TWO_PI * i / spokes + mandalaPhase * 0.3;
      pg.line(centerX, centerY,
              centerX + cos(a) * spokeLen,
              centerY + sin(a) * spokeLen);
    }

    pg.blendMode(BLEND);
  }

  // ── Project a (col,row) world point into a Node ───────────────────────────
  Node projectNode(int col, int row, float offX, float offY, float gs, float breathe,
                   float centerX, float centerY) {
    float wx = offX + col * gs + breathe * sin(phase + row * 0.5);
    float wy = offY + row * gs + breathe * cos(phase + col * 0.5);

    float orbitJitterX = cos(orbitPhase + row * 0.35 + col * 0.18) * gs * 0.03 * sHigh;
    float orbitJitterY = sin(orbitPhase * 1.2 + col * 0.28)        * gs * 0.03 * sHigh;
    wx += orbitJitterX;
    wy += orbitJitterY;

    // Undulating depth wave
    float z = sin(phase * 1.6 + col * 0.42 + row * 0.31) * Z_AMP * (0.6 + sBass * 0.6);
    z += cos(phase * 1.1 - row * 0.27 + col * 0.16) * Z_AMP * 0.4;

    // Radial distance from center in world space (pre-projection)
    float dxC = wx - centerX, dyC = wy - centerY;
    float distC = sqrt(dxC * dxC + dyC * dyC);
    float maxD  = dist(0, 0, width * 0.5, height * 0.5) * 1.2;
    float falloff = 1.0 - constrain(distC / maxD, 0, 1);

    // Beat shockwave: ring at pulseWave radius pushes node toward camera
    float flash = 0;
    if (pulseAlpha > 0.01) {
      float pd = abs(distC - pulseWave);
      float band = gs * 0.6;
      if (pd < band) {
        float k = 1.0 - pd / band;
        z -= k * SHOCK_PUSH * pulseAlpha;
        flash = k * pulseAlpha;
      }
    }

    float scale = FOCAL_LEN / (FOCAL_LEN + z);
    float sx = centerX + dxC * scale;
    float sy = centerY + dyC * scale;

    Node n = new Node();
    n.sx = sx; n.sy = sy; n.scale = scale;
    n.wx = wx; n.wy = wy; n.z = z;
    n.flash = flash; n.falloff = falloff;
    return n;
  }

  // ── Lattice layer (threads + figures) ─────────────────────────────────────
  void drawLatticeLayer(PGraphics pg, float centerX, float centerY, float gs, float driftOffset,
                        float alphaScale, float figureScale, boolean emphasizeCenter, float ts) {
    int cols = (int)(pg.width / gs) + 4;
    int rows = (int)(pg.height / gs) + 4;
    float offX = centerX - (cols / 2) * gs + driftOffset;
    float offY = centerY - (rows / 2) * gs;
    float breathe = sin(phase * 2) * gs * (0.015 + sBass * 0.055);

    // Build projected nodes once per layer.
    Node[][] nodes = new Node[rows][cols];
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        nodes[row][col] = projectNode(col, row, offX, offY, gs, breathe, centerX, centerY);
      }
    }

    // ── Pass A: Hand-linked threads ─────────────────────────────────────
    pg.blendMode(ADD);
    pg.noFill();
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        Node a = nodes[row][col];
        if (a.falloff < 0.05) continue;

        float tAlpha = (8 + sMid * 18) * a.falloff * alphaScale;
        if (emphasizeCenter) {
          float focus = 1.0 - constrain(dist(a.sx, a.sy, centerX, centerY) / CENTER_FOCUS_RADIUS, 0, 1);
          tAlpha *= 1.0 + focus * 0.8;
        }
        float tHue = ringHue(a, centerX, centerY, gs);
        pg.strokeWeight((0.5 + sMid * 0.8) * ts * alphaScale * ((a.scale + 1) * 0.5));

        // Right neighbour
        if (col + 1 < cols) {
          Node b = nodes[row][col + 1];
          pg.stroke(tHue, 40 + sHigh * 20, 30 + sMid * 25, tAlpha);
          drawHandThread(pg, a, b, alphaScale, gs, figureScale);
        }
        // Down neighbour
        if (row + 1 < rows) {
          Node b = nodes[row + 1][col];
          pg.stroke((tHue + 30) % 360, 40 + sHigh * 20, 30 + sMid * 25, tAlpha);
          drawHandThread(pg, a, b, alphaScale, gs, figureScale);
        }
      }
    }

    // ── Pass B: Figures ─────────────────────────────────────────────────
    pg.blendMode(BLEND);
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        Node n = nodes[row][col];
        if (n.sx < -gs || n.sx > pg.width + gs || n.sy < -gs || n.sy > pg.height + gs) continue;
        if (n.falloff < 0.05) continue;

        float figH = gs * 0.55 * n.scale;
        float figAlpha = n.falloff * alphaScale;
        float focusBoost = 1.0;
        if (emphasizeCenter) {
          float focus = 1.0 - constrain(dist(n.sx, n.sy, centerX, centerY) / CENTER_FOCUS_RADIUS, 0, 1);
          focusBoost += focus * 0.9;
          figAlpha *= 1.0 + focus * 0.5;
        }

        float distWorld = dist(n.wx, n.wy, centerX, centerY);
        drawFigure(pg, n, figH * figureScale * focusBoost, figAlpha, distWorld, centerX, centerY, gs, ts);
      }
    }
  }

  // ── Ring-banded hue + depth fog ───────────────────────────────────────────
  float ringHue(Node n, float centerX, float centerY, float gs) {
    float distWorld = dist(n.wx, n.wy, centerX, centerY);
    int   ringIdx   = (int) (distWorld / gs);
    return (hueBase + ringIdx * 28 + flowPhase * 12) % 360;
  }

  // ── Thread endpoints offset toward each other (holding hands) ─────────────
  void drawHandThread(PGraphics pg, Node a, Node b, float alphaScale, float gs, float figureScale) {
    float dx = b.sx - a.sx, dy = b.sy - a.sy;
    float len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;

    // Pull endpoints in by body radius so threads start at arm tips, not figure center.
    float armA = gs * 0.22 * figureScale * a.scale;
    float armB = gs * 0.22 * figureScale * b.scale;
    float ux = dx / len, uy = dy / len;
    float x1 = a.sx + ux * armA;
    float y1 = a.sy + uy * armA;
    float x2 = b.sx - ux * armB;
    float y2 = b.sy - uy * armB;

    float segLen = dist(x1, y1, x2, y2);
    if (segLen < 1) return;
    float nx = -(y2 - y1) / segLen, ny = (x2 - x1) / segLen;

    int segs = 8;
    float prevX = x1, prevY = y1;
    for (int i = 1; i <= segs; i++) {
      float t = (float) i / segs;
      float mx = lerp(x1, x2, t);
      float my = lerp(y1, y2, t);
      float wave = sin(flowPhase * threadWarp + t * PI * 2 + segLen * 0.02) * segLen * 0.03 * threadWarp;
      mx += nx * wave;
      my += ny * wave;
      pg.line(prevX, prevY, mx, my);
      prevX = mx;
      prevY = my;
    }

    // Traveling packet + 2-ghost trail
    float baseT = (flowPhase * (0.16 + sMid * 0.08) + segLen * 0.002) % 1.0;
    for (int g = 0; g < 3; g++) {
      float pulseT = (baseT - g * 0.06 + 1.0) % 1.0;
      float px = lerp(x1, x2, pulseT);
      float py = lerp(y1, y2, pulseT);
      float swerve = sin(flowPhase * 2.2 * threadWarp + segLen * 0.02) * segLen * 0.02 * threadWarp;
      px += nx * swerve * (1 - g * 0.3);
      py += ny * swerve * (1 - g * 0.3);
      float gAlpha = (26 - g * 9) * alphaScale;
      float gSize  = (6 + sMid * 7) * (1 - g * 0.25);
      pg.noStroke();
      pg.fill((hueBase + segLen * 0.08 + flowPhase * 18) % 360, 35 + sHigh * 20, 75 + sMid * 20, gAlpha);
      pg.ellipse(px, py, gSize, gSize);
    }
  }

  // ── Figure dispatch ───────────────────────────────────────────────────────
  void drawFigure(PGraphics pg, Node n, float h, float alphaFrac, float distWorld,
                  float centerX, float centerY, float gs, float ts) {
    float halfH = h * 0.5;
    float ringHue = ringHueFromDist(distWorld, gs);

    // Depth fog: far nodes tint toward base hue, dim brightness
    float fog = constrain((1.0 - n.falloff) * 0.8, 0, 0.7);
    float figHue = lerpAngle(ringHue, (hueBase + 200) % 360, fog);

    // Aura glow (audio + beat flash)
    pg.blendMode(ADD);
    pg.noStroke();
    float auraR = h * (0.48 + sBass * 0.22 + n.flash * 0.4);
    float aAlpha = (4 + sBass * 10 + sHigh * 6 + n.flash * 22) * alphaFrac;
    pg.fill(figHue, 35, 45 + n.flash * 40, aAlpha);
    pg.ellipse(n.sx, n.sy, auraR * 2, auraR * 1.3);

    pg.blendMode(BLEND);

    if (figureStyle == 0) {
      drawFigureOutline(pg, n, halfH, alphaFrac, figHue, centerX, centerY, ts);
    } else if (figureStyle == 1) {
      drawFigureNervous(pg, n, halfH, alphaFrac, figHue, centerX, centerY, distWorld, ts);
    } else {
      drawFigureChakra(pg, n, halfH, alphaFrac, figHue, centerX, centerY, distWorld, ts);
    }

    // Chakra column — skip for round buddy (too dominant on small body).
    // Star/flower buddies carry it as a subtle internal accent.
    if (figureStyle != 0) {
      drawChakraColumn(pg, n, halfH, alphaFrac);
    }
  }

  float ringHueFromDist(float distWorld, float gs) {
    int ringIdx = (int) (distWorld / gs);
    return (hueBase + ringIdx * 28 + flowPhase * 12) % 360;
  }

  // ── Vertical 7-chakra column inside body ─────────────────────────────────
  void drawChakraColumn(PGraphics pg, Node n, float halfH, float alphaFrac) {
    pg.blendMode(ADD);
    pg.noStroke();
    float colTop    = n.sy - halfH * 0.32;
    float colBottom = n.sy + halfH * 0.28;
    int   binsPer   = max(1, analyzer.spectrum.length / 7);
    for (int i = 0; i < 7; i++) {
      float t = i / 6.0;
      float cy = lerp(colBottom, colTop, t);
      float amp = 0.3;
      int b0 = i * binsPer;
      int b1 = min(analyzer.spectrum.length, b0 + binsPer);
      float sum = 0; int cnt = 0;
      for (int b = b0; b < b1; b++) { sum += analyzer.spectrum[b]; cnt++; }
      if (cnt > 0) amp = sum / cnt;
      float r     = halfH * (0.025 + amp * 0.04);
      float alpha = (10 + amp * 22 + n.flash * 18) * alphaFrac;
      pg.fill(chakraHues[i], 75, 95, alpha);
      pg.ellipse(n.sx, cy, r * 2, r * 2);
    }
    pg.blendMode(BLEND);
  }

  // ── Style 0: round buddy ─────────────────────────────────────────────────
  void drawFigureOutline(PGraphics pg, Node n, float halfH, float alphaFrac, float figHue,
                         float centerX, float centerY, float ts) {
    float alpha = (55 + sHigh * 25) * alphaFrac;
    float cx = n.sx, cy = n.sy;
    float bodyR = halfH * 0.35;
    float headR = halfH * 0.22;
    float headY = cy - halfH * 0.25;
    float bodyY = cy + halfH * 0.15;

    pg.stroke(figHue, 50, 75 + n.flash * 25, alpha);
    pg.strokeWeight((0.8 + sHigh * 0.4) * ts * n.scale);
    pg.noFill();
    pg.ellipse(cx, bodyY, bodyR * 2, bodyR * 1.8);
    pg.ellipse(cx, headY, headR * 2, headR * 2);

    // Arms (stubby, waving)
    float armAngle = sin(phase * 2 + dist(n.wx, n.wy, centerX, centerY) * 0.01) * 0.4;
    float armLen = halfH * 0.22;
    float laX = cx - bodyR * 0.85, laY = bodyY - bodyR * 0.3;
    pg.line(laX, laY, laX - cos(armAngle) * armLen, laY - sin(armAngle + 0.8) * armLen);
    float raX = cx + bodyR * 0.85, raY = bodyY - bodyR * 0.3;
    pg.line(raX, raY, raX + cos(-armAngle) * armLen, raY - sin(-armAngle + 0.8) * armLen);

    // Legs
    float legY = bodyY + bodyR * 0.7;
    float legW = halfH * 0.12;
    pg.line(cx - legW, legY, cx - legW, legY + halfH * 0.15);
    pg.line(cx + legW, legY, cx + legW, legY + halfH * 0.15);

    drawGazingFace(pg, cx, headY, headR, figHue, alpha, centerX, centerY, ts, n.scale);
  }

  // ── Style 1: star buddy ──────────────────────────────────────────────────
  void drawFigureNervous(PGraphics pg, Node n, float halfH, float alphaFrac, float figHue,
                         float centerX, float centerY, float distWorld, float ts) {
    float alpha = (45 + sHigh * 30) * alphaFrac;
    float cx = n.sx, cy = n.sy;
    float starR = halfH * 0.4;
    int points = 5;
    float rot = phase + distWorld * 0.003;

    pg.stroke(figHue, 55, 70 + n.flash * 30, alpha);
    pg.strokeWeight((0.7 + sMid * 0.4) * ts * n.scale);
    pg.noFill();
    pg.beginShape();
    for (int i = 0; i <= points * 2; i++) {
      float angle = TWO_PI * i / (points * 2) + rot;
      float r = (i % 2 == 0) ? starR : starR * 0.45;
      pg.vertex(cx + cos(angle) * r, cy + sin(angle) * r);
    }
    pg.endShape(CLOSE);

    drawGazingFace(pg, cx, cy, starR * 0.35, figHue, alpha, centerX, centerY, ts, n.scale);
  }

  // ── Style 2: flower buddy (spinning petals) ──────────────────────────────
  void drawFigureChakra(PGraphics pg, Node n, float halfH, float alphaFrac, float figHue,
                        float centerX, float centerY, float distWorld, float ts) {
    float cx = n.sx, cy = n.sy;
    int petals = 6;
    float petalR  = halfH * 0.3;
    float centerR = halfH * 0.22;
    float rot = phase * 1.1 + distWorld * 0.004 + sMid * 1.2;

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
      float pAlpha = (12 + intensity * 26 + sHigh * 10 + n.flash * 22) * alphaFrac;
      pg.noStroke();
      pg.fill(pHue, 65, 60 + intensity * 30, pAlpha);
      pg.ellipse(px, py, centerR * 1.4, centerR * 1.4);
    }

    pg.blendMode(BLEND);
    float alpha = (50 + sHigh * 25) * alphaFrac;
    pg.noStroke();
    pg.fill(figHue, 30, 18, alpha * 0.5);
    pg.ellipse(cx, cy, centerR * 2, centerR * 2);

    drawGazingFace(pg, cx, cy, centerR, figHue, alpha, centerX, centerY, ts, n.scale);
  }

  // ── Face with pupils tracking scene center ───────────────────────────────
  void drawGazingFace(PGraphics pg, float cx, float cy, float r, float figHue, float alpha,
                      float centerX, float centerY, float ts, float nodeScale) {
    float eyeSpacing = r * 0.35;
    float eyeY = cy - r * 0.15;
    float eyeR = r * 0.18;

    // Direction from face to scene center (hive-mind gaze).
    float gdx = centerX - cx, gdy = centerY - cy;
    float gLen = max(1, sqrt(gdx * gdx + gdy * gdy));
    float gx = gdx / gLen, gy = gdy / gLen;
    float pupilShift = eyeR * 0.45;

    // Eye whites
    pg.noStroke();
    pg.fill(0, 0, 92, alpha * 0.8);
    pg.ellipse(cx - eyeSpacing, eyeY, eyeR * 2.2, eyeR * 2.2);
    pg.ellipse(cx + eyeSpacing, eyeY, eyeR * 2.2, eyeR * 2.2);

    // Pupils, shifted toward center
    pg.fill(0, 0, 5, alpha);
    pg.ellipse(cx - eyeSpacing + gx * pupilShift, eyeY + gy * pupilShift, eyeR * 1.2, eyeR * 1.2);
    pg.ellipse(cx + eyeSpacing + gx * pupilShift, eyeY + gy * pupilShift, eyeR * 1.2, eyeR * 1.2);

    // Smile
    pg.noFill();
    pg.stroke(figHue, 45, 70, alpha * 0.8);
    pg.strokeWeight(0.5 * ts * nodeScale);
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
      "Undulating 3D grid of figures",
      "holding hands across a web.",
      "",
      "Three figure styles:",
      "  0: round buddy",
      "  1: star buddy",
      "  2: flower buddy",
      "",
      "Beats fire a shockwave ring",
      "that punches nodes forward.",
      "Pupils gaze to center.",
      "Chakra column pulses to",
      "the audio spectrum.",
      "",
      "Audio mapping:",
      "  Bass \u2192 lattice breathing",
      "  Mid  \u2192 thread turbulence",
      "  High \u2192 orbital shimmer",
      "  Beat \u2192 shockwave ring",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LB / RB",       "Figure style"),
      new ControllerLayout("LStick \u2195", "Zoom"),
      new ControllerLayout("LStick \u2194", "Drift"),
      new ControllerLayout("RStick \u2194", "Hue shift"),
      new ControllerLayout("RStick \u2195", "Thread turbulence"),
      new ControllerLayout("LT / RT",       "Lattice density"),
      new ControllerLayout("A",             "Reset"),
    };
  }
}
