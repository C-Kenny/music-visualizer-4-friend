/**
 * SriYantraScene (scene 36)
 *
 * The Sri Yantra — a 2000-year-old sacred geometry diagram composed of
 * nine interlocking triangles (4 pointing up / Shiva, 5 pointing down / Shakti),
 * surrounded by lotus petals and a square outer boundary.
 *
 * Construction (approximate — true Sri Yantra requires solving a 5-variable
 * nonlinear system; this uses a high-quality numerical approximation):
 *
 *   • 4 upward isosceles triangles  (masculine principle)
 *   • 5 downward isosceles triangles (feminine principle)
 *   • 8-petal inner lotus
 *   • 16-petal outer lotus
 *   • Square boundary with 4 T-gates (Bhupura)
 *   • Central dot (Bindu)
 *
 * Each concentric region responds to a different audio band.
 *
 * Controller:
 *   RStick ↕  — zoom
 *   A          — toggle slow rotation
 *   B          — toggle colour mode (gold / rainbow / monochrome)
 *   Bass       — triangles pulse outward
 *   Mid        — lotus petals bloom
 *   Beat       — full flash
 */
class SriYantraScene implements IScene, IForeground {

  // ── Visual state ──────────────────────────────────────────────────────────
  float rotation   = 0;
  boolean autoRotate = true;
  int   colorMode  = 0;          // 0=gold  1=rainbow  2=mono
  float userScale  = 1.0;
  float targetScale = 1.0;

  // ── Audio smoothing ────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;

  // ── Prebuilt triangle PShapes (normalized S=1, rebuilt on onEnter) ────────
  PShape[] triShapes;

  // ── Triangle data ─────────────────────────────────────────────────────────
  // Each row: [tip_x, tip_y, base_y, half_width]  — normalized, y-up, unit=1
  // Positive tip_y = upward triangle; tip_y < base_y = downward triangle.
  // These are approximate but produce a visually convincing Sri Yantra.

  // Upward triangles (tip at top — negative screen y)
  // [tip_x, tip_y, base_y, base_half_width]  (y-up convention)
  float[][] upTri = {
    { 0,  0.955f, -0.440f,  0.810f },   // U1 — outermost
    { 0,  0.560f, -0.730f,  0.605f },   // U2
    { 0,  0.235f, -0.370f,  0.370f },   // U3
    { 0, -0.050f, -0.555f,  0.215f },   // U4 — innermost upward
  };

  // Downward triangles (tip at bottom — positive screen y)
  float[][] downTri = {
    { 0, -0.940f,  0.460f,  0.830f },   // D1 — outermost
    { 0, -0.555f,  0.695f,  0.610f },   // D2
    { 0, -0.240f,  0.460f,  0.455f },   // D3
    { 0,  0.060f,  0.590f,  0.295f },   // D4
    { 0,  0.185f,  0.080f,  0.125f },   // D5 — innermost downward (central triangle)
  };

  // ── IScene lifecycle ──────────────────────────────────────────────────────

  String fgLabel() { return "Sri Yantra"; }

  void onEnter() {
    rotation = 0;
    // Build normalized (S=1) triangle PShapes — vertex coords are fixed,
    // only scale changes per frame. Caller applies pg.scale(S*(1+pulse)).
    triShapes = new PShape[downTri.length + upTri.length];
    for (int i = 0; i < downTri.length; i++)
      triShapes[i] = _buildTriShape(downTri[i]);
    for (int i = 0; i < upTri.length; i++)
      triShapes[downTri.length + i] = _buildTriShape(upTri[i]);
  }
  void onExit() {}

  // Normalized triangle at S=1. disableStyle() so caller controls stroke/fill.
  PShape _buildTriShape(float[] t) {
    PShape s = createShape();
    s.beginShape();
    s.vertex( t[0], -t[1]);   // tip
    s.vertex(-t[3], -t[2]);   // base-left
    s.vertex( t[3], -t[2]);   // base-right
    s.endShape(CLOSE);
    s.disableStyle();
    return s;
  }

  // ── Controller ────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    if (c.aJustPressed) autoRotate = !autoRotate;
    if (c.bJustPressed) colorMode  = (colorMode + 1) % 3;

    float ry = 1.0 - (c.ry / (float) height);
    targetScale = lerp(0.4, 1.6, ry);
  }

  void handleKey(char k) {
    switch (k) {
      case 'r': case 'R': autoRotate = !autoRotate; break;
      case 'c': case 'C': colorMode  = (colorMode + 1) % 3; break;
    }
  }

  // ── Draw ──────────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    pg.beginDraw();
    pg.background(4, 3, 10);
    pg.blendMode(ADD);
    drawForeground(pg);
    pg.blendMode(BLEND);

    // ── Labels ─────────────────────────────────────────────────────────────
    float ts = uiScale();
    pg.textFont(monoFont);
    pg.fill(255, 215, 80, 140);
    pg.textSize(10 * ts);
    pg.textAlign(RIGHT, BOTTOM);
    pg.text("Sri Yantra", pg.width / 2 - 12 * ts, pg.height / 2 - 12 * ts);
    pg.fill(255, 255, 255, 60);
    pg.text("A rotate  B colour", pg.width / 2 - 12 * ts, pg.height / 2 - 1 * ts);

    pg.endDraw();
  }

  // Draw only the yantra geometry — no background, no blend mode changes.
  // Used by combo scenes that supply their own background layer.
  void drawForeground(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.06);
    sMid  = lerp(sMid,  analyzer.mid,  0.06);
    sHigh = lerp(sHigh, analyzer.high, 0.06);
    if (audio.beat.isOnset()) sBeat = 1.0;
    sBeat = lerp(sBeat, 0, 0.06);

    userScale = lerp(userScale, targetScale, 0.04);
    if (autoRotate) rotation += analyzer.rotDir * (0.0015 + sMid * 0.008);

    float S  = min(pg.width, pg.height) * 0.42 * userScale * (1.0 + sBass * 0.06);
    float ts = uiScale();

    pg.pushMatrix();
    pg.translate(pg.width * 0.5, pg.height * 0.5);
    pg.rotate(rotation);

    drawBhupura(pg, S * 1.28, ts);
    drawLotus(pg, S * 1.08, 16, sMid * 0.10, ts, 0);
    drawLotus(pg, S * 0.88, 8,  sMid * 0.14, ts, PI/8);

    for (int i = 0; i < downTri.length; i++) {
      float pulse = (i == 0) ? sBass * 0.05 : (i < 3 ? sMid * 0.04 : sHigh * 0.03);
      pg.noFill();
      setYantraStroke(pg, i, 0.5 + sBass * 0.3 + sBeat * 0.4, 0.7, ts);
      pg.strokeWeight(ts * (1.2 + sHigh * 1.0));
      pg.pushMatrix(); pg.scale(S * (1 + pulse)); pg.shape(triShapes[i]); pg.popMatrix();
    }
    for (int i = 0; i < upTri.length; i++) {
      float pulse = (i == 0) ? sBass * 0.04 : sMid * 0.03;
      pg.noFill();
      setYantraStroke(pg, i + 5, 0.5 + sBass * 0.3 + sBeat * 0.4, 0.9, ts);
      pg.strokeWeight(ts * (1.2 + sHigh * 1.0));
      pg.pushMatrix(); pg.scale(S * (1 + pulse)); pg.shape(triShapes[downTri.length + i]); pg.popMatrix();
    }

    pg.noFill();
    setYantraStroke(pg, 0, sBass + sBeat, 0.6, ts);
    pg.strokeWeight(1.5 * ts);
    pg.ellipse(0, 0, S * 0.18, S * 0.18);

    float bindR = S * 0.025 * (1 + sBeat * 0.8);
    pg.noStroke();
    setYantraFill(pg, 0, 1.0 + sBeat, ts);
    pg.ellipse(0, 0, bindR * 2, bindR * 2);

    pg.popMatrix();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void drawLotus(PGraphics pg, float R, int petals, float bloom, float ts, float phaseOffset) {
    pg.noFill();
    float petalW  = TWO_PI / petals;
    float bright  = 0.3 + sMid * 0.4;
    setYantraStroke(pg, -1, bright, 0.5, ts);
    pg.strokeWeight(ts * 0.9);

    for (int i = 0; i < petals; i++) {
      float angle = petalW * i + phaseOffset;
      float cx    = cos(angle) * R * 0.5;
      float cy    = sin(angle) * R * 0.5;
      float cr    = R * (0.52 + bloom);
      pg.ellipse(cx, cy, cr, cr);
    }
  }

  // Outer square with T-shaped gates on each side (Bhupura)
  void drawBhupura(PGraphics pg, float S, float ts) {
    pg.noFill();
    setYantraStroke(pg, -2, 0.4 + sHigh * 0.3, 0.6, ts);
    pg.strokeWeight(ts * 1.2);

    // Three concentric squares
    for (float f : new float[]{1.0, 0.92, 0.84}) {
      pg.rect(-S * f, -S * f, S * 2 * f, S * 2 * f);
    }

    // T-gates: a notch extending outward on each side center
    float gW = S * 0.18, gD = S * 0.08;
    // top
    pg.line(-gW, -S, -gW, -S - gD); pg.line(gW, -S, gW, -S - gD); pg.line(-gW, -S - gD, gW, -S - gD);
    // bottom
    pg.line(-gW,  S, -gW,  S + gD); pg.line(gW,  S, gW,  S + gD); pg.line(-gW,  S + gD, gW,  S + gD);
    // left
    pg.line(-S, -gW, -S - gD, -gW); pg.line(-S,  gW, -S - gD,  gW); pg.line(-S - gD, -gW, -S - gD,  gW);
    // right
    pg.line( S, -gW,  S + gD, -gW); pg.line( S,  gW,  S + gD,  gW); pg.line( S + gD, -gW,  S + gD,  gW);
  }

  // Set stroke colour according to colorMode and element index
  void setYantraStroke(PGraphics pg, int idx, float bright, float alpha, float ts) {
    bright = constrain(bright, 0, 1);
    switch (colorMode) {
      case 0: // gold palette
        float g = 180 + bright * 75;
        pg.stroke(g, g * 0.84, g * 0.2, alpha * 220); break;
      case 1: // rainbow — hue by element index
        pg.colorMode(HSB, 360, 100, 100, 100);
        float h = ((idx + 5) * 37) % 360;
        pg.stroke(h, 70, 60 + bright * 40, alpha * 90);
        pg.colorMode(RGB, 255); break;
      case 2: // monochrome
        float v = 120 + bright * 135;
        pg.stroke(v, v, v, alpha * 200); break;
    }
  }

  void setYantraFill(PGraphics pg, int idx, float bright, float ts) {
    bright = constrain(bright, 0, 1);
    switch (colorMode) {
      case 0: float g = 200 + bright * 55; pg.fill(g, g * 0.84, g * 0.2); break;
      case 1:
        pg.colorMode(HSB, 360, 100, 100);
        pg.fill(((idx + 5) * 37) % 360, 70, 60 + bright * 40);
        pg.colorMode(RGB, 255); break;
      case 2: float v = 180 + bright * 75; pg.fill(v, v, v); break;
    }
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Sri Yantra ===",
      "",
      "9 interlocking triangles:",
      "  4 upward   (Shiva)",
      "  5 downward  (Shakti)",
      "",
      "True construction requires",
      "solving a 5-variable nonlinear",
      "system for exact intersections.",
      "",
      "Concentric regions:",
      "  Triangles \u2192 bass / mid / high",
      "  Lotus 8   \u2192 mid bloom",
      "  Lotus 16  \u2192 mid bloom",
      "  Bhupura   \u2192 high",
      "  Bindu     \u2192 beat flash",
      "",
      "A rotate   B colour mode",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("RStick \u2195", "Zoom"),
      new ControllerLayout("A",            "Toggle rotation"),
      new ControllerLayout("B",            "Cycle colour mode"),
    };
  }
}
