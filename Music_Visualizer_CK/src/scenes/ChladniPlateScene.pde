/**
 * ChladniPlateScene (scene 46) — Opus 4.7 showcase, skybox mode
 *
 * Chladni 1787 plate physics, wrapped around the camera as a living skybox.
 * Six vibrating plates form a cube; camera sits at the centre and looks
 * outward. Each wall deforms under a superposition of 4 FFT-weighted modes,
 * and thousands of sand grains per face migrate toward nodal lines via
 * gradient descent on u\u00b2 \u2014 same as the real experiment.
 *
 *   u(x,y) = sum_i w_i * ( cos(n_i \u03c0 x) cos(m_i \u03c0 y)
 *                        - cos(m_i \u03c0 x) cos(n_i \u03c0 y) )
 *
 * Walls are oriented so local +Z points outward; the plate deforms outward
 * (away from the viewer) so the inside of the cube stays clear to fly
 * through. Each wall offsets its mode weights by a small phase so the six
 * faces are related but not identical.
 *
 * Controller:
 *   LStick \u2194 / \u2195   Look azimuth / pitch
 *   RStick \u2194        Jitter gain (chaos)
 *   RStick \u2195        Plate amplitude (bulge)
 *   LT / RT           Slow / fast time
 *   A                 Cycle palette (Heat, Ice, Acid, Plasma)
 *   B                 Toggle plate wireframe / filled
 *   X                 Explode grains
 *   Y                 Shuffle mode bank
 *   LB / RB           Fewer / more sand grains (per face)
 */
class ChladniPlateScene implements IScene {

  // ── Plate geometry ────────────────────────────────────────────────────────
  static final int   GRID       = 64;       // mesh resolution per side
  static final float PLATE_SIZE = 6600;     // cube edge length
  static final float HALF       = PLATE_SIZE / 2.0;

  // ── Cube face basis vectors (outward normal, local x-axis, local y-axis) ──
  // +Z, -Z, +X, -X, +Y, -Y — ordered so neighbouring faces share edges nicely.
  static final int N_FACES = 6;
  final float[][] FACE_N = {
    { 0,  0,  1},  // +Z (front)
    { 0,  0, -1},  // -Z (back)
    { 1,  0,  0},  // +X (right)
    {-1,  0,  0},  // -X (left)
    { 0,  1,  0},  // +Y (floor, PG y grows downward)
    { 0, -1,  0},  // -Y (ceiling)
  };
  final float[][] FACE_X = {
    { 1,  0,  0},
    {-1,  0,  0},
    { 0,  0, -1},
    { 0,  0,  1},
    { 1,  0,  0},
    { 1,  0,  0},
  };
  final float[][] FACE_Y = {
    { 0,  1,  0},
    { 0,  1,  0},
    { 0,  1,  0},
    { 0,  1,  0},
    { 0,  0, -1},
    { 0,  0,  1},
  };

  // ── Modes ─────────────────────────────────────────────────────────────────
  final int ACTIVE_MODES = 4;
  int[]   modeN   = new int[ACTIVE_MODES];
  int[]   modeM   = new int[ACTIVE_MODES];
  float[] modeAmp = new float[ACTIVE_MODES];
  float[] modeTgt = new float[ACTIVE_MODES];

  final int[][] MODE_BANK = {
    {3, 5}, {5, 7}, {4, 6}, {7, 3}, {6, 4}, {8, 2}, {2, 8}, {5, 3},
    {9, 5}, {4, 8}, {11, 3}, {6, 6}, {10, 4}, {3, 11}, {7, 5}, {8, 6}
  };

  // ── Precomputed cosine tables (separable eval) ────────────────────────────
  int maxModeIdx = 12;
  float[][] cosTable;                        // cosTable[k][i] = cos(k*pi*i/GRID)

  // ── Sand grains (per-face arrays) ─────────────────────────────────────────
  static final int MAX_PER_FACE = 900;
  int perFaceGrains = 450;
  float[][] gX  = new float[N_FACES][MAX_PER_FACE];
  float[][] gY  = new float[N_FACES][MAX_PER_FACE];
  float[][] gVX = new float[N_FACES][MAX_PER_FACE];
  float[][] gVY = new float[N_FACES][MAX_PER_FACE];

  // ── Audio smoothing ───────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;
  int beatCooldown = 0;

  // ── Camera (at origin, looking out) ───────────────────────────────────────
  float camAzim = 0, camPitch = 0;
  float targetAzim = 0, targetPitch = 0;

  // ── Tuneables ─────────────────────────────────────────────────────────────
  float plateAmp    = 540;
  float targetAmp   = 540;
  float jitterGain  = 1.0;
  float targetJit   = 1.0;
  float timeScale   = 1.0;
  float targetTime  = 1.0;

  // ── State flags ───────────────────────────────────────────────────────────
  int   paletteIdx   = 0;
  final String[] paletteNames = { "Heat", "Ice", "Acid", "Plasma" };
  // 0 = wire, 1 = fill, 2 = both.  Wire default — user likes the mesh view.
  int   renderMode   = 0;
  final String[] renderModeNames = { "wire", "fill", "both" };
  float   u_time     = 0;
  int     explodeFrames = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  ChladniPlateScene() {
    cosTable = new float[maxModeIdx + 1][GRID + 1];
    for (int i = 0; i < ACTIVE_MODES; i++) {
      int[] p = MODE_BANK[i];
      modeN[i] = p[0];
      modeM[i] = p[1];
      modeAmp[i] = 0;
      modeTgt[i] = 1.0;
    }
    resetGrains();
  }

  void onEnter() {
    u_time = 0;
    sBeat  = 0;
    explodeFrames = 0;
    resetGrains();
  }
  void onExit() {}

  void resetGrains() {
    for (int f = 0; f < N_FACES; f++) {
      for (int i = 0; i < MAX_PER_FACE; i++) {
        gX [f][i] = random(1);
        gY [f][i] = random(1);
        gVX[f][i] = 0;
        gVY[f][i] = 0;
      }
    }
  }

  // ── Controller ────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    float lx = (c.lx - width  * 0.5f) / (width  * 0.5f);
    float ly = (c.ly - height * 0.5f) / (height * 0.5f);
    float rx = (c.rx - width  * 0.5f) / (width  * 0.5f);
    float ry = (c.ry - height * 0.5f) / (height * 0.5f);
    if (abs(lx) > 0.08) targetAzim  += lx * 0.06;
    if (abs(ly) > 0.08) targetPitch  = constrain(targetPitch + ly * 0.04, -1.3, 1.3);
    if (abs(rx) > 0.08) targetJit    = constrain(targetJit - rx * 0.05, 0.0, 4.0);
    if (abs(ry) > 0.08) targetAmp    = constrain(targetAmp - ry * 24.0, 120, 1260);

    targetTime = 1.0 + (c.rt - c.lt) * 1.8;

    if (c.aJustPressed)  paletteIdx = (paletteIdx + 1) % paletteNames.length;
    if (c.bJustPressed)  renderMode = (renderMode + 1) % renderModeNames.length;
    if (c.xJustPressed)  explodeFrames = 20;
    if (c.yJustPressed)  shuffleModes();
    if (c.leftStickClickJustPressed)  perFaceGrains = max(50,           perFaceGrains - 75);
    if (c.rightStickClickJustPressed) perFaceGrains = min(MAX_PER_FACE, perFaceGrains + 75);
  }

  void handleKey(char k) {
    switch (k) {
      case 'a': case 'A': paletteIdx = (paletteIdx + 1) % paletteNames.length; break;
      case 'w': case 'W': renderMode = (renderMode + 1) % renderModeNames.length; break;
      case 'x': case 'X': explodeFrames = 20; break;
      case 'y': case 'Y': shuffleModes(); break;
      case '-': perFaceGrains = max(50,           perFaceGrains - 75); break;
      case '=': case '+': perFaceGrains = min(MAX_PER_FACE, perFaceGrains + 75); break;
    }
  }

  void shuffleModes() {
    for (int i = 0; i < ACTIVE_MODES; i++) {
      int[] p = MODE_BANK[(int) random(MODE_BANK.length)];
      modeN[i] = p[0];
      modeM[i] = p[1];
    }
  }

  void rotateOneMode() {
    int weakest = 0;
    for (int i = 1; i < ACTIVE_MODES; i++) {
      if (modeAmp[i] < modeAmp[weakest]) weakest = i;
    }
    int[] p = MODE_BANK[(int) random(MODE_BANK.length)];
    modeN[weakest] = p[0];
    modeM[weakest] = p[1];
    modeAmp[weakest] = 0;
  }

  // ── Draw ──────────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.10);
    sMid  = lerp(sMid,  analyzer.mid,  0.10);
    sHigh = lerp(sHigh, analyzer.high, 0.10);
    if (audio.beat.isOnset()) { sBeat = 1.0; if (beatCooldown <= 0) { rotateOneMode(); beatCooldown = 24; } }
    sBeat = lerp(sBeat, 0, 0.10);
    if (beatCooldown > 0) beatCooldown--;

    camAzim   = lerp(camAzim,   targetAzim,   0.08);
    camPitch  = lerp(camPitch,  targetPitch,  0.08);
    plateAmp  = lerp(plateAmp,  targetAmp,    0.06);
    jitterGain= lerp(jitterGain,targetJit,    0.06);
    timeScale = lerp(timeScale, targetTime,   0.08);

    float[] bandE = { sBass, sMid, sHigh, (sBass + sMid) * 0.5f };
    for (int i = 0; i < ACTIVE_MODES; i++) {
      modeTgt[i] = 0.2 + bandE[i] * 1.4;
      modeAmp[i] = lerp(modeAmp[i], modeTgt[i], 0.08);
    }

    u_time += 0.012 * timeScale + sBass * 0.01;
    float envelope = 0.65 + 0.35 * sin(u_time * 2.0);

    refreshCosineTables();
    updateAllGrains(envelope);

    pg.beginDraw();
    pg.background(4, 4, 10);

    // Camera at origin of world; far clip past \u221a3 * HALF (\u22485715 for a 6600 cube).
    pg.perspective(PI / 3.0, (float) pg.width / pg.height, 10, 14000);

    pg.pushMatrix();
    pg.translate(pg.width * 0.5, pg.height * 0.5, 0);
    pg.rotateX(camPitch);
    pg.rotateY(camAzim);

    // Inward-facing geometry: disable backface culling so we see inner surface
    // cleanly regardless of vertex winding.
    pg.hint(DISABLE_DEPTH_TEST);

    pg.colorMode(HSB, 360, 100, 100, 100);

    // Walls breathe to the music: amp swells with bass + beat kick.
    float breathAmp = plateAmp * (1.0 + sBass * 0.85 + sBeat * 0.45);

    for (int f = 0; f < N_FACES; f++) {
      drawFace(pg, f, envelope, breathAmp);
      drawFaceGrains(pg, f, envelope, breathAmp);
    }

    pg.hint(ENABLE_DEPTH_TEST);
    pg.popMatrix();

    // HUD
    pg.hint(DISABLE_DEPTH_TEST);
    pg.camera();
    pg.perspective();
    pg.colorMode(RGB, 255);
    drawHUD(pg);
    pg.hint(ENABLE_DEPTH_TEST);

    pg.endDraw();
  }

  // ── Separable cosine eval ─────────────────────────────────────────────────

  void refreshCosineTables() {
    boolean[] need = new boolean[maxModeIdx + 1];
    for (int i = 0; i < ACTIVE_MODES; i++) {
      if (modeN[i] <= maxModeIdx) need[modeN[i]] = true;
      if (modeM[i] <= maxModeIdx) need[modeM[i]] = true;
    }
    float invG = PI / GRID;
    for (int k = 0; k <= maxModeIdx; k++) {
      if (!need[k]) continue;
      for (int i = 0; i <= GRID; i++) {
        cosTable[k][i] = cos(k * i * invG);
      }
    }
  }

  // Evaluate u at integer grid (i, j) for face f (face supplies a phase).
  float uAtGrid(int i, int j, int faceIdx) {
    float phase = faceIdx * 0.18;   // small decorrelation between faces
    float s = 0;
    for (int k = 0; k < ACTIVE_MODES; k++) {
      int n = modeN[k], m = modeM[k];
      float a = cosTable[n][i] * cosTable[m][j]
              - cosTable[m][i] * cosTable[n][j];
      s += modeAmp[k] * cos(u_time * 0.5 + phase * (k + 1)) * a;
    }
    return s;
  }

  // Evaluate u at arbitrary normalised (x, y) in [0, 1] on a given face.
  float uAtNorm(float x, float y, int faceIdx) {
    float px = x * PI, py = y * PI;
    float phase = faceIdx * 0.18;
    float s = 0;
    for (int k = 0; k < ACTIVE_MODES; k++) {
      int n = modeN[k], m = modeM[k];
      float a = cos(n * px) * cos(m * py) - cos(m * px) * cos(n * py);
      s += modeAmp[k] * cos(u_time * 0.5 + phase * (k + 1)) * a;
    }
    return s;
  }

  // ── Face vertex world coordinates ─────────────────────────────────────────

  // Compute world position of a point on face f at normalised (u,v) ∈ [0,1]
  // with outward deflection `height`.
  void faceVertex(float[] out, int f, float u, float v, float height) {
    float[] N = FACE_N[f];
    float[] X = FACE_X[f];
    float[] Y = FACE_Y[f];
    float cu = (u - 0.5) * PLATE_SIZE;
    float cv = (v - 0.5) * PLATE_SIZE;
    float cn = HALF + height;            // centre of face is at N * HALF, bulge outward
    out[0] = N[0] * cn + X[0] * cu + Y[0] * cv;
    out[1] = N[1] * cn + X[1] * cu + Y[1] * cv;
    out[2] = N[2] * cn + X[2] * cu + Y[2] * cv;
  }

  float[] vtmp = new float[3];

  // ── Face mesh ─────────────────────────────────────────────────────────────

  void drawFace(PGraphics pg, int faceIdx, float envelope, float ampEff) {
    boolean drawFill = (renderMode == 1 || renderMode == 2);
    boolean drawWire = (renderMode == 0 || renderMode == 2);
    float invG = 1.0 / GRID;

    // Fill pass (no stroke, per-vertex palette color).
    if (drawFill) {
      pg.noStroke();
      for (int j = 0; j < GRID; j++) {
        pg.beginShape(QUAD_STRIP);
        for (int i = 0; i <= GRID; i++) {
          float u0 = uAtGrid(i, j,     faceIdx) * envelope;
          float u1 = uAtGrid(i, j + 1, faceIdx) * envelope;
          pg.fill(paletteColor(u0, 60));
          faceVertex(vtmp, faceIdx, i * invG, j * invG, u0 * ampEff);
          pg.vertex(vtmp[0], vtmp[1], vtmp[2]);
          pg.fill(paletteColor(u1, 60));
          faceVertex(vtmp, faceIdx, i * invG, (j + 1) * invG, u1 * ampEff);
          pg.vertex(vtmp[0], vtmp[1], vtmp[2]);
        }
        pg.endShape();
      }
    }

    // Wire pass (thin white mesh, slightly lifted so it sits above fill).
    if (drawWire) {
      pg.noFill();
      pg.stroke(200, 30, 95, drawFill ? 70 : 60);
      pg.strokeWeight(1);
      float lift = drawFill ? 4.0 : 0.0;
      for (int j = 0; j < GRID; j++) {
        pg.beginShape(QUAD_STRIP);
        for (int i = 0; i <= GRID; i++) {
          float u0 = uAtGrid(i, j,     faceIdx) * envelope;
          float u1 = uAtGrid(i, j + 1, faceIdx) * envelope;
          faceVertex(vtmp, faceIdx, i * invG, j * invG,       u0 * ampEff + lift);
          pg.vertex(vtmp[0], vtmp[1], vtmp[2]);
          faceVertex(vtmp, faceIdx, i * invG, (j + 1) * invG, u1 * ampEff + lift);
          pg.vertex(vtmp[0], vtmp[1], vtmp[2]);
        }
        pg.endShape();
      }
    }
  }

  // ── Grain simulation ──────────────────────────────────────────────────────

  void updateAllGrains(float envelope) {
    float kick = 0.0025 * jitterGain * (1.0 + sBass * 1.2 + sBeat * 0.8);
    if (explodeFrames > 0) { kick *= 25.0; explodeFrames--; }
    float drift = 0.0006;
    float damp  = 0.88;
    float eps   = 0.005;

    for (int f = 0; f < N_FACES; f++) {
      float[] gx = gX [f];
      float[] gy = gY [f];
      float[] gvx = gVX[f];
      float[] gvy = gVY[f];
      for (int i = 0; i < perFaceGrains; i++) {
        float u = uAtNorm(gx[i], gy[i], f) * envelope;
        float mag = abs(u);

        gvx[i] += random(-1, 1) * mag * kick;
        gvy[i] += random(-1, 1) * mag * kick;

        float uxp = uAtNorm(gx[i] + eps, gy[i],       f) * envelope;
        float uxm = uAtNorm(gx[i] - eps, gy[i],       f) * envelope;
        float uyp = uAtNorm(gx[i],       gy[i] + eps, f) * envelope;
        float uym = uAtNorm(gx[i],       gy[i] - eps, f) * envelope;
        float gxg = (uxp * uxp - uxm * uxm) / (2 * eps);
        float gyg = (uyp * uyp - uym * uym) / (2 * eps);
        gvx[i] -= gxg * drift;
        gvy[i] -= gyg * drift;

        gvx[i] *= damp;
        gvy[i] *= damp;
        gx[i] += gvx[i];
        gy[i] += gvy[i];

        if (gx[i] < 0) { gx[i] = -gx[i];     gvx[i] = -gvx[i] * 0.5; }
        if (gx[i] > 1) { gx[i] = 2 - gx[i];  gvx[i] = -gvx[i] * 0.5; }
        if (gy[i] < 0) { gy[i] = -gy[i];     gvy[i] = -gvy[i] * 0.5; }
        if (gy[i] > 1) { gy[i] = 2 - gy[i];  gvy[i] = -gvy[i] * 0.5; }
      }
    }
  }

  void drawFaceGrains(PGraphics pg, int faceIdx, float envelope, float ampEff) {
    pg.noFill();
    float[] gx = gX [faceIdx];
    float[] gy = gY [faceIdx];
    for (int i = 0; i < perFaceGrains; i++) {
      float u = uAtNorm(gx[i], gy[i], faceIdx) * envelope;
      float mag = abs(u);
      float t = constrain(mag * 0.8, 0, 1);

      // Outer glow halo (low-alpha soft ring) — lets grains read over colored fill.
      pg.stroke(0, 0, 100, 35);
      pg.strokeWeight(9);
      faceVertex(vtmp, faceIdx, gx[i], gy[i], u * ampEff + 12.0);
      pg.point(vtmp[0], vtmp[1], vtmp[2]);

      // Inner hot core — pure white near nodal lines, palette tone when agitated.
      pg.stroke(grainColor(t));
      pg.strokeWeight(5);
      pg.point(vtmp[0], vtmp[1], vtmp[2]);
    }
  }

  // ── Palettes ──────────────────────────────────────────────────────────────

  int paletteColor(float u, float alpha) {
    // Use sqrt for a gentler ramp — keeps high-amplitude bands saturated
    // instead of washing out into pale pink.
    float m = constrain(sqrt(abs(u)) * 1.1, 0, 1);
    switch (paletteIdx) {
      // Heat: deep maroon \u2192 blood red \u2192 orange \u2192 hot yellow, always rich.
      case 0: return color(lerp(355, 35, m),  lerp(95, 100, m), lerp(18, 100, m), alpha);
      // Ice: midnight violet \u2192 electric cyan \u2192 white-blue.
      case 1: return color(lerp(225, 195, m), lerp(95, 70, m),  lerp(22, 100, m), alpha);
      // Acid: forest \u2192 lime \u2192 yellow.
      case 2: return color(lerp(145, 60, m),  lerp(100, 100, m),lerp(18, 100, m), alpha);
      // Plasma: indigo \u2192 magenta \u2192 hot pink \u2192 gold.
      default:return color(lerp(275, 45, m),  lerp(100, 100, m),lerp(28, 100, m), alpha);
    }
  }

  int grainColor(float t) {
    // Settled (t=0) = white hot core, agitated (t=1) = saturated palette tone.
    switch (paletteIdx) {
      case 0:  return color(lerp(30, 8, t),   lerp(15, 100, t), 100, 95);
      case 1:  return color(lerp(195, 210, t),lerp(15, 100, t), 100, 95);
      case 2:  return color(lerp(55, 90, t),  lerp(15, 100, t), 100, 95);
      default: return color(lerp(315, 50, t), lerp(15, 100, t), 100, 95);
    }
  }

  // ── HUD ───────────────────────────────────────────────────────────────────

  void drawHUD(PGraphics pg) {
    float ts = uiScale();
    pg.textFont(monoFont);
    pg.textAlign(LEFT, TOP);
    pg.fill(255, 200);
    pg.textSize(16 * ts);
    pg.text("Chladni Skybox", 18 * ts, 16 * ts);

    pg.fill(255, 130);
    pg.textSize(11 * ts);
    StringBuilder modes = new StringBuilder();
    for (int i = 0; i < ACTIVE_MODES; i++) {
      if (i > 0) modes.append("  ");
      modes.append("(").append(modeN[i]).append(",").append(modeM[i])
           .append(")~").append(nf(modeAmp[i], 1, 2));
    }
    pg.text(modes.toString(), 18 * ts, 40 * ts);
    pg.text("palette: " + paletteNames[paletteIdx]
          + "   render: " + renderModeNames[renderMode]
          + "   grains/face: " + perFaceGrains
          + "   amp: " + nf(plateAmp, 1, 0)
          + "   jitter: " + nf(jitterGain, 1, 2),
          18 * ts, 58 * ts);

    pg.fill(255, 80);
    pg.textAlign(RIGHT, TOP);
    pg.text("LStick look  RStick jitter/amp  LT/RT time  A palette  B render  X explode  Y shuffle",
            pg.width - 18 * ts, 16 * ts);
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Chladni Skybox ===",
      "",
      "u(x,y) = sum w_i *",
      "  ( cos(n_i \u03c0 x) cos(m_i \u03c0 y)",
      "  - cos(m_i \u03c0 x) cos(n_i \u03c0 y) )",
      "",
      "Six vibrating plates form a cube",
      "around the camera. Each wall runs",
      "its own phase-shifted Chladni sim.",
      "",
      "Sand grains gradient-descend on u\u00b2:",
      "  v -= \u03b7 \u2207(u\u00b2)   (seek zero)",
      "  v += |u|\u00b7\u03be        (antinode kick)",
      "",
      "FFT bands weight 4 active modes;",
      "beats rotate the weakest out.",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LStick \u2194", "Look azimuth"),
      new ControllerLayout("LStick \u2195", "Look pitch"),
      new ControllerLayout("RStick \u2194", "Jitter gain"),
      new ControllerLayout("RStick \u2195", "Plate amplitude"),
      new ControllerLayout("LT / RT",       "Slow / fast time"),
      new ControllerLayout("A",             "Cycle palette"),
      new ControllerLayout("B",             "Render mode (wire/fill/both)"),
      new ControllerLayout("X",             "Explode grains"),
      new ControllerLayout("Y",             "Shuffle modes"),
      new ControllerLayout("L/R StickClick","Fewer / more grains"),
    };
  }
}
