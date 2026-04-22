// Particle Fountain — state 8
// Physics-based particles driven by bass / mid / high frequencies.
// Press '8' to switch to this scene.
//
// Keyboard controls (active when STATE == 8):
//   Mouse move   — aim the fountain toward the cursor
//   Mouse click  — burst explosion at click position
//   Space        — manual burst from fountain origin
//   W A S D      — nudge emission origin around the screen
//   Up / Down    — increase / decrease gravity
//   [ / ]        — narrow / widen emission spread cone

class Particle {
  float x, y;         // position
  float vx, vy;       // velocity
  float life;         // 1.0 = just born, 0.0 = dead
  float lifeDecay;   // how much life is lost per frame
  float size;         // radius in pixels
  float hue;          // HSB hue (0–360)
  float sat;          // HSB saturation
  int   band;         // 0 = bass, 1 = mid, 2 = high

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}

class ParticleFountainScene implements IScene {

  ArrayList<Particle> particles = new ArrayList<Particle>();
  int   MAX_PARTICLES  = 1200;
  ArrayList<Particle> pool = new ArrayList<Particle>();

  float originX;
  float originY;
  float emitAngle = -HALF_PI;
  float emitSpread = radians(60);
  float gravity = 0.12;
  float emitRateMultiplier = 1.0;
  boolean longTrail = false;

  ParticleFountainScene() {
    // Initial origin = pg center. sceneBuffer is the canvas every scene draws
    // into; using its dims keeps the spawn point centered when the scene
    // buffer is smaller than the window (4K display + 1080p render cap).
    originX = sceneBuffer.width  / 2.0;
    originY = sceneBuffer.height / 2.0;
    for (int i = 0; i < MAX_PARTICLES; i++) pool.add(new Particle());
  }

  void drawScene(PGraphics pg) {
    float bassLevel = analyzer.bass;
    float midLevel  = analyzer.mid;
    float highLevel = analyzer.high;
    boolean isBeat = analyzer.isBeat;

    if (!config.USING_CONTROLLER) {
      emitAngle = atan2(pg.parent.mouseY - originY, pg.parent.mouseX - originX);
    }

    float trailOpacity = longTrail ? 18 : 40;
    pg.noStroke();
    pg.rectMode(CORNER);
    pg.fill(0, 0, 0, trailOpacity);
    pg.rect(0, 0, pg.width, pg.height);

    if (particles.size() < MAX_PARTICLES) {
      emitBass(bassLevel);
      emitMid(midLevel);
      emitHigh(highLevel);
      if (isBeat) emitBurst(originX, originY, 20);
    }

    pg.colorMode(HSB, 360, 255, 255, 255);
    for (int i = particles.size() - 1; i >= 0; i--) {
      Particle p = particles.get(i);
      p.vy  += gravity;
      p.vx  *= 0.995;
      p.vy  *= 0.995;
      p.x   += p.vx;
      p.y   += p.vy;
      p.life -= p.lifeDecay;

      if (p.life <= 0 || p.x < -50 || p.x > pg.width + 50 || p.y > pg.height + 50) {
        particles.remove(i);
        pool.add(p);
        continue;
      }

      float alpha = p.life * 255;
      pg.noStroke();
      pg.fill(p.hue, p.sat, 255, alpha * 0.15);
      pg.ellipse(p.x, p.y, p.size * 2.2, p.size * 2.2);
      pg.fill(p.hue, p.sat, 255, alpha);
      pg.ellipse(p.x, p.y, p.size, p.size);
    }
    pg.colorMode(RGB, 255);

    pg.pushStyle();
      pg.stroke(255, 255, 255, 60);
      pg.strokeWeight(1);
      pg.line(originX - 10, originY, originX + 10, originY);
      pg.line(originX, originY - 10, originX, originY + 10);
    pg.popStyle();

    pg.pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      float margin = 4 * uiScale();
      pg.fill(0, 120);
      pg.noStroke();
      pg.rectMode(CORNER);
      pg.rect(8, 8, 270 * uiScale(), margin + lh * 5);
      pg.fill(255);
      pg.textSize(ts);
      pg.textAlign(LEFT, TOP);
      pg.text("Scene: Particle Fountain",             12, 8 + margin);
      pg.text("particles: " + particles.size() + " / " + MAX_PARTICLES, 12, 8 + margin + lh);
      pg.text("gravity: "   + nf(gravity, 1, 3) + "  Up/Down",           12, 8 + margin + lh*2);
      pg.text("spread: "    + nf(degrees(emitSpread), 1, 1) + "deg  [ ]", 12, 8 + margin + lh*3);
      pg.text("bass/mid/high: " + nf(bassLevel,1,1) + " / " + nf(midLevel,1,1) + " / " + nf(highLevel,1,1), 12, 8 + margin + lh*4);
    pg.popStyle();

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void handleKey(char k) {
    if (k == ' ')  triggerBurst();
    else if (k == '[')  adjustSpread(-radians(5));
    else if (k == ']')  adjustSpread(radians(5));
    else if (k == 'w' || k == 'W') nudgeOrigin(0, -10);
    else if (k == 'a' || k == 'A') nudgeOrigin(-10, 0);
    else if (k == 's' || k == 'S') nudgeOrigin(0, 10);
    else if (k == 'd' || k == 'D') nudgeOrigin(10, 0);
    else if (k == CODED) {
      if (keyCode == UP)   adjustGravity(-0.01);
      if (keyCode == DOWN) adjustGravity(0.01);
    }
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Particle Fountain ===",
      "// Physics-based particles born from emission cone",
      "velocity_y += gravity; drag = 0.995",
      "life -= decay; return to pool on death"
    };
  }

  void emitBass(float level) {
    int count = int(level * 2.5 * emitRateMultiplier);
    for (int i = 0; i < count && particles.size() < MAX_PARTICLES; i++) {
      float angle = emitAngle + random(-emitSpread * 0.5, emitSpread * 0.5);
      float speed = random(2, 5) * (1 + level);
      Particle p  = makeParticle(originX, originY, cos(angle) * speed, sin(angle) * speed, random(3, 6) * (1 + level * 0.15), random(0, 40), 180, random(0.008, 0.014), 0);
      particles.add(p);
    }
  }

  void emitMid(float level) {
    int count = int(level * 4.0 * emitRateMultiplier);
    for (int i = 0; i < count && particles.size() < MAX_PARTICLES; i++) {
      float angle = emitAngle + random(-emitSpread * 0.5, emitSpread * 0.5);
      float speed = random(3, 7) * (1 + level * 0.8);
      Particle p  = makeParticle(originX, originY, cos(angle) * speed, sin(angle) * speed, random(1, 4), random(60, 140), 200, random(0.010, 0.018), 1);
      particles.add(p);
    }
  }

  void emitHigh(float level) {
    int count = int(level * 6.0 * emitRateMultiplier);
    for (int i = 0; i < count && particles.size() < MAX_PARTICLES; i++) {
      float angle = emitAngle + random(-emitSpread * 0.7, emitSpread * 0.7);
      float speed = random(5, 12) * (1 + level * 0.6);
      Particle p  = makeParticle(originX, originY, cos(angle) * speed, sin(angle) * speed, random(0.5, 2), random(200, 290), 220, random(0.012, 0.022), 2);
      particles.add(p);
    }
  }

  void emitBurst(float bx, float by, int count) {
    for (int i = 0; i < count && particles.size() < MAX_PARTICLES; i++) {
      float angle = random(TWO_PI);
      float speed = random(4, 14);
      Particle p  = makeParticle(bx, by, cos(angle) * speed, sin(angle) * speed, random(1, 4), random(360), 210, random(0.008, 0.016), (int)random(3));
      particles.add(p);
    }
  }

  Particle makeParticle(float x, float y, float vx, float vy, float size, float hue, float sat, float lifeDecay, int band) {
    Particle p = pool.size() > 0 ? pool.remove(pool.size() - 1) : new Particle();
    p.x=x; p.y=y; p.vx=vx; p.vy=vy; p.size=size; p.hue=hue; p.sat=sat; p.life=1.0; p.lifeDecay=lifeDecay; p.band=band;
    return p;
  }

  void adjustGravity(float delta) { gravity = constrain(gravity + delta, -0.3, 0.8); }
  void adjustSpread(float delta) { emitSpread = constrain(emitSpread + delta, radians(5), TWO_PI); }
  void nudgeOrigin(float dx, float dy) { originX = constrain(originX + dx, 0, sceneBuffer.width); originY = constrain(originY + dy, 0, sceneBuffer.height); }
  void triggerBurst() { emitBurst(originX, originY, 30); }
  void triggerBurstAt(float bx, float by) { emitBurst(bx, by, 30); }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    float rx = map(c.rx, 0, width,  -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);
    if (abs(lx) > 0.1 || abs(ly) > 0.1) emitAngle = atan2(ly, lx);
    emitSpread = map(rx, -1, 1, radians(10), TWO_PI);
    gravity = map(ry, -1, 1, -0.2, 0.6);
    try {
      float z = c.stick.getSlider("z").getValue();
      emitRateMultiplier = map(z, -1, 1, 0.1, 1.0);
    } catch (Exception e) {}
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
