// FFT Worm Scene — state 11
//
// One enormous worm whose body IS the frequency spectrum.
// Head = sub-bass, tail = air-highs. Each segment's radius and colour
// are driven live by its corresponding FFT band.
//
// Low segments  (head)  → fat, red/orange, punchy on bass hits
// Mid segments  (body)  → medium, green/yellow, groove-locked
// High segments (tail)  → thin, cyan/blue, shimmer rapidly
// Beat                  → ripple wave shoots from head to tail + flash ring
//
// Controller:
//   L Stick       → steer the worm's head
//   R Stick ↕     → body amplitude multiplier (how reactive the worm is)
//   A             → snap the worm into a circle formation
//   B             → release / resume wandering
//   X             → reverse travel direction
//   Y             → cycle colour palette (spectrum / heat / ice / mono)
//   RT            → turbo wander speed
//   LT            → slow crawl

class FFTWormScene {

  // Segment chain
  final int   N          = 52;   // number of segments = FFT bands used
  final float SEP        = 16.0; // resting spacing (px)
  float[]     sx         = new float[N];
  float[]     sy         = new float[N];
  float       vx         = 3, vy = 1;

  // Audio snapshot — kept for drawing after update
  float[]     bandAmp    = new float[N];  // smoothed FFT per segment

  // Beat ripple: a "wave" travels from head → tail on each beat
  float[]     ripple     = new float[N];

  // Animation state
  float       noiseOff   = random(20000);
  float       speedScale = 1.0;
  float       ampMult    = 1.0;  // R-stick amplitude multiplier
  boolean     circleMode = false;
  float       circleAng  = 0;    // rotation of the circle formation
  int         palette    = 0;    // 0=spectrum, 1=heat, 2=ice, 3=mono
  boolean     reversed   = false;

  // L-stick steer
  boolean     steering   = false;
  float       steerX, steerY;

  FFTWormScene() {
    // Place worm in a horizontal line at center
    for (int i = 0; i < N; i++) {
      sx[i] = width / 2.0 - i * SEP;
      sy[i] = height / 2.0;
    }
  }

  // ── main draw ─────────────────────────────────────────────────────────────

  void drawScene() {
    // ── Audio ────────────────────────────────────────────────────────────
    boolean isBeat = audio.beat.isOnset();

    int fftSize = max(1, audio.fft.avgSize());
    for (int i = 0; i < N; i++) {
      int band = (int) map(i, 0, N - 1, 0, fftSize - 1);
      float raw = audio.fft.getAvg(band);
      bandAmp[i] = lerp(bandAmp[i], constrain(raw * ampMult, 0, 40), 0.3);
    }

    // Beat ripple: inject at head, propagate toward tail each frame
    if (isBeat) ripple[0] = 1.0;
    for (int i = N - 1; i > 0; i--) {
      ripple[i] = lerp(ripple[i], ripple[i-1], 0.5);
    }
    for (int i = 0; i < N; i++) ripple[i] *= 0.85;

    // ── Background ───────────────────────────────────────────────────────
    background(5, 5, 14);

    // Pulsing dark aura on bass
    float bass = bandAmp[0];
    if (bass > 2) {
      colorMode(HSB, 360, 255, 255, 255);
      noStroke(); noFill();
      for (int r = 3; r > 0; r--) {
        fill(240, 200, 100, bass * 1.2 * r);
        ellipse(sx[0], sy[0], bass * 14 * r, bass * 14 * r);
      }
      colorMode(RGB, 255);
    }

    // ── Move head ─────────────────────────────────────────────────────────
    if (!circleMode) {
      float mid = 0;
      for (int i = N/3; i < 2*N/3; i++) mid += bandAmp[i];
      mid /= (N / 3.0);

      if (steering) {
        float dx = steerX - sx[0], dy = steerY - sy[0];
        float d  = max(dist(sx[0], sy[0], steerX, steerY), 1);
        vx += dx / d * 1.5;
        vy += dy / d * 1.5;
      } else {
        float t      = frameCount * 0.003 + noiseOff;
        float wander = noise(sx[0] * 0.003 + noiseOff,
                             sy[0] * 0.003 + noiseOff * 1.6, t) * TWO_PI * 2.5;
        vx += cos(wander) * 0.3 * (1 + mid * 0.04);
        vy += sin(wander) * 0.3 * (1 + mid * 0.04);
      }

      float topSpeed = (5.5 + bass * 0.15) * speedScale;
      float spd = dist(0, 0, vx, vy);
      if (spd > topSpeed) { vx = vx / spd * topSpeed; vy = vy / spd * topSpeed; }

      float mg = 120;
      if (sx[0] < mg)          vx += 0.7;
      if (sx[0] > width  - mg) vx -= 0.7;
      if (sy[0] < mg)          vy += 0.7;
      if (sy[0] > height - mg) vy -= 0.7;

      sx[0] = constrain(sx[0] + vx, 0, width);
      sy[0] = constrain(sy[0] + vy, 0, height);

      // Segments follow head
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
    } else {
      // Circle formation: worm coils into a circle
      circleAng += 0.01 * speedScale;
      float cx  = width / 2.0, cy = height / 2.0;
      float rad = min(width, height) * 0.28;
      for (int i = 0; i < N; i++) {
        float a   = circleAng + TWO_PI * i / N;
        float tx  = cx + cos(a) * rad;
        float ty  = cy + sin(a) * rad;
        sx[i] = lerp(sx[i], tx, 0.08);
        sy[i] = lerp(sy[i], ty, 0.08);
      }
    }

    // ── Draw segments tail → head ─────────────────────────────────────────
    // Each segment wiggles perpendicular to the body by its band amplitude.
    // High-freq tail: fast small shimmers. Low-freq head: slow big sways.
    // This makes the frequency mapping physically obvious.
    colorMode(HSB, 360, 255, 255, 255);
    noStroke();

    for (int ii = N - 1; ii >= 0; ii--) {
      int i       = reversed ? (N - 1 - ii) : ii; // which FFT band
      int drawIdx = ii;                             // position in chain

      float amp = bandAmp[i];
      float rip = ripple[drawIdx];
      float t   = (float)drawIdx / (N - 1);  // 0=head, 1=tail

      // ── Perpendicular wiggle — subtle, keeps worm shape intact ───────
      float perp_dx = (drawIdx < N-1) ? sx[drawIdx] - sx[drawIdx+1] : vx;
      float perp_dy = (drawIdx < N-1) ? sy[drawIdx] - sy[drawIdx+1] : vy;
      float perp_len = dist(0, 0, perp_dx, perp_dy);
      float px = 0, py = 0;
      if (perp_len > 0.01) { px = -perp_dy / perp_len; py = perp_dx / perp_len; }

      // High-freq tail shimmers fast; bass head sways slow
      float freqSpeed = map(i, 0, N-1, 0.04, 0.35);
      float wiggleAmt = sin(frameCount * freqSpeed + drawIdx * 0.6) * amp * 0.45;
      float wx = sx[drawIdx] + px * wiggleAmt;
      float wy = sy[drawIdx] + py * wiggleAmt;

      // ── Radius: capped so it always reads as a worm ───────────────────
      // Bass segments are thicker, high-freq tail is thin.
      // amp contribution is small and capped — size shows presence, not volume.
      float r = constrain(lerp(14, 3, t) + amp * 0.5 + rip * 5, 3, 24);

      // ── Colour ───────────────────────────────────────────────────────
      float hue;
      switch (palette) {
        case 1:  hue = map(t, 0, 1, 0,   60);  break; // heat
        case 2:  hue = map(t, 0, 1, 180, 260); break; // ice
        case 3:  hue = 140; break;                      // mono
        default: hue = map(t, 0, 1, 0, 270); break;    // spectrum
      }
      // Beat ripple flashes the segment bright
      float sat = map(rip, 0, 1, 210, 70);
      float bri = map(rip, 0, 1, 220, 255);

      // ── Glow (soft aura, kept subtle) ────────────────────────────────
      float glowR = r * 2.0 + amp * 0.6;
      float glowA = constrain(lerp(40, 6, t) + amp * 1.5 + rip * 50, 0, 200);
      fill(hue, sat, bri, glowA);
      ellipse(wx, wy, glowR, glowR);

      // ── 3D sphere shading — light from top-left ───────────────────────
      // Shadow base (dark underside)
      fill(hue, sat, bri * 0.50);
      ellipse(wx, wy, r * 2, r * 2);

      // Mid-tone body (lit face)
      fill(hue, (int)(sat * 0.80), (int)(bri * 0.85));
      ellipse(wx - r * 0.13, wy - r * 0.13, r * 1.65, r * 1.65);

      // Bright face (top-left lit region)
      fill(hue, (int)(sat * 0.55), bri);
      ellipse(wx - r * 0.22, wy - r * 0.22, r * 1.05, r * 1.05);

      // Specular highlight (white glint)
      if (r > 4) {
        fill(0, 0, 255, 220);   // white in HSB
        ellipse(wx - r * 0.30, wy - r * 0.30, r * 0.42, r * 0.42);
      }
    }

    // ── Eyes on head ──────────────────────────────────────────────────────
    {
      float headR   = constrain(14 + bandAmp[0] * 0.5 + ripple[0] * 5, 8, 24);
      float faceAng = atan2(vy, vx);
      float perpX   = cos(faceAng + HALF_PI);
      float perpY   = sin(faceAng + HALF_PI);
      float eyeOff  = headR * 0.38;
      float eyeR    = headR * 0.34;
      float pupilR  = eyeR  * 0.52;
      float lookX   = cos(faceAng) * pupilR * 0.3;
      float lookY   = sin(faceAng) * pupilR * 0.3;

      fill(0, 0, 255);
      ellipse(sx[0] + perpX * eyeOff, sy[0] + perpY * eyeOff, eyeR * 2, eyeR * 2);
      ellipse(sx[0] - perpX * eyeOff, sy[0] - perpY * eyeOff, eyeR * 2, eyeR * 2);
      fill(0, 0, 0);
      ellipse(sx[0] + perpX * eyeOff + lookX, sy[0] + perpY * eyeOff + lookY, pupilR, pupilR);
      ellipse(sx[0] - perpX * eyeOff + lookX, sy[0] - perpY * eyeOff + lookY, pupilR, pupilR);
    }

    colorMode(RGB, 255);

    // ── HUD ──────────────────────────────────────────────────────────────
    String[] palNames = {"Spectrum", "Heat", "Ice", "Mono"};
    pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      fill(0, 160); noStroke(); rectMode(CORNER);
      rect(8, 8, 310 * uiScale(), mg + lh * 5);
      fill(80, 200, 255); textSize(ts); textAlign(LEFT, TOP);
      text("FFT Worm  (" + N + " bands)",                             12, 8 + mg);
      fill(180, 220, 255);
      text("Palette: " + palNames[palette] + "  (Y cycle)",           12, 8 + mg + lh);
      text("Reactivity: " + nf(ampMult,1,2) + "  (R ↕)",             12, 8 + mg + lh * 2);
      text("Speed: " + nf(speedScale,1,2) + "  (LT / RT)",           12, 8 + mg + lh * 3);
      text("A=circle  B=wander  X=reverse  L=steer",                  12, 8 + mg + lh * 4);
    popStyle();

    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
  }

  // ── controller ────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // L Stick: steer
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    steering = sqrt(lx*lx + ly*ly) > 0.18;
    if (steering) { steerX = c.lx; steerY = c.ly; }

    // R Stick ↕: amplitude multiplier
    float ry = map(c.ry, 0, height, -1, 1);
    ampMult = map(ry, -1, 1, 3.0, 0.3);

    // Triggers: speed via combined Z axis
    try {
      float z = c.stick.getSlider("z").getValue();
      speedScale = map(z, -1, 1, 0.2, 2.5);
    } catch (Exception e) { /* no trigger axis */ }

    // Buttons
    if (c.a_just_pressed) { circleMode = true; }
    if (c.b_just_pressed) { circleMode = false; }
    if (c.x_just_pressed) { reversed   = !reversed; }
    if (c.y_just_pressed) { palette    = (palette + 1) % 4; }
  }

  String[] getCodeLines() {
    return new String[] {
      "=== FFT Worm Controls ===",
      "",
      "L Stick      steer the worm's head",
      "R Stick ↕    body reactivity",
      "Z axis       slow (LT) / turbo (RT)",
      "",
      "A            coil into circle",
      "B            resume wandering",
      "X            reverse (highs at head)",
      "Y            cycle colour palette",
      "",
      "LB / RB      prev / next scene",
      "` (backtick) toggle this overlay",
      "",
      "=== Audio ===",
      "Head (bass)  fat + slow sway",
      "Body (mid)   medium bounce",
      "Tail (high)  thin + fast shimmer",
      "Beat         ripple head → tail",
    };
  }
}
