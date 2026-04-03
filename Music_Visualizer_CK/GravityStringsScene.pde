// Gravity Strings scene — state 13
// Cat's Cradle variant: strings sag under simulated gravity.
// Beat onsets "pluck" them upward; they oscillate back down.
// L stick ↕ controls gravity strength.  R stick ↔ controls anchor count.

class GravityStringsScene implements IScene {
  int   numAnchors    = 8;
  int   subdivisions  = 32;
  float phase         = 0;
  float pulse         = 0;
  float rotation      = 0;
  float rotationSpeed = 0.002;
  float gravity       = 1.0;    // 0.1 (light) … 3.0 (heavy)

  // Per-skip-level sag physics (max numAnchors/2 = 7 levels)
  static final int MAX_SKIP = 7;
  float[] sag     = new float[MAX_SKIP];
  float[] sagVel  = new float[MAX_SKIP];

  static final float SPRING_K = 0.03;
  static final float DAMPING  = 0.93;
  static final float SAG_SCALE = 0.14;  // sag * len * SAG_SCALE = pixel displacement

  GravityStringsScene() {}

  void applyController(Controller c) {
    float ly = map(c.ly, 0, height, -1, 1);
    gravity = map(ly, -1, 1, 3.0, 0.1);

    float rx = map(c.rx, 0, width, -1, 1);
    numAnchors = constrain(round(map(rx, -1, 1, 4, 14)), 4, 14);

    if (c.a_just_pressed) pluck(2.5);
  }

  void pluck(float strength) {
    for (int i = 0; i < MAX_SKIP; i++) {
      sagVel[i] -= strength + i * 0.2;  // deeper skips get a slightly bigger kick
    }
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Gravity Strings ===",
      "",
      "// Strings sag under gravity, plucked by beats",
      "sag_vel += gravity * 0.02       // gravity pulls midpoint down",
      "sag_vel -= sag * 0.03           // spring restores toward straight",
      "sag_vel *= 0.93                 // damping",
      "",
      "// Catenary-ish sag shape (max at midpoint)",
      "sag_disp_y = sin(t * PI) * sag * len * 0.14",
      "",
      "// Beat onset -> upward pluck velocity kick",
      "sag_vel -= pluck_strength",
      "",
      "Controls: L stick ↕ gravity   R stick ↔ anchors   A pluck"
    };
  }

  void drawScene(PGraphics pg) {
    pg.background(0);
    // --- audio -----------------------------------------------------------
    float amplitude = 0;
    if (analyzer.isBeat) {
      pulse = 1.0;
      rotation += 0.08;
      pluck(2.2);
    }
    for (int i = 0; i < analyzer.spectrum.length; i++) {
      amplitude += analyzer.spectrum[i];
    }
    amplitude /= analyzer.spectrum.length;

    // --- sag physics (one integrator per skip level) ---------------------
    int maxSkip = numAnchors / 2;
    for (int si = 0; si < maxSkip; si++) {
      sagVel[si] += gravity * 0.02;          // gravity
      sagVel[si] -= sag[si] * SPRING_K;      // spring
      sagVel[si] *= DAMPING;
      sag[si] += sagVel[si];
      sag[si] = constrain(sag[si], -4.0, 4.0);
    }

    pulse    *= 0.88;
    phase    += 0.04;
    rotation += rotationSpeed;

    // --- anchor positions ------------------------------------------------
    float baseRadius = min(pg.width, pg.height) * 0.38;
    float r = baseRadius * (1.0 + pulse * 0.08);

    float[] ax = new float[numAnchors];
    float[] ay = new float[numAnchors];
    for (int i = 0; i < numAnchors; i++) {
      float a = TWO_PI * i / numAnchors + rotation;
      ax[i] = pg.width  / 2.0 + cos(a) * r;
      ay[i] = pg.height / 2.0 + sin(a) * r;
    }

    // --- draw strings ----------------------------------------------------
    for (int skip = 1; skip <= maxSkip; skip++) {
      for (int i = 0; i < numAnchors; i++) {
        int j = (i + skip) % numAnchors;

        // map this string to an FFT band
        int band = ((skip - 1) * numAnchors + i) % analyzer.spectrum.length;
        float bandAmp = analyzer.spectrum[band] * 3.0;

        pg.colorMode(HSB, 360, 255, 255, 255);
        float hue    = map(skip, 1, maxSkip, 270, 180);
        float alpha  = map(skip, 1, maxSkip, 220, 100);
        float weight = map(skip, 1, maxSkip, 2.0, 0.8);
        pg.stroke((int)hue, 210, 255, (int)alpha);
        pg.strokeWeight(weight);
        pg.colorMode(RGB, 255);
        pg.noFill();

        drawString(pg, ax[i], ay[i], ax[j], ay[j], bandAmp, skip, i, sag[skip - 1]);
      }
    }

    // --- anchor dots -----------------------------------------------------
    pg.noStroke();
    for (int i = 0; i < numAnchors; i++) {
      float glow = 6 + pulse * 22;
      pg.fill(255, 220, 80, 70);
      pg.ellipse(ax[i], ay[i], glow * 2, glow * 2);
      pg.fill(255, 240, 160);
      pg.ellipse(ax[i], ay[i], glow * 0.4, glow * 0.4);
    }

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);

    // --- top-left HUD ----------------------------------------------------
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 6 * uiScale();
      pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 310 * uiScale(), mg * 2 + lh * 2);
      pg.fill(255, 220, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Gravity Strings", 12, 8 + mg);
      pg.fill(200, 200, 200);
      pg.text("L \u2195 gravity: " + nf(gravity, 1, 2)
           + "   R \u2194 anchors: " + numAnchors
           + "   A pluck", 12, 8 + mg + lh);
    pg.popStyle();
  }

  // Draw one string between (x1,y1)→(x2,y2).
  // Lateral vibration from CatsCradle, plus downward gravity sag.
  void drawString(PGraphics pg, float x1, float y1, float x2, float y2,
                  float amplitude, int skip, int index, float sagOffset) {
    float dx  = x2 - x1;
    float dy  = y2 - y1;
    float len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;

    // perpendicular unit vector (for lateral vibration)
    float nx = -dy / len;
    float ny =  dx / len;

    float phaseOff = phase * (1 + skip * 0.3) + index * 0.5;

    pg.beginShape();
    for (int s = 0; s <= subdivisions; s++) {
      float t  = (float)s / subdivisions;
      float bx = lerp(x1, x2, t);
      float by = lerp(y1, y2, t);

      // lateral vibration (standing-wave harmonics, same as CatsCradle)
      float vib = 0;
      for (int h = 1; h <= skip; h++) {
        vib += sin(t * PI * h) * sin(phaseOff * h) * amplitude / h;
      }

      // gravity sag: sin envelope = 0 at both endpoints, max at midpoint
      float sagDisp = sin(t * PI) * sagOffset * len * SAG_SCALE;

      pg.vertex(bx + nx * vib, by + ny * vib + sagDisp);
    }
    pg.endShape();
  }

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void handleKey(char k) {}
}
