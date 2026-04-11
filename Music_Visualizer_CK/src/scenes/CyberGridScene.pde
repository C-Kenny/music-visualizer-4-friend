class CyberGridScene implements IScene {
  int cols, rows;
  int scale = 40;
  int w = 2400;
  int h = 1600;

  float flying = 0;
  float[][] terrain;

  CyberGridScene() {
    cols = w / scale;
    rows = h / scale;
    terrain = new float[cols][rows];
  }

  void drawScene(PGraphics pg) {
    flying -= map(analyzer.bass, 0, 1, 0.02, 0.2); // scroll speed based on bass
    float yoff = flying;
    for (int y = 0; y < rows; y++) {
      float xoff = 0;
      for (int x = 0; x < cols; x++) {
        terrain[x][y] = map(noise(xoff, yoff), 0, 1, -80, 80) * (1 + analyzer.bass * 2.5);
        xoff += 0.15;
      }
      yoff += 0.15;
    }

    pg.background(5, 5, 20); // Deep dark blue background
    
    // Draw Retrowave Sun in the distance
    pg.pushMatrix();
    pg.translate(pg.width / 2, pg.height * 0.35, -500);
    drawSun(pg);
    pg.popMatrix();

    // Draw Grid
    pg.pushMatrix();
    pg.translate(pg.width / 2, pg.height / 2 + 100);
    pg.rotateX(PI / 2.5);
    pg.translate(-w / 2, -h / 2);

    pg.strokeWeight(1.5);
    for (int y = 0; y < rows - 1; y++) {
      // Color based on row position (gradient pink→cyan) — set once per row,
      // not per vertex, to avoid GPU state flush on every vertex.
      float t = (float)y / (rows - 1);
      pg.stroke(255 * t, 255 * (1 - t), 255, 200);
      pg.beginShape(TRIANGLE_STRIP);
      for (int x = 0; x < cols; x++) {
        pg.vertex(x * scale, y * scale, terrain[x][y]);
        pg.vertex(x * scale, (y + 1) * scale, terrain[x][y + 1]);
      }
      pg.endShape();
    }
    pg.popMatrix();

    // ── top-left HUD ──────────────────────────────────────────────────────
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 6 * uiScale();
      pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 280 * uiScale(), mg * 2 + lh * 2);
      pg.fill(255, 220, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Cyber Grid  (bass-driven scroll)", 12, 8 + mg);
      pg.fill(200, 200, 200);
      pg.text("terrain height \u221d bass energy", 12, 8 + mg + lh);
    pg.popStyle();
  }

  void drawSun(PGraphics pg) {
    pg.noStroke();
    int layers = 25;
    for (int i = 0; i < layers; i++) {
        float r = 500 - i * 8;
        // Gradient from orange to magenta
        float inter = map(i, 0, layers, 0, 1);
        int c = pg.lerpColor(color(255, 200, 0), color(255, 0, 100), inter);
        pg.fill(c, 150 - i * 5);
        pg.ellipse(0, 0, r, r);
    }
    // Sun scanlines
    pg.stroke(5, 5, 20);
    pg.strokeWeight(4);
    for (int i = -250; i < 250; i += 20) {
        if (i > 0) {
             pg.line(-300, i, 300, i);
        }
    }
  }

  void onEnter() {
  }

  void onExit() {}

  void applyController(Controller c) {
    // scale could be adjusted
  }

  void handleKey(char k) {
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Cyber Grid Scene ===",
      "// Logic: Scrolling Noise Terrain",
      "z = noise(x, y + time) * bass",
      "render(TRIANGLE_STRIP)",
      "sun = layered_gradient_ellipses"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
