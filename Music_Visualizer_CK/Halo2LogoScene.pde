// Halo 2 Logo Mask Scene — state 9
//
// The Halo 2 logo is used as a mask so that plasma/color effects
// show only through the logo shape. The rest of the screen stays dark.
//
// Keyboard controls (active when STATE == 9):
//   B — cycle background effect (plasma, polar plasma, solid color)
//   Up / Down — increase / decrease pulse sensitivity
//
// The logo must be at:  data/images/halo2_logo.gif
// It should be black logo on white (or white logo on black) — both work,
// the scene auto-detects and inverts if needed.

class Halo2LogoScene {

  PImage logo;          // original logo image
  PImage maskImg;       // white-where-logo-is mask
  PGraphics canvas;     // off-screen buffer that gets masked each frame

  // Render at reduced resolution then scale up — avoids per-pixel Java loop bottleneck.
  // RENDER_SCALE = 4 means 1/16th the pixels (e.g. 640×360 instead of 2560×1440).
  final int RENDER_SCALE = 4;
  int rW, rH;  // actual render dimensions

  // logo placement (in screen coords; divide by RENDER_SCALE for render coords)
  float logoX, logoY;
  float logoW, logoH;

  // beat pulse
  float currentScale   = 1.0;
  float targetScale    = 1.0;
  float pulseSens      = 0.35;   // how much a beat expands the scale

  // background mode: 0 = plasma color sweep, 1 = polar-style, 2 = solid pulse
  int bgMode = 0;

  // colour state
  float hueShift = 0;

  boolean loaded = false;

  // ── constructor ───────────────────────────────────────────────────────────

  Halo2LogoScene() {
    logo = loadImage("images/halo2_logo.gif");
    if (logo == null || logo.width == 0) {
      println("Halo2LogoScene: could not load data/images/halo2_logo.png");
      return;
    }

    rW = width  / RENDER_SCALE;
    rH = height / RENDER_SCALE;

    // Scale logo to fit ~82% of the shorter screen dimension, keep aspect ratio
    float scale = min(width * 0.82, height * 0.82) / max(logo.width, logo.height);
    logoW = logo.width  * scale;
    logoH = logo.height * scale;
    logoX = (width  - logoW) / 2.0;
    logoY = (height - logoH) / 2.0;

    buildMask();

    canvas = createGraphics(rW, rH);
    loaded = true;
  }

  // Build a grayscale mask where the logo pixels are WHITE (visible)
  // and the background is BLACK (hidden).
  // Built at render resolution (rW × rH) to match the canvas.
  void buildMask() {
    int mW = rW;
    int mH = rH;

    // Logo dimensions and position scaled to render resolution
    int lw = max(1, (int)(logoW / RENDER_SCALE));
    int lh = max(1, (int)(logoH / RENDER_SCALE));
    int ox = (int)(logoX / RENDER_SCALE);
    int oy = (int)(logoY / RENDER_SCALE);

    PImage resized = logo.copy();
    resized.resize(lw, lh);
    resized.loadPixels();

    // Auto-detect: sample a corner to decide if background is light or dark
    boolean invertNeeded = brightness(resized.pixels[0]) > 128;

    maskImg = createImage(mW, mH, RGB);
    maskImg.loadPixels();

    for (int i = 0; i < maskImg.pixels.length; i++) {
      maskImg.pixels[i] = color(0);
    }

    for (int y = 0; y < lh; y++) {
      for (int x = 0; x < lw; x++) {
        int srcIdx = y * lw + x;
        int dstIdx = (oy + y) * mW + (ox + x);
        if (dstIdx < 0 || dstIdx >= maskImg.pixels.length) continue;
        float b = brightness(resized.pixels[srcIdx]);
        if (invertNeeded) b = 255 - b;
        maskImg.pixels[dstIdx] = color(b);
      }
    }

    maskImg.updatePixels();
  }

  // ── getCodeLines ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[] {
      "=== Halo 2 Logo Mask ===",
      "",
      "// Logo PNG loaded as a stencil mask",
      "mask: white = show effect, black = hide",
      "",
      "// Each frame:",
      "1. render colour effect to off-screen canvas",
      "2. apply logo mask  →  only logo shape visible",
      "3. draw masked canvas onto black background",
      "",
      "// Beat response:",
      "scale pulses up on onset, eases back to 1.0",
      "hue shifts continuously with mid frequency",
      "",
      "// Controls: B = cycle bg mode",
      "//           Up/Down = pulse sensitivity"
    };
  }

  // ── main draw ─────────────────────────────────────────────────────────────

  void drawScene() {
    if (!loaded) {
      background(0);
      fill(255, 0, 0);
      textAlign(CENTER, CENTER);
      textSize(20 * uiScale());
      text("Missing: data/images/halo2_logo.gif", width/2, height/2);
      return;
    }

    // --- audio analysis ---------------------------------------------------
    int fft_size = audio.fft.avgSize();
    int bass_end = max(1, fft_size / 6);
    int mid_end  = max(bass_end + 1, fft_size / 2);

    float bass  = 0, mid = 0, high = 0;
    for (int i = 0;        i < bass_end; i++) bass += audio.fft.getAvg(i);
    for (int i = bass_end; i < mid_end;  i++) mid  += audio.fft.getAvg(i);
    for (int i = mid_end;  i < fft_size; i++) high += audio.fft.getAvg(i);
    bass /= bass_end;
    mid  /= max(1, mid_end  - bass_end);
    high /= max(1, fft_size - mid_end);

    boolean is_beat = audio.beat.isOnset();

    // --- beat pulse -------------------------------------------------------
    if (is_beat) {
      targetScale = 1.0 + pulseSens * constrain(bass / 5.0, 0.3, 1.0);
    }
    currentScale += (targetScale - currentScale) * 0.18;
    targetScale  += (1.0 - targetScale) * 0.08;

    // --- hue shift driven by mids ----------------------------------------
    hueShift = (hueShift + mid * 0.4 + 0.3) % 360;

    // --- render effect into off-screen canvas ----------------------------
    canvas.beginDraw();
    drawBackground(canvas, bass, mid, high, is_beat);
    canvas.endDraw();

    // Apply logo mask to canvas
    PImage frame = canvas.get();
    frame.mask(maskImg);

    // --- composite onto black screen -------------------------------------
    background(0);

    pushMatrix();
      translate(width / 2.0, height / 2.0);
      scale(currentScale);
      translate(-width / 2.0, -height / 2.0);
      image(frame, 0, 0, width, height);  // scale rW×rH up to full screen
    popMatrix();

    // Subtle outer glow ring on beat
    if (currentScale > 1.02) {
      pushStyle();
        colorMode(HSB, 360, 255, 255, 255);
        noFill();
        float glowAlpha = map(currentScale, 1.0, 1.0 + pulseSens, 0, 180);
        stroke(hueShift, 200, 255, glowAlpha);
        strokeWeight(6);
        ellipse(width / 2.0, height / 2.0,
                logoW * currentScale * 1.05,
                logoH * currentScale * 1.05);
        strokeWeight(2);
        stroke(hueShift, 150, 255, glowAlpha * 0.5);
        ellipse(width / 2.0, height / 2.0,
                logoW * currentScale * 1.12,
                logoH * currentScale * 1.12);
        colorMode(RGB, 255);
      popStyle();
    }

    drawHUD(bass, mid, high);
    drawSongNameOnScreen(config.SONG_NAME, width / 2, height - 5);
  }

  // ── background modes ──────────────────────────────────────────────────────

  void drawBackground(PGraphics g, float bass, float mid, float high, boolean is_beat) {
    g.colorMode(HSB, 360, 255, 255, 255);
    switch (bgMode) {
      case 0: drawPlasmaSweep(g, bass, mid, high); break;
      case 1: drawRadialBurst(g, bass, mid, high); break;
      case 2: drawSolidPulse(g,  bass, mid, high, is_beat); break;
    }
    g.colorMode(RGB, 255);
  }

  // Scrolling plasma-style colour sweep — rendered at rW×rH for performance
  void drawPlasmaSweep(PGraphics g, float bass, float mid, float high) {
    g.loadPixels();
    float t = frameCount * 0.015;
    for (int y = 0; y < rH; y++) {
      for (int x = 0; x < rW; x++) {
        float nx = x / (float) rW;
        float ny = y / (float) rH;
        float v  = sin(nx * 6 + t + bass * 0.4)
                 + sin(ny * 4 - t * 0.7 + mid * 0.3)
                 + sin((nx + ny) * 5 + t * 1.3 + high * 0.2);
        float h = (hueShift + v * 40) % 360;
        float s = 200 + high * 8;
        float b = 200 + bass * 10;
        g.pixels[y * rW + x] = g.color(h, constrain(s,0,255), constrain(b,0,255));
      }
    }
    g.updatePixels();
  }

  // Radial burst from center — rendered at rW×rH for performance
  void drawRadialBurst(PGraphics g, float bass, float mid, float high) {
    g.loadPixels();
    float cx = rW / 2.0;
    float cy = rH / 2.0;
    float t  = frameCount * 0.02;
    for (int y = 0; y < rH; y++) {
      for (int x = 0; x < rW; x++) {
        float dx = x - cx;
        float dy = y - cy;
        float r  = sqrt(dx*dx + dy*dy);
        float a  = atan2(dy, dx);
        // multiply r by RENDER_SCALE so spatial frequency matches full-res version
        float v  = sin(r * 0.04 * RENDER_SCALE - t * 2 + bass * 0.5)
                 + sin(a * 3                    + t     + mid  * 0.4);
        float h  = (hueShift + v * 50) % 360;
        g.pixels[y * rW + x] = g.color(h, 220, 230 + high * 5);
      }
    }
    g.updatePixels();
  }

  // Solid colour that shifts on beat
  void drawSolidPulse(PGraphics g, float bass, float mid, float high, boolean is_beat) {
    float h = hueShift;
    float s = 200 + mid * 5;
    float b = 180 + bass * 15;
    g.background(g.color(h % 360, constrain(s,0,255), constrain(b,0,255)));
  }

  // ── HUD ───────────────────────────────────────────────────────────────────

  void drawHUD(float bass, float mid, float high) {
    String[] bgNames = {"Plasma Sweep", "Radial Burst", "Solid Pulse"};
    pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      float margin = 4 * uiScale();
      fill(0, 140);
      noStroke();
      rectMode(CORNER);
      rect(8, 8, 250 * uiScale(), margin + lh * 4);
      fill(255);
      textSize(ts);
      textAlign(LEFT, TOP);
      text("Scene: Halo 2 Logo",                              12, 8 + margin);
      text("bg: "    + bgNames[bgMode] + "  (B to cycle)",   12, 8 + margin + lh);
      text("pulse: " + nf(pulseSens, 1, 2) + "  Up/Down",    12, 8 + margin + lh*2);
      text("bass/mid/high: " + nf(bass,1,1) + " / " + nf(mid,1,1) + " / " + nf(high,1,1), 12, 8 + margin + lh*3);
    popStyle();
  }

  // ── controls ──────────────────────────────────────────────────────────────

  void cycleBgMode() {
    bgMode = (bgMode + 1) % 3;
  }

  void adjustPulseSens(float delta) {
    pulseSens = constrain(pulseSens + delta, 0.05, 1.0);
  }

  void applyController(Controller c) {
    // L Stick ↕ → pulse sensitivity (up = stronger pulse)
    float ly = map(c.ly, 0, height, -1, 1);
    pulseSens = map(ly, -1, 1, 1.0, 0.05);

    // Y button → cycle background mode (B is global blend mode, so use Y here)
    if (c.y_just_pressed) cycleBgMode();

    // A button → trigger a manual scale pulse
    if (c.a_just_pressed) targetScale = 1.0 + pulseSens * 0.9;
  }
}
