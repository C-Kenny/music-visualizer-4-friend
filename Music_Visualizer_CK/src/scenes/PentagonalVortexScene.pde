/**
 * PentagonalVortexScene (scene 43) — v3
 *
 * Two modes (B to toggle), 3D is the default:
 *
 *   3D TUNNEL — camera sits INSIDE the vortex, looking forward.
 *   Pentagons scroll toward the viewer and wrap for an infinite loop.
 *   RStick spins the tunnel around you; tilt to look off-axis.
 *   LT/RT throttle the scroll speed. Beat lurches the camera forward.
 *   Bass breathes the ring size; mid spins the helix; high adds layers.
 *
 *   2D TOP-DOWN — phi-scaled nested polygons, beat shockwave, waveform ring.
 *
 * Controller (3D):
 *   LStick ↕    — zoom (move camera forward / back in tunnel)
 *   RStick ↔    — orbit: spin the tunnel around camera (twist)
 *   RStick ↕    — tilt: look up / down off the tunnel axis
 *   LT (hold)   — slow crawl
 *   RT (hold)   — warp speed
 *   A           — cycle colour (Rainbow → Fire → Ice → Deep Space)
 *   B           — switch to 2D top-down mode
 *   X           — beat burst (speed lurch + camera shake)
 *   LB / RB     — n-fold symmetry 5 → 6 → 7 → 8
 *
 * Controller (2D):
 *   LStick ↕    — zoom
 *   LT / RT     — phi exponent (spiral tightness)
 *   A           — colour mode
 *   B           — switch to 3D
 *   X           — beat burst
 *   LB / RB     — symmetry
 */
class PentagonalVortexScene implements IScene {

  // ── Off-screen 3D buffer ───────────────────────────────────────────────────
  PGraphics buf;

  // ── Audio ─────────────────────────────────────────────────────────────────
  float sBass=0, sMid=0, sHigh=0, sBeat=0;

  // ── Mode ──────────────────────────────────────────────────────────────────
  boolean mode3D = true;   // default: inside the tunnel

  // ── 3D tunnel state ────────────────────────────────────────────────────────
  // Camera is at (0, 0, camZ) looking toward +Z (into the tunnel).
  // tunnelOffset shifts all pentagon z-positions so they scroll toward camera.
  float tunnelOffset = 0;
  float tunnelSpeed  = 8;       // current scroll speed (units / frame)
  float targetSpeed  = 8;       // user-chosen target speed
  float hueOffset    = 0;       // cumulative hue shift — advances on each beat

  float camZ         = -380;    // eye z position  (negative = behind z=0 plane)
  float targetCamZ   = -380;

  float camAzim      = 0;       // world spin around Z — RStick X, accumulates
  float camElev      = 0;       // world tilt around X — RStick Y, clamped
  float globalRot    = 0;       // overall helix twist accumulated per frame

  // Tunnel geometry
  static final int   N_TUNNEL = 42;            // number of pentagon rings
  static final float ZSTEP    = 36.0;          // z spacing between rings
  static final float TOTAL_Z  = N_TUNNEL * ZSTEP;  // = 1512 — wrap length

  // ── 2D state ──────────────────────────────────────────────────────────────
  float rotation    = 0;
  float rotSpeed    = 0.005;
  float targetRot   = 0.005;
  float targetScale = 1.0;
  float userScale   = 1.0;
  float phiExp      = 0.38;
  float targetPhiExp = 0.38;
  float wavePhase   = 2.0;
  float waveAlpha   = 0.0;

  static final float PHI       = 1.6180339887;
  static final float WAVE_SPD  = 0.020;
  static final int   MAX_LAYERS = 34;

  // ── Symmetry + colour ─────────────────────────────────────────────────────
  int symmetry  = 5;
  int colorMode = 0;

  // ── IScene lifecycle ───────────────────────────────────────────────────────
  void onEnter() {
    buf = createGraphics(width, height, P3D);
    tunnelOffset = 0; hueOffset = 0;
    rotation = 0; wavePhase = 2.0; waveAlpha = 0;
  }

  void onExit() {
    if (buf != null) { buf.dispose(); buf = null; }
  }

  // ── Controller ────────────────────────────────────────────────────────────
  void applyController(Controller c) {
    if (c.aJustPressed) colorMode = (colorMode + 1) % 4;
    if (c.bJustPressed) mode3D   = !mode3D;
    if (c.xJustPressed) fireBurst();

    // Symmetry cycling (both modes)
    int[] symOpts = {5, 6, 7, 8};
    if (c.lbJustPressed) {
      for (int i = 0; i < symOpts.length; i++)
        if (symOpts[i] == symmetry) { symmetry = symOpts[(i - 1 + symOpts.length) % symOpts.length]; break; }
    }
    if (c.rbJustPressed) {
      for (int i = 0; i < symOpts.length; i++)
        if (symOpts[i] == symmetry) { symmetry = symOpts[(i + 1) % symOpts.length]; break; }
    }

    if (mode3D) {
      // LStick Y: zoom (move camera forward / back)
      float ly = (c.ly - height * 0.5f) / (height * 0.5f);
      if (abs(ly) > 0.08) targetCamZ = constrain(targetCamZ + ly * 10, -900, -40);

      // RStick: twist (X) + tilt (Y)
      float rx = (c.rx - width  * 0.5f) / (width  * 0.5f);
      float ry = (c.ry - height * 0.5f) / (height * 0.5f);
      if (abs(rx) > 0.08) camAzim += rx * 0.040;
      if (abs(ry) > 0.08) camElev = constrain(camElev + ry * 0.028, -1.3, 1.3);

      // LT/RT: speed
      if (c.lt > 0.15) targetSpeed = lerp(targetSpeed, 0.4, 0.08);
      if (c.rt > 0.15) targetSpeed = lerp(targetSpeed, 90,  0.08);
    } else {
      // 2D: LStick zoom, LT/RT phi exponent
      float ly = (c.ly - height * 0.5f) / (height * 0.5f);
      if (abs(ly) > 0.08) targetScale = constrain(targetScale - ly * 0.02, 0.3, 2.2);
      if (c.lt > 0.15) targetPhiExp = constrain(targetPhiExp - 0.001, 0.10, 0.85);
      if (c.rt > 0.15) targetPhiExp = constrain(targetPhiExp + 0.001, 0.10, 0.85);
    }
  }

  void handleKey(char k) {
    switch (k) {
      case 'c': case 'C': colorMode = (colorMode + 1) % 4; break;
      case '3':           mode3D   = !mode3D;               break;
      case ' ':           fireBurst();                        break;
      case '[': symmetry = (symmetry > 5) ? symmetry - 1 : 8; break;
      case ']': symmetry = (symmetry < 8) ? symmetry + 1 : 5; break;
      case '-': if (!mode3D) targetPhiExp = constrain(targetPhiExp - 0.02, 0.10, 0.85); break;
      case '=': if (!mode3D) targetPhiExp = constrain(targetPhiExp + 0.02, 0.10, 0.85); break;
    }
  }

  void handleMouseWheel(int delta) {
    if (mode3D) targetCamZ  = constrain(targetCamZ + delta * 30, -900, -40);
    else        targetScale = constrain(targetScale - delta * 0.07, 0.3, 2.2);
  }

  void fireBurst() {
    // Beat → advance hue palette (no speed change — speed is always smooth)
    hueOffset += 55 + sBass * 35;
    wavePhase  = 0.0;
    waveAlpha  = 1.0;
    sBeat      = 1.0;
  }

  // ── Draw dispatcher ───────────────────────────────────────────────────────
  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.08);
    sMid  = lerp(sMid,  analyzer.mid,  0.08);
    sHigh = lerp(sHigh, analyzer.high, 0.08);

    if (audio.beat.isOnset()) fireBurst();
    sBeat     = lerp(sBeat,     0, 0.07);
    wavePhase += WAVE_SPD;
    waveAlpha  = lerp(waveAlpha, 0, 0.075);

    phiExp   = lerp(phiExp, targetPhiExp, 0.04);
    rotSpeed = lerp(rotSpeed, targetRot + sMid * 0.018 + sBass * 0.006, 0.04);
    rotation += rotSpeed;
    userScale = lerp(userScale, targetScale, 0.05);

    if (mode3D) drawTunnel(pg);
    else        draw2D(pg);
  }

  // ── 3D TUNNEL ─────────────────────────────────────────────────────────────
  void drawTunnel(PGraphics pg) {
    if (buf == null) buf = createGraphics(width, height, P3D);

    // Scroll — constant speed, no audio speed changes
    tunnelSpeed   = lerp(tunnelSpeed, targetSpeed, 0.04);
    tunnelOffset += tunnelSpeed;
    tunnelOffset  = tunnelOffset % TOTAL_Z;

    // Helix twist: constant rate only — sMid contribution caused counter-rotation illusion
    globalRot += 0.005;

    camZ = lerp(camZ, targetCamZ, 0.05);

    buf.beginDraw();
    buf.background(3, 3, 11);

    // Camera inside the tunnel, looking forward (+Z)
    buf.camera(0, 0, camZ,   0, 0, 2500,   0, 1, 0);
    buf.perspective(PI / 2.2, (float)buf.width / buf.height, 8, 9000);

    // Rotate the WORLD instead of moving the camera — gives the "spin around you" feel
    buf.rotateZ(camAzim);
    buf.rotateX(camElev * 0.38);

    buf.blendMode(ADD);
    buf.noFill();

    float ts    = uiScale();
    float baseR = min(buf.width, buf.height) * 0.44;
    // Each full tunnel loop (N rings) = exactly one full rotation → seamless wrap
    float twistPerRing = TWO_PI / N_TUNNEL;

    for (int i = 0; i < N_TUNNEL; i++) {
      // z: [0, TOTAL_Z) with wrap, 0=closest to camera, TOTAL_Z=farthest
      float z = ((i * ZSTEP - tunnelOffset) % TOTAL_Z + TOTAL_Z) % TOTAL_Z;
      float t = z / TOTAL_Z;   // 0=near, 1=far

      // Helix rotation: z-based so wrapping is seamless;
      // globalRot provides the slow overall spin
      float rot = globalRot + (z / ZSTEP) * twistPerRing;

      // Per-layer spectrum band (near=bass, far=treble)
      int   bin    = constrain((int)(t * analyzer.spectrum.length), 0, analyzer.spectrum.length - 1);
      float binVal = analyzer.spectrum[bin];
      float audioV = lerp(sBass, sHigh, t) * 0.55 + binVal * 0.45;

      // Ring size: uniform base + audio pulse + beat flash (strongest for near rings)
      float r = baseR * (1.0 + audioV * 0.10 + sBeat * 0.08 * (1.0 - t * t));

      // Brightness: near rings are bright, far fade out; beat boosts near
      float bright = constrain(0.42 + audioV * 0.58 + sBeat * 0.45 * (1.0 - t), 0, 1);
      // Alpha: fade far rings and also fade in newly-wrapped rings (z < 80)
      float alpha  = constrain(1.08 - t * 0.88, 0.04, 1.0)
                   * constrain(z / 55.0, 0, 1);   // fade-in after wrap

      buf.strokeWeight(ts * constrain(2.5 - t * 1.8, 0.2, 2.5));
      setStroke(buf, (int)(z / ZSTEP), bright, alpha);

      buf.pushMatrix();
      buf.translate(0, 0, z);
      drawNgon(buf, r, rot, symmetry);
      buf.popMatrix();
    }

    buf.blendMode(BLEND);
    buf.endDraw();

    // Blit + HUD
    pg.beginDraw();
    pg.background(0);
    pg.blendMode(BLEND);
    pg.image(buf, 0, 0);

    float hts = uiScale();
    pg.textFont(monoFont);
    pg.textSize(9 * hts);
    pg.textAlign(RIGHT, BOTTOM);
    pg.fill(255, 255, 255, 70);
    pg.text("Vortex Tunnel 3D  " + symmetry + "-fold  " + colorNames()[colorMode],
            pg.width - 12 * hts, pg.height - 10 * hts);
    pg.textAlign(LEFT, BOTTOM);
    pg.text("RStick twist/tilt  LStick zoom  LT/RT speed  X burst  B:2D",
            12 * hts, pg.height - 10 * hts);
    pg.endDraw();
  }

  // ── 2D TOP-DOWN ────────────────────────────────────────────────────────────
  void draw2D(PGraphics pg) {
    pg.beginDraw();
    pg.background(4, 4, 11);
    pg.blendMode(ADD);
    pg.noFill();
    pg.translate(pg.width * 0.5, pg.height * 0.5);

    float S  = min(pg.width, pg.height) * 0.46 * userScale;
    float ts = uiScale();

    int layers = min(20 + (int)(sHigh * 8), MAX_LAYERS);

    for (int i = 0; i < layers; i++) {
      float r = S * (float) Math.pow(PHI, -i * phiExp);
      if (r < 4) break;

      float t      = i / (float) layers;
      float dir    = (i % 2 == 0) ? 1.0 : -1.15;
      float layRot = rotation * dir * (1.0 + i * 0.10);

      // Per-layer spectrum band
      int   bin    = constrain((int)(t * analyzer.spectrum.length), 0, analyzer.spectrum.length - 1);
      float binVal = analyzer.spectrum[bin];
      float audioV = lerp(sBass, sHigh, t) * 0.6 + binVal * 0.4;

      // Beat shockwave (propagates outward: inner=1 fires first, outer=0 fires last)
      float ringFrac  = 1.0 - t;
      float waveDist  = abs(ringFrac - wavePhase);
      float wavePulse = waveAlpha * max(0, 1.0 - waveDist / 0.14);

      float bright = constrain(0.40 + audioV * 0.60 + wavePulse * 0.55, 0, 1);
      float alpha  = constrain((1.0 - t * 0.38) * 0.90 + wavePulse * 0.45, 0, 1);
      float rDraw  = r * (1.0 + audioV * 0.04 + wavePulse * 0.06);

      pg.strokeWeight(ts * constrain(1.7 - t * 1.1, 0.28, 1.7));
      setStroke(pg, i, bright, alpha);
      drawNgon(pg, rDraw, layRot, symmetry);
    }

    // Radial spokes
    pg.strokeWeight(ts * 0.42);
    for (int i = 0; i < symmetry; i++) {
      float angle = TWO_PI * i / symmetry - HALF_PI + rotation;
      float a = constrain(0.18 + sBass * 0.28 + waveAlpha * 0.20, 0, 1);
      setStroke(pg, i * 4, a * 0.5, a);
      pg.line(0, 0, cos(angle) * S, sin(angle) * S);
    }

    // Center bindu
    pg.noStroke();
    float cr = S * 0.030 * (1.0 + sBeat * 1.6);
    setBinduColor(pg);
    pg.ellipse(0, 0, cr * 2, cr * 2);

    pg.blendMode(BLEND);
    pg.resetMatrix();
    float hts = uiScale();
    pg.textFont(monoFont);
    pg.textSize(9 * hts);
    pg.textAlign(RIGHT, BOTTOM);
    pg.fill(255, 255, 255, 70);
    pg.text("Vortex 2D  " + symmetry + "-fold  \u03c6^(-i*" + nf(phiExp, 1, 2) + ")  " + colorNames()[colorMode],
            pg.width - 12 * hts, pg.height - 10 * hts);
    pg.textAlign(LEFT, BOTTOM);
    pg.text("LT/RT spiral  LStick zoom  X burst  B:3D  [ ] sym",
            12 * hts, pg.height - 10 * hts);
    pg.endDraw();
  }

  // ── Geometry helpers ───────────────────────────────────────────────────────
  void drawNgon(PGraphics b, float r, float rot, int n) {
    b.beginShape();
    for (int i = 0; i < n; i++) {
      float angle = TWO_PI * i / n - HALF_PI + rot;
      b.vertex(cos(angle) * r, sin(angle) * r);
    }
    b.endShape(CLOSE);
  }

  // ── Colour ─────────────────────────────────────────────────────────────────
  String[] colorNames() { return new String[]{"Rainbow", "Fire", "Ice", "Deep Space"}; }

  void setStroke(PGraphics b, int idx, float bright, float alpha) {
    bright = constrain(bright, 0, 1);
    alpha  = constrain(alpha,  0, 1);
    // hueOffset shifts all colours on beat — permanent cumulative advance
    float ho = hueOffset;
    switch (colorMode) {
      case 0: // rainbow — hue cycles per-ring + time + beat offset
        b.colorMode(HSB, 360, 100, 100, 255);
        float h = (idx * 22 + config.logicalFrameCount * 0.7f + ho) % 360;
        b.stroke(h, 74, 52 + (int)(bright * 48), (int)(alpha * 200));
        b.colorMode(RGB, 255);
        break;
      case 1: // fire — beat shifts toward hotter hues
        b.colorMode(HSB, 360, 100, 100, 255);
        b.stroke(((int)(idx * 5 + ho * 0.3f)) % 58, 88, 50 + (int)(bright * 50), (int)(alpha * 215));
        b.colorMode(RGB, 255);
        break;
      case 2: // ice — beat cycles through cool tones
        b.colorMode(HSB, 360, 100, 100, 255);
        float hi = (185 + (idx * 4) % 60 + ho * 0.4f) % 360;
        b.stroke(hi, 55 - (int)(bright * 22), 62 + (int)(bright * 38), (int)(alpha * 200));
        b.colorMode(RGB, 255);
        break;
      case 3: // deep space — beat rotates the purple/blue palette
        b.colorMode(HSB, 360, 100, 100, 255);
        b.stroke((265 + idx * 6 + ho * 0.5f) % 360, 68, 46 + (int)(bright * 54), (int)(alpha * 205));
        b.colorMode(RGB, 255);
        break;
    }
  }

  void setBinduColor(PGraphics b) {
    switch (colorMode) {
      case 0:
        b.colorMode(HSB, 360, 100, 100, 255);
        b.fill((config.logicalFrameCount * 1.2f) % 360, 60, 100, 220);
        b.colorMode(RGB, 255);
        break;
      case 1: b.fill(255, 200, 80,  220); break;
      case 2: b.fill(180, 240, 255, 220); break;
      case 3: b.fill(120, 80,  255, 220); break;
    }
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────
  String[] getCodeLines() {
    return new String[]{
      "=== Pentagonal Vortex ===",
      "",
      "3D: camera inside, looking forward",
      "  42 rings, z-step 36, wraps",
      "  twist/ring = 2\u03c0/42 (seamless)",
      "  Near\u2192bass  Far\u2192treble",
      "",
      "2D: r(i)=S\u00d7\u03c6^(-i\u00d7" + nf(phiExp,1,2) + ")  " + symmetry + "-fold",
      "",
      "Beat \u2192 speed lurch + shake",
      "Bass \u2192 ring size + speed",
      "Mid  \u2192 helix twist speed",
      "High \u2192 treble bands + layers",
      "",
      "RStick twist/tilt  LStick zoom",
      "LT/RT speed   X burst   B mode",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LStick \u2195",       "Zoom (fly fwd/back)"),
      new ControllerLayout("RStick \u2194",       "Twist tunnel (orbit)"),
      new ControllerLayout("RStick \u2195",       "Tilt view up/down"),
      new ControllerLayout("LT / RT",            "Scroll speed (slow/warp)"),
      new ControllerLayout("A",                   "Cycle colour"),
      new ControllerLayout("B",                   "Toggle 3D \u2194 2D"),
      new ControllerLayout("X",                   "Beat burst + shake"),
      new ControllerLayout("LB / RB",            "Symmetry 5\u21928"),
    };
  }
}
