/**
 * TorusKnotScene (scene 34)
 *
 * A (p, q) torus knot — a closed curve that winds p times around the
 * torus longitudinally and q times meridionally.
 *
 * Parametric equations (φ ∈ [0, 2π]):
 *   r(φ) = cos(q·φ) + 2
 *   x(φ) = r(φ) · cos(p·φ)
 *   y(φ) = r(φ) · sin(p·φ)
 *   z(φ) = −sin(q·φ)
 *
 * Controller:
 *   LB / RB      — p winding number (2–9)
 *   X  / Y       — q winding number (2–9)
 *   LStick ↕     — zoom in / out
 *   LStick ↔     — hue offset (shift rainbow palette)
 *   RStick ↔↕   — orbit camera
 *   LT (held)    — slow auto-rotation
 *   RT (held)    — speed up auto-rotation
 *   A            — reset camera + rotation speed
 *   B            — cycle colour mode (rainbow / heat / neon / mono)
 *
 * Audio:
 *   Bass  — knot scale pulse + glow boost
 *   Mid   — auto-rotation speed
 *   High  — line brightness boost
 *   Beat  — scale spike + white flash
 */
class TorusKnotScene implements IScene {

  // ── Knot parameters ───────────────────────────────────────────────────────
  int p = 2, q = 3;
  static final int P_MIN = 2, P_MAX = 9;
  static final int Q_MIN = 2, Q_MAX = 9;

  // ── Geometry ──────────────────────────────────────────────────────────────
  static final int   SEGMENTS   = 900;
  static final float BASE_SCALE = 120;

  // ── Camera ────────────────────────────────────────────────────────────────
  float camAzim    =  0.5;
  float camElev    =  0.35;
  float camDist    =  680;
  float targetDist =  680;

  // ── Rotation speed ────────────────────────────────────────────────────────
  float rotSpeed       = 0.004;
  float targetRotSpeed = 0.004;

  // ── Colour ────────────────────────────────────────────────────────────────
  int   colorMode  = 0;       // 0=rainbow  1=heat  2=neon  3=mono
  float hueOffset  = 0;       // 0..360, shifted by LStick X
  float targetHue  = 0;

  // ── Audio smoothing ────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;
  float beatFlash = 0;        // 0..1, decays after beat

  // ── 3D buffer ─────────────────────────────────────────────────────────────
  PGraphics buf;

  // ── Precomputed curve ─────────────────────────────────────────────────────
  float[] cx, cy, cz;

  // ── IScene lifecycle ──────────────────────────────────────────────────────

  void onEnter() {
    buf = createGraphics(sceneBuffer.width, sceneBuffer.height, P3D);
    rebuildCurve();
  }

  void onExit() {
    if (buf != null) { buf.dispose(); buf = null; }
  }

  // ── Controller ────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // Winding numbers
    if (c.lbJustPressed) changeP(p - 1);
    if (c.rbJustPressed) changeP(p + 1);
    if (c.xJustPressed)  changeQ(q - 1);
    if (c.yJustPressed)  changeQ(q + 1);

    // Reset / colour mode
    if (c.aJustPressed) { camAzim = 0.5; camElev = 0.35; targetDist = 680; targetRotSpeed = 0.004; }
    if (c.bJustPressed) colorMode = (colorMode + 1) % 4;

    // LStick: zoom (Y) + hue offset (X)
    float lx = (c.lx - width  * 0.5f) / (width  * 0.5f);
    float ly = (c.ly - height * 0.5f) / (height * 0.5f);
    if (abs(ly) > 0.08) targetDist = constrain(targetDist + ly * 12, 250, 1400);
    if (abs(lx) > 0.08) targetHue  = (targetHue + lx * 2.5 + 360) % 360;

    // RStick: orbit
    float rx = (c.rx - width  * 0.5f) / (width  * 0.5f);
    float ry = (c.ry - height * 0.5f) / (height * 0.5f);
    if (abs(rx) > 0.08) camAzim += rx * 0.03;
    if (abs(ry) > 0.08) camElev  = constrain(camElev + ry * 0.025, -PI * 0.45, PI * 0.45);

    // Triggers: rotation speed (held state → lerp target)
    float slowTarget = 0.0005, fastTarget = 0.022;
    if (c.lt > 0.15) targetRotSpeed = lerp(targetRotSpeed, slowTarget, 0.08);
    if (c.rt > 0.15) targetRotSpeed = lerp(targetRotSpeed, fastTarget, 0.08);
  }

  void handleKey(char k) {
    switch (k) {
      case '[': changeP(p - 1); break;
      case ']': changeP(p + 1); break;
      case '-': changeQ(q - 1); break;
      case '=': changeQ(q + 1); break;
      case 'c': case 'C': colorMode = (colorMode + 1) % 4; break;
      case 'r': case 'R': camAzim = 0.5; camElev = 0.35; targetDist = 680; break;
    }
  }

  // ── Winding number helpers ─────────────────────────────────────────────────

  void changeP(int newP) {
    newP = constrain(newP, P_MIN, P_MAX);
    if (newP == q) newP = (newP < p) ? max(P_MIN, newP - 1) : min(P_MAX, newP + 1);
    if (newP != q && newP >= P_MIN && newP <= P_MAX) { p = newP; rebuildCurve(); }
  }

  void changeQ(int newQ) {
    newQ = constrain(newQ, Q_MIN, Q_MAX);
    if (newQ == p) newQ = (newQ < q) ? max(Q_MIN, newQ - 1) : min(Q_MAX, newQ + 1);
    if (newQ != p && newQ >= Q_MIN && newQ <= Q_MAX) { q = newQ; rebuildCurve(); }
  }

  // ── Geometry ──────────────────────────────────────────────────────────────

  void rebuildCurve() {
    int n = SEGMENTS;
    cx = new float[n + 1];
    cy = new float[n + 1];
    cz = new float[n + 1];
    for (int i = 0; i <= n; i++) {
      float phi = TWO_PI * i / n;
      float r   = cos(q * phi) + 2.0;
      cx[i] = r * cos(p * phi) * BASE_SCALE;
      cy[i] = r * sin(p * phi) * BASE_SCALE;
      cz[i] = -sin(q * phi)   * BASE_SCALE;
    }
  }

  // ── Colour lookup ─────────────────────────────────────────────────────────

  // Returns HSB hue for segment i, given total n segments.
  float segHue(int i, int n) {
    float t = (float) i / n;
    switch (colorMode) {
      case 0: return (hueOffset + t * 300) % 360;           // rainbow arc
      case 1: return (hueOffset + t * 60)  % 360;           // heat: red→yellow
      case 2: float[] neon = {180, 300, 60, 120};           // neon: 4-colour cycle
              return neon[(int)(t * 4) % 4];
      case 3: return hueOffset;                              // mono, hue controlled
      default: return 0;
    }
  }

  // ── Draw ──────────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    if (buf == null || buf.width != pg.width || buf.height != pg.height) {
      if (buf != null) buf.dispose();
      buf = createGraphics(pg.width, pg.height, P3D);
    }

    // Audio
    sBass  = lerp(sBass,  analyzer.bass,  0.08);
    sMid   = lerp(sMid,   analyzer.mid,   0.08);
    sHigh  = lerp(sHigh,  analyzer.high,  0.08);
    if (audio.beat.isOnset()) beatFlash = 1.0;
    beatFlash = lerp(beatFlash, 0, 0.08);
    sBeat     = beatFlash;

    // Smooth controls
    camDist    = lerp(camDist,    targetDist,    0.06);
    hueOffset  = lerp(hueOffset,  targetHue,     0.04);
    rotSpeed   = lerp(rotSpeed,   targetRotSpeed, 0.05);

    // Auto-rotate speed responds to mid energy
    camAzim += rotSpeed * (1.0 + sMid * 2.5);

    // Scale: bass pulse + beat spike
    float scaleMult = 1.0 + sBass * 0.12 + sBeat * 0.20;

    // ── 3D render ──────────────────────────────────────────────────────────
    buf.beginDraw();
    buf.background(5, 5, 14);
    buf.noFill();

    float eyeX = camDist * cos(camElev) * sin(camAzim);
    float eyeY = camDist * sin(camElev);
    float eyeZ = camDist * cos(camElev) * cos(camAzim);
    buf.camera(eyeX, eyeY, eyeZ, 0, 0, 0, 0, 1, 0);
    buf.perspective(PI / 3.5, (float)buf.width / buf.height, 5, 6000);

    int   n    = cx.length - 1;
    float glow = 0.55 + sBass * 0.70 + sBeat * 0.55 + sHigh * 0.35;
    float flash = sBeat;           // 0..1 white wash on beat

    buf.blendMode(ADD);
    buf.colorMode(HSB, 360, 100, 100, 100);

    // Scale all points by scaleMult inline
    // Glow pass — thick, translucent
    buf.strokeWeight(10);
    for (int i = 0; i < n; i++) {
      float h = segHue(i, n);
      float v = min(100, glow * 28 + flash * 25);
      buf.stroke(h, colorMode == 3 ? 20 : 65, v, 12 + flash * 8);
      buf.line(cx[i]*scaleMult, cy[i]*scaleMult, cz[i]*scaleMult,
               cx[i+1]*scaleMult, cy[i+1]*scaleMult, cz[i+1]*scaleMult);
    }

    // Core pass — thin, bright
    buf.strokeWeight(2.2);
    for (int i = 0; i < n; i++) {
      float h = segHue(i, n);
      float v = min(100, glow * 90 + sHigh * 15 + flash * 40);
      float a = 80 + sHigh * 15 + flash * 20;
      buf.stroke(h, colorMode == 3 ? 15 : 55, v, a);
      buf.line(cx[i]*scaleMult, cy[i]*scaleMult, cz[i]*scaleMult,
               cx[i+1]*scaleMult, cy[i+1]*scaleMult, cz[i+1]*scaleMult);
    }

    // High-energy shimmer: extra bright thin pass when treble spikes
    if (sHigh > 0.4) {
      buf.strokeWeight(0.8);
      for (int i = 0; i < n; i++) {
        float h = (segHue(i, n) + 180) % 360;   // complementary hue
        buf.stroke(h, 30, 100, sHigh * 30);
        buf.line(cx[i]*scaleMult, cy[i]*scaleMult, cz[i]*scaleMult,
                 cx[i+1]*scaleMult, cy[i+1]*scaleMult, cz[i+1]*scaleMult);
      }
    }

    buf.colorMode(RGB, 255);
    buf.blendMode(BLEND);
    buf.endDraw();

    // ── Blit + HUD ────────────────────────────────────────────────────────
    pg.beginDraw();
    pg.background(0);
    pg.blendMode(BLEND);
    pg.image(buf, 0, 0);

    float ts = uiScale();
    pg.textFont(monoFont);

    // Title
    pg.fill(255, 255, 255, 180 + (int)(sBeat * 75));
    pg.textSize(20 * ts);
    pg.textAlign(LEFT, TOP);
    pg.text("(" + p + ", " + q + ") Torus Knot", 18 * ts, 14 * ts);

    // Formula
    pg.fill(255, 255, 255, 75);
    pg.textSize(10 * ts);
    pg.text("r(\u03c6) = cos(" + q + "\u03c6)+2   x=r\u00b7cos(" + p + "\u03c6)   y=r\u00b7sin(" + p + "\u03c6)   z=-sin(" + q + "\u03c6)", 18 * ts, 40 * ts);

    // Colour mode indicator
    String[] modeNames = {"Rainbow", "Heat", "Neon", "Mono"};
    pg.fill(255, 255, 255, 110);
    pg.textSize(10 * ts);
    pg.textAlign(RIGHT, TOP);
    pg.text("B \u2192 " + modeNames[colorMode], pg.width - 14 * ts, 14 * ts);
    pg.text("[ ] p=" + p + "   -= q=" + q, pg.width - 14 * ts, 28 * ts);

    // Live readout bar: bass, mid, high
    drawAudioBar(pg, ts);

    pg.endDraw();
  }

  void drawAudioBar(PGraphics pg, float ts) {
    float bx = 18 * ts, by = pg.height - 28 * ts, bw = 6 * ts, bh = 20 * ts, gap = 10 * ts;
    String[] labels = {"B", "M", "H"};
    float[]  levels = {sBass, sMid, sHigh};
    int[]    cols   = {color(0, 180, 255), color(0, 255, 120), color(255, 80, 255)};
    pg.noStroke();
    for (int i = 0; i < 3; i++) {
      float fh = bh * levels[i];
      pg.fill(40, 40, 40, 160);
      pg.rect(bx + i * gap, by, bw, bh, 2);
      pg.fill(cols[i]);
      pg.rect(bx + i * gap, by + bh - fh, bw, fh, 2);
      pg.fill(255, 255, 255, 80);
      pg.textSize(7 * ts);
      pg.textAlign(CENTER, TOP);
      pg.text(labels[i], bx + i * gap + bw * 0.5, by + bh + 2 * ts);
    }
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Torus Knot (" + p + ", " + q + ") ===",
      "",
      "r(\u03c6) = cos(q\u03c6) + 2",
      "x = r\u00b7cos(p\u03c6)",
      "y = r\u00b7sin(p\u03c6)",
      "z = -sin(q\u03c6)",
      "",
      "p \u2260 q, gcd(p,q)=1 for knot.",
      "Shared factors \u2192 link.",
      "p = q \u2192 circle.",
      "",
      "Colour modes:",
      "  Rainbow / Heat / Neon / Mono",
      "",
      "Audio:",
      "  Bass  \u2192 scale + glow",
      "  Mid   \u2192 rotation speed",
      "  High  \u2192 shimmer + brightness",
      "  Beat  \u2192 scale spike + flash",
      "",
      "[ ] p   -= q   C colour",
      "R  reset camera",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LB / RB",       "p winding \u00b11"),
      new ControllerLayout("X / Y",         "q winding \u00b11"),
      new ControllerLayout("LStick \u2195", "Zoom"),
      new ControllerLayout("LStick \u2194", "Hue offset"),
      new ControllerLayout("RStick",        "Orbit camera"),
      new ControllerLayout("LT (hold)",     "Slow rotation"),
      new ControllerLayout("RT (hold)",     "Fast rotation"),
      new ControllerLayout("A",             "Reset camera + speed"),
      new ControllerLayout("B",             "Cycle colour mode"),
    };
  }
}
