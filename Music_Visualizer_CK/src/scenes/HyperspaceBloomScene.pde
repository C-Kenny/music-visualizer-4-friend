/**
 * HyperspaceBloomScene (scene 52) - Superformula Bloom
 *
 * A living 3D organic bloom generated entirely from Johan Gielis's
 * "superformula" - a single equation that describes an astonishing range of
 * natural forms (flowers, starfish, diatoms, crystals) as you sweep its
 * parameters:
 *
 *     r(θ) = ( |cos(m·θ/4) / a|^n2  +  |sin(m·θ/4) / b|^n3 ) ^ (-1/n1)
 *
 * The 3D surface is the spherical product of two superformulas - one sweeping
 * latitude, one sweeping longitude. We morph the parameters live with the
 * music so the shape continually "blooms":
 *
 *   Bass → n1   (lower n1 = spikier, more aggressive petals)
 *   Mid  → m    (rotational symmetry / petal count)
 *   High → n2/n3 (edge sharpness, surface filigree)
 *   Beat → radial bloom-pulse + pollen burst
 *
 * Rendered as an additive wireframe with glowing vertices, an inner core
 * light, and pollen motes that spray off the surface on each beat and drift
 * outward before fading. The camera orbits slowly; the right stick steers it.
 *
 * Controller:
 *   LStick ↕ - n1 spikiness
 *   LStick ↔ - m symmetry (petal count)
 *   RStick ↔↕ - orbit camera (disables auto-orbit)
 *   LB / RB - palette
 *   A - bloom burst (manual)
 *   B - toggle face fill / wireframe-only
 *   X - reset params + recentre camera
 *   Y - toggle auto-orbit
 */
class HyperspaceBloomScene implements IScene {

  // ── Mesh resolution ─────────────────────────────────────────────────────────
  // LAT bands × LON segments. 40×80 ≈ 3200 verts - cheap because the two
  // superformulas are evaluated only once per row/column (120 evals/frame),
  // then combined as a spherical product.
  static final int LAT = 40;
  static final int LON = 80;

  // Per-row / per-column superformula caches (recomputed each frame).
  float[] r1 = new float[LAT + 1];
  float[] cosT = new float[LAT + 1], sinT = new float[LAT + 1];
  float[] r2 = new float[LON + 1];
  float[] cosP = new float[LON + 1], sinP = new float[LON + 1];

  // Flattened vertex grid (built each frame from the caches above).
  float[] vx = new float[(LAT + 1) * (LON + 1)];
  float[] vy = new float[(LAT + 1) * (LON + 1)];
  float[] vz = new float[(LAT + 1) * (LON + 1)];
  // Same grid pre-multiplied by the on-screen world radius. We emit THESE so the
  // matrix carries only translate+rotate - never scale(). In P3D a strokeWeight
  // > 1 is built as triangulated geometry in model space, so a matrix scale()
  // would balloon every stroke to hundreds of px (the white-out bug). Baking the
  // scale into the coordinates keeps strokeWeight in honest pixels.
  float[] sx = new float[(LAT + 1) * (LON + 1)];
  float[] sy = new float[(LAT + 1) * (LON + 1)];
  float[] sz = new float[(LAT + 1) * (LON + 1)];

  // ── Superformula parameters (smoothed toward audio-driven targets) ──────────
  float m1 = 6,   tM1 = 6;     // latitude symmetry
  float n11 = 1,  tN11 = 1;    // latitude n1 (spikiness)
  float n21 = 1,  tN21 = 1;
  float n31 = 1,  tN31 = 1;
  float m2 = 6,   tM2 = 6;     // longitude symmetry
  float n12 = 1,  tN12 = 1;
  float n22 = 1,  tN22 = 1;
  float n32 = 1,  tN32 = 1;

  // Manual user offsets folded into the targets.
  float userM     = 6;     // base symmetry the user can nudge
  float userSpike = 1.0;   // base n1 the user can nudge (lower = spikier)

  // ── Animation / audio ───────────────────────────────────────────────────────
  float phase     = 0;
  float bloom      = 0;    // radial bloom-pulse, spikes on beat
  float beatFlash  = 0;
  float sBass = 0, sMid = 0, sHigh = 0;

  // ── Camera ──────────────────────────────────────────────────────────────────
  float camAzim = 0.6, camPitch = -0.3;
  float tAzim = 0.6, tPitch = -0.3;
  boolean autoOrbit = true;
  float orbit = 0;

  // Largest vertex radius in the current mesh - used to normalize on-screen
  // size so spiky/low-n1 params can't overflow the screen.
  float meshMaxR = 1;

  // ── Render options ──────────────────────────────────────────────────────────
  boolean faceFill = false;   // wireframe-only by default; faces blow out to white in ADD
  int palette = 0;
  // Each palette: {hueA, hueB, hueShiftSpeed}
  float[][] palettes = {
    {190, 320,  18},   // cyan → magenta
    { 35, 150,  12},   // amber → green
    {275, 200,  22},   // violet → blue
    {350,  60,  16},   // crimson → gold
    {120, 285,  20},   // green → purple
  };

  // ── Pollen particle pool ────────────────────────────────────────────────────
  static final int POLLEN = 320;
  float[] ppx = new float[POLLEN], ppy = new float[POLLEN], ppz = new float[POLLEN];
  float[] pvx = new float[POLLEN], pvy = new float[POLLEN], pvz = new float[POLLEN];
  float[] plife = new float[POLLEN];      // 1 → 0
  float[] phue  = new float[POLLEN];
  int pcursor = 0;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  void onEnter() {
    phase = 0; bloom = 0; beatFlash = 0;
    tAzim = camAzim; tPitch = camPitch; orbit = 0;
    for (int i = 0; i < POLLEN; i++) plife[i] = 0;
  }
  void onExit() {}

  void applyController(Controller c) {
    // LStick ↕ → spikiness (n1). Up = spikier (lower n1).
    float ly = (c.ly - height * 0.5f) / (height * 0.5f);   // -1..1
    if (abs(ly) > 0.08) userSpike = constrain(userSpike + ly * 0.04, 0.15, 3.0);
    // LStick ↔ → symmetry.
    float lx = (c.lx - width * 0.5f) / (width * 0.5f);
    if (abs(lx) > 0.10) userM = constrain(userM + lx * 0.10, 2, 20);

    // RStick → orbit camera.
    float rx = (c.rx - width * 0.5f) / (width * 0.5f);
    float ry = (c.ry - height * 0.5f) / (height * 0.5f);
    if (abs(rx) > 0.08) { tAzim += rx * 0.05; autoOrbit = false; }
    if (abs(ry) > 0.08) { tPitch = constrain(tPitch + ry * 0.04, -1.45, 1.45); autoOrbit = false; }

    if (c.lbJustPressed) palette = (palette - 1 + palettes.length) % palettes.length;
    if (c.rbJustPressed) palette = (palette + 1) % palettes.length;
    if (c.aJustPressed)  triggerBloom(1.0);
    if (c.bJustPressed)  faceFill = !faceFill;
    if (c.yJustPressed)  autoOrbit = !autoOrbit;
    if (c.xJustPressed) {
      userM = 6; userSpike = 1.0; palette = 0;
      tAzim = 0.6; tPitch = -0.3; autoOrbit = true;
    }
  }

  void handleKey(char k) {
    switch (k) {
      case '[': palette = (palette - 1 + palettes.length) % palettes.length; break;
      case ']': palette = (palette + 1) % palettes.length; break;
      case 'm': userM = constrain(userM - 1, 2, 20); break;
      case 'M': userM = constrain(userM + 1, 2, 20); break;
      case ' ': triggerBloom(1.0); break;
      case 'f': case 'F': faceFill = !faceFill; break;
      case 'y': case 'Y': autoOrbit = !autoOrbit; break;
      case 'r': case 'R':
        userM = 6; userSpike = 1.0; palette = 0;
        tAzim = 0.6; tPitch = -0.3; autoOrbit = true;
        break;
    }
  }

  void triggerBloom(float strength) {
    bloom = max(bloom, strength);
    spawnPollen((int)(24 + 40 * strength));
  }

  // ── Draw ──────────────────────────────────────────────────────────────────
  void drawScene(PGraphics pg) {
    // Audio (smoothed so the shape morphs rather than jitters).
    sBass = lerp(sBass, analyzer.bass, 0.12);
    sMid  = lerp(sMid,  analyzer.mid,  0.12);
    sHigh = lerp(sHigh, analyzer.high, 0.12);
    if (audio.beat.isOnset()) {
      beatFlash = config.calmFactor();
      triggerBloom(0.7 + 0.6 * sBass);
    }
    beatFlash = lerp(beatFlash, 0, 0.06);
    bloom     = lerp(bloom, 0, 0.05);

    phase += 0.004 + sMid * 0.012;
    if (autoOrbit) { orbit += 0.0035 + sMid * 0.004; tAzim = orbit; }
    camAzim  = lerp(camAzim,  tAzim,  0.08);
    camPitch = lerp(camPitch, tPitch, 0.08);

    // ── Parameter targets from audio + user nudges ──────────────────────────
    // Latitude superformula: symmetry from mid + user, n1 from bass + spike.
    tM1  = userM + sMid * 6;
    tN11 = constrain(userSpike - sBass * 0.55, 0.12, 3.0);
    tN21 = 1.0 + sHigh * 2.4;
    tN31 = 1.0 + sHigh * 2.4;
    // Longitude superformula: a complementary symmetry so the bloom is layered.
    tM2  = userM * 0.5 + 3 + sMid * 4;
    tN12 = constrain(userSpike * 1.1 - sBass * 0.4, 0.15, 3.0);
    tN22 = 1.0 + sHigh * 1.8 + sin(phase * 1.3) * 0.4;
    tN32 = 1.0 + sHigh * 1.8;

    float s = 0.10;
    m1  = lerp(m1,  tM1,  s);  n11 = lerp(n11, tN11, s);
    n21 = lerp(n21, tN21, s);  n31 = lerp(n31, tN31, s);
    m2  = lerp(m2,  tM2,  s);  n12 = lerp(n12, tN12, s);
    n22 = lerp(n22, tN22, s);  n32 = lerp(n32, tN32, s);

    buildMesh();
    updatePollen();

    // ── Render ──────────────────────────────────────────────────────────────
    float ts = uiScale();
    // Normalize so the largest vertex maps to a fixed fraction of the screen.
    // Guarantees the bloom fits regardless of how spiky the params get.
    float worldR = min(pg.width, pg.height) * (0.34 + bloom * 0.05) / meshMaxR;
    int vcount = (LAT + 1) * (LON + 1);
    for (int k = 0; k < vcount; k++) {
      sx[k] = vx[k] * worldR; sy[k] = vy[k] * worldR; sz[k] = vz[k] * worldR;
    }

    pg.beginDraw();
    // Additive glow reads best with depth test off - overlapping wireframe and
    // pollen sum into light instead of z-fighting. Re-enabled before endDraw.
    pg.hint(DISABLE_DEPTH_TEST);
    pg.background(2, 2, 7 + (int)(beatFlash * 6));
    pg.colorMode(HSB, 360, 100, 100, 100);

    pg.pushMatrix();
    pg.translate(pg.width * 0.5, pg.height * 0.5, 0);
    pg.rotateY(camAzim);
    pg.rotateX(camPitch);
    // NOTE: no scale() here - vertices are pre-scaled (sx/sy/sz) so strokeWeight
    // stays in pixels. See the sx[] field comment.

    float hueA = palettes[palette][0];
    float hueB = palettes[palette][1];
    float hueSpd = palettes[palette][2];
    float hueRot = phase * hueSpd;

    // Inner core glow - a soft additive sphere pulsing with bass. Low detail
    // + few layers keeps it cheap (sphere() at default detail is costly).
    pg.blendMode(ADD);
    pg.noStroke();
    pg.sphereDetail(12);
    // coreR in pixels: (frac)*meshMaxR*worldR; meshMaxR cancels worldR's divisor.
    float coreR = (0.18 + sBass * 0.12 + bloom * 0.10) * meshMaxR * worldR;
    for (int i = 3; i >= 1; i--) {
      float f = i / 3.0;
      pg.fill((hueA + hueRot) % 360, 60, 80, 8 * (1.0 - f) + beatFlash * 6);
      pg.sphere(coreR * (0.4 + f * 1.4));
    }

    // ── Optional translucent faces ──────────────────────────────────────────
    if (faceFill) {
      pg.blendMode(ADD);
      pg.noStroke();
      for (int la = 0; la < LAT; la++) {
        float fLat = (float) la / LAT;
        float hue = (lerp(hueA, hueB, fLat) + hueRot) % 360;
        float alpha = 6 + sHigh * 10 + beatFlash * 6;
        pg.fill(hue, 70, 55 + sHigh * 25, alpha);
        pg.beginShape(TRIANGLE_STRIP);
        for (int lo = 0; lo <= LON; lo++) {
          int a = idx(la,     lo);
          int b = idx(la + 1, lo);
          pg.vertex(sx[a], sy[a], sz[a]);
          pg.vertex(sx[b], sy[b], sz[b]);
        }
        pg.endShape();
      }
    }

    // ── Wireframe (latitude rings) ────────────────────────────────────────────
    // BLEND, not ADD - additive lines pile up to solid white where rings
    // overlap. BLEND keeps each ring a crisp colored stroke over the dark bg.
    pg.blendMode(BLEND);
    pg.noFill();
    pg.strokeWeight((1.1 + sHigh * 0.8 + bloom * 0.8) * ts);
    for (int la = 0; la <= LAT; la++) {
      float fLat = (float) la / LAT;
      float hue = (lerp(hueA, hueB, fLat) + hueRot) % 360;
      float bri = 70 + sHigh * 25 + beatFlash * 5;
      pg.stroke(hue, 85, bri, 78);
      pg.beginShape();
      for (int lo = 0; lo <= LON; lo++) {
        int a = idx(la, lo);
        pg.vertex(sx[a], sy[a], sz[a]);
      }
      pg.endShape();
    }
    // Longitude ribs (sparser - every 4th column) for a woven look.
    pg.strokeWeight((0.9 + bloom * 0.6) * ts);
    for (int lo = 0; lo <= LON; lo += 4) {
      float fLon = (float) lo / LON;
      float hue = (lerp(hueB, hueA, fLon) + hueRot) % 360;
      pg.stroke(hue, 70, 60 + sMid * 20, 55);
      pg.beginShape();
      for (int la = 0; la <= LAT; la++) {
        int a = idx(la, lo);
        pg.vertex(sx[a], sy[a], sz[a]);
      }
      pg.endShape();
    }

    // ── Glowing vertices on the bloom edge ───────────────────────────────────
    // Batched into one beginShape(POINTS) per row - individual point() calls
    // are a separate GL draw each and were the main FPS sink. ADD here is fine:
    // sparse points, so they sparkle rather than fill.
    pg.blendMode(ADD);
    pg.strokeWeight((3.0 + sBass * 3.0) * ts);
    for (int la = 0; la <= LAT; la += 3) {
      float fLat = (float) la / LAT;
      float hue = (lerp(hueA, hueB, fLat) + hueRot + 40) % 360;
      pg.stroke(hue, 50, 95, 35 + beatFlash * 40);
      pg.beginShape(POINTS);
      for (int lo = 0; lo <= LON; lo += 5) {
        int a = idx(la, lo);
        pg.vertex(sx[a], sy[a], sz[a]);
      }
      pg.endShape();
    }

    // ── Pollen ───────────────────────────────────────────────────────────────
    // Bucketed by remaining life into 3 batched POINTS passes (instead of one
    // point() per mote) so the fade survives without hundreds of draw calls.
    pg.strokeWeight(2.5 * ts);
    float pHue = (palettes[palette][1] + hueRot + 20) % 360;
    float[] bandMin = { 0.66, 0.33, 0.0 };
    float[] bandMax = { 1.01, 0.66, 0.33 };
    float[] bandAlpha = { 75, 45, 20 };
    for (int band = 0; band < 3; band++) {
      pg.stroke(pHue, 55, 100, bandAlpha[band]);
      pg.beginShape(POINTS);
      for (int i = 0; i < POLLEN; i++) {
        float l = plife[i];
        if (l > bandMin[band] && l <= bandMax[band])
          pg.vertex(ppx[i] * worldR, ppy[i] * worldR, ppz[i] * worldR);
      }
      pg.endShape();
    }

    pg.popMatrix();

    // ── HUD (unified terminal style) ──────────────────────────────────────────
    pg.blendMode(BLEND);
    pg.colorMode(RGB, 255);
    String[] hud = {
      "m(sym): " + nf(m1, 1, 1) + " / " + nf(m2, 1, 1) + "   n1: " + nf(n11, 1, 2),
      "palette " + (palette + 1) + "/" + palettes.length
                 + "   faces:" + (faceFill ? "on" : "off")
                 + "   orbit:" + (autoOrbit ? "auto" : "manual"),
      "bass " + bar(sBass) + " mid " + bar(sMid) + " high " + bar(sHigh),
      "LStick spike/sym  RStick orbit  A burst  B faces  Y orbit  X reset",
    };
    sceneHUD(pg, "Hyperspace Bloom", hud);

    pg.hint(ENABLE_DEPTH_TEST);
    pg.endDraw();
  }

  // ── Mesh construction ───────────────────────────────────────────────────────
  void buildMesh() {
    // Latitude θ ∈ [-π/2, π/2]; longitude φ ∈ [-π, π].
    for (int la = 0; la <= LAT; la++) {
      float t = map(la, 0, LAT, -HALF_PI, HALF_PI);
      r1[la]   = superR(t, m1, n11, n21, n31);
      cosT[la] = cos(t);
      sinT[la] = sin(t);
    }
    for (int lo = 0; lo <= LON; lo++) {
      float p = map(lo, 0, LON, -PI, PI);
      r2[lo]   = superR(p, m2, n12, n22, n32);
      cosP[lo] = cos(p);
      sinP[lo] = sin(p);
    }
    // Spherical product of the two superformulas. Track the largest radius so
    // the whole bloom can be normalized to a fixed on-screen size - otherwise
    // a low-n1 (spiky) frame produces radii up to the clamp and overflows.
    float maxR2 = 1e-4;
    for (int la = 0; la <= LAT; la++) {
      float rl = r1[la], ct = cosT[la], st = sinT[la];
      for (int lo = 0; lo <= LON; lo++) {
        int k = idx(la, lo);
        float rL = r2[lo];
        float x = rl * ct * rL * cosP[lo];
        float y = rl * st;                  // pole-to-pole axis = Y
        float z = rl * ct * rL * sinP[lo];
        vx[k] = x; vy[k] = y; vz[k] = z;
        float r2v = x*x + y*y + z*z;
        if (r2v > maxR2) maxR2 = r2v;
      }
    }
    meshMaxR = sqrt(maxR2);
  }

  // Gielis superformula radius. Guards against div-by-zero / NaN blowups.
  float superR(float angle, float m, float n1, float n2, float n3) {
    float t = m * angle / 4.0;
    float c = abs(cos(t));
    float s = abs(sin(t));
    // a = b = 1
    float p1 = pow(c, n2);
    float p2 = pow(s, n3);
    float sum = p1 + p2;
    if (sum < 1e-6) return 0;
    float r = pow(sum, -1.0 / max(n1, 0.05));
    if (Float.isNaN(r) || Float.isInfinite(r)) return 0;
    return constrain(r, 0, 4.0);   // clamp spikes so a frame can't explode the mesh
  }

  int idx(int la, int lo) { return la * (LON + 1) + lo; }

  // ── Pollen ──────────────────────────────────────────────────────────────────
  void spawnPollen(int count) {
    for (int n = 0; n < count; n++) {
      int i = pcursor;
      pcursor = (pcursor + 1) % POLLEN;
      // Spawn at a random surface vertex, fling outward along its radius.
      int k = (int) random((LAT + 1) * (LON + 1));
      float x = vx[k], y = vy[k], z = vz[k];
      float len = sqrt(x*x + y*y + z*z) + 1e-4;
      float spd = 0.006 + random(0.012);
      ppx[i] = x; ppy[i] = y; ppz[i] = z;
      pvx[i] = x / len * spd + random(-0.003, 0.003);
      pvy[i] = y / len * spd + random(-0.003, 0.003);
      pvz[i] = z / len * spd + random(-0.003, 0.003);
      plife[i] = 1.0;
      phue[i]  = (palettes[palette][1] + random(-30, 30) + 360) % 360;
    }
  }

  void updatePollen() {
    for (int i = 0; i < POLLEN; i++) {
      if (plife[i] <= 0) continue;
      ppx[i] += pvx[i]; ppy[i] += pvy[i]; ppz[i] += pvz[i];
      pvy[i] += 0.0002;          // faint gravity so motes settle
      plife[i] -= 0.012;
    }
  }

  // Tiny 4-cell text meter for the HUD.
  String bar(float v) {
    int n = (int) constrain(v * 4, 0, 4);
    String[] b = {"....", "|...", "||..", "|||.", "||||"};
    return b[n];
  }

  // ── IScene overlays ─────────────────────────────────────────────────────────
  String[] getCodeLines() {
    return new String[]{
      "=== Hyperspace Bloom ===",
      "  Gielis superformula (2003)",
      "",
      "r(θ) = ( |cos(mθ/4)/a|^n2",
      "       + |sin(mθ/4)/b|^n3 )^(-1/n1)",
      "",
      "3D surface = spherical product",
      "of two superformulas:",
      "  one sweeps latitude (θ),",
      "  one sweeps longitude (φ).",
      "",
      "Audio mapping:",
      "  Bass → n1  (spikiness)",
      "  Mid  → m   (petal symmetry)",
      "  High → n2/n3 (edge filigree)",
      "  Beat → bloom pulse + pollen",
      "",
      "One equation, endless flowers.",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LStick ↕", "Spikiness (n1)"),
      new ControllerLayout("LStick ↔", "Symmetry (m)"),
      new ControllerLayout("RStick",        "Orbit camera"),
      new ControllerLayout("LB / RB",       "Palette"),
      new ControllerLayout("A",             "Bloom burst"),
      new ControllerLayout("B",             "Faces on/off"),
      new ControllerLayout("Y",             "Auto-orbit"),
      new ControllerLayout("X",             "Reset"),
    };
  }
}
