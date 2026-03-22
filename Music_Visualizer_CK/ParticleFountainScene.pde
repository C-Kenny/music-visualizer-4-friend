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
//
// Controller controls (active when STATE == 8):
//   Left stick   — aim emission direction
//   Right stick X — emission spread (cone width)
//   Right stick Y — gravity strength
//   Left trigger  — thin out emission rate (hold to reduce particles)
//   A button      — manual burst
//   B button      — toggle trail length (short / long)

// ─── Particle data ────────────────────────────────────────────────────────────

class Particle {
  float x, y;         // position
  float vx, vy;       // velocity
  float life;         // 1.0 = just born, 0.0 = dead
  float life_decay;   // how much life is lost per frame
  float size;         // radius in pixels
  float hue;          // HSB hue (0–360)
  float sat;          // HSB saturation
  int   band;         // 0 = bass, 1 = mid, 2 = high
}

// ─── Scene ────────────────────────────────────────────────────────────────────

class ParticleFountainScene {

  ArrayList<Particle> particles = new ArrayList<Particle>();

  int   MAX_PARTICLES  = 1200;

  // emission origin (screen coords) — user can nudge this with WASD
  float origin_x;
  float origin_y;

  // emission direction — angle in radians (default: straight up)
  float emit_angle = -HALF_PI;

  // half-angle of the emission cone (PI = full circle, 0 = laser beam)
  float emit_spread = radians(60);

  // downward pull per frame
  float gravity = 0.12;

  // multiplier on top of audio-driven emission (user-adjustable via trigger)
  float emit_rate_multiplier = 1.0;

  // long vs short phosphor trail
  boolean long_trail = false;

  ParticleFountainScene() {
    origin_x = width  / 2.0;
    origin_y = height / 2.0;
  }

  // ── getCodeLines ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[] {
      "=== Particle Fountain ===",
      "",
      "// Particles born at origin, aimed within a spread cone",
      "emit_angle  = direction toward mouse (or left stick)",
      "spawn_speed = base_speed * (1 + frequency_level * 2)",
      "spawn_size  = base_size  * (1 + frequency_level)",
      "",
      "// Bass  → large, slow, warm (red/orange) particles",
      "// Mid   → medium, green/yellow particles",
      "// High  → small, fast, cool (blue/purple) particles",
      "",
      "// Physics update every frame:",
      "velocity_y  += gravity",
      "velocity_x  *= 0.995   // gentle air drag",
      "velocity_y  *= 0.995",
      "position    += velocity",
      "life        -= life_decay   // particle fades and disappears",
      "",
      "// Beat onset: burst of 45 random-direction particles",
      "// Controls: mouse aim   Space burst   W/A/S/D move origin",
      "//           Up/Down gravity   [ ] spread cone"
    };
  }

  // ── main draw ─────────────────────────────────────────────────────────────

  void drawScene() {

    // --- frequency levels -------------------------------------------
    int fft_size = audio.fft.avgSize();
    int bass_end = max(1, fft_size / 6);
    int mid_end  = max(bass_end + 1, fft_size / 2);

    float bass_level = 0, mid_level = 0, high_level = 0;
    for (int i = 0;       i < bass_end; i++) bass_level += audio.fft.getAvg(i);
    for (int i = bass_end; i < mid_end; i++) mid_level  += audio.fft.getAvg(i);
    for (int i = mid_end; i < fft_size; i++) high_level += audio.fft.getAvg(i);
    bass_level /= bass_end;
    mid_level  /= max(1, mid_end  - bass_end);
    high_level /= max(1, fft_size - mid_end);

    // beat detection
    audio.beat.detect(audio.player.mix);
    boolean is_beat = audio.beat.isOnset();

    // --- aim toward mouse when not using controller -----------------
    if (!config.USING_CONTROLLER) {
      emit_angle = atan2(mouseY - origin_y, mouseX - origin_x);
    }

    // --- phosphor trail (semi-transparent fade) ----------------------
    float trail_opacity = long_trail ? 18 : 40;
    noStroke();
    rectMode(CORNER);
    fill(0, 0, 0, trail_opacity);
    rect(0, 0, width, height);

    // --- emit new particles -----------------------------------------
    if (particles.size() < MAX_PARTICLES) {
      emitBass(bass_level);
      emitMid(mid_level);
      emitHigh(high_level);
      if (is_beat) emitBurst(origin_x, origin_y, 20);
    }

    // --- update and draw particles ----------------------------------
    colorMode(HSB, 360, 255, 255, 255);

    for (int i = particles.size() - 1; i >= 0; i--) {
      Particle p = particles.get(i);

      // physics
      p.vy  += gravity;
      p.vx  *= 0.995;
      p.vy  *= 0.995;
      p.x   += p.vx;
      p.y   += p.vy;
      p.life -= p.life_decay;

      // remove dead or off-screen particles
      if (p.life <= 0 || p.x < -50 || p.x > width + 50 || p.y > height + 50) {
        particles.remove(i);
        continue;
      }

      float alpha = p.life * 255;

      // outer glow
      noStroke();
      fill(p.hue, p.sat, 255, alpha * 0.15);
      ellipse(p.x, p.y, p.size * 2.2, p.size * 2.2);

      // core
      fill(p.hue, p.sat, 255, alpha);
      ellipse(p.x, p.y, p.size, p.size);
    }

    colorMode(RGB, 255);

    // --- draw origin crosshair -------------------------------------
    pushStyle();
      stroke(255, 255, 255, 60);
      strokeWeight(1);
      line(origin_x - 10, origin_y, origin_x + 10, origin_y);
      line(origin_x, origin_y - 10, origin_x, origin_y + 10);
    popStyle();

    // --- HUD -------------------------------------------------------
    pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      float margin = 4 * uiScale();
      fill(0, 120);
      noStroke();
      rectMode(CORNER);
      rect(8, 8, 270 * uiScale(), margin + lh * 5);
      fill(255);
      textSize(ts);
      textAlign(LEFT, TOP);
      text("Scene: Particle Fountain",             12, 8 + margin);
      text("particles: " + particles.size() + " / " + MAX_PARTICLES, 12, 8 + margin + lh);
      text("gravity: "   + nf(gravity, 1, 3) + "  Up/Down",           12, 8 + margin + lh*2);
      text("spread: "    + nf(degrees(emit_spread), 1, 1) + "deg  [ ]", 12, 8 + margin + lh*3);
      text("bass/mid/high: " + nf(bass_level,1,1) + " / " + nf(mid_level,1,1) + " / " + nf(high_level,1,1), 12, 8 + margin + lh*4);
    popStyle();

    drawSongNameOnScreen(config.SONG_NAME, width / 2, height - 5);
  }

  // ── emission helpers ──────────────────────────────────────────────────────

  // Bass: large, slow, warm (red–orange). Few but impactful.
  void emitBass(float level) {
    int count = int(level * 2.5 * emit_rate_multiplier);
    for (int i = 0; i < count && particles.size() < MAX_PARTICLES; i++) {
      float angle = emit_angle + random(-emit_spread * 0.5, emit_spread * 0.5);
      float speed = random(2, 5) * (1 + level);
      Particle p  = makeParticle(
        origin_x, origin_y,
        cos(angle) * speed, sin(angle) * speed,
        random(3, 6) * (1 + level * 0.15),     // size
        random(0, 40),                         // hue: red–orange
        180,                                   // saturation
        random(0.008, 0.014),                  // life decay
        0                                      // band
      );
      particles.add(p);
    }
  }

  // Mid: medium, green–yellow.
  void emitMid(float level) {
    int count = int(level * 4.0 * emit_rate_multiplier);
    for (int i = 0; i < count && particles.size() < MAX_PARTICLES; i++) {
      float angle = emit_angle + random(-emit_spread * 0.5, emit_spread * 0.5);
      float speed = random(3, 7) * (1 + level * 0.8);
      Particle p  = makeParticle(
        origin_x, origin_y,
        cos(angle) * speed, sin(angle) * speed,
        random(1, 4),                          // size
        random(60, 140),                       // hue: green–yellow
        200,
        random(0.010, 0.018),
        1
      );
      particles.add(p);
    }
  }

  // High: small, fast, cool (blue–purple). Lots of them.
  void emitHigh(float level) {
    int count = int(level * 6.0 * emit_rate_multiplier);
    for (int i = 0; i < count && particles.size() < MAX_PARTICLES; i++) {
      float angle = emit_angle + random(-emit_spread * 0.7, emit_spread * 0.7);
      float speed = random(5, 12) * (1 + level * 0.6);
      Particle p  = makeParticle(
        origin_x, origin_y,
        cos(angle) * speed, sin(angle) * speed,
        random(0.5, 2),                        // size
        random(200, 290),                      // hue: blue–purple
        220,
        random(0.012, 0.022),
        2
      );
      particles.add(p);
    }
  }

  // Burst: explosion of mixed particles from a given position.
  void emitBurst(float bx, float by, int count) {
    for (int i = 0; i < count && particles.size() < MAX_PARTICLES; i++) {
      float angle = random(TWO_PI);
      float speed = random(4, 14);
      Particle p  = makeParticle(
        bx, by,
        cos(angle) * speed, sin(angle) * speed,
        random(1, 4),
        random(360),
        210,
        random(0.008, 0.016),
        (int)random(3)
      );
      particles.add(p);
    }
  }

  Particle makeParticle(float x, float y, float vx, float vy,
                        float size, float hue, float sat,
                        float life_decay, int band) {
    Particle p   = new Particle();
    p.x          = x;
    p.y          = y;
    p.vx         = vx;
    p.vy         = vy;
    p.size       = size;
    p.hue        = hue;
    p.sat        = sat;
    p.life       = 1.0;
    p.life_decay = life_decay;
    p.band       = band;
    return p;
  }

  // ── user input helpers ────────────────────────────────────────────────────

  void adjustGravity(float delta) {
    gravity = constrain(gravity + delta, -0.3, 0.8);
  }

  void adjustSpread(float delta) {
    emit_spread = constrain(emit_spread + delta, radians(5), TWO_PI);
  }

  void nudgeOrigin(float dx, float dy) {
    origin_x = constrain(origin_x + dx, 0, width);
    origin_y = constrain(origin_y + dy, 0, height);
  }

  void triggerBurst() {
    emitBurst(origin_x, origin_y, 30);
  }

  void triggerBurstAt(float bx, float by) {
    emitBurst(bx, by, 30);
  }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    float rx = map(c.rx, 0, width,  -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);

    // left stick aims emission direction
    if (abs(lx) > 0.1 || abs(ly) > 0.1) {
      emit_angle = atan2(ly, lx);
    }

    // right stick X → spread, right stick Y → gravity
    emit_spread         = map(rx, -1, 1, radians(10), TWO_PI);
    gravity             = map(ry, -1, 1, -0.2, 0.6);

    // left trigger → reduce emission rate (hold to thin out the fountain)
    float left_trigger   = map(c.stick.getSlider("lt").getValue(), -1, 1, 0, 1);
    emit_rate_multiplier = map(left_trigger, 0, 1, 1.0, 0.1);
  }
}
