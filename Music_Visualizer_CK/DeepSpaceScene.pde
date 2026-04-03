class DeepSpaceScene implements IScene {
  class Star {
    float x, y, z;
    float pz;

    Star() {
      x = random(-width, width);
      y = random(-height, height);
      z = random(width);
      pz = z;
    }

    void update(float speed) {
      z = z - speed;
      if (z < 1) {
        z = width;
        x = random(-width, width);
        y = random(-height, height);
        pz = z;
      }
    }

    void show(PGraphics pg) {
      pg.fill(255);
      pg.noStroke();

      float sx = map(x / z, 0, 1, 0, pg.width/2);
      float sy = map(y / z, 0, 1, 0, pg.height/2);

      float r = map(z, 0, pg.width, 8, 0);
      pg.ellipse(sx, sy, r, r);

      float px = map(x / pz, 0, 1, 0, pg.width/2);
      float py = map(y / pz, 0, 1, 0, pg.height/2);

      pz = z;

      pg.stroke(255, 150);
      pg.strokeWeight(map(z, 0, pg.width, 2, 0));
      pg.line(px, py, sx, sy);
    }
  }

  Star[] stars = new Star[800];
  float speed;
  float nebulaPhase = 0;

  DeepSpaceScene() {
    for (int i = 0; i < stars.length; i++) {
      stars[i] = new Star();
    }
  }

  void drawScene(PGraphics pg) {
    pg.background(0);
    pg.translate(pg.width / 2, pg.height / 2);

    // Audio reactive speed
    speed = map(analyzer.master, 0, 1, 2, 50);
    if (analyzer.bass > 0.8) speed *= 2;

    // Draw Nebula clouds (noise-based)
    drawNebula(pg);

    for (int i = 0; i < stars.length; i++) {
      stars[i].update(speed);
      stars[i].show(pg);
    }
    
    // Draw central "core" pulse
    pg.noStroke();
    float pulse = analyzer.bass * 100;
    pg.fill(100, 150, 255, 50);
    pg.ellipse(0, 0, pulse, pulse);
    pg.fill(255, 255, 255, 100);
    pg.ellipse(0, 0, pulse * 0.5, pulse * 0.5);
  }

  void drawNebula(PGraphics pg) {
    pg.pushStyle();
    pg.noStroke();
    nebulaPhase += 0.005;
    float res = 70;
    for (float x = -pg.width/2; x < pg.width/2; x += res) {
      for (float y = -pg.height/2; y < pg.height/2; y += res) {
        float n = noise(x * 0.003, y * 0.003, nebulaPhase);
        if (n > 0.6) {
          float alpha = map(n, 0.6, 1.0, 0, 40) * analyzer.mid * 2;
          pg.fill(150 * n, 50, 255 * n, alpha);
          pg.rect(x, y, res, res);
        }
      }
    }
    pg.popStyle();

    // ── top-left HUD ──────────────────────────────────────────────────────
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 6 * uiScale();
      pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 280 * uiScale(), mg * 2 + lh * 2);
      pg.fill(255, 220, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Deep Space  (warp speed: " + nf(speed, 1, 1) + ")", 12, 8 + mg);
      pg.fill(200, 200, 200);
      pg.text("speed \u221d audio energy  \u00d72 on bass hit", 12, 8 + mg + lh);
    pg.popStyle();
  }

  void onEnter() {
  }

  void onExit() {}

  void applyController(Controller c) {
    // R-stick ↕ could control star count or density if we wanted
  }

  void handleKey(char k) {
    if (k == 'c' || k == 'C') {
        // change nebula color?
    }
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Deep Space Scene ===",
      "// Logic: 3D Starfield Warp",
      "sx = map(x / z, 0, 1, 0, width/2)",
      "sy = map(y / z, 0, 1, 0, height/2)",
      "speed = map(audio_energy, 0, 1, 2, 50)",
      "nebula = noise(x, y, time) * energy"
    };
  }
}
