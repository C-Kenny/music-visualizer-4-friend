// Neural Weave — state 14
// See documentation/neural_weave.md for behaviour, controls, and main-sketch integration.
//
// Biology + instrumentation: a woven mesh with metabolic haze (LT), tech injection (RT),
// optional synapse bridges, vesicle halos, and a lab-style overlay.
//
// Controller: sticks as before; LT/RT; A ripple; B growth stage; X lab HUD; Y palette;
//            L3 reset view; R3 reshuffle bridges + pulse.

class NeuralWeaveScene implements IScene {

  int   cols        = 12;
  int   rows        = 9;
  float edgeGain    = 1.15;
  float rot         = 0;
  float rotSpeed    = 0.00035;
  float panX        = 0;
  float panY        = 0;
  float zoom        = 1.0;
  float ripple      = 0;
  float globalHue   = 210;
  int   palette     = 0;

  int   growthMode  = 0;
  boolean labMode   = false;
  boolean vesicles  = true;

  float metabolism  = 0;
  float techInject  = 0;
  float organicPhase = 0;

  static final int MAX_BRIDGES = 40;
  int[][] bridges = new int[MAX_BRIDGES][4];
  int bridgeCount = 0;
  int bridgeTick    = 0;

  float[] smoothAmp;
  boolean initialised = false;

  float[] blobAng;
  float[] blobRad;

  NeuralWeaveScene() {
    blobAng = new float[7];
    blobRad = new float[7];
    for (int i = 0; i < 7; i++) {
      blobAng[i] = TWO_PI * i / 7.0 + 0.3;
      blobRad[i] = 0.12 + i * 0.04;
    }
  }

  float nodeJX(int i, int j) {
    float m = (0.12 + metabolism * 0.88) * (1.0 + growthMode * 0.07);
    return sin(i * 1.31 + j * 0.77 + organicPhase * 1.2) * (5.5 + techInject * 5.0) * m
         + cos(frameCount * 0.019 + i * 0.4) * 2.2 * m;
  }

  float nodeJY(int i, int j) {
    float m = (0.12 + metabolism * 0.88) * (1.0 + growthMode * 0.07);
    return cos(j * 1.21 + i * 0.63 + organicPhase) * (5.5 + techInject * 5.0) * m
         + sin(frameCount * 0.017 + j * 0.35) * 2.2 * m;
  }

  void regenBridges() {
    bridgeCount = 0;
    if (growthMode == 0) return;
    int target = (growthMode == 1) ? 20 : 36;
    bridgeCount = min(MAX_BRIDGES, target);
    randomSeed(bridgeTick / 90 + cols * 1000 + rows * 17);
    for (int k = 0; k < bridgeCount; k++) {
      int i0 = (int)random(cols + 1);
      int j0 = (int)random(rows + 1);
      int di = (int)random(-3, 4);
      int dj = (int)random(-3, 4);
      if (di == 0 && dj == 0) dj = 1;
      int i1 = constrain(i0 + di, 0, cols);
      int j1 = constrain(j0 + dj, 0, rows);
      if (i0 == i1 && j0 == j1) {
        j1 = constrain(j0 + 1, 0, rows);
      }
      bridges[k][0] = i0;
      bridges[k][1] = j0;
      bridges[k][2] = i1;
      bridges[k][3] = j1;
    }
    randomSeed(millis());
  }

  void drawDiffusion(PGraphics pg, float cx, float cy, float bass) {
    float env = max(metabolism, ripple * 0.6);
    if (env < 0.03) return;

    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();
    float pulse = bass * 0.45 + ripple * 0.35;
    float maxR = min(pg.width, pg.height) * 0.52;

    for (int k = 0; k < blobAng.length; k++) {
      float ang = blobAng[k] + organicPhase * 0.35;
      float spread = blobRad[k] * maxR * (0.82 + pulse * 0.22 + metabolism * 0.28);
      float bx = cx + cos(ang) * spread * 0.38;
      float by = cy + sin(ang) * spread * 0.38;
      float h = (globalHue + k * 26 + (labMode ? 15 : 0)) % 360;
      float al = (6 + metabolism * 62 + pulse * 35) * (labMode ? 0.75 : 1.0);
      pg.fill(h, 150 + (labMode ? 40 : 0), 255, constrain(al, 0, 115));
      float wob = 1.0 + sin(pg.parent.frameCount * 0.018 + k * 1.1) * 0.07;
      pg.ellipse(bx, by, spread * wob * 1.05, spread * 0.95 * wob);
    }
  }

  void drawBridge(PGraphics pg, float x0, float y0, float x1, float y1,
                  float amp, int band, int N, float bass) {
    float mx = (x0 + x1) * 0.5;
    float my = (y0 + y1) * 0.5;
    float dx = x1 - x0;
    float dy = y1 - y0;
    float len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    float nx = -dy / len;
    float ny = dx / len;
    float bow = (14 + techInject * 22) * (1.0 + sin(pg.parent.frameCount * 0.035 + band) * 0.35);
    float cx1 = mx + nx * bow;
    float cy1 = my + ny * bow;

    float t = (float)band / max(1, N - 1);
    float hue = hueFor(t, amp);
    float alpha = (12 + amp * 160 * edgeGain + bass * 25) * (0.55 + techInject * 0.45);
    pg.stroke(hue, 170, 255, constrain(alpha, 0, 200));
    pg.strokeWeight(0.5 + amp * 2.8 * edgeGain + techInject * 1.2);

    int steps = max(10, (int)(len / 10));
    pg.noFill();
    pg.beginShape(); // using generic beginShape (consistent with LINE_STRIP style)
    for (int s = 0; s <= steps; s++) {
      float u = s / (float)steps;
      float omt = 1 - u;
      float bx = omt * omt * x0 + 2 * omt * u * cx1 + u * u * x1;
      float by = omt * omt * y0 + 2 * omt * u * cy1 + u * u * y1;
      pg.vertex(bx, by);
    }
    pg.endShape();
  }

  void drawBridges(PGraphics pg, float cellW, float cellH, int N, float bass) {
    if (growthMode == 0 || bridgeCount == 0) return;
    for (int k = 0; k < bridgeCount; k++) {
      int i0 = bridges[k][0], j0 = bridges[k][1];
      int i1 = bridges[k][2], j1 = bridges[k][3];
      float x0 = i0 * cellW + nodeJX(i0, j0);
      float y0 = j0 * cellH + nodeJY(i0, j0);
      float x1 = i1 * cellW + nodeJX(i1, j1);
      float y1 = j1 * cellH + nodeJY(i1, j1);
      int b = ((i0 + j0 + i1 + j1) * 3 + k) % N;
      drawBridge(pg, x0, y0, x1, y1, smoothAmp[b], b, N, bass);
    }
  }

  void drawLabOverlay(PGraphics pg, float tech) {
    pg.pushStyle();
    pg.stroke(130, 210, 255, (28 + tech * 55) * (labMode ? 1.0 : tech));
    pg.strokeWeight(1);
    for (int y = 0; y < pg.height; y += 4) {
      pg.line(0, y, pg.width, y);
    }
    pg.stroke(0, 220, 255, (35 + tech * 70) * (labMode ? 1.0 : tech));
    float cx = pg.width * 0.5, cy = pg.height * 0.5;
    pg.line(cx - 22, cy, cx + 22, cy);
    pg.line(cx, cy - 22, cx, cy + 22);
    pg.popStyle();
  }

  void drawScene(PGraphics pg) {
    if (!initialised) {
      smoothAmp = new float[analyzer.spectrum.length];
      initialised = true;
    }

    int N = analyzer.spectrum.length;
    for (int i = 0; i < N; i++) {
      smoothAmp[i] = lerp(smoothAmp[i], analyzer.spectrum[i], 0.24);
    }

    float bass = analyzer.bass;
    float mid  = analyzer.mid;
    float high = analyzer.high;

    organicPhase += 0.0016 + mid * 0.001 + bass * 0.0004;

    if (analyzer.isBeat) {
      ripple = 1.0;
      globalHue = (globalHue + random(28, 72)) % 360;
    }
    ripple *= 0.91;
    rot += rotSpeed + mid * 0.00012 + high * 0.00004;

    bridgeTick++;
    if (growthMode > 0 && bridgeTick % 90 == 0) {
      regenBridges();
    }

    pg.background(3, 5, 12);

    float cx = pg.width  * 0.5 + panX;
    float cy = pg.height * 0.5 + panY;
    float span = min(pg.width, pg.height) * 0.42 * zoom;
    float cellW = (span * 2) / cols;
    float cellH = (span * 2) / rows;

    pg.blendMode(ADD);
    pg.colorMode(HSB, 360, 255, 255, 255);
    drawDiffusion(pg, cx, cy, bass);

    pg.pushMatrix();
    pg.translate(cx, cy);
    pg.rotate(rot);
    pg.translate(-cols * cellW * 0.5, -rows * cellH * 0.5);

    for (int j = 0; j <= rows; j++) {
      for (int i = 0; i < cols; i++) {
        int b = (i + j * 5) % N;
        float x0 = i * cellW + nodeJX(i, j);
        float y0 = j * cellH + nodeJY(i, j);
        float x1 = (i + 1) * cellW + nodeJX(i + 1, j);
        float y1 = j * cellH + nodeJY(i + 1, j);
        edgeSeg(pg, x0, y0, x1, y1, smoothAmp[b], b, N, bass);
      }
    }
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i <= cols; i++) {
        int b = (i * 3 + j * 7) % N;
        float x0 = i * cellW + nodeJX(i, j);
        float y0 = j * cellH + nodeJY(i, j);
        float x1 = i * cellW + nodeJX(i, j + 1);
        float y1 = (j + 1) * cellH + nodeJY(i, j + 1);
        edgeSeg(pg, x0, y0, x1, y1, smoothAmp[b], b, N, bass);
      }
    }
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < cols; i++) {
        if (((i + j) & 1) == 0) {
          int b = (i * 11 + j) % N;
          float x0 = i * cellW + nodeJX(i, j);
          float y0 = j * cellH + nodeJY(i, j);
          float x1 = (i + 1) * cellW + nodeJX(i + 1, j + 1);
          float y1 = (j + 1) * cellH + nodeJY(i + 1, j + 1);
          edgeSeg(pg, x0, y0, x1, y1, smoothAmp[b] * 0.85, b, N, bass);
        }
      }
    }

    drawBridges(pg, cellW, cellH, N, bass);

    float mx = cols * cellW * 0.5;
    float my = rows * cellH * 0.5;
    pg.noStroke();
    for (int j = 0; j <= rows; j++) {
      for (int i = 0; i <= cols; i++) {
        float x = i * cellW + nodeJX(i, j);
        float y = j * cellH + nodeJY(i, j);
        float d = dist(x, y, mx, my);
        float rip = ripple * (0.4 + 0.6 * sin(d * 0.08 + pg.parent.frameCount * 0.12));
        int b = (i * 13 + j * 17) % N;
        float a = smoothAmp[b];
        float hue = hueFor((float)b / max(1, N - 1), a);
        float br = 120 + a * 130 + bass * 40 + rip * 70;
        float al = 35 + a * 160 + ripple * 90;

        if (vesicles) {
          float ves = (growthMode >= 2 ? 1.35 : 1.0) * (1.0 + metabolism * 0.4);
          pg.fill(hue, 120, 255, constrain(12 + bass * 40 + metabolism * 35, 0, 90));
          pg.ellipse(x, y, (14 + a * 22) * ves, (14 + a * 22) * ves);
        }

        pg.fill(hue, 200, constrain(br, 0, 255), constrain(al, 0, 255));
        float sz = 2.2 + a * 9 + bass * 5 + rip * 6 + techInject * 2;
        pg.ellipse(x, y, sz, sz);
      }
    }

    pg.popMatrix();

    pg.blendMode(BLEND);
    pg.colorMode(RGB, 255);

    float tech = max(labMode ? 1.0 : 0, techInject);
    if (tech > 0.08) {
      drawLabOverlay(pg, tech);
    }

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width * 0.5, pg.height - 5);

    String[] palNames = {"Nebula", "Solar", "Glacier", "Mono"};
    String[] growthNames = {"Mesh", "Synapse web", "Tissue bloom"};
    pg.pushStyle();
    float ts = 11 * uiScale(), lh = ts * 1.28, mg = 5 * uiScale();
    pg.fill(0, 165); pg.noStroke(); pg.rectMode(CORNER);
    pg.rect(8, 8, 360 * uiScale(), mg + lh * 7);
    pg.fill(180, 230, 255); pg.textSize(ts); pg.textAlign(LEFT, TOP);
    pg.text("Neural Weave  (" + cols + "\u00d7" + rows + ")", 12, 8 + mg);
    pg.fill(200, 215, 235);
    pg.text("Growth: " + growthNames[growthMode] + "  (B / G)",                    12, 8 + mg + lh);
    pg.text("Palette: " + palNames[palette] + "  (K | pad Y)   Vesicles: "
         + (vesicles ? "on" : "off") + "  (V)",                                  12, 8 + mg + lh * 2);
    pg.text("LT metabolism " + nf(metabolism, 1, 2) + "   RT tech " + nf(techInject, 1, 2), 12, 8 + mg + lh * 3);
    pg.text("Lab: " + (labMode ? "on" : "off") + "  (E | pad X)   Edge: "
         + nf(edgeGain, 1, 2) + "  (- / =)",                                      12, 8 + mg + lh * 4);
    pg.text("L3 reset view   R3 reshuffle bridges",                                  12, 8 + mg + lh * 5);
    pg.text("Ripple " + nf(ripple, 1, 2) + "   [ ] grid",                            12, 8 + mg + lh * 6);
    pg.popStyle();
  }

  void edgeSeg(PGraphics pg, float x1, float y1, float x2, float y2,
               float amp, int band, int N, float bass) {
    float t = (float)band / max(1, N - 1);
    float hue = hueFor(t, amp);
    float alpha = (22 + amp * 220 * edgeGain) * (0.75 + bass * 0.35);
    float sw = 0.6 + amp * 4.0 * edgeGain + bass * 0.8;
    pg.stroke(hue, 175, 255, constrain(alpha, 0, 255));
    pg.strokeWeight(sw);

    int segs = max(4, (int)(dist(x1, y1, x2, y2) / 14));
    float ph = pg.parent.frameCount * 0.04 + band * 0.3;
    float org = metabolism * (1.2 + growthMode * 0.15);
    pg.noFill();
    pg.beginShape();
    for (int s = 0; s <= segs; s++) {
      float u = s / (float)segs;
      float x = lerp(x1, x2, u);
      float y = lerp(y1, y2, u);
      float nx = -(y2 - y1);
      float ny = (x2 - x1);
      float L = sqrt(nx * nx + ny * ny);
      if (L > 0.001) {
        nx /= L;
        ny /= L;
      }
      float wobble = sin(u * TWO_PI + ph) * amp * 2.2 * edgeGain
                   + sin(u * TWO_PI * 3 + ph * 1.3) * amp * org * 1.1;
      pg.vertex(x + nx * wobble, y + ny * wobble);
    }
    pg.endShape();
  }

  float hueFor(float t, float amp) {
    float h;
    switch (palette) {
      case 1:
        h = map(t, 0, 1, 8, 48);
        break;
      case 2:
        h = map(t, 0, 1, 160, 230);
        break;
      case 3:
        h = 195;
        break;
      default:
        h = (globalHue + t * 260 + amp * 40) % 360;
        break;
    }
    if (labMode) {
      h = (h * 0.65 + 200 * 0.35) % 360;
    }
    return h;
  }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    float rx = map(c.rx, 0, width,  -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);

    metabolism = lerp(metabolism, c.lt, 0.14);
    techInject = lerp(techInject, c.rt, 0.14);

    panX = lerp(panX, lx * min(width, height) * 0.22, 0.08);
    panY = lerp(panY, ly * min(width, height) * 0.18, 0.08);

    if (abs(ry) < 0.14) {
      rotSpeed = lerp(rotSpeed, 0, 0.06);
    } else {
      rotSpeed = lerp(rotSpeed, map(ry, -1, 1, -0.0028, 0.0028), 0.12);
    }
    zoom = constrain(lerp(zoom, map(rx, -1, 1, 0.55, 1.75), 0.1), 0.45, 2.0);

    if (c.a_just_pressed) ripple = 1.0;
    if (c.y_just_pressed) palette = (palette + 1) % 4;
    if (c.b_just_pressed) cycleGrowthMode();
    if (c.x_just_pressed) labMode = !labMode;

    if (c.lstickclick_just_pressed) {
      panX = 0;
      panY = 0;
      zoom = 1.0;
      rotSpeed = 0.00035;
    }
    if (c.rstickclick_just_pressed) {
      regenBridges();
      ripple = max(ripple, 0.45);
    }
  }

  void adjustCols(int delta) {
    cols = constrain(cols + delta, 6, 22);
    rows = constrain(rows + delta, 5, 18);
    regenBridges();
  }

  void adjustEdgeGain(float d) {
    edgeGain = constrain(edgeGain + d, 0.35, 2.4);
  }

  void cyclePalette() {
    palette = (palette + 1) % 4;
  }

  void cycleGrowthMode() {
    growthMode = (growthMode + 1) % 3;
    regenBridges();
  }

  void toggleLabMode() {
    labMode = !labMode;
  }

  void toggleVesicles() {
    vesicles = !vesicles;
  }

  void triggerRipple() {
    ripple = 1.0;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Neural Weave (bio + tech) ===",
      "",
      "// LT / RT   metabolic haze vs tech overlay (smooth)",
      "// Growth    Mesh \u2192 Synapse bridges \u2192 Tissue bloom",
      "// X / E     lab crosshair + scanlines",
      "// V         vesicle halos under nodes",
      "",
      "L Stick     pan",
      "R Stick     zoom / spin",
      "A / Space   ripple",
      "B / G       cycle growth stage",
      "Y / K       palette",
      "L3          reset pan, zoom, spin",
      "R3          reshuffle bridges + pulse",
      "",
      "[ ]  grid   - =  edge   `  overlay",
    };
  }

  void onEnter() {
    background(3, 5, 12);
  }

  void onExit() {}

  void handleKey(char k) {
    if (k == '[') adjustCols(-1);
    else if (k == ']') adjustCols(1);
    else if (k == '-' || k == '_') adjustEdgeGain(-0.1);
    else if (k == '=' || k == '+') adjustEdgeGain(0.1);
    else if (k == 'v' || k == 'V') toggleVesicles();
    else if (k == 'e' || k == 'E') toggleLabMode();
    else if (k == 'g' || k == 'G') cycleGrowthMode();
    else if (k == 'k' || k == 'K') cyclePalette();
    else if (k == ' ') triggerRipple();
  }
}
