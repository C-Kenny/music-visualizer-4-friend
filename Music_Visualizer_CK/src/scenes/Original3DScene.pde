/**
 * Original3DScene (scene 40)
 *
 * The original mandala scene rebuilt with real 3D geometry:
 *   - Flat quad diamonds → 3D double-pyramids at 4 corners
 *   - Flat bezier fins   → 3D curved blades that sweep through Y+Z
 *   - Flat purple circle → Thick wireframe torus
 *   - Flat waveform line → 3D helix ribbon wrapping the composition
 *
 * Same colours, same audio reactivity, same controls — but truly 3D.
 */
class Original3DScene implements IScene {

  PGraphics buf;

  // ── Camera ────────────────────────────────────────────────────────────────
  float camAzim = 0.3, camElev = 0.35, camDist = 550, targetDist = 550;
  float autoRotSpeed = 0.0025;

  // ── Scale ─────────────────────────────────────────────────────────────────
  float S;

  // ── Fins ──────────────────────────────────────────────────────────────────
  float   fins = 14, finYOffset = -90, targetFinYOffset = -90;
  boolean finClockwise = false, rainbowFins = false, drawFins = true;

  // ── Diamonds ──────────────────────────────────────────────────────────────
  boolean drawDiamonds = true;
  float   diamondDistCenter = 0;
  boolean diamondGrowing = true;

  // ── toggles ───────────────────────────────────────────────────────────────
  boolean drawWaveform = true, drawRing = true, bgEnabled = true;

  // ── Audio ─────────────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, beatFlash = 0;

  // ── Fin cycle ─────────────────────────────────────────────────────────────
  float finRedness = 0;
  boolean finRednessRising = true;
  boolean canChangeFinDir = true;
  int lastFinCheck = 0;

  // ── Blend ─────────────────────────────────────────────────────────────────
  int blendIdx = 0;
  int[] blendModes = { BLEND, ADD, SUBTRACT, EXCLUSION };
  String[] blendNames = { "BLEND", "ADD", "SUBTRACT", "EXCLUSION" };
  void changeBlendMode() { blendIdx = (blendIdx + 1) % blendModes.length; }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void onEnter() {
    buf = createGraphics(sceneBuffer.width, sceneBuffer.height, P3D);
    buf.smooth(4);
    S = min(sceneBuffer.width, sceneBuffer.height) * 0.45;
    diamondDistCenter = S * 0.07;
  }
  void onExit() { if (buf != null) { buf.dispose(); buf = null; } }

  // ── Controller ────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    float ly = (c.ly - height * 0.5) / (height * 0.5);
    if (abs(ly) > 0.08) targetFinYOffset = constrain(targetFinYOffset + ly * 3, -200, 50);
    float rx = (c.rx - width  * 0.5) / (width  * 0.5);
    float ry = (c.ry - height * 0.5) / (height * 0.5);
    if (abs(rx) > 0.08) camAzim += rx * 0.03;
    if (abs(ry) > 0.08) camElev = constrain(camElev + ry * 0.025, -PI*0.4, PI*0.4);
    if (c.lt > 0.15) targetDist = constrain(targetDist - c.lt * 8, 250, 1100);
    if (c.rt > 0.15) targetDist = constrain(targetDist + c.rt * 8, 250, 1100);
    if (c.aJustPressed) rainbowFins = !rainbowFins;
    if (c.bJustPressed) changeBlendMode();
    if (c.xJustPressed) bgEnabled = !bgEnabled;
    if (c.yJustPressed) finClockwise = !finClockwise;
  }

  void handleKey(char k) {
    switch (k) {
      case 'f': drawFins = !drawFins; break;
      case 'F': rainbowFins = !rainbowFins; break;
      case 'w': case 'W': drawWaveform = !drawWaveform; break;
      case 'x': case 'X': bgEnabled = !bgEnabled; break;
      case 'd': case 'D': drawDiamonds = !drawDiamonds; break;
      case 'r': case 'R': drawRing = !drawRing; break;
      case 'y': case 'Y': finClockwise = !finClockwise; break;
      case 'b': case 'B': changeBlendMode(); break;
    }
  }

  // ── Main draw ─────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    if (buf == null || buf.width != pg.width || buf.height != pg.height) {
      if (buf != null) buf.dispose();
      buf = createGraphics(pg.width, pg.height, P3D);
      buf.smooth(4);
    }
    S = min(buf.width, buf.height) * 0.45;

    // Audio
    sBass = lerp(sBass, analyzer.bass, 0.10);
    sMid  = lerp(sMid,  analyzer.mid,  0.10);
    sHigh = lerp(sHigh, analyzer.high, 0.10);
    if (analyzer.isBeat) beatFlash = 1.0;
    beatFlash = lerp(beatFlash, 0, 0.08);

    camDist    = lerp(camDist, targetDist, 0.06);
    finYOffset = lerp(finYOffset, targetFinYOffset, 0.06);
    camAzim   += autoRotSpeed * (1.0 + sMid * 2.5);

    // Fin count animation
    if (finRednessRising) { finRedness += 1; fins += 0.02; }
    else                  { finRedness -= 1; fins -= 0.02; }
    if (finRedness >= 255) finRednessRising = false;
    else if (finRedness <= 0) finRednessRising = true;
    fins = constrain(fins, 6, 22);

    // Audio-reactive
    if (sBass > 0.9 && random(1, 10) > 7) changeBlendMode();
    float maxDD = S * 0.3, minDD = S * 0.1;
    if (diamondDistCenter >= maxDD) diamondGrowing = false;
    else if (diamondDistCenter <= minDD) diamondGrowing = true;
    if (sMid > 0.5) diamondDistCenter += diamondGrowing ? S * 0.008 : -S * 0.008;
    int ms = millis();
    if (ms > lastFinCheck + 10000) { canChangeFinDir = true; lastFinCheck = ms; }
    if (canChangeFinDir && sHigh > 0.3) { finClockwise = !finClockwise; canChangeFinDir = false; }

    // ── Render ───────────────────────────────────────────────────────────
    buf.beginDraw();
    if (bgEnabled) {
      buf.background(180, 180, 188);
    } else {
      buf.hint(DISABLE_DEPTH_TEST);
      buf.noStroke(); buf.fill(10, 8, 18, 25);
      buf.rectMode(CORNER); buf.rect(0, 0, buf.width, buf.height);
      buf.hint(ENABLE_DEPTH_TEST);
    }

    float eyeX = camDist * cos(camElev) * sin(camAzim);
    float eyeY = camDist * sin(camElev);
    float eyeZ = camDist * cos(camElev) * cos(camAzim);
    buf.camera(eyeX, eyeY, eyeZ, 0, 0, 0, 0, 1, 0);
    buf.perspective(PI / 3.0, (float)buf.width / buf.height, 5, 5000);

    // Simple directional light for the filled shapes
    buf.lights();
    buf.directionalLight(220, 210, 200, -0.3, -0.6, -0.5);
    buf.ambientLight(80, 80, 90);

    buf.blendMode(blendModes[blendIdx]);

    if (drawDiamonds) draw3DDiamonds();
    if (drawFins)     draw3DFins();
    if (drawRing)     draw3DTorus();
    if (drawWaveform) draw3DWaveform();

    buf.noLights();
    buf.blendMode(BLEND);
    buf.endDraw();

    // Blit + HUD
    pg.beginDraw();
    pg.background(0);
    pg.blendMode(BLEND);
    pg.image(buf, 0, 0);
    float ts = uiScale();
    pg.textFont(monoFont);
    pg.pushStyle();
    float hudLh = 11 * ts * 1.3, hudMg = 6 * ts;
    pg.fill(0, 140); pg.noStroke(); pg.rectMode(CORNER);
    pg.rect(8, 8, 360 * ts, hudMg * 2 + hudLh * 2);
    pg.fill(255, 220, 120); pg.textSize(11 * ts); pg.textAlign(LEFT, TOP);
    pg.text("Original 3D  (fins: " + nf(fins, 1, 1) + "  blend: " + blendNames[blendIdx] + ")", 12, 8 + hudMg);
    pg.fill(200, 200, 200);
    pg.text("w wave  x stacking  f fins  b blend  F rainbow  Y flip", 12, 8 + hudMg + hudLh);
    pg.popStyle();
    pg.endDraw();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3D DIAMONDS — double-pyramid shapes at the original's 4 corner positions
  // ══════════════════════════════════════════════════════════════════════════

  void draw3DDiamonds() {
    float pulse = 1.0 + sBass * 0.08 + beatFlash * 0.12;
    // Original places diamonds at 4 mirrored corners. In 3D we position
    // them at ±X, ±Y in the XZ plane (spread around the centre).
    float dist = (S * 0.55 + diamondDistCenter) * pulse;
    float sz   = (S * 0.28 + sBass * 20 + beatFlash * 15) * pulse;
    float halfH = sz * 0.7;  // half-height of the double pyramid

    float[][] positions = {
      { dist,  0,  dist},   // front-right
      {-dist,  0,  dist},   // front-left
      {-dist,  0, -dist},   // back-left
      { dist,  0, -dist}    // back-right
    };

    for (int d = 0; d < 4; d++) {
      float px = positions[d][0], py = positions[d][1], pz = positions[d][2];

      // Filled double-pyramid (like the original's solid red/orange quads)
      buf.fill(255, 76, 52, 210);
      buf.stroke(200, 50, 30);
      buf.strokeWeight(2.5);
      drawDoublePyramid(px, py, pz, sz, halfH);
    }
    buf.noFill();
  }

  // Double pyramid (octahedron-like but with a square cross-section)
  void drawDoublePyramid(float cx, float cy, float cz, float w, float h) {
    float hw = w * 0.5;
    // 6 vertices: top apex, bottom apex, 4 equator corners
    // Top
    float tx = cx, ty = cy - h, tz = cz;
    // Bottom
    float bx = cx, by = cy + h, bz = cz;
    // Equator (rotated 45° to look like a diamond from the front)
    float e0x = cx + hw, e0y = cy, e0z = cz;
    float e1x = cx,      e1y = cy, e1z = cz + hw;
    float e2x = cx - hw, e2y = cy, e2z = cz;
    float e3x = cx,      e3y = cy, e3z = cz - hw;

    buf.beginShape(TRIANGLES);
    // Top 4 faces
    buf.vertex(tx, ty, tz); buf.vertex(e0x, e0y, e0z); buf.vertex(e1x, e1y, e1z);
    buf.vertex(tx, ty, tz); buf.vertex(e1x, e1y, e1z); buf.vertex(e2x, e2y, e2z);
    buf.vertex(tx, ty, tz); buf.vertex(e2x, e2y, e2z); buf.vertex(e3x, e3y, e3z);
    buf.vertex(tx, ty, tz); buf.vertex(e3x, e3y, e3z); buf.vertex(e0x, e0y, e0z);
    // Bottom 4 faces
    buf.vertex(bx, by, bz); buf.vertex(e1x, e1y, e1z); buf.vertex(e0x, e0y, e0z);
    buf.vertex(bx, by, bz); buf.vertex(e2x, e2y, e2z); buf.vertex(e1x, e1y, e1z);
    buf.vertex(bx, by, bz); buf.vertex(e3x, e3y, e3z); buf.vertex(e2x, e2y, e2z);
    buf.vertex(bx, by, bz); buf.vertex(e0x, e0y, e0z); buf.vertex(e3x, e3y, e3z);
    buf.endShape();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3D FINS — bezier curves that sweep UP and OUT through Y and Z,
  // creating a flower/turbine shape with real depth
  // ══════════════════════════════════════════════════════════════════════════

  void draw3DFins() {
    int finCount = max(4, (int)fins);
    float spinAngle = config.logicalFrameCount * 0.008 * (finClockwise ? -1 : 1);
    float yOff = finYOffset;

    for (int i = 0; i < finCount; i++) {
      float t = (float)i / finCount;
      float rotAmount = TWO_PI * t;
      if (finClockwise) rotAmount = -rotAmount;

      float noiseW = noise(i * 0.3, config.logicalFrameCount * 0.01);
      float angle = radians(config.logicalFrameCount + noiseW) / 2.0 + rotAmount;
      float ca = cos(angle), sa = sin(angle);

      // Colour
      if (rainbowFins) {
        float hue = (t * 360 + config.logicalFrameCount * 0.4 + finRedness * 0.24) % 360;
        buf.colorMode(HSB, 360, 255, 255, 255);
        buf.stroke(hue, 220, 255);
        buf.fill(hue, 180, 220, 60);
        buf.colorMode(RGB, 255);
      } else {
        buf.stroke(10, 10, 12);
        buf.fill(60, 10, 50, 50);
      }
      buf.strokeWeight(4);

      // The original's bezier points, but we add Z variation:
      // Each fin curves upward (negative Y in 3D) and also tilts into Z,
      // so looking from the side shows a flower-like bowl shape.
      float xOff = -20;
      float finScale = 1.6;

      // Original bezier control points — we transform each (x,y) into 3D:
      //   X in 2D → radial outward (using ca/sa rotation)
      //   Y in 2D → becomes both Y and Z in 3D (fin curves up AND out in depth)
      //
      // Outer edge: P0(-36,-126) → P1(-36,-126) → P2(32,-118) → P3(68,-52)
      draw3DFinCurve(ca, sa, finScale, xOff, yOff,
        -36, -126, -36, -126, 32, -118, 68, -52);
      // Inner edge: P0(-36,-126) → P1(-36,-126) → P2(-10,-88) → P3(-22,-52)
      draw3DFinCurve(ca, sa, finScale, xOff, yOff,
        -36, -126, -36, -126, -10, -88, -22, -52);
      // Connecting curve: P0(-22,-52) → P1(-22,-52) → P2(20,-74) → P3(68,-52)
      draw3DFinCurve(ca, sa, finScale, xOff, yOff,
        -22, -52, -22, -52, 20, -74, 68, -52);
    }
    buf.noFill();
  }

  // Transform a 2D bezier curve into 3D: the original's Y axis maps to
  // both Y (vertical) and Z (depth), creating a bowl/turbine shape.
  void draw3DFinCurve(float ca, float sa, float scl, float xOff, float yOff,
                       float ax, float ay, float bx, float by,
                       float cx, float cy, float dx, float dy) {
    int steps = 20;
    float prevRX = 0, prevRY = 0, prevRZ = 0;
    for (int s = 0; s <= steps; s++) {
      float t = (float)s / steps;
      float u = 1 - t;
      float px = (u*u*u*(ax+xOff) + 3*u*u*t*(bx+xOff) + 3*u*t*t*(cx+xOff) + t*t*t*(dx+xOff)) * scl;
      float py = (u*u*u*(ay+yOff) + 3*u*u*t*(by+yOff) + 3*u*t*t*(cy+yOff) + t*t*t*(dy+yOff)) * scl;

      // Key 3D trick: the radial component (px) goes outward in the XZ plane,
      // the vertical component (py) maps partly to Y and partly to Z (depth).
      // This creates a flower that cups/bowls in 3D.
      float radial = px;      // distance from centre
      float lift   = py * 0.7;  // vertical rise
      float depth  = py * 0.5;  // Z depth (creates the 3D curvature)

      float rx = radial * ca - depth * sa;
      float ry = lift;
      float rz = radial * sa + depth * ca;

      if (s > 0) buf.line(prevRX, prevRY, prevRZ, rx, ry, rz);
      prevRX = rx; prevRY = ry; prevRZ = rz;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3D TORUS — actual torus ring with tube cross-section (not a flat circle)
  // ══════════════════════════════════════════════════════════════════════════

  void draw3DTorus() {
    float ringR = 100 * (1.0 + sBass * 0.1 + beatFlash * 0.12);
    float tubeR = 18  * (1.0 + sBass * 0.15);
    int ringSegs = 48, tubeSegs = 12;

    buf.stroke(204, 39, 242);
    buf.strokeWeight(3);
    buf.noFill();

    // Longitudinal rings (go around the big circle)
    for (int j = 0; j < tubeSegs; j++) {
      float phi = TWO_PI * j / tubeSegs;
      float cp = cos(phi), sp = sin(phi);
      float px = 0, py = 0, pz = 0;
      for (int i = 0; i <= ringSegs; i++) {
        float theta = TWO_PI * i / ringSegs;
        float ct = cos(theta), st = sin(theta);
        float x = (ringR + tubeR * cp) * ct;
        float y = tubeR * sp;
        float z = (ringR + tubeR * cp) * st;
        if (i > 0) buf.line(px, py, pz, x, y, z);
        px = x; py = y; pz = z;
      }
    }

    // Meridional rings (go around the tube cross-section)
    buf.strokeWeight(2);
    buf.stroke(180, 30, 220);
    for (int i = 0; i < ringSegs; i += 3) {
      float theta = TWO_PI * i / ringSegs;
      float ct = cos(theta), st = sin(theta);
      float px = 0, py = 0, pz = 0;
      for (int j = 0; j <= tubeSegs; j++) {
        float phi = TWO_PI * j / tubeSegs;
        float cp = cos(phi), sp = sin(phi);
        float x = (ringR + tubeR * cp) * ct;
        float y = tubeR * sp;
        float z = (ringR + tubeR * cp) * st;
        if (j > 0) buf.line(px, py, pz, x, y, z);
        px = x; py = y; pz = z;
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3D WAVEFORM — helix that spirals around the Y axis through the scene
  // ══════════════════════════════════════════════════════════════════════════

  void draw3DWaveform() {
    int wBufSz = audio.player.bufferSize();
    float helixR = 140;   // radius of helix
    float helixH = S * 0.8;  // total height
    int step = max(1, wBufSz / 300);

    float r_line = (config.logicalFrameCount % 255) / 10.0;
    float g_line = max(0, (config.logicalFrameCount % 255) - 75);
    float b_line = (config.logicalFrameCount % 255);

    buf.stroke(r_line, g_line, b_line);
    buf.strokeWeight(3.5);
    buf.strokeCap(ROUND);
    buf.noFill();

    float prevX = 0, prevY = 0, prevZ = 0;
    boolean first = true;

    for (int i = 0; i < wBufSz; i += step) {
      float t = (float)i / wBufSz;
      float angle = t * TWO_PI * 3;   // 3 full rotations
      float yPos = lerp(-helixH * 0.5, helixH * 0.5, t);

      // Audio amplitude modulates the helix radius
      float amp = audio.player.right.get(i) * config.WAVE_MULTIPLIER * 0.5;
      float r = helixR + amp;

      float x = cos(angle) * r;
      float y = yPos;
      float z = sin(angle) * r;

      if (!first) buf.line(prevX, prevY, prevZ, x, y, z);
      prevX = x; prevY = y; prevZ = z;
      first = false;
    }
  }

  // ── Interface stubs ───────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[] {
      "=== Original 3D ===",
      "// The mandala in true 3D",
      "// Diamonds \u2192 double pyramids",
      "// Fins sweep through Y and Z",
      "// Ring \u2192 torus   Waveform \u2192 helix"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("LStick \u2195", "Fin Y offset"),
      new ControllerLayout("RStick", "Orbit camera"),
      new ControllerLayout("A", "Toggle rainbow fins"),
      new ControllerLayout("B", "Cycle blend mode"),
      new ControllerLayout("X", "Toggle stacking/trails"),
      new ControllerLayout("Y", "Flip fin direction"),
      new ControllerLayout("LT", "Zoom in"),
      new ControllerLayout("RT", "Zoom out")
    };
  }
}