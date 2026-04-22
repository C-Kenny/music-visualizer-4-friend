/**
 * VoidBloomScene — Scene 26
 *
 * A cosmic bloom that pulses to music.
 * Audio-driven petal arms radiate from a glowing core, surrounded by
 * orbiting rings, drifting particles and a twinkling star field.
 *
 * Audio mapping:
 *   bass              → core glow radius, petal scale, ring breath
 *   mid               → rotation speed modifier
 *   high              → star twinkle intensity
 *   isBeat            → hue shift, ripple ring, particle burst
 *   spectrum[0..22]   → individual petal amplitudes
 *
 * Keyboard:
 *   [ / ]   petal count −/+
 *   C       cycle palette (Nebula / Solar / Ocean / Crimson)
 *   Z / z   zoom out / in
 *   S       toggle star field
 *   R       reset
 *   Space   particle burst
 *
 * Controller:
 *   L Stick     pan
 *   R Stick Y   zoom
 *   A           particle burst
 *   B           cycle palette
 *   Y           cycle petal count (4 → 6 → … → 16 → 4)
 *   X           toggle stars
 */
class VoidBloomScene implements IScene {

  // ── Parameters ──────────────────────────────────────────────────────────────
  int   numPetals = 8;
  int   palette   = 0;   // 0=Nebula  1=Solar  2=Ocean  3=Crimson
  float zoom      = 1.0;
  float panX      = 0;
  float panY      = 0;

  // ── Animation State ──────────────────────────────────────────────────────────
  float globalRotation = 0;
  float hueShift       = 0;   // advances on every beat

  // ── Smoothed Audio ───────────────────────────────────────────────────────────
  float bassSmooth = 0;
  float midSmooth  = 0;
  float highSmooth = 0;
  float beatFlash  = 0;

  // ── Beat Ripple ──────────────────────────────────────────────────────────────
  float rippleRadius = 0;
  float rippleAlpha  = 0;

  // ── Star Field ───────────────────────────────────────────────────────────────
  final int NUM_STARS = 140;
  float[] sx    = new float[NUM_STARS];
  float[] sy    = new float[NUM_STARS];
  float[] sBri  = new float[NUM_STARS];
  float[] sSize = new float[NUM_STARS];
  boolean showStars = true;

  // ── Particles ─────────────────────────────────────────────────────────────────
  final int MAX_PARTICLES = 300;
  float[] px  = new float[MAX_PARTICLES];
  float[] py  = new float[MAX_PARTICLES];
  float[] pvx = new float[MAX_PARTICLES];
  float[] pvy = new float[MAX_PARTICLES];
  float[] pa  = new float[MAX_PARTICLES];   // alpha 0..100
  float[] pSz = new float[MAX_PARTICLES];
  float[] pH  = new float[MAX_PARTICLES];
  int particleHead = 0;

  // ────────────────────────────────────────────────────────────────────────────
  VoidBloomScene() {
    for (int i = 0; i < MAX_PARTICLES; i++) pa[i] = 0;
  }

  void onEnter() {
    globalRotation = 0;
    bassSmooth = midSmooth = highSmooth = 0;
    beatFlash = 0;
    rippleRadius = 0;
    rippleAlpha  = 0;
    hueShift = 0;
    for (int i = 0; i < NUM_STARS; i++) {
      sx[i]   = random(sceneBuffer.width);
      sy[i]   = random(sceneBuffer.height);
      sBri[i] = random(40, 95);
      sSize[i]= random(0.6, 2.8);
    }
  }

  void onExit() {}

  // ── Main Draw ────────────────────────────────────────────────────────────────
  void drawScene(PGraphics pg) {

    // Smooth audio inputs
    bassSmooth = lerp(bassSmooth, analyzer.bass,  0.15);
    midSmooth  = lerp(midSmooth,  analyzer.mid,   0.12);
    highSmooth = lerp(highSmooth, analyzer.high,  0.10);

    // Beat response
    if (analyzer.isBeat) {
      beatFlash    = 0.55;
      hueShift     = (hueShift + 35) % 360;
      rippleRadius = 0;
      rippleAlpha  = 1.0;
      spawnBurst(pg.width / 2.0 + panX, pg.height / 2.0 + panY, 25 + (int)(bassSmooth * 20));
    }
    beatFlash    *= 0.86;
    rippleRadius += 10 + bassSmooth * 18;
    rippleAlpha  *= 0.93;

    // Rotation driven by mid
    globalRotation += 0.004 * (1.0 + midSmooth * 1.8);

    // Continuous slow particle emission from a random petal tip
    if (config.logicalFrameCount % 2 == 0) {
      float base2  = min(pg.width, pg.height) * 0.30 * zoom;
      int   pIdx   = (int) random(numPetals);
      float pAngle = pIdx * TWO_PI / numPetals + globalRotation;
      int   bIdx   = constrain((int) map(pIdx, 0, numPetals, 0, 22), 0, analyzer.spectrum.length - 1);
      float amp    = lerp(0.25, 1.0, analyzer.spectrum[bIdx]);
      float tipR   = base2 * amp * 0.85;
      spawnParticle(
        pg.width / 2.0 + panX + cos(pAngle) * tipR,
        pg.height / 2.0 + panY + sin(pAngle) * tipR
      );
    }

    // ── Scene geometry ────────────────────────────────────────────────────────
    pg.colorMode(HSB, 360, 100, 100, 100);
    pg.background(0, 0, 4);

    drawNebulaGlow(pg);
    if (showStars) drawStars(pg);

    float cx   = pg.width  / 2.0 + panX;
    float cy   = pg.height / 2.0 + panY;
    float base = min(pg.width, pg.height) * 0.30 * zoom;

    drawRings(pg, cx, cy, base);

    pg.pushMatrix();
    pg.translate(cx, cy);
    pg.rotate(globalRotation);
    drawPetals(pg, base);
    pg.popMatrix();

    drawCore(pg, cx, cy, base);

    // Ripple ring
    if (rippleAlpha > 0.01) {
      float rh = getHue(0.5);
      pg.noFill();
      pg.strokeWeight(2.0);
      pg.stroke(rh, 65, 100, rippleAlpha * 45);
      pg.ellipse(cx, cy, rippleRadius * 2, rippleRadius * 2);
      pg.stroke(rh, 50, 100, rippleAlpha * 18);
      pg.ellipse(cx, cy, rippleRadius * 1.7, rippleRadius * 1.7);
    }

    updateParticles(pg);

    // Beat flash overlay
    if (beatFlash > 0.01) {
      pg.noStroke();
      pg.fill(getHue(0.5), 35, 100, beatFlash * 10);
      pg.rect(0, 0, pg.width, pg.height);
    }
  }

  // ── Background nebula glow ────────────────────────────────────────────────────
  void drawNebulaGlow(PGraphics pg) {
    float cx   = pg.width  / 2.0 + panX;
    float cy   = pg.height / 2.0 + panY;
    float maxR = min(pg.width, pg.height) * 0.5;
    int   steps = 14;
    pg.noStroke();
    for (int i = steps; i >= 1; i--) {
      float t   = (float) i / steps;
      float r   = maxR * t;
      float h   = getHue(t * 0.7);
      float sat = bassSmooth * 35 * t;
      float bri = bassSmooth * 18 * t * t;
      pg.fill(h, sat, bri, 85);
      pg.ellipse(cx, cy, r * 2, r * 2);
    }
  }

  // ── Star field ────────────────────────────────────────────────────────────────
  void drawStars(PGraphics pg) {
    pg.noStroke();
    for (int i = 0; i < NUM_STARS; i++) {
      float twinkle = 0.6 + 0.4 * sin(config.logicalFrameCount * 0.025 + i * 1.37);
      float bri     = sBri[i] * twinkle * (0.5 + highSmooth * 0.6);
      pg.fill(210, 15, bri, 88);
      pg.ellipse(sx[i], sy[i], sSize[i], sSize[i]);
    }
  }

  // ── Orbital rings ─────────────────────────────────────────────────────────────
  void drawRings(PGraphics pg, float cx, float cy, float base) {
    pg.noFill();
    for (int r = 1; r <= 4; r++) {
      float t     = (float) r / 4;
      float ringR = base * (0.28 + t * 0.78) * (1 + bassSmooth * 0.08);
      float h     = getHue(t);
      float alpha = 13 - r * 2;
      pg.stroke(h, 50, 65, alpha);
      pg.strokeWeight(1.0);
      pg.ellipse(cx, cy, ringR * 2, ringR * 2);
    }
  }

  // ── Petal arms ────────────────────────────────────────────────────────────────
  void drawPetals(PGraphics pg, float base) {
    for (int p = 0; p < numPetals; p++) {
      int   bIdx    = constrain((int) map(p, 0, numPetals, 0, 22), 0, analyzer.spectrum.length - 1);
      float amp     = lerp(0.25, 1.0, analyzer.spectrum[bIdx]);
      float petalLen = base * amp;
      float h       = getHue((float) p / numPetals);
      drawOnePetal(pg, petalLen, h, amp);
      pg.rotate(TWO_PI / numPetals);
    }
  }

  // Draws a single teardrop petal pointing in the +X direction.
  void drawOnePetal(PGraphics pg, float len, float hue, float amp) {
    float w = len * 0.22 * (0.4 + amp * 0.6);
    pg.noStroke();
    // Outer glow layers
    for (int g = 4; g >= 1; g--) {
      float sc    = 1.0 + g * 0.10;
      float alpha = (5 - g) * 9.0 * amp;
      pg.fill(hue, 72 - g * 8, 90, alpha);
      pg.beginShape();
      pg.vertex(0, 0);
      pg.bezierVertex(len * 0.28, -w * sc,          len * 0.68, -w * sc * 0.55, len * sc * 0.88, 0);
      pg.bezierVertex(len * 0.68,  w * sc * 0.55,   len * 0.28,  w * sc,        0,               0);
      pg.endShape(CLOSE);
    }
    // Core fill
    pg.fill(hue, 55, 100, 52 * amp);
    pg.beginShape();
    pg.vertex(0, 0);
    pg.bezierVertex(len * 0.28, -w * 0.85, len * 0.68, -w * 0.50, len * 0.88, 0);
    pg.bezierVertex(len * 0.68,  w * 0.50, len * 0.28,  w * 0.85, 0,          0);
    pg.endShape(CLOSE);
    // Spine
    pg.stroke(hue, 35, 100, 65 * amp);
    pg.strokeWeight(1.5);
    pg.noFill();
    pg.line(0, 0, len * 0.85, 0);
  }

  // ── Central glow ─────────────────────────────────────────────────────────────
  void drawCore(PGraphics pg, float cx, float cy, float base) {
    float cR = base * 0.08 * (1 + bassSmooth * 1.1);
    float h  = getHue(0.5 + 0.1 * sin(config.logicalFrameCount * 0.02));
    pg.noStroke();
    for (int g = 6; g >= 1; g--) {
      float r     = cR * (1 + g * 0.85);
      float alpha = (7 - g) * 5.0;
      pg.fill(h, 25 + g * 9, 100, alpha);
      pg.ellipse(cx, cy, r * 2, r * 2);
    }
    pg.fill(h, 10, 100, 88);
    pg.ellipse(cx, cy, cR * 1.6, cR * 1.6);
    pg.fill(0, 0, 100, 95);
    pg.ellipse(cx, cy, cR * 0.65, cR * 0.65);
  }

  // ── Particles ─────────────────────────────────────────────────────────────────
  void spawnBurst(float cx, float cy, int count) {
    for (int i = 0; i < count; i++) spawnParticle(cx, cy);
  }

  void spawnParticle(float cx, float cy) {
    float angle = random(TWO_PI);
    float speed = random(1.5, 5.5) * (0.7 + bassSmooth);
    px[particleHead]  = cx;
    py[particleHead]  = cy;
    pvx[particleHead] = cos(angle) * speed;
    pvy[particleHead] = sin(angle) * speed;
    pa[particleHead]  = 100;
    pSz[particleHead] = random(1.2, 4.5);
    pH[particleHead]  = getHue(random(1.0));
    particleHead = (particleHead + 1) % MAX_PARTICLES;
  }

  void updateParticles(PGraphics pg) {
    pg.noStroke();
    for (int i = 0; i < MAX_PARTICLES; i++) {
      if (pa[i] < 0.5) continue;
      px[i]  += pvx[i];
      py[i]  += pvy[i];
      pvy[i] += 0.04;
      pvx[i] *= 0.982;
      pvy[i] *= 0.982;
      pa[i]  *= 0.955;
      pg.fill(pH[i], 65, 100, pa[i]);
      pg.ellipse(px[i], py[i], pSz[i], pSz[i]);
    }
  }

  // ── Palette ───────────────────────────────────────────────────────────────────
  float getHue(float t) {
    switch (palette) {
      case 0: return (hueShift + 195 + t * 130) % 360;   // Nebula:  cyan → violet
      case 1: return (25       + t * 35)         % 360;   // Solar:   orange → yellow
      case 2: return (175      + t * 50)          % 360;   // Ocean:   cyan → blue
      case 3: return (315      + t * 70)          % 360;   // Crimson: magenta → red
      default: return (hueShift + t * 360) % 360;
    }
  }

  // ── Controller ────────────────────────────────────────────────────────────────
  void applyController(Controller c) {
    // Pan is applied to pg-space coords, so clamp to sceneBuffer dims (not
    // window dims) — otherwise on capped-resolution stages the pan can push
    // the bloom off the visible buffer area.
    panX = constrain(panX + (c.lx - width  / 2.0) * 0.04, -sceneBuffer.width  * 0.4, sceneBuffer.width  * 0.4);
    panY = constrain(panY + (c.ly - height / 2.0) * 0.04, -sceneBuffer.height * 0.4, sceneBuffer.height * 0.4);
    float zd = map(c.ry, 0, height, -1, 1);
    zoom = constrain(zoom + zd * 0.025, 0.3, 3.5);
    if (c.aJustPressed) spawnBurst(sceneBuffer.width / 2.0 + panX, sceneBuffer.height / 2.0 + panY, 30);
    if (c.bJustPressed) palette   = (palette + 1) % 4;
    if (c.yJustPressed) numPetals = (numPetals >= 16) ? 4 : numPetals + 2;
    if (c.xJustPressed) showStars = !showStars;
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────────
  void handleKey(char k) {
    if (k == '[')              numPetals = max(2,  numPetals - 1);
    if (k == ']')              numPetals = min(20, numPetals + 1);
    if (k == 'c' || k == 'C') palette   = (palette + 1) % 4;
    if (k == 'z')              zoom      = constrain(zoom - 0.12, 0.3, 3.5);
    if (k == 'Z')              zoom      = constrain(zoom + 0.12, 0.3, 3.5);
    if (k == 's' || k == 'S') showStars = !showStars;
    if (k == ' ')              spawnBurst(sceneBuffer.width / 2.0 + panX, sceneBuffer.height / 2.0 + panY, 30);
    if (k == 'r' || k == 'R') {
      zoom = 1.0; panX = 0; panY = 0; numPetals = 8; palette = 0;
    }
  }

  // ── Code Overlay ─────────────────────────────────────────────────────────────
  String[] getCodeLines() {
    String[] palNames = {"Nebula", "Solar", "Ocean", "Crimson"};
    return new String[]{
      "╔══ VOID BLOOM ══╗",
      "[ / ]   petals: " + numPetals,
      "C       palette: " + palNames[palette],
      "Z / z   zoom: " + nf(zoom, 1, 2),
      "S       stars: " + (showStars ? "on" : "off"),
      "R       reset",
      "Space   burst"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("[   /   ]", "Adjust petal count"),
      new ControllerLayout("C", "Cycle palette"),
      new ControllerLayout("Z / z", "Zoom in/out"),
      new ControllerLayout("S", "Toggle stars"),
      new ControllerLayout("SPACE", "Burst effect"),
      new ControllerLayout("R", "Reset all")
    };
  }
}
