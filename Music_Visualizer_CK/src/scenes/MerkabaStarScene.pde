/**
 * MerkabaStarScene (scene 42) — v2 (3D)
 *
 * The Merkaba (Stella Octangula) — two regular tetrahedra inscribed in the
 * same cube, forming a 3D Star of David / Star Tetrahedron.
 *
 * Geometry: two tetrahedra use the alternating corners of a cube with
 * side 2R/√3. Their intersection is a regular octahedron.
 *
 *   Cube vertices at (±1, ±1, ±1)
 *   Tet A: (1,1,1)  (1,-1,-1)  (-1,1,-1)  (-1,-1,1)
 *   Tet B: (-1,-1,-1)  (-1,1,1)  (1,-1,1)  (1,1,-1)
 *   Oct:   midpoints (±1,0,0)  (0,±1,0)  (0,0,±1)
 *
 * Render: glow pass (thick ADD) + core pass (thin), vertex sphere nodes,
 * optional semi-transparent faces and circumsphere great circles.
 *
 * Audio:
 *   Bass     — circumradius pulse + vertex glow
 *   Mid      — auto-rotation speed
 *   High     — edge brightness + shimmer pass
 *   Beat     — vertex expansion burst + white flash
 *
 * Controller:
 *   RStick ↔↕  — orbit camera
 *   LStick ↕   — zoom
 *   LT (hold)  — slow rotation
 *   RT (hold)  — fast rotation
 *   A          — toggle semi-transparent faces
 *   B          — cycle colour mode (blue/cyan → rainbow → gold)
 *   LB / RB    — geometry mode (merkaba → +octahedron → +great circles)
 *   X          — reset camera & speed
 *   Y          — trigger manual beat
 */
class MerkabaStarScene implements IScene {

  // ── Off-screen 3D buffer ───────────────────────────────────────────────────
  PGraphics buf;

  // ── Audio ─────────────────────────────────────────────────────────────────
  float sBass=0, sMid=0, sHigh=0, sBeat=0;
  float beatExpand=0;   // 0-1, decays after beat (drives vertex burst)

  // ── Camera ────────────────────────────────────────────────────────────────
  float camAzim    = 0.55;
  float camElev    = 0.30;
  float camDist    = 630;
  float targetDist = 630;

  // ── Rotation ──────────────────────────────────────────────────────────────
  float rotSpeed       = 0.004;
  float targetRotSpeed = 0.004;

  // Multi-axis rotation — 5 distinct paths.
  // Each row: [X-rate, Y-orbit-rate, Z-rate] as multiples of rotSpeed.
  // Y-orbit-rate drives camAzim (camera circles the star).
  // X and Z rotate the world geometry so you see different faces over time.
  // Setting Y-orbit-rate to 0 freezes the camera → pure geometric tumble.
  float rotX = 0, rotZ = 0;
  int   rotPath    = 0;
  int   pathFrames = 0;
  float[][] PATH_RATES = {
    { 0.0f,  1.0f,  0.0f },   // 0: classic orbit only
    { 0.6f,  1.0f,  0.0f },   // 1: orbit + strong forward tilt
    { 0.0f,  0.7f,  0.6f },   // 2: orbit + barrel roll
    { 1.0f,  0.0f,  0.0f },   // 3: pure X tumble — camera frozen
    { 0.4f,  0.8f,  0.5f },   // 4: all-axis compound tumble
  };

  // ── Visual flags ──────────────────────────────────────────────────────────
  int   colorMode = 0;      // 0=blue/cyan  1=rainbow  2=gold
  boolean showFaces = false; // semi-transparent filled faces
  int   geoMode   = 0;      // 0=merkaba  1=+octahedron  2=+great circles

  // ── Stella Octangula vertices (unit cube corners, magnitude = √3) ──────────
  //    Scaled to circumradius R by multiplying by R / sqrt(3)
  float[][] tetA = { { 1, 1, 1}, { 1,-1,-1}, {-1, 1,-1}, {-1,-1, 1} };
  float[][] tetB = { {-1,-1,-1}, {-1, 1, 1}, { 1,-1, 1}, { 1, 1,-1} };

  // All 6 edges of a tetrahedron (by vertex index)
  int[][] tetEdges = { {0,1},{0,2},{0,3},{1,2},{1,3},{2,3} };

  // 4 faces of a tetrahedron
  int[][] tetFaces = { {0,1,2},{0,1,3},{0,2,3},{1,2,3} };

  // Octahedron (intersection of A ∩ B) — circumradius 1 (scale by R/√3 too)
  float[][] oct = {
    { 1, 0, 0},{-1, 0, 0},
    { 0, 1, 0},{ 0,-1, 0},
    { 0, 0, 1},{ 0, 0,-1}
  };
  int[][] octEdges = {
    {0,2},{0,3},{0,4},{0,5},
    {1,2},{1,3},{1,4},{1,5},
    {2,4},{2,5},{3,4},{3,5}
  };

  // ── IScene lifecycle ───────────────────────────────────────────────────────
  void onEnter() {
    buf = createGraphics(width, height, P3D);
    camAzim=0.55; camElev=0.30; beatExpand=0;
    rotX=0; rotZ=0; rotPath=0; pathFrames=0;
  }

  void onExit() {
    if (buf != null) { buf.dispose(); buf = null; }
  }

  // ── Controller ────────────────────────────────────────────────────────────
  void applyController(Controller c) {
    if (c.aJustPressed) showFaces  = !showFaces;
    if (c.bJustPressed) colorMode  = (colorMode + 1) % 3;
    if (c.lbJustPressed) geoMode   = (geoMode - 1 + 3) % 3;
    if (c.rbJustPressed) geoMode   = (geoMode + 1) % 3;
    if (c.xJustPressed) { camAzim=0.55; camElev=0.30; targetDist=630; targetRotSpeed=0.004; rotX=0; rotZ=0; }
    if (c.yJustPressed)  sBeat = 1.0;

    // LStick ↕ = zoom
    float ly = (c.ly - height * 0.5f) / (height * 0.5f);
    if (abs(ly) > 0.08) targetDist = constrain(targetDist + ly * 14, 180, 1500);

    // RStick = orbit
    float rx = (c.rx - width  * 0.5f) / (width  * 0.5f);
    float ry = (c.ry - height * 0.5f) / (height * 0.5f);
    if (abs(rx) > 0.08) camAzim += rx * 0.032;
    if (abs(ry) > 0.08) camElev  = constrain(camElev + ry * 0.026, -HALF_PI * 0.88, HALF_PI * 0.88);

    // LT/RT = rotation speed
    if (c.lt > 0.15) targetRotSpeed = lerp(targetRotSpeed, 0.0003, 0.08);
    if (c.rt > 0.15) targetRotSpeed = lerp(targetRotSpeed, 0.026, 0.08);
  }

  void handleKey(char k) {
    switch (k) {
      case 'f': case 'F': showFaces = !showFaces; break;
      case 'c': case 'C': colorMode = (colorMode + 1) % 3; break;
      case 'r': case 'R': camAzim=0.55; camElev=0.30; targetDist=630; targetRotSpeed=0.004; rotX=0; rotZ=0; break;
      case '[':            geoMode = (geoMode - 1 + 3) % 3; break;
      case ']':            geoMode = (geoMode + 1) % 3; break;
    }
  }

  void handleMouseWheel(int delta) {
    targetDist = constrain(targetDist + delta * 25, 180, 1500);
  }

  // ── Draw ──────────────────────────────────────────────────────────────────
  void drawScene(PGraphics pg) {
    if (buf == null) return;

    sBass = lerp(sBass, analyzer.bass, 0.07);
    sMid  = lerp(sMid,  analyzer.mid,  0.07);
    sHigh = lerp(sHigh, analyzer.high, 0.07);
    if (audio.beat.isOnset()) { sBeat = 1.0; beatExpand = 1.0; }
    sBeat      = lerp(sBeat,      0, 0.07);
    beatExpand = lerp(beatExpand, 0, 0.11);

    camDist  = lerp(camDist,  targetDist,   0.06);
    rotSpeed = lerp(rotSpeed, targetRotSpeed, 0.05);

    float spd = rotSpeed * (1.0 + sMid * 2.0);
    float[] pr = PATH_RATES[rotPath];

    // Y-orbit rate varies per path (0 = camera frozen → pure geometric tumble)
    camAzim += spd * pr[1];
    // World geometry tilt and roll — the visible "different direction" per path
    rotX    += spd * pr[0];
    rotZ    += spd * pr[2];

    // Advance path every ~500 frames (~8 s at 60fps) — distinct enough to notice
    pathFrames++;
    if (pathFrames > 500) { pathFrames = 0; rotPath = (rotPath + 1) % 5; }

    // Circumradius: bass pulse + beat expansion
    float R  = 165.0 * (1.0 + sBass * 0.16 + sBeat * 0.24 + beatExpand * 0.10);
    float sr = R / sqrt(3.0);   // per-vertex scale factor

    float glow = 0.5 + sBass * 0.55 + sBeat * 0.55 + sHigh * 0.35;
    float ts   = uiScale();

    // ── 3D render to buf ──────────────────────────────────────────────────
    buf.beginDraw();
    buf.background(3, 5, 16);

    float eyeX = camDist * cos(camElev) * sin(camAzim);
    float eyeY = camDist * sin(camElev);
    float eyeZ = camDist * cos(camElev) * cos(camAzim);
    buf.camera(eyeX, eyeY, eyeZ, 0, 0, 0, 0, 1, 0);
    buf.perspective(PI / 3.5, (float)buf.width / buf.height, 5, 5000);

    // Extra tilt/roll applied to geometry (camera orbit is handled via camAzim above)
    buf.rotateX(rotX);
    buf.rotateZ(rotZ);

    buf.blendMode(ADD);
    buf.noFill();

    // ── Glow pass (thick, semi-transparent) ───────────────────────────────
    drawTetEdges(buf, tetA, sr, glow, true,  10.0, 0.10);
    drawTetEdges(buf, tetB, sr, glow, false, 10.0, 0.10);

    // ── Core pass (thin, bright) ───────────────────────────────────────────
    float coreW = 1.6 + sHigh * 0.7;
    drawTetEdges(buf, tetA, sr, glow, true,  coreW, 0.88);
    drawTetEdges(buf, tetB, sr, glow, false, coreW, 0.88);

    // ── High-energy shimmer — complementary hue, very thin ────────────────
    if (sHigh > 0.35) {
      drawTetEdges(buf, tetA, sr, sHigh, true,  0.6, sHigh * 0.28);
      drawTetEdges(buf, tetB, sr, sHigh, false, 0.6, sHigh * 0.28);
    }

    // ── Optional octahedron (inner structure) ─────────────────────────────
    if (geoMode >= 1) {
      buf.strokeWeight(ts * 0.65);
      for (int[] e : octEdges) {
        setEdgeColor(buf, true, e[0] + e[1] + 20, glow * 0.45, 0.40);
        buf.line(oct[e[0]][0]*sr, oct[e[0]][1]*sr, oct[e[0]][2]*sr,
                 oct[e[1]][0]*sr, oct[e[1]][1]*sr, oct[e[1]][2]*sr);
      }
    }

    // ── Circumsphere great circles — always visible, brighter in geoMode 2 ──
    {
      float gcScale = (geoMode == 0) ? 0.35f : (geoMode == 1) ? 0.62f : 1.0f;
      drawGreatCircles(buf, R, glow, ts, gcScale);
    }

    // ── Vertex spheres (pulse on beat) ────────────────────────────────────
    float vr = (8.0 + sBeat * 14 + beatExpand * 10) * ts;
    drawVertexSpheres(buf, tetA, sr, glow, true,  vr);
    drawVertexSpheres(buf, tetB, sr, glow, false, vr);

    // ── Semi-transparent faces ────────────────────────────────────────────
    if (showFaces) {
      drawTetFaces(buf, tetA, sr, glow, true);
      drawTetFaces(buf, tetB, sr, glow, false);
    }

    buf.blendMode(BLEND);
    buf.endDraw();

    // ── Blit to pg + 2D HUD ───────────────────────────────────────────────
    pg.beginDraw();
    pg.background(0);
    pg.blendMode(BLEND);
    pg.image(buf, 0, 0);

    String[] modeNames = {"Blue/Cyan", "Rainbow", "Gold"};
    String[] geoNames  = {"Merkaba", "+Octahedron", "+Circles"};
    pg.textFont(monoFont);
    pg.fill(255, 255, 255, 165 + (int)(sBeat * 90));
    pg.textSize(18 * ts);
    pg.textAlign(LEFT, TOP);
    pg.text("Merkaba / Stella Octangula", 16 * ts, 12 * ts);

    pg.fill(255, 255, 255, 85);
    pg.textSize(9 * ts);
    pg.text("Colour: " + modeNames[colorMode] +
            "  |  Geo: " + geoNames[geoMode] +
            (showFaces ? "  |  faces" : ""),
            16 * ts, 36 * ts);
    pg.text("A faces   B colour   [ ] geo   R reset   scroll zoom", 16 * ts, 48 * ts);

    drawAudioBar(pg, ts);
    pg.endDraw();
  }

  // ── 3D draw helpers ────────────────────────────────────────────────────────

  void drawTetEdges(PGraphics b, float[][] v, float sr,
                   float glow, boolean isA, float weight, float alpha) {
    b.strokeWeight(weight);
    b.noFill();
    for (int[] e : tetEdges) {
      setEdgeColor(b, isA, e[0] + e[1], glow, alpha);
      b.line(v[e[0]][0]*sr, v[e[0]][1]*sr, v[e[0]][2]*sr,
             v[e[1]][0]*sr, v[e[1]][1]*sr, v[e[1]][2]*sr);
    }
  }

  void drawTetFaces(PGraphics b, float[][] v, float sr, float glow, boolean isA) {
    b.noStroke();
    for (int fi = 0; fi < tetFaces.length; fi++) {
      int[] f = tetFaces[fi];
      setFaceColor(b, isA, fi, glow * 0.5, 0.10 + sBeat * 0.07);
      b.beginShape(TRIANGLES);
      b.vertex(v[f[0]][0]*sr, v[f[0]][1]*sr, v[f[0]][2]*sr);
      b.vertex(v[f[1]][0]*sr, v[f[1]][1]*sr, v[f[1]][2]*sr);
      b.vertex(v[f[2]][0]*sr, v[f[2]][1]*sr, v[f[2]][2]*sr);
      b.endShape();
    }
  }

  void drawVertexSpheres(PGraphics b, float[][] v, float sr,
                         float glow, boolean isA, float vr) {
    b.noStroke();
    for (float[] vtx : v) {
      setVertexColor(b, isA, glow, 0.85);
      b.pushMatrix();
      b.translate(vtx[0]*sr, vtx[1]*sr, vtx[2]*sr);
      b.sphere(vr);
      b.popMatrix();
    }
  }

  void drawGreatCircles(PGraphics b, float R, float glow, float ts, float scale) {
    b.noFill();
    int   segs    = 96;
    float baseA   = constrain(0.35 + sMid * 0.30 + sBeat * 0.20, 0, 1) * scale;
    float weight  = ts * (0.85 + sHigh * 0.55) * scale;

    // Glow pass (thicker, low alpha)
    b.strokeWeight(weight * 3.5);
    setEdgeColor(b, true,  10, glow * 0.55 * scale, baseA * 0.18);
    b.beginShape();
    for (int i = 0; i <= segs; i++) { float ang=TWO_PI*i/segs; b.vertex(cos(ang)*R, sin(ang)*R, 0); }
    b.endShape(CLOSE);
    setEdgeColor(b, false, 11, glow * 0.55 * scale, baseA * 0.18);
    b.beginShape();
    for (int i = 0; i <= segs; i++) { float ang=TWO_PI*i/segs; b.vertex(cos(ang)*R, 0, sin(ang)*R); }
    b.endShape(CLOSE);
    setEdgeColor(b, true,  12, glow * 0.55 * scale, baseA * 0.18);
    b.beginShape();
    for (int i = 0; i <= segs; i++) { float ang=TWO_PI*i/segs; b.vertex(0, cos(ang)*R, sin(ang)*R); }
    b.endShape(CLOSE);

    // Core pass (thin, bright)
    b.strokeWeight(weight);
    setEdgeColor(b, true,  10, glow * 0.68 * scale, baseA);
    b.beginShape();
    for (int i = 0; i <= segs; i++) { float ang=TWO_PI*i/segs; b.vertex(cos(ang)*R, sin(ang)*R, 0); }
    b.endShape(CLOSE);
    setEdgeColor(b, false, 11, glow * 0.68 * scale, baseA);
    b.beginShape();
    for (int i = 0; i <= segs; i++) { float ang=TWO_PI*i/segs; b.vertex(cos(ang)*R, 0, sin(ang)*R); }
    b.endShape(CLOSE);
    setEdgeColor(b, true,  12, glow * 0.68 * scale, baseA);
    b.beginShape();
    for (int i = 0; i <= segs; i++) { float ang=TWO_PI*i/segs; b.vertex(0, cos(ang)*R, sin(ang)*R); }
    b.endShape(CLOSE);
  }

  // ── Colour helpers ─────────────────────────────────────────────────────────

  void setEdgeColor(PGraphics b, boolean isA, int idx, float bright, float alpha) {
    bright = constrain(bright, 0, 1);
    alpha  = constrain(alpha,  0, 1);
    switch (colorMode) {
      case 0: // blue/cyan
        if (isA) b.stroke(65, 185+(int)(bright*70), 255, (int)(alpha*218));
        else     b.stroke(90, 255, 230, (int)(alpha*200));
        break;
      case 1: // rainbow
        b.colorMode(HSB, 360, 100, 100, 255);
        float h = ((idx * 52) + (isA ? 0 : 30) + config.logicalFrameCount * 0.35f) % 360;
        b.stroke(h, 70, 52+(int)(bright*48), (int)(alpha*215));
        b.colorMode(RGB, 255);
        break;
      case 2: // gold
        float g = 155 + (int)(bright*100);
        if (isA) b.stroke((int)g, (int)(g*0.84f), (int)(g*0.12f), (int)(alpha*215));
        else     b.stroke((int)(g*0.88f), (int)(g*0.70f), 12, (int)(alpha*200));
        break;
    }
  }

  void setFaceColor(PGraphics b, boolean isA, int idx, float bright, float alpha) {
    bright = constrain(bright, 0, 1);
    alpha  = constrain(alpha,  0, 1);
    switch (colorMode) {
      case 0:
        if (isA) b.fill(40, 100+(int)(bright*100), 200, (int)(alpha*255));
        else     b.fill(50, 170+(int)(bright*85),  170, (int)(alpha*255));
        break;
      case 1:
        b.colorMode(HSB, 360, 100, 100, 255);
        float h = ((idx*52)+(isA?0:30)+config.logicalFrameCount*0.35f) % 360;
        b.fill(h, 65, 40+(int)(bright*35), (int)(alpha*255));
        b.colorMode(RGB, 255);
        break;
      case 2:
        float g = 100 + (int)(bright*90);
        b.fill((int)g, (int)(g*0.84f), 12, (int)(alpha*255));
        break;
    }
  }

  void setVertexColor(PGraphics b, boolean isA, float bright, float alpha) {
    bright = constrain(bright, 0, 1);
    alpha  = constrain(alpha,  0, 1);
    switch (colorMode) {
      case 0:
        if (isA) b.fill(110, 200+(int)(bright*55), 255, (int)(alpha*255));
        else     b.fill(130, 255, 240, (int)(alpha*255));
        break;
      case 1:
        b.colorMode(HSB, 360, 100, 100, 255);
        float h = (isA ? 210 : 130) + config.logicalFrameCount * 0.5f;
        b.fill(h % 360, 60, 72+(int)(bright*28), (int)(alpha*255));
        b.colorMode(RGB, 255);
        break;
      case 2:
        float g = 210 + (int)(bright*45);
        b.fill((int)g, (int)(g*0.85f), 60, (int)(alpha*255));
        break;
    }
  }

  // ── Audio bar (bottom-left) ────────────────────────────────────────────────
  void drawAudioBar(PGraphics pg, float ts) {
    float bx=16*ts, by=pg.height-30*ts, bw=7*ts, bh=22*ts, gap=11*ts;
    String[] lbl = {"B","M","H"};
    float[]  lvl = {sBass, sMid, sHigh};
    int[]    col = {color(0,190,255), color(0,255,130), color(255,90,255)};
    pg.noStroke();
    for (int i = 0; i < 3; i++) {
      float fh = bh * lvl[i];
      pg.fill(35, 35, 35, 160); pg.rect(bx+i*gap, by, bw, bh, 2);
      pg.fill(col[i]);           pg.rect(bx+i*gap, by+bh-fh, bw, fh, 2);
      pg.fill(255, 255, 255, 75);
      pg.textSize(7*ts); pg.textAlign(CENTER, TOP);
      pg.text(lbl[i], bx+i*gap+bw*0.5, by+bh+2*ts);
    }
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────
  String[] getCodeLines() {
    return new String[]{
      "=== Merkaba / Stella Octangula ===",
      "",
      "Two tetrahedra in a common cube:",
      "  A: (1,1,1)(1,-1,-1)(-1,1,-1)(-1,-1,1)",
      "  B: (-1,-1,-1)(-1,1,1)(1,-1,1)(1,1,-1)",
      "  A\u2229B = regular octahedron",
      "",
      "Bass  \u2192 circumradius pulse",
      "Mid   \u2192 rotation speed",
      "High  \u2192 edge brightness",
      "Beat  \u2192 vertex expansion burst",
      "",
      "A faces  B colour  [ ] geo",
      "RStick orbit   LT/RT speed",
      "R reset   scroll zoom",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LStick \u2195",  "Zoom"),
      new ControllerLayout("RStick \u2194\u2195", "Orbit camera"),
      new ControllerLayout("LT / RT",       "Rotation speed"),
      new ControllerLayout("A",              "Toggle faces"),
      new ControllerLayout("B",              "Cycle colour mode"),
      new ControllerLayout("LB / RB",       "Geometry mode"),
      new ControllerLayout("X",              "Reset camera & speed"),
      new ControllerLayout("Y",              "Manual beat trigger"),
    };
  }
}
