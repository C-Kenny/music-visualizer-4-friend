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

  // ── Shader ─────────────────────────────────────────────────────────────────
  PShader kaleidoShader;

  KaleidoscopeScene() {}

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  void onEnter() {
    rotation = 0; manualRot = 0;
    zoom = 0.65; beatFlash = 0;
    kaleidoShader = loadShader("kaleidoscope_3d.glsl");
  }

  void onExit() {}

  // ── Main render ─────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    if (kaleidoShader == null) kaleidoShader = loadShader("kaleidoscope_3d.glsl");

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

    float liveZoom = zoom * (1.0 + sBass * 0.06);

    kaleidoShader.set("resolution", (float)pg.width, (float)pg.height);
    kaleidoShader.set("time", (float)millis() / 1000.0f);
    kaleidoShader.set("bass", sBass);
    kaleidoShader.set("mid", sMid);
    kaleidoShader.set("high", sHigh);
    kaleidoShader.set("segments", (float) segments);
    kaleidoShader.set("rotation", rotation);
    kaleidoShader.set("zoom", liveZoom);

    pg.colorMode(HSB, 360, 255, 255);
    color pCol = pg.color((paletteHues[paletteIdx] + hueOffset) % 360, 200, 255);
    kaleidoShader.set("paletteCol", pg.red(pCol)/255.0f, pg.green(pCol)/255.0f, pg.blue(pCol)/255.0f);
    pg.colorMode(RGB, 255);

    pg.background(0);
    pg.shader(kaleidoShader);
    pg.noStroke();
    pg.fill(0);
    pg.rect(0, 0, pg.width, pg.height);
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


  // ── HUD ─────────────────────────────────────────────────────────────────────

  void drawHUD(PGraphics pg) {
    sceneHUD(pg, "Kaleidoscope", new String[]{
      "Bass:" + nf(sBass,1,2) + "  Mid:" + nf(sMid,1,2) + "  High:" + nf(sHigh,1,2),
      "Segments:" + segments + "  Zoom:" + nf(zoom,1,2) + "  RotSpd:" + nf(rotSpeed,1,3),
      "Palette:" + paletteNames[paletteIdx] + "  Trail:" + nf(trailAlpha,1,0) + "  AutoRot:" + (autoRotate ? "ON" : "OFF") + "  Dir:" + (flipDir ? "CCW" : "CW"),
      "A segs+2  B segs-2  Y palette  X reset",
      "L-stick rotate/zoom  LT slow  RT fast",
      "[/] segs  -/= speed  z/Z zoom  c hue  f flip  a auto  r reset"
    });
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

    if (c.aJustPressed) segments   = constrain(segments + 2, 4, 24);
    if (c.bJustPressed) segments   = constrain(segments - 2, 4, 24);
    if (c.yJustPressed) paletteIdx = (paletteIdx + 1) % paletteNames.length;
    if (c.xJustPressed) {
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
      "=== 3D Raymarched Kaleidoscope ===",
      "// " + segments + " wedges  zoom:" + nf(zoom,1,2) + "  " + paletteNames[paletteIdx],
      "Raymarching infinite KIFS fractal",
      "fold:  a = mod(a + w, 2w) - w; a = abs(a);",
      "fractal: q = abs(q) - offset; q *= rot(t);",
      "lighting: Lambertian + Fresnel rim light",
      "bass→fractal pulse  mid→speed  high→glow"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
