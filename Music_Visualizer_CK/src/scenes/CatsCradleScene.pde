// Cat's Cradle scene — audio-reactive string web
// Switch to it with the '4' key.
// Strings vibrate perpendicular to their axis, driven by FFT bands.
// Beat onsets pulse the anchor ring outward and spin it.

class CatsCradleScene implements IScene {
  int    numAnchors   = 8;     // points evenly spaced on the ring
  int    subdivisions = 28;    // segments per string (more = smoother vibration)
  float  phase        = 0;     // master phase for string oscillation
  float  pulse        = 0;     // decaying beat-pulse value
  float  rotation     = 0;     // slow rotation of the whole frame
  float  rotationSpeed = 0.002; // controllable rotation speed (default matches original)

  CatsCradleScene() {}

  void applyController(Controller c) {
    // L Stick ↕ → rotation speed (up = faster, down = slower)
    float ly = map(c.ly, 0, height, -1, 1);
    rotationSpeed = map(ly, -1, 1, 0.008, 0.0004);

    // R Stick ↔ → numAnchors (4–14)
    float rx = map(c.rx, 0, width, -1, 1);
    int newAnchors = round(map(rx, -1, 1, 4, 14));
    numAnchors = constrain(newAnchors, 4, 14);

    // A button → inject a manual beat pulse
    if (c.aJustPressed) pulse = 1.0;
  }

  // --- code overlay -----------------------------------------------

  String[] getCodeLines() {
    return new String[] {
      "=== Cat's Cradle ===",
      "",
      "// Anchor points evenly spaced on a rotating ring",
      "anchor_x = cos(2*PI * i / num_anchors + rotation) * ring_radius",
      "anchor_y = sin(2*PI * i / num_anchors + rotation) * ring_radius",
      "",
      "// Ring pulses outward on each beat",
      "ring_radius = base_radius * (1 + beat_pulse * 0.08)",
      "rotation   += 0.002 each frame,  +0.08 on beat",
      "",
      "// Each string vibrates as a standing wave",
      "// t = position along string (0 to 1)",
      "vibration = sum over harmonics of:",
      "  sin(t * PI * harmonic) * sin(phase * harmonic) * fft_band / harmonic",
      "",
      "// Colour: purple (adjacent) → cyan (crossing strings)",
      "hue = map(skip, 1, num_anchors/2, 270, 180)"
    };
  }

  void drawScene(PGraphics pg) {
    pg.background(0);

    // --- audio sampling -------------------------------------------------
    float amplitude = 0;
    if (analyzer.isBeat) {
      pulse    = 1.0;
      rotation += 0.08;      // spin jolt on beat
    }
    for (int i = 0; i < analyzer.spectrum.length; i++) {
      amplitude += analyzer.spectrum[i];
    }
    amplitude /= analyzer.spectrum.length;
    pulse    *= 0.88;
    phase    += 0.04;
    rotation += rotationSpeed;

    // --- layout ---------------------------------------------------------
    float baseRadius = min(pg.width, pg.height) * 0.38;
    float r = baseRadius * (1.0 + pulse * 0.08);

    float[] ax = new float[numAnchors];
    float[] ay = new float[numAnchors];
    for (int i = 0; i < numAnchors; i++) {
      float a = TWO_PI * i / numAnchors + rotation;
      ax[i] = pg.width  / 2.0 + cos(a) * r;
      ay[i] = pg.height / 2.0 + sin(a) * r;
    }

    // --- draw strings ---------------------------------------------------
    // skip=1 → adjacent edges (outer ring)
    // skip=2 → every-other (star)
    // skip=3 → skip-two (inner cross), etc.
    for (int skip = 1; skip <= numAnchors / 2; skip++) {
      for (int i = 0; i < numAnchors; i++) {
        int j = (i + skip) % numAnchors;

        // map this string to an FFT band
        int band = ((skip - 1) * numAnchors + i) % analyzer.spectrum.length;
        float bandAmp = analyzer.spectrum[band] * 3.0;

        // colour: hue sweeps from purple → cyan as skip increases
        pg.colorMode(HSB, 360, 255, 255, 255);
        float hue   = map(skip, 1, numAnchors / 2.0, 270, 180);
        float alpha = map(skip, 1, numAnchors / 2.0, 220, 100);
        float weight = map(skip, 1, numAnchors / 2.0, 2.0, 0.8);
        pg.stroke((int)hue, 210, 255, (int)alpha);
        pg.strokeWeight(weight);
        pg.colorMode(RGB, 255);
        pg.noFill();

        drawString(pg, ax[i], ay[i], ax[j], ay[j], bandAmp, skip, i);
      }
    }

    // --- anchor dots ----------------------------------------------------
    pg.noStroke();
    for (int i = 0; i < numAnchors; i++) {
      float glow = 6 + pulse * 22;
      pg.fill(255, 220, 80, 70);
      pg.ellipse(ax[i], ay[i], glow * 2, glow * 2);
      pg.fill(255, 240, 160);
      pg.ellipse(ax[i], ay[i], glow * 0.4, glow * 0.4);
    }

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);

    // ── top-left HUD ──────────────────────────────────────────────────────
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 6 * uiScale();
      pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 310 * uiScale(), mg * 2 + lh * 2);
      pg.fill(255, 220, 120); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Cat's Cradle  (anchors: " + numAnchors + "  speed: " + nf(rotationSpeed, 1, 4) + ")", 12, 8 + mg);
      pg.fill(200, 200, 200);
      pg.text("L \u2195 rotation speed   R \u2194 anchor count   A beat pulse", 12, 8 + mg + lh);
    pg.popStyle();
  }

  // Draw one vibrating string between (x1,y1) and (x2,y2).
  // Vibration is a sum of harmonics — richer for strings that cross more points.
  void drawString(PGraphics pg, float x1, float y1, float x2, float y2,
                  float amplitude, int skip, int index) {
    float dx  = x2 - x1;
    float dy  = y2 - y1;
    float len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;

    // perpendicular unit vector
    float nx = -dy / len;
    float ny =  dx / len;

    float phaseOff = phase * (1 + skip * 0.3) + index * 0.5;

    pg.beginShape();
    for (int s = 0; s <= subdivisions; s++) {
      float t  = (float)s / subdivisions;
      float bx = lerp(x1, x2, t);
      float by = lerp(y1, y2, t);

      // standing-wave vibration: sum of harmonics up to `skip`
      float vib = 0;
      for (int h = 1; h <= skip; h++) {
        vib += sin(t * PI * h) * sin(phaseOff * h) * amplitude / h;
      }
      pg.vertex(bx + nx * vib, by + ny * vib);
    }
    pg.endShape();
  }

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void handleKey(char k) {}

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("LStick ↕", "Rotation speed"),
      new ControllerLayout("RStick ↔", "Number of anchors (4–14)"),
      new ControllerLayout("A Button", "Inject beat pulse")
    };
  }
}
