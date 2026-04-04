// KaleidoscopeScene — Scene 24
//
// A GPU glass kaleidoscope.  A structured source buffer (concentric coloured
// rings + radial spokes + caustic highlights) is folded by kaleidoscope.glsl
// into N mirror-symmetric wedges.  The shader adds chromatic aberration,
// mirror-seam shadow, specular glint, thin-film iridescence, and vignette so
// the result looks like a real stained-glass kaleidoscope toy.
//
// Source layout (half-res for performance):
//   Rings   — thick concentric arcs of shifting HSB colour (the glass panels)
//   Spokes  — thin radial lines (the lead / solder dividers between panels)
//   Caustics— small bright soft blobs (focused light through glass)
//   Core    — bass-driven central glow (the light source)
//   Trail   — very slow fade for layered depth
//
// Audio:
//   Bass  → core glow radius + zoom pulse
//   Mid   → ring hue speed + fold rotation speed
//   High  → caustic brightness + chromatic aberration
//   Beat  → soft warm pulse (no strobe)
//
// Controller (R-stick deliberately left unbound — too easy to spoil the look):
//   L Stick X   → manual rotation
//   L Stick Y   → zoom
//   LT / RT     → slower / faster auto-rotation
//   A           → segments +2  (use to explore: 4 / 6 / 8 / 10 / 12 / 16 / 20)
//   B           → segments −2
//   Y           → cycle glass palette
//   X           → reset everything
//
// Keys:
//   a/A   → toggle auto-rotate
//   [/]   → segments −/+
//   -/=   → rotation speed −/+
//   c/C   → hue offset +30°
//   z/Z   → zoom out / in
//   f/F   → flip rotation direction
//   r/R   → reset all

class KaleidoscopeScene implements IScene {

  // ── Tuneable parameters ────────────────────────────────────────────────────
  int     segments    = 12;
  float   rotSpeed    = 0.003;
  // zoom 0.65 ensures the shader's maximum sample radius (0.707 * zoom ≈ 0.46)
  // stays within the source content circle (maxR ≈ 0.48 of source height).
  float   zoom        = 0.65;
  float   hueOffset   = 0;
  float   trailAlpha  = 10;
  boolean autoRotate  = true;
  boolean flipDir     = false;

  // ── Glass palettes ─────────────────────────────────────────────────────────
  final String[] paletteNames = { "Cobalt",  "Amber",  "Viridian", "Rose"  };
  final float[]  paletteHues  = { 210,        35,        155,        330    };
  int paletteIdx = 0;

  // ── Smoothed audio ─────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0;

  // ── Runtime state ──────────────────────────────────────────────────────────
  float rotation  = 0;
  float manualRot = 0;
  float beatFlash = 0;
  float noiseTime = 0;
  float lt = 0, rt = 0;

  // ── Shader + half-resolution source buffer ─────────────────────────────────
  PShader   kaleidoShader;
  PGraphics srcBuf;

  KaleidoscopeScene() {}

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  void onEnter() {
    rotation = 0; manualRot = 0;
    zoom = 0.65; beatFlash = 0;
    kaleidoShader = loadShader("kaleidoscope.glsl");
    srcBuf = createGraphics(width / 2, height / 2, P3D);
    srcBuf.beginDraw(); srcBuf.background(0); srcBuf.endDraw();
  }

  void onExit() {}

  // ── Main render ─────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    if (srcBuf == null || srcBuf.width != pg.width/2 || srcBuf.height != pg.height/2) {
      srcBuf = createGraphics(pg.width/2, pg.height/2, P3D);
      srcBuf.beginDraw(); srcBuf.background(0); srcBuf.endDraw();
    }
    if (kaleidoShader == null) kaleidoShader = loadShader("kaleidoscope.glsl");

    sBass  = lerp(sBass,  analyzer.bass,  0.12);
    sMid   = lerp(sMid,   analyzer.mid,   0.10);
    sHigh  = lerp(sHigh,  analyzer.high,  0.16);

    if (analyzer.isBeat) beatFlash = 0.35;
    beatFlash = max(0, beatFlash - 0.016);

    float dir    = flipDir ? -1 : 1;
    float spdMod = 1.0 + sMid * 0.5 + (rt - lt) * 1.2;
    if (autoRotate) rotation += dir * rotSpeed * spdMod;
    rotation += manualRot;
    manualRot *= 0.88;

    drawGlassSource(srcBuf);

    float liveZoom = zoom * (1.0 + sBass * 0.06);  // gentle bass pulse

    kaleidoShader.set("segments",  (float) segments);
    kaleidoShader.set("rotation",  rotation);
    kaleidoShader.set("zoom",      liveZoom);
    kaleidoShader.set("chromaAmt", 0.022 + sHigh * 0.025);  // visible aberration
    kaleidoShader.set("seamWidth", 0.14);
    kaleidoShader.set("seamDark",  0.65);

    pg.background(0);
    pg.shader(kaleidoShader);
    pg.image(srcBuf, 0, 0, pg.width, pg.height);
    pg.resetShader();

    // Subtle warm beat pulse — no strobe
    if (beatFlash > 0.02) {
      pg.blendMode(ADD);
      pg.noStroke(); pg.fill(50, 25, 0, beatFlash * 16);
      pg.rect(0, 0, pg.width, pg.height);
      pg.blendMode(BLEND);
    }

    drawHUD(pg);
    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width * 0.5, pg.height - 8);
  }

  // ── Glass source content ────────────────────────────────────────────────────
  // Structured rings + spokes give a clear stained-glass panel layout.
  // The slow trail creates depth; caustics add the "light through glass" sparkle.

  void drawGlassSource(PGraphics src) {
    src.beginDraw();
    src.colorMode(HSB, 360, 255, 255, 255);

    // Trail fade — very slow for layered glass depth
    src.blendMode(BLEND);
    src.noStroke();
    src.fill(0, 0, 0, trailAlpha);
    src.rect(0, 0, src.width, src.height);

    // maxR fills ~96% of the source's inscribed circle, which maps safely to
    // the screen edge at zoom=0.65 (max sample radius = 0.46 of source height).
    float cx   = src.width  * 0.5;
    float cy   = src.height * 0.5;
    float maxR = min(src.width, src.height) * 0.48;

    noiseTime += 0.0015 + sMid * 0.0018;
    float baseHue = paletteHues[paletteIdx] + hueOffset;

    // ── Concentric ring panels (the glass panes) ─────────────────────────────
    // Each ring is a thick arc — stroke only, no fill — so gaps between rings
    // are naturally dark, like the lead lines in stained glass.
    src.blendMode(BLEND);
    src.noFill();
    int numRings = 6;
    for (int ri = numRings; ri >= 1; ri--) {
      float r    = maxR * ri / numRings;
      float w    = maxR / numRings * 0.72;  // ring width; gap = remaining 28%
      float hue  = (baseHue + ri * 52 + noiseTime * 4) % 360;
      float sat  = 200 + noise(ri, noiseTime * 0.6) * 45;
      float bri  = 155 + sBass * 40 * (ri == 1 ? 1 : 0.3)
                       + noise(ri * 3, noiseTime * 0.8) * 65;
      float alph = 200;

      src.stroke(hue, sat, bri, alph);
      src.strokeWeight(w);
      src.ellipse(cx, cy, r * 2, r * 2);
    }

    // ── Radial spokes (the lead dividers between panels) ─────────────────────
    // A small number of softly-coloured lines from centre to edge.
    // When folded N times, these create the radial symmetry lines.
    src.strokeWeight(1.8);
    int numSpokes = 8;
    for (int si = 0; si < numSpokes; si++) {
      float ang  = TWO_PI * si / numSpokes + noiseTime * 0.06;
      float hue  = (baseHue + 180 + si * 45 + noiseTime * 3) % 360;
      float sat  = 160 + noise(si * 5, noiseTime * 0.5) * 60;
      float bri  = 200;
      float alph = 140 + noise(si * 7, noiseTime) * 60;
      float innerR = maxR * 0.10;

      src.stroke(hue, sat, bri, alph);
      src.line(cx + cos(ang) * innerR, cy + sin(ang) * innerR,
               cx + cos(ang) * maxR,   cy + sin(ang) * maxR);
    }

    // ── Caustic highlights (light focused through curved glass) ───────────────
    src.blendMode(ADD);
    src.noStroke();
    int numCaustics = 5;
    for (int i = 0; i < numCaustics; i++) {
      float ang  = noise(i * 11.3, noiseTime * 0.5) * TWO_PI;
      float r    = maxR * (0.15 + noise(i * 8.7, noiseTime * 0.4) * 0.70);
      float ex   = cx + cos(ang) * r;
      float ey   = cy + sin(ang) * r;
      float sz   = 12 + noise(i * 6.1, noiseTime * 0.7) * 20 + sHigh * 14;
      float hue  = (baseHue + 60 + noise(i, noiseTime * 0.3) * 50) % 360;
      float alph = 14 + sHigh * 20 + noise(i * 4.4, noiseTime * 0.5) * 12;

      src.fill(hue, 90, 255, alph * 0.4);
      src.ellipse(ex, ey, sz * 2.4, sz * 2.4);
      src.fill(hue, 60, 255, alph);
      src.ellipse(ex, ey, sz, sz);
    }

    // ── Central light source (bass-driven) ────────────────────────────────────
    float coreR = maxR * (0.07 + sBass * 0.10);
    float cHue  = (baseHue + 40) % 360;
    for (float rr = coreR * 2.2; rr > 1.5; rr *= 0.60) {
      float a = map(rr, 1.5, coreR * 2.2, 180 + sBass * 55, 6);
      src.noStroke();
      src.fill(cHue, 90, 255, a);
      src.ellipse(cx, cy, rr * 2, rr * 2);
    }

    // ── Beat pulse ─────────────────────────────────────────────────────────────
    if (beatFlash > 0.02) {
      src.noStroke();
      src.fill(cHue, 70, 255, beatFlash * 50);
      src.ellipse(cx, cy, maxR * 0.60 * beatFlash, maxR * 0.60 * beatFlash);
    }

    src.colorMode(RGB, 255);
    src.blendMode(BLEND);
    src.endDraw();
  }

  // ── HUD ─────────────────────────────────────────────────────────────────────

  void drawHUD(PGraphics pg) {
    pg.pushStyle();
    float ts = 11 * uiScale(), lh = ts * 1.35;
    pg.noStroke(); pg.rectMode(CORNER);
    pg.fill(0, 150);
    pg.rect(8, 8, 415 * uiScale(), 8 + lh * 8);
    pg.textSize(ts); pg.textAlign(LEFT, TOP);
    pg.fill(100, 220, 255);
    pg.text("=== Kaleidoscope ===", 12, 12);
    pg.fill(180, 230, 255);
    pg.text("Bass:" + nf(sBass,1,2) + "  Mid:" + nf(sMid,1,2) + "  High:" + nf(sHigh,1,2),
            12, 12 + lh);
    pg.text("Segments:" + segments +
            "  Zoom:" + nf(zoom,1,2) +
            "  RotSpd:" + nf(rotSpeed,1,3),
            12, 12 + lh * 2);
    pg.text("Palette:" + paletteNames[paletteIdx] +
            "  Trail:" + nf(trailAlpha,1,0) +
            "  AutoRot:" + (autoRotate ? "ON" : "OFF") +
            "  Dir:" + (flipDir ? "CCW" : "CW"),
            12, 12 + lh * 3);
    pg.fill(120, 180, 220);
    pg.text("A segs+2  B segs-2  Y palette  X reset", 12, 12 + lh * 4.8);
    pg.text("L-stick rotate/zoom  LT slow  RT fast",  12, 12 + lh * 5.8);
    pg.text("[/] segs  -/= speed  z/Z zoom  c hue  f flip  a auto  r reset",
            12, 12 + lh * 6.8);
    pg.popStyle();
  }

  // ── Controller ──────────────────────────────────────────────────────────────
  // R-stick intentionally unbound — it was too easy to accidentally change
  // segments/trail and make the scene look wrong.

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    if (abs(lx) > 0.12) manualRot += lx * 0.025;
    if (abs(ly) > 0.12) zoom = constrain(zoom - ly * 0.015, 0.30, 0.85);

    try {
      float z = c.stick.getSlider("z").getValue();
      lt = max(0, -z); rt = max(0, z);
    } catch (Exception e) { lt = 0; rt = 0; }

    if (c.a_just_pressed) segments   = constrain(segments + 2, 4, 24);
    if (c.b_just_pressed) segments   = constrain(segments - 2, 4, 24);
    if (c.y_just_pressed) paletteIdx = (paletteIdx + 1) % paletteNames.length;
    if (c.x_just_pressed) {
      zoom = 0.65; manualRot = 0; rotSpeed = 0.003; segments = 12;
    }
  }

  // ── Keyboard ────────────────────────────────────────────────────────────────

  void handleKey(char k) {
    if      (k == 'a' || k == 'A') autoRotate  = !autoRotate;
    else if (k == '[')             segments    = constrain(segments - 1, 4, 24);
    else if (k == ']')             segments    = constrain(segments + 1, 4, 24);
    else if (k == '-' || k == '_') rotSpeed   -= 0.001;
    else if (k == '=' || k == '+') rotSpeed   += 0.001;
    else if (k == 'c' || k == 'C') hueOffset   = (hueOffset + 30) % 360;
    else if (k == 'z')             zoom        = constrain(zoom - 0.05, 0.30, 0.85);
    else if (k == 'Z')             zoom        = constrain(zoom + 0.05, 0.30, 0.85);
    else if (k == 'r' || k == 'R') { zoom = 0.65; manualRot = 0; rotSpeed = 0.003; segments = 12; }
    else if (k == 'f' || k == 'F') flipDir     = !flipDir;
    else if (k == 'y' || k == 'Y') paletteIdx  = (paletteIdx + 1) % paletteNames.length;
  }

  // ── Code overlay ────────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Kaleidoscope ===",
      "// " + segments + " wedges  zoom:" + nf(zoom,1,2) + "  " + paletteNames[paletteIdx],
      "fold:  fa = mod(a, 2π/seg); if fa>π/seg → 2π/seg - fa",
      "chroma: R/G/B sample at zoom ± chromaAmt",
      "seam:   edge = min(fa, wedge-fa) / (wedge*0.5)",
      "glint:  exp(-edge²/(w²·0.03)) · 0.45  →  mirror reflection",
      "irid:   rainbow hue along edge (thin-film interference)",
      "bass→zoom  mid→rotspd  high→chroma+caustics"
    };
  }
}
