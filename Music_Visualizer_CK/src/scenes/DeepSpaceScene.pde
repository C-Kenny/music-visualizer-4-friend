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

  // Live knobs - driven by controller sticks, keyboard, web sliders, or the
  // idle autopilot via the ParamRouter spine.
  SceneParam pWarp   = new SceneParam("warp",   "Warp Factor",    0.2, 3,   1);
  SceneParam pStars  = new SceneParam("stars",  "Star Density",   100, 800, 800);
  SceneParam pNebula = new SceneParam("nebula", "Nebula Glow",    0,   2.5, 1);
  SceneParam pPulse  = new SceneParam("pulse",  "Core Pulse",     0,   2.5, 1);
  SceneParam[] params = { pWarp, pStars, pNebula, pPulse };

  DeepSpaceScene() {
    for (int i = 0; i < stars.length; i++) {
      stars[i] = new Star();
    }
  }

  // 8D audio: how far the warp's vanishing point may slide toward the sound,
  // as a fraction of screen size. Only kicks in while an orbit is detected.
  final float VANISH_REACH_X = 0.18;
  final float VANISH_REACH_Y = 0.07;

  void drawScene(PGraphics pg) {
    pg.background(0);
    // When the mix circles the head, stars rush from where the sound sits:
    // pan slides the vanishing point left/right, and passing behind the
    // head lifts it (cos of the head angle is +1 in front, -1 behind).
    float vanishX = spatial.pan * pg.width * VANISH_REACH_X * spatial.orbitStrength;
    float vanishY = -cos(spatial.azimuth) * pg.height * VANISH_REACH_Y * spatial.orbitStrength;
    pg.translate(pg.width / 2 + vanishX, pg.height / 2 + vanishY);

    // Audio reactive speed
    speed = map(analyzer.master, 0, 1, 2, 50) * pWarp.value;
    if (analyzer.bass > 0.8) speed *= 2;

    // Draw Nebula clouds (noise-based)
    drawNebula(pg);

    int visibleStars = (int) pStars.value;
    for (int i = 0; i < stars.length; i++) {
      stars[i].update(speed); // keep all moving so density changes pop in seamlessly
      if (i < visibleStars) stars[i].show(pg);
    }

    // Draw central "core" pulse
    pg.noStroke();
    float pulse = analyzer.bass * 100 * pPulse.value;
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
          float alpha = map(n, 0.6, 1.0, 0, 40) * analyzer.mid * 2 * pNebula.value;
          pg.fill(150 * n, 50, 255 * n, alpha);
          pg.rect(x, y, res, res);
        }
      }
    }
    pg.popStyle();

    // ── top-left HUD ──────────────────────────────────────────────────────
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 6 * uiScale();
      boolean show8d = spatial.orbitStrength > 0.05;
      pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 280 * uiScale(), mg * 2 + lh * (show8d ? 3 : 2));
      pg.fill(255, 220, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Deep Space  (warp speed: " + nf(speed, 1, 1) + ")", 12, 8 + mg);
      pg.fill(200, 200, 200);
      pg.text("speed \u221d audio energy  \u00d72 on bass hit", 12, 8 + mg + lh);
      if (show8d) {
        pg.fill(140, 220, 255);
        pg.text(spatial.debugLine(), 12, 8 + mg + lh * 2);
      }
    pg.popStyle();
  }

  void onEnter() {
  }

  void onExit() {}

  void applyController(Controller c) {
    // Generic spine mapping: LX=warp, LY=stars, RX=nebula, RY=pulse, A=reset.
    routeParamsToSticks(c, params);
  }

  void handleKey(char k) {
    handleParamKey(k);   // < > select knob, - + nudge
  }

  SceneParam[] getParams() { return params; }

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

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
