// Silhouette Painting Scene
//
// Inspired by the "Bad Apple!!" silhouette-painting PV. SDF morph + transition
// variety pack (cut / whip / iris / curtain / invert-flash) + per-shot camera
// composition (Ken Burns pan/zoom/rotation, off-center placement) so each
// shape feels like a deliberate framed shot, not a static spinner.
//
// Assets: data/silhouettes/silhouette_00.png .. silhouette_15.png

class SilhouettePaintingScene implements IScene {

  static final int SHAPE_COUNT = 16;
  static final int SDF_W = 256;
  static final int SDF_H = 256;
  static final int N    = SDF_W * SDF_H;
  // Output buffer res - SDF is bilinearly sampled into this. Higher = smoother edges.
  static final int RENDER_RES = 768;
  static final int RN = RENDER_RES * RENDER_RES;

  // transition modes
  static final int TR_MORPH   = 0;
  static final int TR_CUT     = 1;
  static final int TR_WHIP    = 2;
  static final int TR_IRIS    = 3;
  static final int TR_CURTAIN = 4;
  static final int TR_FLASH   = 5;
  static final int TR_COUNT   = 6;

  float[][] sdfs;            // [SHAPE_COUNT][N] signed distance fields
  float[] outMask;           // scratch foreground-mask 0..1 per OUTPUT pixel (size RN)
  PImage outImg;             // RENDER_RES × RENDER_RES - drawn each frame
  int[] order;
  int cursor = 0;
  float morphT = 0;
  float baseSpeed = 0.012;
  float bassBoost = 0.06;
  boolean invert = false;
  float pulseScale = 1.0;

  // Transition state for current shot
  int trMode = TR_MORPH;
  float trAngle = 0;     // whip direction (radians)
  float trCx = 0.5;      // iris center (normalized 0..1)
  float trCy = 0.5;

  // Camera composition per shot - interpolated each frame
  float camX, camY;          // current center offset (px)
  float camScale;            // current zoom
  float camRot;              // current rotation (radians)
  float camTgtX, camTgtY;    // shot target - Ken Burns endpoint
  float camTgtScale;
  float camTgtRot;
  float shotProgress = 0;    // 0..1 across the shot duration (used for ken-burns)

  boolean loaded = false;

  SilhouettePaintingScene() {
    sdfs = new float[SHAPE_COUNT][];
    int ok = 0;
    for (int i = 0; i < SHAPE_COUNT; i++) {
      String path = "silhouettes/silhouette_" + nf(i, 2) + ".png";
      PImage img = loadImage(path);
      if (img == null || img.width == 0) {
        println("SilhouettePaintingScene: missing " + path);
        continue;
      }
      sdfs[i] = buildSDF(img);
      ok++;
    }
    if (ok < 2) {
      println("SilhouettePaintingScene: need at least 2 shapes, got " + ok);
      return;
    }
    order = new int[SHAPE_COUNT];
    for (int i = 0; i < SHAPE_COUNT; i++) order[i] = i;
    shuffleOrder();
    outImg = createImage(RENDER_RES, RENDER_RES, RGB);
    outMask = new float[RN];
    pickNewShot();
    loaded = true;
  }

  // ── SDF construction ──────────────────────────────────────────────────────

  float[] buildSDF(PImage src) {
    PImage s = src.copy();
    s.resize(SDF_W, SDF_H);
    s.filter(BLUR, 1.0);
    s.loadPixels();
    boolean[] inside = new boolean[N];
    for (int i = 0; i < N; i++) {
      inside[i] = brightness(s.pixels[i]) < 128;
    }
    float[] dOut = chamferDT(inside, false);
    float[] dIn  = chamferDT(inside, true);
    float[] sdf = new float[N];
    for (int i = 0; i < N; i++) sdf[i] = dIn[i] - dOut[i];
    return sdf;
  }

  float[] chamferDT(boolean[] inside, boolean seedInside) {
    int W = SDF_W, H = SDF_H;
    float INF = 1e9;
    float[] d = new float[N];
    for (int i = 0; i < N; i++) d[i] = (inside[i] == seedInside) ? 0 : INF;
    final float D1 = 1.0;
    final float D2 = 1.4142136;
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        int i = y * W + x;
        float v = d[i];
        if (x > 0)            v = min(v, d[i - 1]     + D1);
        if (y > 0)            v = min(v, d[i - W]     + D1);
        if (x > 0 && y > 0)   v = min(v, d[i - W - 1] + D2);
        if (x < W-1 && y > 0) v = min(v, d[i - W + 1] + D2);
        d[i] = v;
      }
    }
    for (int y = H - 1; y >= 0; y--) {
      for (int x = W - 1; x >= 0; x--) {
        int i = y * W + x;
        float v = d[i];
        if (x < W-1)              v = min(v, d[i + 1]     + D1);
        if (y < H-1)              v = min(v, d[i + W]     + D1);
        if (x < W-1 && y < H-1)   v = min(v, d[i + W + 1] + D2);
        if (x > 0   && y < H-1)   v = min(v, d[i + W - 1] + D2);
        d[i] = v;
      }
    }
    return d;
  }

  void shuffleOrder() {
    if (order == null) return;
    for (int i = order.length - 1; i > 0; i--) {
      int j = (int)random(i + 1);
      int t = order[i]; order[i] = order[j]; order[j] = t;
    }
    cursor = 0;
    morphT = 0;
  }

  // ── shot composition ──────────────────────────────────────────────────────
  // Each shape advance picks a fresh shot: transition mode + camera framing.

  void pickNewShot() {
    // Weighted transition pick - morph dominant, others sprinkle in.
    float r = random(1);
    if      (r < 0.45) trMode = TR_MORPH;
    else if (r < 0.60) trMode = TR_CUT;
    else if (r < 0.75) trMode = TR_WHIP;
    else if (r < 0.85) trMode = TR_IRIS;
    else if (r < 0.93) trMode = TR_CURTAIN;
    else               trMode = TR_FLASH;

    trAngle = random(TWO_PI);
    trCx = random(0.25, 0.75);
    trCy = random(0.25, 0.75);

    // Composition - start frame and Ken-Burns target
    // Off-center allowed via offset fraction of screen
    camX = random(-0.18, 0.18);
    camY = random(-0.12, 0.12);
    camScale = random(0.70, 1.00);
    camRot = random(-0.15, 0.15);

    camTgtX = camX + random(-0.10, 0.10);
    camTgtY = camY + random(-0.07, 0.07);
    camTgtScale = constrain(camScale + random(-0.10, 0.20), 0.55, 1.10);
    camTgtRot = camRot + random(-0.10, 0.10);

    shotProgress = 0;
  }

  // ── render ────────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    if (!loaded) {
      pg.background(255);
      pg.fill(0);
      pg.textAlign(CENTER, CENTER);
      pg.textSize(20 * uiScale());
      pg.text("Silhouette Painting: missing data/silhouettes/*.png", pg.width/2.0, pg.height/2.0);
      return;
    }

    float bass = analyzer.bass;
    boolean isBeat = analyzer.isBeat;

    morphT += baseSpeed + bassBoost * constrain(bass, 0, 4) * 0.25;
    shotProgress = min(1.0, shotProgress + 0.004);

    if (isBeat && morphT > 0.4) {
      advanceShape(bass);
    }
    if (morphT >= 1.0) advanceShape(bass);

    pulseScale = lerp(pulseScale, 1.0, 0.12);

    // ── build foreground mask via active transition ──
    float[] sdfA = sdfs[order[cursor]];
    float[] sdfB = sdfs[order[(cursor + 1) % SHAPE_COUNT]];
    float t = smoothstep01(morphT);

    boolean flashInvert = false;
    switch (trMode) {
      case TR_MORPH:   maskMorph(sdfA, sdfB, t); break;
      case TR_CUT:     maskCut(sdfA, sdfB, t); break;
      case TR_WHIP:    maskWhip(sdfA, sdfB, t); break;
      case TR_IRIS:    maskIris(sdfA, sdfB, t); break;
      case TR_CURTAIN: maskCurtain(sdfA, sdfB, t); break;
      case TR_FLASH:
        maskMorph(sdfA, sdfB, t);
        flashInvert = (morphT < 0.06);  // 1-2 frame inversion at transition start
        break;
    }

    // ── mask -> pixels ──
    outImg.loadPixels();
    boolean inv = invert ^ flashInvert;
    int bgCol = inv ? color(0)   : color(255);
    int fgCol = inv ? color(255) : color(0);
    for (int i = 0; i < RN; i++) {
      outImg.pixels[i] = lerpColor(bgCol, fgCol, outMask[i]);
    }
    outImg.updatePixels();

    // ── camera & composite ──
    pg.background(inv ? 0 : 255);
    // Ken-Burns lerp toward target across shot duration
    float kb = smoothstep01(shotProgress);
    float cx = lerp(camX, camTgtX, kb);
    float cy = lerp(camY, camTgtY, kb);
    float cs = lerp(camScale, camTgtScale, kb) * pulseScale;
    float cr = lerp(camRot,   camTgtRot,   kb);

    float baseSide = min(pg.width, pg.height) * 0.82;
    float side = baseSide * cs;
    float ox = pg.width  / 2.0 + cx * pg.width;
    float oy = pg.height / 2.0 + cy * pg.height;

    pg.pushMatrix();
      pg.translate(ox, oy);
      pg.rotate(cr);
      pg.imageMode(CENTER);
      pg.image(outImg, 0, 0, side, side);
    pg.popMatrix();

    drawHUD(pg, inv);
    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  void advanceShape(float bass) {
    cursor = (cursor + 1) % SHAPE_COUNT;
    morphT = 0;
    pulseScale = 1.0 + 0.06 * constrain(bass, 0, 2);
    pickNewShot();
  }

  // ── transitions: each writes into outMask[i] (RN entries, 0=bg, 1=fg) ─────
  //
  // SDFs are bilinearly sampled at output resolution so edges stay smooth at
  // any zoom - the curve isn't quantized to the 256² grid anymore.

  // Bilinear sample of SDF at fractional grid coords (sx,sy in [0..SDF_W-1]).
  float bilin(float[] sdf, float sx, float sy) {
    if (sx < 0) sx = 0; else if (sx > SDF_W - 1.001) sx = SDF_W - 1.001;
    if (sy < 0) sy = 0; else if (sy > SDF_H - 1.001) sy = SDF_H - 1.001;
    int x0 = (int)sx, y0 = (int)sy;
    float tx = sx - x0, ty = sy - y0;
    int i = y0 * SDF_W + x0;
    float v00 = sdf[i],         v10 = sdf[i + 1];
    float v01 = sdf[i + SDF_W], v11 = sdf[i + SDF_W + 1];
    float a = v00 + (v10 - v00) * tx;
    float b = v01 + (v11 - v01) * tx;
    return a + (b - a) * ty;
  }

  // Scale factor: 1 SDF unit ≈ (RENDER_RES/SDF_W) output pixels.
  // Edge band measured in SDF units stays visually consistent on output.
  static final float EDGE_SDF = 1.6;

  void maskMorph(float[] A, float[] B, float t) {
    float step = (SDF_W - 1) / (float)(RENDER_RES - 1);
    for (int oy = 0; oy < RENDER_RES; oy++) {
      float sy = oy * step;
      int row = oy * RENDER_RES;
      for (int ox = 0; ox < RENDER_RES; ox++) {
        float sx = ox * step;
        float va = bilin(A, sx, sy);
        float vb = bilin(B, sx, sy);
        float v = va + (vb - va) * t;
        outMask[row + ox] = edgeAlpha(v, EDGE_SDF);
      }
    }
  }

  void maskCut(float[] A, float[] B, float t) {
    float[] src = (t < 0.5) ? A : B;
    float step = (SDF_W - 1) / (float)(RENDER_RES - 1);
    for (int oy = 0; oy < RENDER_RES; oy++) {
      float sy = oy * step;
      int row = oy * RENDER_RES;
      for (int ox = 0; ox < RENDER_RES; ox++) {
        outMask[row + ox] = edgeAlpha(bilin(src, ox * step, sy), EDGE_SDF);
      }
    }
  }

  // Whip: shift sample coords. A slides out in +dir, B slides in from -dir.
  void maskWhip(float[] A, float[] B, float t) {
    float dx = cos(trAngle) * SDF_W;
    float dy = sin(trAngle) * SDF_H;
    float aShiftX = dx * t,        aShiftY = dy * t;
    float bShiftX = -dx * (1 - t), bShiftY = -dy * (1 - t);
    float step = (SDF_W - 1) / (float)(RENDER_RES - 1);
    for (int oy = 0; oy < RENDER_RES; oy++) {
      float sy = oy * step;
      int row = oy * RENDER_RES;
      for (int ox = 0; ox < RENDER_RES; ox++) {
        float sx = ox * step;
        float aMask = edgeAlpha(bilin(A, sx - aShiftX, sy - aShiftY), EDGE_SDF);
        float bMask = edgeAlpha(bilin(B, sx - bShiftX, sy - bShiftY), EDGE_SDF);
        outMask[row + ox] = max(aMask * (1 - t), bMask * t);
      }
    }
  }

  void maskIris(float[] A, float[] B, float t) {
    float cxp = trCx * RENDER_RES;
    float cyp = trCy * RENDER_RES;
    float maxR = dist(0, 0, RENDER_RES, RENDER_RES);
    float r = t * maxR;
    float band = RENDER_RES * 0.015;
    float step = (SDF_W - 1) / (float)(RENDER_RES - 1);
    for (int oy = 0; oy < RENDER_RES; oy++) {
      float sy = oy * step;
      int row = oy * RENDER_RES;
      for (int ox = 0; ox < RENDER_RES; ox++) {
        float sx = ox * step;
        float aMask = edgeAlpha(bilin(A, sx, sy), EDGE_SDF);
        float bMask = edgeAlpha(bilin(B, sx, sy), EDGE_SDF);
        float d = dist(ox, oy, cxp, cyp);
        float reveal = constrain((r - d) / band, 0, 1);
        outMask[row + ox] = aMask * (1 - reveal) + bMask * reveal;
      }
    }
  }

  void maskCurtain(float[] A, float[] B, float t) {
    float edgeX = t * RENDER_RES;
    float band = RENDER_RES * 0.025;
    float step = (SDF_W - 1) / (float)(RENDER_RES - 1);
    for (int oy = 0; oy < RENDER_RES; oy++) {
      float sy = oy * step;
      int row = oy * RENDER_RES;
      for (int ox = 0; ox < RENDER_RES; ox++) {
        float sx = ox * step;
        float aMask = edgeAlpha(bilin(A, sx, sy), EDGE_SDF);
        float bMask = edgeAlpha(bilin(B, sx, sy), EDGE_SDF);
        float reveal = constrain((edgeX - ox) / band, 0, 1);
        outMask[row + ox] = aMask * (1 - reveal) + bMask * reveal;
      }
    }
  }

  float edgeAlpha(float v, float edge) {
    if (v <= -edge) return 1.0;
    if (v >=  edge) return 0.0;
    float x = constrain(0.5 - 0.5 * (v / edge), 0, 1);
    return x * x * (3 - 2 * x);
  }

  float smoothstep01(float x) {
    x = constrain(x, 0, 1);
    return x * x * (3 - 2 * x);
  }

  // ── HUD ───────────────────────────────────────────────────────────────────

  String trName(int m) {
    switch (m) {
      case TR_MORPH:   return "morph";
      case TR_CUT:     return "cut";
      case TR_WHIP:    return "whip";
      case TR_IRIS:    return "iris";
      case TR_CURTAIN: return "curtain";
      case TR_FLASH:   return "flash";
    }
    return "?";
  }

  void drawHUD(PGraphics pg, boolean inv) {
    pg.pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      float margin = 4 * uiScale();
      int panelFill = inv ? color(255, 140) : color(0, 140);
      int textCol   = inv ? color(0) : color(255);
      pg.fill(panelFill); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 280 * uiScale(), margin + lh * 4);
      pg.fill(textCol);
      pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("Scene: Silhouette Painting",        12, 8 + margin);
      pg.text("shape: " + order[cursor] + "→" + order[(cursor+1) % SHAPE_COUNT]
              + "  t=" + nf(morphT, 1, 2)
              + "  tr=" + trName(trMode),          12, 8 + margin + lh);
      pg.text("Y invert  X shuffle  A skip  B cycle-tr", 12, 8 + margin + lh*2);
      pg.text("RT morph speed",                    12, 8 + margin + lh*3);
    pg.popStyle();
  }

  // ── controls ──────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    float rtBoost = constrain(c.rt, 0, 1);
    baseSpeed = lerp(baseSpeed, 0.012 + rtBoost * 0.05, 0.15);

    if (c.aJustPressed) { advanceShape(0); }
    if (c.yJustPressed) invert = !invert;
    if (c.xJustPressed) shuffleOrder();
    if (c.bJustPressed) {  // cycle transition mode (debug/preview)
      trMode = (trMode + 1) % TR_COUNT;
      morphT = 0;
    }
  }

  void onEnter() {
    morphT = 0;
    pulseScale = 1.0;
    pickNewShot();
  }
  void onExit() {}

  void handleKey(char k) {
    if (k == 'i' || k == 'I') invert = !invert;
    else if (k == 's' || k == 'S') shuffleOrder();
    else if (k == 'n' || k == 'N') advanceShape(0);
    else if (k == 't' || k == 'T') {
      trMode = (trMode + 1) % TR_COUNT;
      morphT = 0;
    }
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Silhouette Painting ===",
      "",
      "// 16 silhouettes → SDFs",
      "// transition modes:",
      "//   morph - SDF interp",
      "//   cut - instant swap",
      "//   whip - directional slide",
      "//   iris - radial reveal",
      "//   curtain - horiz sweep",
      "//   flash - invert spike",
      "",
      "// each shot: random framing",
      "// camera Ken-Burns drifts",
      "// across shot duration",
      "",
      "// I invert  S shuffle  N next  T trans"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("A Button", "Skip to next shape"),
      new ControllerLayout("Y Button", "Invert B/W"),
      new ControllerLayout("X Button", "Shuffle order"),
      new ControllerLayout("B Button", "Cycle transition"),
      new ControllerLayout("RT", "Morph speed")
    };
  }
}
