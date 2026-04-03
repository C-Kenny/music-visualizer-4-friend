class HeartGridScene implements IScene {
  BezierHeart bezier_heart_0;
  BezierHeart bezier_heart_1;
  BezierHeart bezier_heart_2;
  BezierHeart bezier_heart_3;

  float heartBeatDecay = 0;    
  float heartHue       = 0;    
  float heartTargetHue = 0;    
  float heartZoom      = 1.0;  
  float heartFocusNX   = 0.0;  
  float heartFocusNY   = 0.0;  

  HeartGridScene() {
    bezier_heart_0 = new BezierHeart(0.0, 0.25, 300);
    bezier_heart_1 = new BezierHeart(0.0, 0.25, 300);
    bezier_heart_2 = new BezierHeart(0.0, 0.25, 300);
    bezier_heart_3 = new BezierHeart(0.0, 0.25, 300);
  }

  void applyController(Controller c) {
    float lx_norm = map(c.lx, 0, width, -1, 1);
    config.HEART_COLS = constrain(round(map(lx_norm, -1, 1, 3, 15)), 3, 15);

    float rx_norm = map(c.rx, 0, width, -1, 1);
    float ry_norm = map(c.ry, 0, height, -1, 1);
    float stickMag = sqrt(rx_norm * rx_norm + ry_norm * ry_norm);
    if (stickMag > 0.15) {
      heartZoom = min(heartZoom + 0.02, 3.5);
      heartFocusNX = lerp(heartFocusNX, rx_norm, 0.04);
      heartFocusNY = lerp(heartFocusNY, ry_norm, 0.04);
    } else {
      heartZoom = max(heartZoom - 0.015, 1.0);
      heartFocusNX *= 0.95;
      heartFocusNY *= 0.95;
    }
  }

  void drawScene(PGraphics pg) {
    pg.background(0);

    final float HEART_NAT_W = 831.0;
    final float HEART_NAT_H = 562.0;
    float baseScale = pg.width / (config.HEART_COLS * HEART_NAT_W);
    float cellH     = HEART_NAT_H;
    int   rows      = ceil(pg.height / (cellH * baseScale)) + 1;

    float breath = sin(pg.parent.frameCount * 0.03) * 12;

    if (analyzer.isBeat) {
      heartBeatDecay = 35.0;
      heartTargetHue = (heartTargetHue + random(60, 120)) % 360;
    }
    heartBeatDecay *= 0.95;

    float hueDiff = heartTargetHue - heartHue;
    if (hueDiff >  180) hueDiff -= 360;
    if (hueDiff < -180) hueDiff += 360;
    heartHue = (heartHue + hueDiff * 0.012 + 360) % 360;

    pg.colorMode(HSB, 360, 255, 255);
    color c0 = color(heartHue, 210, 220);
    color c1 = color((heartHue + 180) % 360, 210, 220);
    pg.colorMode(RGB, 255);
    bezier_heart_0.bezier_heart_fill_color_r = red(c0);
    bezier_heart_0.bezier_heart_fill_color_g = green(c0);
    bezier_heart_0.bezier_heart_fill_color_b = blue(c0);
    bezier_heart_1.bezier_heart_fill_color_r = red(c1);
    bezier_heart_1.bezier_heart_fill_color_g = green(c1);
    bezier_heart_1.bezier_heart_fill_color_b = blue(c1);

    config.HEART_PULSE = breath + heartBeatDecay;

    float focusX = pg.width / 2.0 + heartFocusNX * pg.width  * 0.25;
    float focusY = pg.height / 2.0 + heartFocusNY * pg.height * 0.25;
    pg.pushMatrix();
      pg.translate(focusX, focusY);
      pg.scale(heartZoom);
      pg.translate(-focusX, -focusY);
      for (int row = 0; row < rows; row++) {
        for (int col = 0; col < config.HEART_COLS; col++) {
          float xOff = col * HEART_NAT_W + 443.0;
          float yOff = row * HEART_NAT_H;
          BezierHeart heart = ((row + col) % 2 == 0) ? bezier_heart_0 : bezier_heart_1;
          heart.drawBezierHeart(pg, xOff, yOff, baseScale);
        }
      }
    pg.popMatrix();

    if (config.DRAW_WAVEFORM) {
      drawOscilloscope(pg, focusX, focusY, heartZoom);
    }

    if (heartZoom > 1.05) {
      drawHeartFocus(pg, focusX, focusY);
    }

    // ── top-left HUD ──────────────────────────────────────────────────────
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 6 * uiScale();
      pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 310 * uiScale(), mg * 2 + lh * 2);
      pg.fill(255, 220, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Heart Grid  (cols: " + config.HEART_COLS + "  zoom: " + nf(heartZoom, 1, 2) + "x)", 12, 8 + mg);
      pg.fill(200, 200, 200);
      pg.text("L \u2194 columns   R stick zoom & pan", 12, 8 + mg + lh);
    pg.popStyle();
  }

  void drawOscilloscope(PGraphics pg, float focusX, float focusY, float zoom) {
    pg.pushStyle();
    pg.stroke(255);
    pg.strokeWeight(1.0);
    pg.noFill();
    int bSize = audio.player.bufferSize();
    pg.pushMatrix();
      pg.translate(focusX, focusY);
      pg.scale(zoom);
      pg.translate(-focusX, -focusY);
      pg.translate(0, pg.height / 2.0);
      pg.beginShape();
      for (int i = 0; i < bSize; i+=8) {
        float x = map(i, 0, bSize, 0, pg.width);
        float y = audio.player.left.get(i) * 150;
        pg.vertex(x, y);
      }
      pg.endShape();
    pg.popMatrix();
    pg.popStyle();
  }

  void drawHeartFocus(PGraphics pg, float focusX, float focusY) {
    pg.pushStyle();
    pg.noFill();
    pg.stroke(255, 100);
    pg.strokeWeight(2);
    pg.ellipse(focusX, focusY, 20, 20);
    pg.line(focusX - 30, focusY, focusX - 10, focusY);
    pg.line(focusX + 10, focusY, focusX + 30, focusY);
    pg.line(focusX, focusY - 30, focusX, focusY - 10);
    pg.line(focusX, focusY + 10, focusX, focusY + 30);
    pg.popStyle();
  }

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void handleKey(char k) {
    if (k == '[') {
      config.HEART_COLS = max(1, config.HEART_COLS - 1);
    } else if (k == ']') {
      config.HEART_COLS = min(10, config.HEART_COLS + 1);
    }
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Heart Grid Scene ===",
      "// Logic: Bezier-curve hearts in a dynamic grid",
      "cols = lerp(cols, target_cols, 0.1)",
      "beat = onset ? flash : decay"
    };
  }
}
