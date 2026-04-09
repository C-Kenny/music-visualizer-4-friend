// Worm Colony Scene — state 10
//
// A colony of neon worms slithers across a dark screen.
// Each worm is a chain of glowing segments driven by Perlin-noise wandering.
//
// Audio mapping:
//   Bass   → body thickness pulses, beat-scatter kick
//   Mid    → movement speed and wander energy
//   High   → glow aura intensity + sparkle particles
//   Beat   → flash + radial burst + worms scatter
//
// Controller:
//   L Stick       → lure all worms toward stick (hold)
//   R Stick       → repel worms from stick position (hold)
//   A             → spawn a new worm
//   B             → remove last worm
//   X             → scatter burst (all worms launch outward)
//   Y             → cycle color mode (rainbow / frequency / mono)
//   LT            → slow worms down
//   RT            → turbo mode (speed up)

// ── Worm ─────────────────────────────────────────────────────────────────────

// ── Worm ─────────────────────────────────────────────────────────────────────

class Worm {
  final int   N   = 42;      
  final float SEP = 14.0;   

  float[] sx = new float[N];
  float[] sy = new float[N];
  float   vx, vy;

  float baseHue;
  float hue;
  float noiseOff;
  float speedMult;

  Worm(float x, float y, float bHue) {
    baseHue = bHue;
    hue     = bHue;
    for (int i = 0; i < N; i++) { sx[i] = x; sy[i] = y; }
    vx = random(-2, 2);
    vy = random(-2, 2);
    noiseOff  = random(10000);
    speedMult = random(0.75, 1.35);
  }

  void update(PGraphics pg, float bass, float mid, boolean isBeat,
              float lureX, float lureY, boolean luring,
              float repelX, float repelY, boolean repelling,
              float speedScale) {

    float topSpeed = (2.2 + mid * 0.2) * speedMult * speedScale;
    float t      = pg.parent.frameCount * 0.003 + noiseOff;
    float wander = pg.parent.noise(sx[0] * 0.004 + noiseOff,
                         sy[0] * 0.004 + noiseOff * 1.7, t) * TWO_PI * 2.5;

    if (luring) {
      float dx = lureX - sx[0], dy = lureY - sy[0];
      float d  = max(dist(sx[0], sy[0], lureX, lureY), 1);
      vx += dx / d * 1.4;
      vy += dy / d * 1.4;
    } else if (repelling) {
      float dx = sx[0] - repelX, dy = sy[0] - repelY;
      float d  = max(dist(sx[0], sy[0], repelX, repelY), 1);
      vx += dx / d * 1.8;
      vy += dy / d * 1.8;
    } else {
      vx += cos(wander) * 0.22 * (1 + mid * 0.04);
      vy += sin(wander) * 0.22 * (1 + mid * 0.04);
    }

    float spd = dist(0, 0, vx, vy);
    if (spd > topSpeed) { vx = vx / spd * topSpeed; vy = vy / spd * topSpeed; }

    float mg = 90;
    if (sx[0] < mg)          vx += 0.55;
    if (sx[0] > pg.width  - mg) vx -= 0.55;
    if (sy[0] < mg)          vy += 0.55;
    if (sy[0] > pg.height - mg) vy -= 0.55;

    sx[0] = constrain(sx[0] + vx, 0, pg.width);
    sy[0] = constrain(sy[0] + vy, 0, pg.height);

    for (int i = 1; i < N; i++) {
      float dx = sx[i-1] - sx[i];
      float dy = sy[i-1] - sy[i];
      float d  = dist(sx[i-1], sy[i-1], sx[i], sy[i]);
      if (d > SEP) {
        float pull = (d - SEP) / d;
        sx[i] += dx * pull;
        sy[i] += dy * pull;
      }
    }

    if (isBeat) {
      float ang = random(TWO_PI);
      vx += cos(ang) * bass * 0.55;
      vy += sin(ang) * bass * 0.55;
      hue = (baseHue + pg.parent.frameCount * 0.8 + random(40)) % 360;
    }
  }

  void draw(PGraphics pg, float bass, float high, boolean isBeat, int colorMode) {
    float pulse = 1.0 + bass * 0.13;
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();
    for (int i = N - 1; i >= 0; i--) {
      float t    = (float)i / (N - 1);          
      float r    = lerp(17, 4, t) * pulse;
      float segHue;
      switch (colorMode) {
        case 1:  segHue = (hue + i * 10 + pg.parent.frameCount * 0.6f) % 360; break; 
        case 2:  segHue = map(i, 0, N - 1, hue, (hue + 120) % 360); break; 
        default: segHue = hue; break;                                         
      }
      float glowR = r * 1.7 + high * 0.4;
      float glowA = lerp(20, 5, t) + high * 0.6;
      pg.fill(segHue, 195, 255, glowA);
      pg.ellipse(sx[i], sy[i], glowR, glowR);
      pg.fill(segHue, 200, 235);
      pg.ellipse(sx[i], sy[i], r * 2, r * 2);
      if (r > 6) {
        pg.fill(segHue, 70, 255, 170);
        pg.ellipse(sx[i] - r * 0.27, sy[i] - r * 0.27, r * 0.65, r * 0.65);
      }
    }
    float headR    = 17 * pulse;
    float faceAng  = atan2(vy, vx);
    float perpX    = cos(faceAng + HALF_PI);
    float perpY    = sin(faceAng + HALF_PI);
    float eyeOff   = headR * 0.38;
    float eyeR     = headR * 0.34;
    float pupilR   = eyeR  * 0.52;
    float lookX    = cos(faceAng) * pupilR * 0.28;
    float lookY    = sin(faceAng) * pupilR * 0.28;
    pg.fill(0, 0, 255);
    pg.ellipse(sx[0] + perpX * eyeOff, sy[0] + perpY * eyeOff, eyeR * 2, eyeR * 2);
    pg.ellipse(sx[0] - perpX * eyeOff, sy[0] - perpY * eyeOff, eyeR * 2, eyeR * 2);
    pg.fill(0, 0, 0);
    pg.ellipse(sx[0] + perpX * eyeOff + lookX, sy[0] + perpY * eyeOff + lookY, pupilR, pupilR);
    pg.ellipse(sx[0] - perpX * eyeOff + lookX, sy[0] - perpY * eyeOff + lookY, pupilR, pupilR);
    pg.colorMode(RGB, 255);
  }

  void scatter() {
    float ang = random(TWO_PI);
    vx += cos(ang) * 14;
    vy += sin(ang) * 14;
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}

class DirtParticle {
  float x, y, vx, vy, life, maxLife, hue;
  DirtParticle(float x, float y, float hue) {
    this.x = x; this.y = y; this.hue = hue;
    float ang = random(-PI, 0); 
    float spd = random(3, 12);
    vx = cos(ang) * spd;
    vy = sin(ang) * spd;
    maxLife = life = random(20, 50);
  }
  boolean update() {
    vy += 0.4; 
    x += vx; y += vy;
    life--;
    return life > 0;
  }
  void draw(PGraphics pg) {
    float t = life / maxLife;
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();
    pg.fill(hue, 180, 255, t * 180);
    pg.ellipse(x, y, t * 6, t * 6);
    pg.colorMode(RGB, 255);
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}

class WormScene implements IScene {
  ArrayList<Worm>         worms     = new ArrayList<Worm>();
  ArrayList<DirtParticle> particles = new ArrayList<DirtParticle>();

  final int   MAX_WORMS    = 12;
  final int   START_WORMS  = 6;
  int   colorM   = 1;   
  float speedS  = 1.0;
  float beatRing    = 0;   
  float beatGlow    = 0;   

  boolean luring    = false;
  boolean repelling = false;
  float   lureX, lureY, repelX, repelY;

  WormScene() {
    for (int i = 0; i < START_WORMS; i++) addWorm(1280, 720);
  }

  void addWorm(float w, float h) {
    if (worms.size() >= MAX_WORMS) return;
    float hue = (worms.size() * 53 + random(20)) % 360;
    float x   = random(w  * 0.2, w  * 0.8);
    float y   = random(h * 0.2, h * 0.8);
    worms.add(new Worm(x, y, hue));
  }

  void removeWorm() {
    if (worms.size() > 1) worms.remove(worms.size() - 1);
  }

  void scatter() {
    for (Worm w : worms) w.scatter();
    spawnParticles(1280 / 2.0, 720 / 2.0, 30, 280);
  }

  void spawnParticles(float x, float y, int count, float hue) {
    for (int i = 0; i < count; i++) {
      particles.add(new DirtParticle(
        x + random(-80, 80),
        y + random(-20, 20),
        (hue + random(-30, 30) + 360) % 360
      ));
    }
  }

  void drawScene(PGraphics pg) {
    boolean isBeat = analyzer.isBeat;
    int fftSize = audio.fft.avgSize();
    int bassEnd = max(1, (int)(fftSize * 0.18));
    int midEnd  = max(bassEnd + 1, (int)(fftSize * 0.52));

    float bass = 0, mid = 0, high = 0;
    for (int i = 0;       i < bassEnd; i++) bass += audio.fft.getAvg(i);
    for (int i = bassEnd; i < midEnd;  i++) mid  += audio.fft.getAvg(i);
    for (int i = midEnd;  i < fftSize; i++) high += audio.fft.getAvg(i);
    bass /= bassEnd;
    mid  /= max(1, midEnd - bassEnd);
    high /= max(1, fftSize - midEnd);

    pg.background(8, 18, 8);

    if (isBeat) {
      beatGlow = 1.0;
      beatRing = 0;
      for (Worm w : worms) spawnParticles(w.sx[0], w.sy[0], 3, w.hue);
    }
    for (int i = particles.size() - 1; i >= 0; i--) {
      DirtParticle p = particles.get(i);
      if (!p.update()) { particles.remove(i); continue; }
      p.draw(pg);
    }
    for (Worm w : worms) {
      w.update(pg, bass, mid, isBeat, lureX, lureY, luring, repelX, repelY, repelling, speedS);
      w.draw(pg, bass, high, isBeat, colorM);
    }

    if (luring) {
      pg.colorMode(HSB, 360, 255, 255, 255);
      pg.stroke(90, 220, 255, 180); pg.strokeWeight(2); pg.noFill();
      pg.ellipse(lureX, lureY, 28, 28);
      pg.line(lureX - 18, lureY, lureX + 18, lureY);
      pg.line(lureX, lureY - 18, lureX, lureY + 18);
      pg.colorMode(RGB, 255); pg.noStroke();
    }
    if (repelling) {
      pg.colorMode(HSB, 360, 255, 255, 255);
      pg.stroke(0, 220, 255, 180); pg.strokeWeight(2); pg.noFill();
      pg.ellipse(repelX, repelY, 28, 28);
      pg.line(repelX - 14, repelY - 14, repelX + 14, repelY + 14);
      pg.line(repelX - 14, repelY + 14, repelX + 14, repelY - 14);
      pg.colorMode(RGB, 255); pg.noStroke();
    }

    String[] modeNames = {"Mono", "Rainbow", "Gradient"};
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      pg.fill(0, 150); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 290 * uiScale(), mg + lh * 5);
      pg.fill(80, 255, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Worm Colony",                                        12, 8 + mg);
      pg.fill(200, 255, 200);
      pg.text("Worms: " + worms.size() + "/" + MAX_WORMS + "  (A add / B remove)",  12, 8 + mg + lh);
      pg.text("Color: " + modeNames[colorM] + "  (Y to cycle)",                  12, 8 + mg + lh * 2);
      pg.text("Speed: " + nf(speedS, 1, 2) + "  (LT slow / RT turbo)",          12, 8 + mg + lh * 3);
      pg.text("bass:" + nf(bass,1,1) + "  mid:" + nf(mid,1,1) + "  high:" + nf(high,1,1), 12, 8 + mg + lh * 4);
    pg.popStyle();

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    luring = sqrt(lx * lx + ly * ly) > 0.18;
    if (luring) { lureX = c.lx; lureY = c.ly; }
    float rx = map(c.rx, 0, width,  -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);
    repelling = sqrt(rx * rx + ry * ry) > 0.18;
    if (repelling) { repelX = c.rx; repelY = c.ry; }
    try {
      float z = c.stick.getSlider("z").getValue(); 
      speedS = map(z, -1, 1, 0.3, 2.2);
    } catch (Exception e) {}
    if (c.aJustPressed) addWorm(1280, 720);
    if (c.bJustPressed) removeWorm();
    if (c.xJustPressed) scatter();
    if (c.yJustPressed) colorM = (colorM + 1) % 3;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Worm Colony ===",
      "// Neon worms via Perlin-noise wandering",
      "Bass drives thickness; Mid drives speed; High drives aura"
    };
  }

  void onEnter() { background(8, 18, 8); }
  void onExit() {}
  void handleKey(char k) {
    if (k == 'a') addWorm(1280, 720);
    if (k == 'b') removeWorm();
    if (k == 'x') scatter();
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
