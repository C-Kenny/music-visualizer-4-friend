/**
 * VisualizerExplainerScene (scene 45)
 *
 * Interactive walkthrough of how the visualizer works.
 * Four pages, each demonstrating a core concept with live audio.
 *
 * Navigation:
 *   , / D-pad left    — prev page
 *   . / D-pad right   — next page
 *   Space             — next page
 */
class VisualizerExplainerScene implements IScene {

  int page       = 0;
  int PAGE_COUNT = 5;

  // Energy history for beat page (circular buffer)
  float[] energyHistory = new float[300];
  int     histHead      = 0;
  int     beatCount     = 0;

  // Coord system demo
  float demoAngle = 0;
  float demoScale = 1.0;

  // 3D page state
  float rot3DX = 0, rot3DY = 0, rot3DZ = 0;
  float beatScale3D = 1.0;

  // Audio smoothing
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;

  void onEnter()  { page = 0; beatCount = 0; }
  void onExit()   {}

  void applyController(Controller c) {
    if (c.dpadRightJustPressed) page = (page + 1) % PAGE_COUNT;
    if (c.dpadLeftJustPressed)  page = (page - 1 + PAGE_COUNT) % PAGE_COUNT;
  }

  void handleKey(char k) {
    if (k == ' ' || k == '.') page = (page + 1) % PAGE_COUNT;
    if (k == ',')              page = (page - 1 + PAGE_COUNT) % PAGE_COUNT;
  }

  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.10);
    sMid  = lerp(sMid,  analyzer.mid,  0.10);
    sHigh = lerp(sHigh, analyzer.high, 0.10);
    if (audio.beat.isOnset()) { sBeat = 1.0; beatCount++; }
    sBeat = lerp(sBeat, 0, 0.08);

    // Store energy history
    energyHistory[histHead] = analyzer.master;
    histHead = (histHead + 1) % energyHistory.length;

    pg.background(6, 8, 14);

    float ts  = uiScale();
    float W   = pg.width;
    float H   = pg.height;
    float pad = 32 * ts;

    drawChrome(pg, ts, W, H, pad);

    switch (page) {
      case 0: drawPageSignal(pg, ts, W, H, pad);     break;
      case 1: drawPageBeat(pg, ts, W, H, pad);        break;
      case 2: drawPageBands(pg, ts, W, H, pad);       break;
      case 3: drawPageCoords(pg, ts, W, H, pad);      break;
      case 4: drawPage3D(pg, ts, W, H, pad);          break;
    }
  }

  // ── Chrome: title bar + page indicator ───────────────────────────────────

  void drawChrome(PGraphics pg, float ts, float W, float H, float pad) {
    // Title bar
    pg.noStroke();
    pg.fill(255, 255, 255, 12);
    pg.rect(0, 0, W, 48 * ts);

    String[] titles = {
      "01 / 05  —  Raw Audio Signal & FFT Spectrum",
      "02 / 05  —  Beat Detection",
      "03 / 05  —  Frequency Bands in Action",
      "04 / 05  —  Coordinate System",
      "05 / 05  —  3D Scenes & Transformations",
    };

    pg.textFont(monoFont);
    pg.textSize(13 * ts);
    pg.textAlign(LEFT, CENTER);
    pg.fill(255, 215, 80);
    pg.text(titles[page], pad, 24 * ts);

    // Nav hint
    pg.textAlign(RIGHT, CENTER);
    pg.fill(255, 255, 255, 80);
    pg.textSize(10 * ts);
    pg.text(", / .  or  D-pad  to navigate", W - pad, 24 * ts);

    // Page dots
    float dotY = H - 18 * ts;
    float dotSpacing = 18 * ts;
    float dotsX = W * 0.5 - (PAGE_COUNT - 1) * dotSpacing * 0.5;
    for (int i = 0; i < PAGE_COUNT; i++) {
      pg.noStroke();
      pg.fill(i == page ? color(255, 215, 80) : color(255, 255, 255, 60));
      pg.ellipse(dotsX + i * dotSpacing, dotY, 8 * ts, 8 * ts);
    }
  }

  // ── Page 0: Raw waveform + FFT spectrum ──────────────────────────────────

  void drawPageSignal(PGraphics pg, float ts, float W, float H, float pad) {
    float top    = 60 * ts;
    float bottom = H - 30 * ts;
    float mid    = (top + bottom) * 0.5;
    float halfH  = (bottom - top) * 0.5;

    // Section dividers
    sectionLabel(pg, ts, pad, top + 8 * ts, "WAVEFORM  (raw left channel)");
    sectionLabel(pg, ts, pad, mid + 8 * ts, "FFT SPECTRUM  (frequency content)");

    // Divider line
    pg.stroke(255, 255, 255, 30);
    pg.strokeWeight(ts);
    pg.line(pad, mid, W - pad, mid);

    // ── Waveform ─────────────────────────────────────────────────────────
    int total = audio.player != null ? audio.player.left.size() : 0;
    if (total > 2) {
      int useN = min(512, total);
      float waveW = W - pad * 2;
      float waveY = (top + mid) * 0.5;
      float amp   = halfH * 0.38;

      pg.noFill();
      pg.stroke(80, 200, 255, 180);
      pg.strokeWeight(1.5 * ts);
      pg.beginShape();
      for (int i = 0; i < useN; i++) {
        float x = pad + waveW * i / (useN - 1);
        float s = audio.player.left.get(i);
        pg.vertex(x, waveY - s * amp);
      }
      pg.endShape();

      // Zero line
      pg.stroke(255, 255, 255, 25);
      pg.strokeWeight(ts);
      pg.line(pad, waveY, W - pad, waveY);
    }

    // ── FFT bars ─────────────────────────────────────────────────────────
    int   fftBands = audio.fft.avgSize();
    float barW     = (W - pad * 2) / fftBands;
    float fftBaseY = bottom - 4 * ts;
    float fftMaxH  = halfH * 0.82;

    // Bass/mid/high region backgrounds
    float bassEnd = W * 0.25,  midEnd = W * 0.65;
    pg.noStroke();
    pg.fill(255, 80,  80,  12); pg.rect(pad,     mid + 28*ts, bassEnd - pad,          bottom - mid - 28*ts);
    pg.fill(80,  255, 80,  12); pg.rect(bassEnd, mid + 28*ts, midEnd  - bassEnd,       bottom - mid - 28*ts);
    pg.fill(80,  120, 255, 12); pg.rect(midEnd,  mid + 28*ts, W - pad - midEnd,        bottom - mid - 28*ts);

    for (int i = 0; i < fftBands; i++) {
      float x   = pad + i * barW;
      float val = constrain(audio.fft.getAvg(i) / 40.0, 0, 1);
      float bH  = val * fftMaxH;
      float frac = (float)i / fftBands;

      // Color by band
      if      (frac < 0.25) pg.fill(255, 80 + val*120,  60,  180);
      else if (frac < 0.65) pg.fill(60,  200 + val*55,  80,  180);
      else                  pg.fill(80,  100 + val*80, 255,  180);

      pg.noStroke();
      pg.rect(x, fftBaseY - bH, max(barW - 1, 1), bH);
    }

    // Band labels
    pg.textFont(monoFont);
    pg.textSize(9 * ts);
    pg.textAlign(CENTER, TOP);
    pg.fill(255, 80, 80,   200); pg.text("BASS",  (pad + bassEnd) * 0.5,           mid + 30 * ts);
    pg.fill(80, 255, 80,   200); pg.text("MID",   (bassEnd + midEnd) * 0.5,         mid + 30 * ts);
    pg.fill(80, 140, 255,  200); pg.text("HIGH",  (midEnd + W - pad) * 0.5,         mid + 30 * ts);

    // Live values
    pg.textAlign(RIGHT, BOTTOM);
    pg.textSize(9 * ts);
    pg.fill(255, 80,  80, 200);  pg.text("bass  " + nf(sBass, 1, 2), W - pad, bottom - 4 * ts);
    pg.fill(80, 255,  80, 200);  pg.text("mid   " + nf(sMid,  1, 2), W - pad, bottom - 14 * ts);
    pg.fill(80, 140, 255, 200);  pg.text("high  " + nf(sHigh, 1, 2), W - pad, bottom - 24 * ts);
  }

  // ── Page 1: Beat detection ────────────────────────────────────────────────

  void drawPageBeat(PGraphics pg, float ts, float W, float H, float pad) {
    float top    = 60 * ts;
    float bottom = H - 30 * ts;
    float cx     = W * 0.38;
    float cy     = (top + bottom) * 0.5;

    // ── Big beat circle ───────────────────────────────────────────────────
    float baseR = min(W, H) * 0.18;
    float beatR = baseR * (1.0 + sBeat * 0.7 + sBass * 0.25);

    // Outer glow rings
    for (int i = 3; i >= 0; i--) {
      float a   = sBeat * 60 / (i + 1);
      float r   = beatR + i * 22 * ts;
      pg.noFill();
      pg.stroke(255, 215, 80, a);
      pg.strokeWeight((4 - i) * ts);
      pg.ellipse(cx, cy, r * 2, r * 2);
    }

    // Main circle
    pg.noFill();
    pg.stroke(255, 215, 80, 180 + sBeat * 75);
    pg.strokeWeight(3 * ts);
    pg.ellipse(cx, cy, beatR * 2, beatR * 2);

    // Fill with energy
    pg.fill(255, 215, 80, 15 + sBeat * 80 + sBass * 30);
    pg.noStroke();
    pg.ellipse(cx, cy, beatR * 2, beatR * 2);

    // BEAT label
    pg.textFont(monoFont);
    pg.textAlign(CENTER, CENTER);
    float beatAlpha = 100 + sBeat * 155;
    pg.fill(255, 215, 80, beatAlpha);
    pg.textSize(24 * ts * (1.0 + sBeat * 0.3));
    pg.text(sBeat > 0.3 ? "BEAT!" : "beat", cx, cy);

    pg.textSize(10 * ts);
    pg.fill(255, 255, 255, 120);
    pg.text("beats detected: " + beatCount, cx, cy + baseR + 20 * ts);

    // ── Energy history graph ──────────────────────────────────────────────
    float gx    = W * 0.56;
    float gy    = top + 28 * ts;
    float gw    = W - gx - pad;
    float gh    = (bottom - top) * 0.55;

    sectionLabel(pg, ts, gx, gy - 18 * ts, "ENERGY OVER TIME");

    pg.noFill();
    pg.stroke(255, 255, 255, 25);
    pg.strokeWeight(ts);
    pg.rect(gx, gy, gw, gh);

    // Energy line
    pg.beginShape();
    pg.noFill();
    pg.stroke(80, 200, 120, 200);
    pg.strokeWeight(1.5 * ts);
    for (int i = 0; i < energyHistory.length; i++) {
      int idx = (histHead + i) % energyHistory.length;
      float x  = gx + gw * i / (energyHistory.length - 1);
      float y  = gy + gh - energyHistory[idx] * gh * 0.9;
      pg.vertex(x, y);
    }
    pg.endShape();

    // ── Explanation text ──────────────────────────────────────────────────
    float tx  = W * 0.56;
    float ty  = gy + gh + 28 * ts;
    float tw  = gw;

    String[] lines = {
      "Beat detection measures how quickly",
      "audio energy spikes relative to recent",
      "average. When energy > threshold:",
      "",
      "  audio.beat.isOnset() → true",
      "",
      "Fires once per onset, not per frame.",
      "Use isOnset() for single-shot events",
      "(spawn burst, toggle, step counter).",
      "Use held state + lerp() for sustained.",
    };
    drawExplainText(pg, ts, tx, ty, tw, lines);
  }

  // ── Page 2: Frequency bands in action ────────────────────────────────────

  void drawPageBands(PGraphics pg, float ts, float W, float H, float pad) {
    float top    = 60 * ts;
    float bottom = H - 30 * ts;
    float panelW = (W - pad * 2) / 3.0;
    float cy     = (top + bottom) * 0.5;
    float baseR  = min(panelW, bottom - top) * 0.28;

    String[] bandNames  = {"BASS",          "MID",           "HIGH"};
    String[] freqRange  = {"20 – 250 Hz",   "250 Hz – 4 kHz","4 kHz – 20 kHz"};
    String[] examples   = {"kick, sub bass","vocals, guitar", "hi-hats, air"};
    String[] drivesWhat = {"→  size",       "→  hue",        "→  sparkle"};
    float[]  bandVals   = {sBass,           sMid,            sHigh};
    color[]  bandColors = {
      color(255, 80,  60),
      color(80,  220, 80),
      color(80,  140, 255),
    };

    for (int b = 0; b < 3; b++) {
      float cx = pad + panelW * b + panelW * 0.5;
      float v  = bandVals[b];

      // Panel background
      pg.noStroke();
      pg.fill(red(bandColors[b]), green(bandColors[b]), blue(bandColors[b]), 10 + v * 20);
      pg.rect(pad + panelW * b + 4 * ts, top, panelW - 8 * ts, bottom - top);

      if (b == 0) {
        // Bass: circle size
        float r = baseR * (0.35 + v * 1.0);
        for (int i = 3; i >= 0; i--) {
          pg.noFill();
          pg.stroke(255, 80, 60, v * 40 / (i + 1));
          pg.strokeWeight((3 - i) * ts);
          pg.ellipse(cx, cy, (r + i * 15 * ts) * 2, (r + i * 15 * ts) * 2);
        }
        pg.fill(255, 80, 60, 60 + v * 120);
        pg.noStroke();
        pg.ellipse(cx, cy, r * 2, r * 2);

      } else if (b == 1) {
        // Mid: hue shift
        float hue = map(sMid, 0, 1, 180, 340);
        pg.colorMode(HSB, 360, 100, 100, 100);
        pg.fill(hue, 70, 80, 80);
        pg.noStroke();
        pg.ellipse(cx, cy, baseR * 1.5, baseR * 1.5);
        pg.noFill();
        for (int i = 0; i < 6; i++) {
          float a = TWO_PI * i / 6 + frameCount * 0.01;
          float r = baseR * (0.85 + sMid * 0.3);
          pg.stroke((hue + i * 20) % 360, 60, 90, 60 + sMid * 30);
          pg.strokeWeight(1.5 * ts);
          pg.line(cx, cy, cx + cos(a) * r, cy + sin(a) * r);
        }
        pg.colorMode(RGB, 255);

      } else {
        // High: sparkle dots
        pg.noStroke();
        pg.fill(80, 140, 255, 80 + sHigh * 120);
        pg.ellipse(cx, cy, baseR * 1.2, baseR * 1.2);
        randomSeed(42);
        for (int i = 0; i < 60; i++) {
          float a   = random(TWO_PI);
          float r   = random(baseR * 0.2, baseR * 1.4);
          float px2 = cx + cos(a) * r;
          float py2 = cy + sin(a) * r;
          float bright = random(sHigh);
          if (bright > 0.05) {
            pg.fill(180, 200, 255, bright * 220);
            float d = random(2, 6) * ts;
            pg.ellipse(px2, py2, d, d);
          }
        }
      }

      // Labels
      pg.textFont(monoFont);
      pg.textAlign(CENTER, TOP);
      pg.fill(red(bandColors[b]), green(bandColors[b]), blue(bandColors[b]), 220);
      pg.textSize(14 * ts);
      pg.text(bandNames[b], cx, top + 16 * ts);

      pg.fill(255, 255, 255, 140);
      pg.textSize(9 * ts);
      pg.text(freqRange[b],  cx, top + 34 * ts);
      pg.text(examples[b],   cx, top + 46 * ts);

      pg.textAlign(CENTER, BOTTOM);
      pg.fill(red(bandColors[b]), green(bandColors[b]), blue(bandColors[b]), 200);
      pg.textSize(11 * ts);
      pg.text("analyzer." + bandNames[b].toLowerCase(), cx, bottom - 38 * ts);
      pg.fill(255, 255, 255, 160);
      pg.textSize(10 * ts);
      pg.text(drivesWhat[b], cx, bottom - 24 * ts);

      // Live bar
      float barX  = cx - baseR * 0.6;
      float barY  = bottom - 14 * ts;
      float barW2 = baseR * 1.2;
      float barH  = 6 * ts;
      pg.noStroke();
      pg.fill(255, 255, 255, 20);
      pg.rect(barX, barY, barW2, barH, 3 * ts);
      pg.fill(red(bandColors[b]), green(bandColors[b]), blue(bandColors[b]), 200);
      pg.rect(barX, barY, barW2 * v, barH, 3 * ts);
    }

    // Dividers between panels
    pg.stroke(255, 255, 255, 20);
    pg.strokeWeight(ts);
    pg.line(pad + panelW,     top, pad + panelW,     bottom);
    pg.line(pad + panelW * 2, top, pad + panelW * 2, bottom);
  }

  // ── Page 3: Coordinate system ─────────────────────────────────────────────

  void drawPageCoords(PGraphics pg, float ts, float W, float H, float pad) {
    float top    = 60 * ts;
    float bottom = H - 30 * ts;
    float halfW  = (W - pad * 2) * 0.5;
    float leftCX = pad + halfW * 0.5;
    float rightCX= pad + halfW + halfW * 0.5;
    float panelH = bottom - top;
    float cy     = (top + bottom) * 0.5;

    // Divider
    pg.stroke(255, 255, 255, 20);
    pg.strokeWeight(ts);
    pg.line(pad + halfW, top, pad + halfW, bottom);

    sectionLabel(pg, ts, pad,           top + 8 * ts,  "DEFAULT  (0,0 = top-left)");
    sectionLabel(pg, ts, pad + halfW + 4*ts, top + 8 * ts, "AFTER  translate(width/2, height/2)");

    // ── Left panel: default coordinate system ──────────────────────────
    float ax = pad;
    float ay = top + 30 * ts;
    float aw = halfW - 4 * ts;
    float ah = panelH - 40 * ts;

    drawCoordAxes(pg, ts, ax, ay, aw, ah, false);

    // Dot at top-left
    pg.noStroke();
    pg.fill(255, 215, 80, 220);
    pg.ellipse(ax + 12*ts, ay + 12*ts, 10*ts, 10*ts);
    pg.textFont(monoFont);
    pg.textSize(9 * ts);
    pg.fill(255, 215, 80, 200);
    pg.textAlign(LEFT, TOP);
    pg.text("(0, 0)", ax + 16*ts, ay + 6*ts);

    // Animated rectangle in default coords
    pg.noFill();
    pg.stroke(80, 200, 255, 160);
    pg.strokeWeight(1.5 * ts);
    float rx = ax + aw * 0.55, ry = ay + ah * 0.35, rw = aw * 0.25, rh = ah * 0.25;
    pg.rect(rx, ry, rw, rh);
    pg.fill(80, 200, 255, 80);
    pg.textSize(8 * ts);
    pg.textAlign(CENTER, BOTTOM);
    pg.text("rect(" + int(rx-ax) + ", " + int(ry-ay) + ", " + int(rw) + ", " + int(rh) + ")", rx + rw*0.5, ry - 2*ts);

    // ── Right panel: translated coordinate system ───────────────────────
    demoAngle += 0.012 + sMid * 0.03;
    float bx = pad + halfW + 4 * ts;
    float by = top + 30 * ts;
    float bw = halfW - 8 * ts;
    float bh = panelH - 40 * ts;

    drawCoordAxes(pg, ts, bx, by, bw, bh, true);  // shows (0,0) at center

    // Rotating square around new origin
    float ocx = bx + bw * 0.5;
    float ocy = by + bh * 0.5;
    float sqS = min(bw, bh) * 0.22;
    float sqR = min(bw, bh) * 0.28;

    // Orbit circle
    pg.noFill();
    pg.stroke(255, 255, 255, 15);
    pg.ellipse(ocx, ocy, sqR * 2, sqR * 2);

    // Orbiting dot (driven by bass for size)
    float dotX = ocx + cos(demoAngle) * sqR;
    float dotY = ocy + sin(demoAngle) * sqR;
    pg.fill(255, 80, 60, 200);
    pg.noStroke();
    float dotR = 10 * ts * (1 + sBass * 0.8);
    pg.ellipse(dotX, dotY, dotR * 2, dotR * 2);

    // Rotating square
    pg.pushMatrix();
    pg.translate(ocx, ocy);
    pg.rotate(demoAngle);
    pg.noFill();
    pg.stroke(255, 215, 80, 160);
    pg.strokeWeight(1.5 * ts);
    pg.rect(-sqS, -sqS, sqS * 2, sqS * 2);
    pg.popMatrix();

    // Code annotation
    pg.textFont(monoFont);
    pg.textSize(8.5 * ts);
    pg.textAlign(LEFT, BOTTOM);
    pg.fill(255, 215, 80, 180);
    float codeY = by + bh - 2 * ts;
    pg.text("pg.translate(width/2, height/2);",  bx + 4*ts, codeY - 34 * ts);
    pg.text("pg.rotate(angle);",                 bx + 4*ts, codeY - 22 * ts);
    pg.fill(80, 200, 255, 180);
    pg.text("// orbit radius * bass",             bx + 4*ts, codeY - 10 * ts);
    pg.fill(255, 80, 60, 180);
    pg.text("pg.ellipse(cos(a)*r, sin(a)*r, ...);", bx + 4*ts, codeY);

    // Origin dot
    pg.noStroke();
    pg.fill(255, 255, 255, 180);
    pg.ellipse(ocx, ocy, 8*ts, 8*ts);
    pg.fill(255, 255, 255, 140);
    pg.textSize(9 * ts);
    pg.textAlign(LEFT, BOTTOM);
    pg.text("(0, 0)", ocx + 6*ts, ocy - 3*ts);
  }

  // ── Page 4: 3D Scenes & Transformations ──────────────────────────────────

  void drawPage3D(PGraphics pg, float ts, float W, float H, float pad) {
    float top    = 60 * ts;
    float bottom = H - 30 * ts;
    float panelW = (W - pad * 2) / 3.0;
    float cy     = (top + bottom) * 0.5;
    float boxUnit = min(panelW, bottom - top) * 0.22;

    // Axis rotations accumulate each frame
    rot3DX += 0.018 + sMid  * 0.04;
    rot3DY += 0.022 + sBass * 0.06;
    rot3DZ += 0.011 + sHigh * 0.03;
    beatScale3D = lerp(beatScale3D, 1.0, 0.08);
    if (audio.beat.isOnset()) beatScale3D = 1.5;

    // Panel dividers
    pg.stroke(255, 255, 255, 20);
    pg.strokeWeight(ts);
    pg.line(pad + panelW,     top, pad + panelW,     bottom);
    pg.line(pad + panelW * 2, top, pad + panelW * 2, bottom);

    // ── Single-axis panels ────────────────────────────────────────────────
    String[] axisNames  = { "rotateX()",       "rotateY()",        "rotateZ()" };
    color[]  axisColors = { color(255, 80, 80), color(80, 220, 80), color(80, 140, 255) };
    float[]  rotAngles  = { rot3DX, rot3DY, rot3DZ };
    String[] rotDesc    = { "axis: X  →  horizontal", "axis: Y  ↓  vertical", "axis: Z  •  depth (into screen)" };

    for (int b = 0; b < 3; b++) {
      float cx  = pad + panelW * b + panelW * 0.5;
      float pcx = cx;
      float pcy = cy - 10 * ts;
      float s   = boxUnit * (b == 0 ? 1.0 + sBass * 0.4
                           : b == 1 ? 1.0 + sMid  * 0.4
                           :           1.0 + sHigh * 0.4);

      // Panel tint
      int cr = (int)red(axisColors[b]), cg = (int)green(axisColors[b]), cb2 = (int)blue(axisColors[b]);
      pg.noStroke(); pg.fill(cr, cg, cb2, 8);
      pg.rect(pad + panelW * b + 4*ts, top, panelW - 8*ts, bottom - top);

      sectionLabel(pg, ts, pad + panelW * b + 8*ts, top + 10*ts, axisNames[b]);

      // 3D box drawn on pg directly
      pg.pushMatrix();
      pg.translate(pcx, pcy, 0);
      pg.lights();
      if (b == 0) pg.rotateX(rotAngles[0]);
      else if (b == 1) pg.rotateY(rotAngles[1]);
      else             pg.rotateZ(rotAngles[2]);

      pg.noStroke();
      pg.fill(cr, cg, cb2, 180);
      pg.box(s * 1.4, s * 0.9, s * 0.9);
      pg.stroke(cr, cg, cb2, 100);
      pg.strokeWeight(ts);
      pg.noFill();
      pg.box(s * 1.4 + 2, s * 0.9 + 2, s * 0.9 + 2);
      pg.popMatrix();

      // Axis arrow — shows the actual axis direction, not motion
      float arrowLen = boxUnit * 0.75;
      pg.stroke(cr, cg, cb2, 200);
      pg.strokeWeight(2 * ts);
      if (b == 0) {
        // X-axis: horizontal arrow pointing right
        pg.line(pcx - arrowLen, pcy, pcx + arrowLen, pcy);
        pg.fill(cr, cg, cb2, 200); pg.noStroke();
        pg.triangle(pcx + arrowLen + 6*ts, pcy, pcx + arrowLen, pcy - 4*ts, pcx + arrowLen, pcy + 4*ts);
        // label
        pg.textFont(monoFont); pg.textSize(8*ts); pg.textAlign(RIGHT, BOTTOM);
        pg.fill(cr, cg, cb2, 160);
        pg.text("X", pcx + arrowLen + 14*ts, pcy - 1*ts);
      } else if (b == 1) {
        // Y-axis: vertical arrow pointing down (Processing Y goes down)
        pg.line(pcx, pcy - arrowLen, pcx, pcy + arrowLen);
        pg.fill(cr, cg, cb2, 200); pg.noStroke();
        pg.triangle(pcx, pcy + arrowLen + 6*ts, pcx - 4*ts, pcy + arrowLen, pcx + 4*ts, pcy + arrowLen);
        pg.textFont(monoFont); pg.textSize(8*ts); pg.textAlign(CENTER, TOP);
        pg.fill(cr, cg, cb2, 160);
        pg.text("Y (↓ in Processing)", pcx, pcy + arrowLen + 10*ts);
      } else {
        // Z-axis: dot = into screen, circle = around Z
        pg.noFill();
        pg.stroke(cr, cg, cb2, 140);
        pg.ellipse(pcx, pcy, arrowLen * 1.4, arrowLen * 1.4);
        // center dot = axis going into screen
        pg.fill(cr, cg, cb2, 220); pg.noStroke();
        pg.ellipse(pcx, pcy, 10*ts, 10*ts);
        pg.textFont(monoFont); pg.textSize(8*ts); pg.textAlign(CENTER, TOP);
        pg.fill(cr, cg, cb2, 160);
        pg.text("Z  (• = into screen)", pcx, pcy + arrowLen * 0.75);
      }

      // Labels
      pg.textFont(monoFont);
      pg.textAlign(CENTER, TOP);
      pg.fill(cr, cg, cb2, 220);
      pg.textSize(11 * ts);
      pg.text(axisNames[b], pcx, top + 28 * ts);

      pg.fill(255, 255, 255, 130);
      pg.textSize(8.5 * ts);
      pg.text(rotDesc[b], pcx, top + 44 * ts);

      // Live rotation value
      pg.textAlign(CENTER, BOTTOM);
      pg.fill(cr, cg, cb2, 160);
      pg.textSize(8 * ts);
      pg.text("angle = " + nf(rotAngles[b] % TWO_PI, 1, 2), pcx, bottom - 30 * ts);

      // Code snippet
      pg.fill(255, 215, 80, 160);
      pg.textSize(8 * ts);
      pg.text("pg." + axisNames[b] + "angle);", pcx, bottom - 16 * ts);
    }

    // ── All-axes combined: small inset bottom-right ───────────────────────
    float insetW = panelW * 0.55;
    float insetH = (bottom - top) * 0.28;
    float insetX = W - pad - insetW;
    float insetY = bottom - insetH - 8 * ts;

    pg.noStroke(); pg.fill(255, 255, 255, 6);
    pg.rect(insetX, insetY, insetW, insetH);
    sectionLabel(pg, ts, insetX + 4*ts, insetY + 4*ts, "ALL AXES  (combined)");

    float iCX = insetX + insetW * 0.38;
    float iCY = insetY + insetH * 0.58;
    float iS  = min(insetW, insetH) * 0.28 * beatScale3D;

    pg.pushMatrix();
    pg.translate(iCX, iCY, 0);
    pg.lights();
    pg.rotateX(rot3DX);
    pg.rotateY(rot3DY);
    pg.rotateZ(rot3DZ);
    pg.noStroke();
    pg.fill(200, 160, 255, 180);
    pg.box(iS);
    pg.popMatrix();

    // Code next to inset
    float codX = iCX + insetW * 0.32;
    float codY = insetY + 20 * ts;
    pg.textFont(monoFont);
    pg.textSize(8 * ts);
    pg.textAlign(LEFT, TOP);
    pg.fill(255, 215, 80, 180);
    pg.text("pg.translate(cx, cy, 0);",  codX, codY);
    pg.fill(255, 80, 80,  180); pg.text("pg.rotateX(rx);",           codX, codY + 12 * ts);
    pg.fill(80, 220, 80,  180); pg.text("pg.rotateY(ry);",           codX, codY + 22 * ts);
    pg.fill(80, 140, 255, 180); pg.text("pg.rotateZ(rz);",           codX, codY + 32 * ts);
    pg.fill(200, 160, 255, 180); pg.text("pg.box(size);",            codX, codY + 44 * ts);
    pg.fill(255, 255, 255, 100); pg.text("pg.popMatrix();",          codX, codY + 54 * ts);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void drawCoordAxes(PGraphics pg, float ts, float ax, float ay, float aw, float ah, boolean centered) {
    float ox = centered ? ax + aw * 0.5 : ax;
    float oy = centered ? ay + ah * 0.5 : ay;

    pg.stroke(255, 255, 255, 35);
    pg.strokeWeight(ts);
    // Grid
    int gSteps = 5;
    for (int i = 0; i <= gSteps; i++) {
      float gx = ax + aw * i / gSteps;
      float gy = ay + ah * i / gSteps;
      pg.line(gx, ay, gx, ay + ah);
      pg.line(ax, gy, ax + aw, gy);
    }

    // X axis
    pg.stroke(255, 80, 80, 200);
    pg.strokeWeight(2 * ts);
    pg.line(ox, oy, ox + aw * (centered ? 0.45 : 0.9), oy);
    // Y axis
    pg.stroke(80, 220, 80, 200);
    pg.line(ox, oy, ox, oy + ah * (centered ? 0.45 : 0.9));

    // Labels
    pg.textFont(monoFont);
    pg.textSize(9 * ts);
    pg.fill(255, 80, 80, 200);
    pg.textAlign(LEFT, CENTER);
    pg.text("x →", ox + aw * (centered ? 0.46 : 0.91), oy);
    pg.fill(80, 220, 80, 200);
    pg.textAlign(CENTER, TOP);
    pg.text("y ↓", ox, oy + ah * (centered ? 0.46 : 0.91));
  }

  void sectionLabel(PGraphics pg, float ts, float x, float y, String label) {
    pg.textFont(monoFont);
    pg.textSize(9 * ts);
    pg.textAlign(LEFT, TOP);
    pg.fill(255, 215, 80, 160);
    pg.text(label, x, y);
  }

  void drawExplainText(PGraphics pg, float ts, float x, float y, float maxW, String[] lines) {
    pg.textFont(monoFont);
    pg.textSize(10 * ts);
    pg.textAlign(LEFT, TOP);
    float lh = 15 * ts;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith("  ")) {
        pg.fill(255, 215, 80, 200);
      } else if (lines[i].isEmpty()) {
        // skip
      } else {
        pg.fill(255, 255, 255, 160);
      }
      pg.text(lines[i], x, y + i * lh);
    }
  }

  String[] getCodeLines() {
    return new String[]{
      "=== Visualizer Explainer ===",
      "",
      "Page 1: Audio signal + FFT",
      "Page 2: Beat detection",
      "Page 3: Frequency bands",
      "Page 4: Coordinate system",
      "Page 5: 3D transforms",
      "",
      ". / D-pad right = next page",
      ", / D-pad left  = prev page",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("D-pad ← →", "Cycle pages"),
    };
  }
}
