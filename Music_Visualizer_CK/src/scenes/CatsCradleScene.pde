// Cat's Cradle scene — audio-reactive string web
// Switch to it with the '4' key.
// Strings vibrate perpendicular to their axis, driven by FFT bands.
// Beat onsets pulse the anchor ring outward and spin it.

class CatsCradleScene implements IScene {
  int    numAnchors   = 8;
  int    subdivisions = 28;
  float  phase        = 0;
  float  pulse        = 0;
  float  rotation     = 0;
  float  rotationSpeed = 0.002;

  // New state
  int    rotDir       = 1;     // +1 / -1, flipped by bass drops or B
  float  bassEnv      = 0;     // smoothed bass for breath + drop detection
  float  bassPrev     = 0;
  float  breathPhase  = 0;
  int    paletteIdx   = 0;
  boolean trailMode   = false; // trail fade vs hard clear (default: hard clear)
  boolean glowOn      = false; // opt-in — additive glow can saturate on bright frames

  // Palettes: {hueStart, hueEnd} sweeps across skip levels
  final float[][] palettes = {
    {270, 180},  // purple -> cyan (orig)
    {  0,  60},  // red -> orange
    {120, 200},  // green -> teal
    {320,  30},  // magenta -> yellow (wraps)
    { 40, 320}   // gold -> violet
  };
  final String[] paletteNames = {"Purple-Cyan","Fire","Forest","Sunset","Gold-Violet"};

  // Glow shader (shared with RecursiveMandala)
  PShader glowShader;
  PGraphics glowBuf;

  CatsCradleScene() {}

  void applyController(Controller c) {
    float ly = map(c.ly, 0, height, -1, 1);
    rotationSpeed = map(ly, -1, 1, 0.008, 0.0004);

    float rx = map(c.rx, 0, width, -1, 1);
    int newAnchors = round(map(rx, -1, 1, 4, 14));
    numAnchors = constrain(newAnchors, 4, 14);

    if (c.aJustPressed) pulse = 1.0;
    if (c.bJustPressed) rotDir = -rotDir;
    if (c.yJustPressed) paletteIdx = (paletteIdx + 1) % palettes.length;
    if (c.xJustPressed) trailMode = !trailMode;
    if (c.leftStickClickJustPressed) glowOn = !glowOn;
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
    // Lazy-load shader + glow buffer
    if (glowShader == null) {
      try { glowShader = loadShader("mandala_glow.glsl"); } catch (Exception e) { glowOn = false; }
    }
    if (glowOn && (glowBuf == null || glowBuf.width != pg.width/2 || glowBuf.height != pg.height/2)) {
      glowBuf = createGraphics(pg.width/2, pg.height/2, P3D);
      glowBuf.smooth(4);
      glowBuf.beginDraw(); glowBuf.background(0); glowBuf.endDraw();
    }

    // Trail fade: low-alpha black rect instead of hard clear -> motion trails.
    // Alpha scales with framerate — at 1000fps a low alpha never clears,
    // trails accumulate to white. Target ~20% decay per logical frame @ 60hz.
    if (trailMode) {
      float fadeAlpha = constrain(90.0 * (60.0 / max(30.0, frameRate)), 12, 160);
      pg.noStroke();
      pg.fill(0, fadeAlpha);
      pg.rect(0, 0, pg.width, pg.height);
    } else {
      pg.background(0);
    }

    // --- audio sampling -------------------------------------------------
    float amplitude = 0;
    if (analyzer.isBeat) {
      pulse    = 1.0;
      rotation += 0.08 * rotDir;
    }
    for (int i = 0; i < analyzer.spectrum.length; i++) {
      amplitude += analyzer.spectrum[i];
    }
    amplitude /= analyzer.spectrum.length;
    pulse    *= 0.88;
    phase    += 0.04;
    rotation += rotationSpeed * rotDir;

    // Bass envelope + drop-detection for auto flip
    bassEnv = lerp(bassEnv, analyzer.bass, 0.12);
    // Drop detected when bass was high and crashes: flip rotation direction.
    if (bassPrev > 0.65 && analyzer.bass < 0.25) rotDir = -rotDir;
    bassPrev = lerp(bassPrev, analyzer.bass, 0.25);

    // Breath: slow sine + bass envelope modulate ring radius
    breathPhase += 0.012;
    float breath = 1.0 + sin(breathPhase) * 0.10 + bassEnv * 0.18;

    // --- layout ---------------------------------------------------------
    float baseRadius = min(pg.width, pg.height) * 0.34;
    float r = baseRadius * breath * (1.0 + pulse * 0.08);

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

        // colour: hue sweeps across selected palette range
        pg.colorMode(HSB, 360, 255, 255, 255);
        float hueA = palettes[paletteIdx][0], hueB = palettes[paletteIdx][1];
        float hue   = (map(skip, 1, numAnchors / 2.0, hueA, hueB) + 360) % 360;
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

    // Glow shader disabled — additive blending on large halos causes white-out
    // The shader approach (8-tap ring sample + additive blend) compounds across the scene
    // even with minimal parameters. Disable L3 glow button for now.
    
    // if (glowOn && glowShader != null && glowBuf != null) {
    //   glowBuf.beginDraw();
    //   glowBuf.background(0);
    //   glowBuf.image(pg, 0, 0, glowBuf.width, glowBuf.height);
    //   glowBuf.endDraw();
    //   float gs = constrain(0.08 + analyzer.high * 0.08 + pulse * 0.05, 0, 0.25);
    //   float gr = constrain(0.8 + analyzer.mid * 0.4 + pulse * 0.2, 0.8, 1.5);
    //   glowShader.set("glowStrength", gs);
    //   glowShader.set("glowRadius",   gr);
    //   pg.shader(glowShader);
    //   pg.image(glowBuf, 0, 0, pg.width, pg.height);
    //   pg.resetShader();
    // }

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);

    sceneHUD(pg, "Cat's Cradle", new String[]{
      "anchors: " + numAnchors + "  speed: " + nf(rotationSpeed, 1, 4) + "  dir: " + (rotDir>0?"CW":"CCW"),
      "palette: " + paletteNames[paletteIdx] + "  trails: " + (trailMode?"ON":"OFF") + "  glow: " + (glowOn?"ON":"OFF"),
      "L\u2195 speed  R\u2194 anchors  A pulse  B flip  Y palette  X trails  L3 glow"
    });
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

  void handleKey(char k) {
    if      (k == 'f' || k == 'F') rotDir = -rotDir;
    else if (k == 'p' || k == 'P') paletteIdx = (paletteIdx + 1) % palettes.length;
    else if (k == 't' || k == 'T') trailMode = !trailMode;
    else if (k == 'g' || k == 'G') glowOn = !glowOn;
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("LStick ↕", "Rotation speed"),
      new ControllerLayout("RStick ↔", "Number of anchors (4–14)"),
      new ControllerLayout("A Button", "Inject beat pulse"),
      new ControllerLayout("B Button", "Flip rotation direction"),
      new ControllerLayout("Y Button", "Cycle palette"),
      new ControllerLayout("X Button", "Toggle trail fade"),
      new ControllerLayout("L3",       "Toggle glow shader")
    };
  }
}
