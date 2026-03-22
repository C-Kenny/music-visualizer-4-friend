// Oscilloscope / Lissajous scene  — state 5
// Left audio channel → X axis, right channel → Y axis.
//
// Frequency modulation:
//   Bass  → boosts Y scale (figure breathes vertically on bass hits)
//   High  → boosts X scale (treble widens the figure horizontally)
//   Mid   → speeds up the phosphor trail fade (busier mid = shorter trail)
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

class OscilloscopeScene {
  float gainX       = 2.2;   // user-adjustable X axis gain
  float gainY       = 2.2;   // user-adjustable Y axis gain
  float trailAlpha  = 28;    // phosphor fade opacity (lower = longer trail)
  float brightness  = 1.0;   // overall brightness multiplier

  // internal state
  float hue   = 180;
  float pulse = 0;

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
    // normalize sticks from screen-space back to -1..1
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
      "// Stroke gets thicker on loud passages",
      "stroke_weight = 1.0 + overall_volume * 3.5",
      "",
      "// Colour shifts warm on bass, cool on treble",
      "hue = hue + bass * 30 - treble * 30",
      "",
      "// Controls (keyboard):  [ ]  x_gain    - =  y_gain    ; '  trail"
    };
  }

  // --- draw -------------------------------------------------------

  void drawScene() {
    int bufSize = audio.player.bufferSize();
    int fftSize = audio.fft.avgSize();

    // --- frequency band levels --------------------------------------
    // Split FFT into bass / mid / high thirds
    int bassEnd = max(1, fftSize / 6);
    int midEnd  = max(bassEnd + 1, fftSize / 2);

    float bassAmp = 0, midAmp = 0, highAmp = 0;
    for (int i = 0;       i < bassEnd; i++) bassAmp += audio.fft.getAvg(i);
    for (int i = bassEnd; i < midEnd;  i++) midAmp  += audio.fft.getAvg(i);
    for (int i = midEnd;  i < fftSize; i++) highAmp += audio.fft.getAvg(i);
    bassAmp /= bassEnd;
    midAmp  /= max(1, midEnd  - bassEnd);
    highAmp /= max(1, fftSize - midEnd);

    // overall amplitude for stroke weight
    float amplitude = (bassAmp + midAmp + highAmp) / 3.0;

    // beat
    audio.beat.detect(audio.player.mix);
    if (audio.beat.isOnset()) pulse = 1.0;
    pulse *= 0.90;
    hue    = (hue + 0.5) % 360;

    // --- phosphor trail ---------------------------------------------
    // mid frequencies speed up the fade (busy mid = snappier trail)
    float dynamicFade = trailAlpha + midAmp * 8;
    noStroke();
    fill(0, 0, 0, constrain(dynamicFade, 5, 120));
    rect(0, 0, width, height);

    // --- axis ranges ------------------------------------------------
    // Bass expands Y, highs expand X, user gain scales both
    float xRange = (width  / 2.0) * gainX * (1.0 + highAmp * 0.4);
    float yRange = (height / 2.0) * gainY * (1.0 + bassAmp * 0.4);
    float cx = width  / 2.0;
    float cy = height / 2.0;

    // --- draw Lissajous figure --------------------------------------
    float strokeB  = constrain(brightness * 220 + pulse * 35, 80, 255);
    float weight   = constrain(1.0 + amplitude * 3.5, 0.8, 5.0);

    colorMode(HSB, 360, 255, 255, 255);
    // hue offset: bass shifts toward warm, highs toward cool
    float dynamicHue = (hue + bassAmp * 30 - highAmp * 30 + 360) % 360;
    stroke(dynamicHue, 200, (int)strokeB, 210);
    strokeWeight(weight);
    noFill();

    beginShape();
    for (int i = 0; i < bufSize; i++) {
      float x = cx + audio.player.left.get(i)  * xRange;
      float y = cy + audio.player.right.get(i) * yRange;
      vertex(x, y);
    }
    endShape();

    colorMode(RGB, 255);

    // --- beat pulse dot ---------------------------------------------
    noStroke();
    fill(255, 220, 80, (int)(pulse * 200));
    float dotSize = 4 + pulse * 28;
    ellipse(cx, cy, dotSize, dotSize);

    // --- HUD (gain + trail readout) ---------------------------------
    pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      float margin = 4 * uiScale();
      fill(0, 120);
      noStroke();
      rectMode(CORNER);
      rect(8, 8, 240 * uiScale(), margin + lh * 4);
      fill(255);
      textSize(ts);
      textAlign(LEFT, TOP);
      text("Scene: Oscilloscope",              12, 8 + margin);
      text("gainX: "  + nf(gainX, 1, 2) + "  [ / ]",    12, 8 + margin + lh);
      text("gainY: "  + nf(gainY, 1, 2) + "  - / =",    12, 8 + margin + lh*2);
      text("trail: "  + nf(trailAlpha, 1, 1) + "  ; / '", 12, 8 + margin + lh*3);
    popStyle();

    drawSongNameOnScreen(config.SONG_NAME, width / 2, height - 5);
  }
}
