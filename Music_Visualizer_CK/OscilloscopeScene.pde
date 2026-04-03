// Oscilloscope / Lissajous scene  — state 5
// Left audio channel → X axis, right channel → Y axis.
//
// Frequency modulation:
//   Bass  → boosts Y scale (figure breathes vertically on bass hits)
//   High  → boosts X scale (treble widens the figure horizontally)
//   Mid   → speeds up the phosphor trail fade (busier mid = shorter trail)
//
// Vignette: a dark ring is drawn each frame outside a circular viewport.
// Lines that escape the circle are erased almost immediately; content inside
// accumulates as a phosphor glow. After CYCLE_SECONDS the canvas fades out
// and restarts fresh so the current figure stays readable.
//
// User controls (keyboard, active when STATE == 5):
//   [ / ]   increase / decrease X gain
//   - / =   increase / decrease Y gain
//   ; / '   slower / faster trail fade
//
// Controller controls (active when STATE == 5):
//   Left stick X  →  X gain
//   Left stick Y  →  Y gain
//   Right stick Y →  trail fade speed
//   Right stick X →  overall brightness

class OscilloscopeScene implements IScene {
  float gainX       = 1.0;   // user-adjustable X axis gain
  float gainY       = 1.0;   // user-adjustable Y axis gain
  float trailAlpha  = 50;    // phosphor fade opacity (lower = longer trail)
  float brightness  = 1.0;   // overall brightness multiplier

  // internal state
  float hue   = 180;
  float pulse = 0;

  // Cycle: fade out after CYCLE_SECONDS and restart
  final int CYCLE_SECONDS   = 20;
  final int FADE_OUT_FRAMES = 50;   // ~0.8 s fade before reset
  int  cycleStartMs  = 0;
  boolean fadingOut  = false;
  int  fadeOutFrame  = 0;

  OscilloscopeScene() {}

  // --- user input -------------------------------------------------

  void adjustGainX(float delta) {
    gainX = constrain(gainX + delta, 0.5, 6.0);
  }

  void adjustGainY(float delta) {
    gainY = constrain(gainY + delta, 0.5, 6.0);
  }

  void adjustTrail(float delta) {
    trailAlpha = constrain(trailAlpha + delta, 5, 120);
  }

  void adjustBrightness(float delta) {
    brightness = constrain(brightness + delta, 0.2, 2.0);
  }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    float rx = map(c.rx, 0, width,  -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);

    gainX      = map(lx, -1, 1, 0.5, 6.0);
    gainY      = map(ly, -1, 1, 0.5, 6.0);
    trailAlpha = map(ry, -1, 1, 5,   120);
    brightness = map(rx, -1, 1, 0.3, 2.0);
  }

  // --- code overlay -----------------------------------------------

  String[] getCodeLines() {
    return new String[] {
      "=== Oscilloscope / Lissajous ===",
      "",
      "// Each audio sample plots one point on screen",
      "x = screen_center + left_channel  * x_gain * (1 + treble * 0.4)",
      "y = screen_center + right_channel * y_gain * (1 + bass   * 0.4)",
      "",
      "// Phosphor trail: old frames fade instead of clearing",
      "trail_fade = base_fade + mid_level * 8",
      "",
      "// Vignette ring: outside circle fades at trail + 160 per frame",
      "// so content can't accumulate beyond the circular boundary",
      "",
      "// Controls (keyboard):  [ ]  x_gain    - =  y_gain    ; '  trail"
    };
  }

  // --- draw -------------------------------------------------------

  void drawScene(PGraphics pg) {
    int bufSize = audio.player.bufferSize();

    float cx = pg.width  / 2.0;
    float cy = pg.height / 2.0;
    float vigR = min(pg.width, pg.height) * 0.44;   // circular viewport radius

    // --- init cycle timer on first call ----------------------------
    if (cycleStartMs == 0) cycleStartMs = pg.parent.millis();

    // --- check if it's time to fade out ----------------------------
    int elapsed = pg.parent.millis() - cycleStartMs;
    if (!fadingOut && elapsed >= CYCLE_SECONDS * 1000) {
      fadingOut   = true;
      fadeOutFrame = 0;
    }

    // --- frequency band levels -------------------------------------
    float bassAmp = analyzer.bass;
    float midAmp  = analyzer.mid;
    float highAmp = analyzer.high;
    float amplitude = (bassAmp + midAmp + highAmp) / 3.0;

    if (analyzer.isBeat) pulse = 1.0;
    pulse *= 0.90;
    hue    = (hue + 0.5) % 360;

    // --- phosphor trail: fade the whole canvas ---------------------
    float dynamicFade = fadingOut
        ? map(fadeOutFrame, 0, FADE_OUT_FRAMES, trailAlpha + midAmp * 8, 255)
        : trailAlpha + midAmp * 8;
    pg.colorMode(RGB, 255);
    pg.noStroke();
    pg.fill(0, 0, 0, constrain(dynamicFade, 5, 255));
    pg.rect(0, 0, pg.width, pg.height);

    // --- handle fade-out completion --------------------------------
    if (fadingOut) {
      fadeOutFrame++;
      if (fadeOutFrame >= FADE_OUT_FRAMES) {
        pg.background(0);
        fadingOut    = false;
        cycleStartMs = pg.parent.millis();
      }
      // skip drawing new content while fading out
      drawVignette(pg, cx, cy, vigR);
      drawHUD(pg, elapsed, vigR);
      drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
      return;
    }

    // --- axis ranges -----------------------------------------------
    float xRange = (pg.width  / 2.0) * gainX * (1.0 + highAmp * 0.4);
    float yRange = (pg.height / 2.0) * gainY * (1.0 + bassAmp * 0.4);

    // --- draw Lissajous figure -------------------------------------
    float strokeB    = constrain(brightness * 220 + pulse * 35, 80, 255);
    float weight     = constrain(1.0 + amplitude * 3.5, 0.8, 5.0);
    float dynamicHue = (hue + bassAmp * 30 - highAmp * 30 + 360) % 360;

    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.stroke(dynamicHue, 200, (int)strokeB, 210);
    pg.strokeWeight(weight);
    pg.noFill();

    pg.beginShape();
    for (int i = 0; i < bufSize; i++) {
      float x = cx + audio.player.left.get(i)  * xRange;
      float y = cy + audio.player.right.get(i) * yRange;
      pg.vertex(x, y);
    }
    pg.endShape();

    pg.colorMode(RGB, 255);

    // --- beat pulse dot --------------------------------------------
    pg.noStroke();
    pg.fill(255, 220, 80, (int)(pulse * 200));
    float dotSize = 4 + pulse * 28;
    pg.ellipse(cx, cy, dotSize, dotSize);

    // --- vignette: dark ring outside viewport ----------------------
    drawVignette(pg, cx, cy, vigR);

    // --- HUD -------------------------------------------------------
    drawHUD(pg, elapsed, vigR);

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  // Draws a dark ring over everything outside the circular viewport.
  // This prevents phosphor accumulation outside the circle and gives
  // the scene a clear bounded shape.
  void drawVignette(PGraphics pg, float cx, float cy, float vigR) {
    pg.colorMode(RGB, 255);
    pg.noStroke();
    pg.fill(0, 0, 0, 160);

    // Full-screen rect with a circular hole punched in the center.
    // The outer rectangle covers the whole canvas; the contour is the
    // counter-clockwise hole (Processing cuts it out when filled).
    pg.beginShape();
      pg.vertex(0,     0);
      pg.vertex(pg.width, 0);
      pg.vertex(pg.width, pg.height);
      pg.vertex(0,     pg.height);
      pg.beginContour();
        int pts = 80;
        for (int i = 0; i < pts; i++) {
          float a = -TWO_PI * i / pts;   // CCW = hole direction
          pg.vertex(cx + cos(a) * vigR, cy + sin(a) * vigR);
        }
      pg.endContour();
    pg.endShape(CLOSE);

    // Faint circle outline to define the viewport edge
    pg.noFill();
    pg.stroke(255, 40);
    pg.strokeWeight(1.2 * uiScale());
    pg.ellipse(cx, cy, vigR * 2, vigR * 2);
  }

  void drawHUD(PGraphics pg, int elapsedMs, float vigR) {
    float cx = pg.width / 2.0, cy = pg.height / 2.0;

    // Cycle progress arc drawn just outside the viewport ring
    float progress = constrain((float)elapsedMs / (CYCLE_SECONDS * 1000), 0, 1);
    float arcR = vigR + 6 * uiScale();
    pg.colorMode(RGB, 255);
    pg.noFill();
    pg.stroke(255, 255, 255, 35);
    pg.strokeWeight(2.5 * uiScale());
    // background dim arc (full circle)
    pg.ellipse(cx, cy, arcR * 2, arcR * 2);
    // progress arc (bright)
    pg.stroke(200, 220, 255, 120);
    pg.arc(cx, cy, arcR * 2, arcR * 2, -HALF_PI, -HALF_PI + TWO_PI * progress);

    // Text panel
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      pg.fill(0, 120); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 240 * uiScale(), mg + lh * 5);
      pg.fill(255); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Scene: Oscilloscope",                       12, 8 + mg);
      pg.text("gainX: "  + nf(gainX, 1, 2)      + "  [ / ]",   12, 8 + mg + lh);
      pg.text("gainY: "  + nf(gainY, 1, 2)      + "  - / =",   12, 8 + mg + lh * 2);
      pg.text("trail: "  + nf(trailAlpha, 1, 1) + "  ; / '",   12, 8 + mg + lh * 3);
      int secLeft = max(0, CYCLE_SECONDS - elapsedMs / 1000);
      pg.text("reset in: " + secLeft + "s" + (fadingOut ? "  (fading...)" : ""), 12, 8 + mg + lh * 4);
    pg.popStyle();
  }

  void onEnter() {
    background(0);
    cycleStartMs = millis();
    fadingOut = false;
  }

  void onExit() {}

  void handleKey(char k) {
    if (k == '[') adjustGainX(-0.1);
    else if (k == ']') adjustGainX(0.1);
    else if (k == '-') adjustGainY(-0.1);
    else if (k == '=') adjustGainY(0.1);
    else if (k == ';') adjustTrail(-2);
    else if (k == '\'') adjustTrail(2);
  }
}
