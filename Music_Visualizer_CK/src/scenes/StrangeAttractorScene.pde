/**
 * StrangeAttractorScene (scene 47) — Opus 4.7 showcase v2
 *
 * 25,000 particles live inside a 3D vector field defined by one of six
 * classical strange attractors from dynamical systems theory:
 *
 *   Lorenz      dx = \u03c3(y\u2212x)
 *               dy = x(\u03c1\u2212z)\u2212y
 *               dz = xy\u2212\u03b2z                    (butterfly, 1963)
 *
 *   Aizawa      dx = (z\u2212b)x \u2212 dy
 *               dy = dx + (z\u2212b)y
 *               dz = c + az \u2212 z\u00b3/3 \u2212 (x\u00b2+y\u00b2)(1+ez) + fzx\u00b3
 *                                                 (double-torus halo)
 *
 *   Thomas      dx = sin(y) \u2212 bx
 *               dy = sin(z) \u2212 by
 *               dz = sin(x) \u2212 bz             (cyclically symmetric)
 *
 *   Halvorsen   dx = \u2212ax \u2212 4y \u2212 4z \u2212 y\u00b2
 *               dy = \u2212ay \u2212 4z \u2212 4x \u2212 z\u00b2
 *               dz = \u2212az \u2212 4x \u2212 4y \u2212 x\u00b2    (spiral braid)
 *
 *   R\u00f6ssler     dx = \u2212y \u2212 z
 *               dy = x + ay
 *               dz = b + z(x\u2212c)                  (taffy-pull)
 *
 *   Chen        dx = a(y\u2212x)
 *               dy = (c\u2212a)x \u2212 xz + cy
 *               dz = xy \u2212 bz                     (two-wing)
 *
 * The active system is crossfaded into the next on beat onsets, so the
 * vector field morphs continuously \u2014 particles are gracefully pushed from
 * one topology to another instead of teleporting. FFT bands live-modulate
 * a signature parameter per attractor so the shape breathes with the music.
 *
 * Rendering: each particle draws a short streak (current position \u2192 position
 * plus velocity) in a single batched LINES shape, additive blend for glow.
 * Colour maps from speed, depth, angle, or per-particle phase.
 *
 * Controller:
 *   RStick \u2194   Look (azimuth)
 *   RStick \u2195   Look (pitch, up \u2192 look up)
 *   LStick \u2195   Zoom
 *   LStick \u2194   Param bias (warps the signature parameter)
 *   LT / RT    Slow / fast integration
 *   A          Cycle colour mode (Speed / Depth / Angle / Phase)
 *   B          Cycle attractor manually
 *   X          Re-scatter particles
 *   Y          Toggle auto-orbit
 */
class StrangeAttractorScene implements IScene {

  // ── Particle cloud ────────────────────────────────────────────────────────
  static final int N = 25000;
  float[] px = new float[N], py = new float[N], pz = new float[N];
  float[] dx = new float[N], dy = new float[N], dz = new float[N];
  float[] phase = new float[N];           // static per-particle hue seed

  // ── Attractor systems ─────────────────────────────────────────────────────
  static final int N_SYS = 6;
  static final int LORENZ = 0, AIZAWA = 1, THOMAS = 2, HALVORSEN = 3, ROSSLER = 4, CHEN = 5;
  final String[] SYS_NAMES = { "Lorenz", "Aizawa", "Thomas", "Halvorsen", "Rossler", "Chen" };
  // Per-system timestep and world-space scale so each attractor fills space nicely.
  final float[] SYS_DT    = { 0.0045, 0.007,  0.012,  0.0055, 0.022,  0.0025 };
  final float[] SYS_SCALE = { 18.0,   220.0,  55.0,   38.0,   38.0,   14.0  };

  int   activeIdx    = 0;
  int   nextIdx      = -1;
  float morphT       = 0;                 // 0 = all active, 1 = all next

  // ── Audio smoothing ───────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0, sBeat = 0;
  int   beatCooldown = 0;

  // ── Camera ────────────────────────────────────────────────────────────────
  float camAzim = 0.4, camPitch = 0.25;
  float targetAzim = 0.4, targetPitch = 0.25;
  float camDist = 1800, targetDist = 1800;
  float orbitPhase = 0;
  boolean autoOrbit = true;

  // ── Tuneables ─────────────────────────────────────────────────────────────
  float paramBias   = 0;
  float targetBias  = 0;
  float timeScale   = 1.0;
  float targetTime  = 1.0;
  float streakLen   = 28.0;               // base streak length multiplier

  int   colorMode  = 0;                   // 0 speed, 1 depth, 2 angle, 3 phase
  final String[] COLOR_MODES = { "Speed", "Depth", "Angle", "Phase" };
  int   explodeFrames = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  StrangeAttractorScene() {
    scatter();
  }

  void onEnter() {
    scatter();
    sBeat = 0;
    orbitPhase = 0;
    nextIdx = -1;
    morphT = 0;
    explodeFrames = 0;
    targetAzim = camAzim;
    targetPitch = camPitch;
    targetDist = camDist;
  }
  void onExit() {}

  void scatter() {
    float s = SYS_SCALE[activeIdx];
    for (int i = 0; i < N; i++) {
      // Seed in a small cloud near origin, in the natural scale of the active
      // system. Chaos spreads them out within the first second.
      px[i] = (random(1) - 0.5) * s * 0.5;
      py[i] = (random(1) - 0.5) * s * 0.5;
      pz[i] = (random(1) - 0.5) * s * 0.5 + s * 0.4;  // small bias off origin
      dx[i] = dy[i] = dz[i] = 0;
      phase[i] = random(1);
    }
  }

  // ── Controller ────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    float lx = (c.lx - width  * 0.5f) / (width  * 0.5f);
    float ly = (c.ly - height * 0.5f) / (height * 0.5f);
    float rx = (c.rx - width  * 0.5f) / (width  * 0.5f);
    float ry = (c.ry - height * 0.5f) / (height * 0.5f);

    // RStick = look around. Push UP = look UP (non-inverted).
    if (abs(rx) > 0.08) { targetAzim  += rx * 0.06; autoOrbit = false; }
    if (abs(ry) > 0.08) { targetPitch  = constrain(targetPitch - ry * 0.05, -1.45, 1.45); autoOrbit = false; }

    // LStick Y = zoom; LStick X = param bias
    if (abs(ly) > 0.08) targetDist = constrain(targetDist + ly * 40, 400, 5000);
    if (abs(lx) > 0.08) targetBias = constrain(targetBias + lx * 0.02, -1.5, 1.5);

    targetTime = 1.0 + (c.rt - c.lt) * 2.2;

    if (c.aJustPressed) colorMode = (colorMode + 1) % COLOR_MODES.length;
    if (c.bJustPressed) startMorph((activeIdx + 1) % N_SYS);
    if (c.xJustPressed) explodeFrames = 18;
    if (c.yJustPressed) autoOrbit = !autoOrbit;
  }

  void handleKey(char k) {
    switch (k) {
      case 'a': case 'A': colorMode = (colorMode + 1) % COLOR_MODES.length; break;
      case 'b': case 'B': startMorph((activeIdx + 1) % N_SYS); break;
      case 'x': case 'X': explodeFrames = 18; break;
      case 'y': case 'Y': autoOrbit = !autoOrbit; break;
      case 'r': case 'R': scatter(); break;
    }
  }

  void startMorph(int target) {
    if (nextIdx >= 0 || target == activeIdx) return;             // already morphing
    nextIdx = target;
    morphT  = 0;
  }

  // ── Attractor equations ───────────────────────────────────────────────────
  // Write dt*f(x,y,z) into out[]. The caller adds this delta to the position.
  // Inline pointer-free form for speed; 25k particles * 6 attractors in hot loop.

  void stepSystem(int sys, float x, float y, float z,
                  float dt, float bias, float bassM, float midM, float highM,
                  float[] out) {
    float vx = 0, vy = 0, vz = 0;
    switch (sys) {
      case LORENZ: {
        // FFT modulates sigma with bass; rho with bias+mid.
        float sigma = 10.0  + bassM * 6.0;
        float rho   = 28.0  + midM  * 18.0 + bias * 10.0;
        float beta  = 8.0 / 3.0 + highM * 0.6;
        vx = sigma * (y - x);
        vy = x * (rho - z) - y;
        vz = x * y - beta * z;
        break;
      }
      case AIZAWA: {
        float a = 0.95 + bassM * 0.3;
        float b = 0.70 + bias  * 0.2;
        float c = 0.60 + midM  * 0.2;
        float d = 3.50 + highM * 0.6;
        float e = 0.25, f = 0.10;
        float zb = z - b;
        vx = zb * x - d * y;
        vy = d * x + zb * y;
        vz = c + a * z - (z * z * z) / 3.0
                      - (x * x + y * y) * (1.0 + e * z)
                      + f * z * x * x * x;
        break;
      }
      case THOMAS: {
        float bp = 0.208 + bias * 0.12 - bassM * 0.06;
        if (bp < 0.02) bp = 0.02;
        vx = sin(y) - bp * x;
        vy = sin(z) - bp * y;
        vz = sin(x) - bp * z;
        break;
      }
      case HALVORSEN: {
        float a = 1.4 + bias * 0.3 + midM * 0.4;
        vx = -a * x - 4.0 * y - 4.0 * z - y * y;
        vy = -a * y - 4.0 * z - 4.0 * x - z * z;
        vz = -a * z - 4.0 * x - 4.0 * y - x * x;
        break;
      }
      case ROSSLER: {
        float a = 0.20 + bassM * 0.10;
        float b = 0.20;
        float c = 5.70 + bias * 1.5 + midM * 1.0;
        vx = -y - z;
        vy = x + a * y;
        vz = b + z * (x - c);
        break;
      }
      default: { // CHEN
        float a = 35.0 + bassM * 6.0;
        float b =  3.0 + bias  * 1.0;
        float cc= 28.0 + midM  * 6.0;
        vx = a * (y - x);
        vy = (cc - a) * x - x * z + cc * y;
        vz = x * y - b * z;
        break;
      }
    }
    out[0] = vx * dt;
    out[1] = vy * dt;
    out[2] = vz * dt;
  }

  // ── Draw ──────────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    // Audio
    sBass = lerp(sBass, analyzer.bass, 0.10);
    sMid  = lerp(sMid,  analyzer.mid,  0.10);
    sHigh = lerp(sHigh, analyzer.high, 0.10);
    if (audio.beat.isOnset()) {
      sBeat = 1.0;
      if (beatCooldown <= 0 && nextIdx < 0) {
        // Rotate to next attractor on beat (with a cooldown so we don't
        // flap between systems on every snare hit).
        startMorph((activeIdx + 1) % N_SYS);
        beatCooldown = 180;
      }
    }
    sBeat = lerp(sBeat, 0, 0.08);
    if (beatCooldown > 0) beatCooldown--;

    // Smooth inputs
    paramBias = lerp(paramBias, targetBias, 0.06);
    timeScale = lerp(timeScale, targetTime, 0.08);
    camAzim   = lerp(camAzim,   targetAzim,  0.08);
    camPitch  = lerp(camPitch,  targetPitch, 0.08);
    camDist   = lerp(camDist,   targetDist,  0.06);

    // Auto orbit nudges targetAzim slowly
    if (autoOrbit) {
      orbitPhase += 0.0025;
      targetAzim = orbitPhase;
    }

    // Advance morph between attractors
    if (nextIdx >= 0) {
      morphT += 0.006 * timeScale;
      if (morphT >= 1.0) {
        activeIdx = nextIdx;
        nextIdx   = -1;
        morphT    = 0;
      }
    }

    // Step particles
    stepParticles();

    // Render
    pg.beginDraw();
    pg.background(3, 3, 8);

    pg.pushMatrix();
    pg.translate(pg.width * 0.5, pg.height * 0.5, 0);
    pg.rotateX(camPitch);
    pg.rotateY(camAzim);
    pg.translate(0, 0, -camDist);

    pg.colorMode(HSB, 360, 100, 100, 100);
    pg.blendMode(ADD);
    pg.strokeWeight(1.25 + sBass * 1.2 + sBeat * 0.6);

    drawParticles(pg);

    pg.blendMode(BLEND);
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

  // ── Simulation ────────────────────────────────────────────────────────────

  float[] deltaA = new float[3];
  float[] deltaB = new float[3];

  void stepParticles() {
    float bias    = paramBias;
    float bassM   = sBass, midM = sMid, highM = sHigh;
    float scaleA  = SYS_SCALE[activeIdx];
    float dtA     = SYS_DT[activeIdx]    * timeScale * (1.0 + sBass * 0.4);
    float scaleB  = (nextIdx >= 0) ? SYS_SCALE[nextIdx] : scaleA;
    float dtB     = (nextIdx >= 0) ? SYS_DT[nextIdx] * timeScale * (1.0 + sBass * 0.4) : dtA;
    float w       = morphT;               // blend weight for "next" during morph
    int   sysA    = activeIdx, sysB = (nextIdx >= 0) ? nextIdx : activeIdx;
    float kick    = explodeFrames > 0 ? 40.0 : 0;
    if (explodeFrames > 0) explodeFrames--;

    // Integrate each particle in attractor-local coordinates. We divide
    // by the system scale going in and multiply on render, so particles
    // stay in numerically stable ranges.
    for (int i = 0; i < N; i++) {
      // Convert world pos back to system-local.
      float xA = px[i] / scaleA, yA = py[i] / scaleA, zA = pz[i] / scaleA;

      stepSystem(sysA, xA, yA, zA, dtA, bias, bassM, midM, highM, deltaA);
      float dxW, dyW, dzW;
      if (nextIdx >= 0) {
        // Compute the next system on the same world coord (in its native scale).
        float xB = px[i] / scaleB, yB = py[i] / scaleB, zB = pz[i] / scaleB;
        stepSystem(sysB, xB, yB, zB, dtB, bias, bassM, midM, highM, deltaB);
        // Blend deltas in world space (already multiplied by local dt;
        // rescale each to world units).
        float aw = (1.0 - w);
        dxW = deltaA[0] * scaleA * aw + deltaB[0] * scaleB * w;
        dyW = deltaA[1] * scaleA * aw + deltaB[1] * scaleB * w;
        dzW = deltaA[2] * scaleA * aw + deltaB[2] * scaleB * w;
      } else {
        dxW = deltaA[0] * scaleA;
        dyW = deltaA[1] * scaleA;
        dzW = deltaA[2] * scaleA;
      }

      // Explode kick — shove particles outward radially.
      if (kick > 0) {
        float rr = sqrt(px[i]*px[i] + py[i]*py[i] + pz[i]*pz[i]) + 1e-3;
        dxW += kick * px[i] / rr;
        dyW += kick * py[i] / rr;
        dzW += kick * pz[i] / rr;
      }

      // Velocity clamp — chaotic systems can spike briefly; cap so a frame
      // doesn't throw a particle halfway to the moon.
      float maxStep = 60.0;
      if (dxW >  maxStep) dxW =  maxStep; else if (dxW < -maxStep) dxW = -maxStep;
      if (dyW >  maxStep) dyW =  maxStep; else if (dyW < -maxStep) dyW = -maxStep;
      if (dzW >  maxStep) dzW =  maxStep; else if (dzW < -maxStep) dzW = -maxStep;

      dx[i] = dxW;  dy[i] = dyW;  dz[i] = dzW;
      px[i] += dxW; py[i] += dyW; pz[i] += dzW;

      // Bounding sphere: respawn particles that flee too far.
      float r2 = px[i]*px[i] + py[i]*py[i] + pz[i]*pz[i];
      float maxR = 1600;
      if (r2 > maxR * maxR) {
        float sn = lerp(scaleA, scaleB, w);
        px[i] = (random(1) - 0.5) * sn * 0.5;
        py[i] = (random(1) - 0.5) * sn * 0.5;
        pz[i] = (random(1) - 0.5) * sn * 0.5 + sn * 0.3;
        dx[i] = dy[i] = dz[i] = 0;
      }
    }
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  void drawParticles(PGraphics pg) {
    float k = streakLen;
    float beatBoost = 1.0 + sBeat * 0.8;
    // One batched LINES shape; per-vertex stroke via pg.stroke() inside
    // beginShape is honoured in P3D.
    pg.noFill();
    pg.beginShape(LINES);
    for (int i = 0; i < N; i++) {
      float vx = dx[i], vy = dy[i], vz = dz[i];
      float spd = sqrt(vx*vx + vy*vy + vz*vz);
      float hue, sat, bri, alp;
      switch (colorMode) {
        case 0: { // Speed → hue ramp
          float t = constrain(spd * 0.025, 0, 1);
          hue = (200 + t * 180) % 360;
          sat = 95; bri = 50 + t * 50; alp = 65 + t * 30;
          break;
        }
        case 1: { // Depth → hue
          float t = constrain((pz[i] + 600) / 1200.0, 0, 1);
          hue = (40 + t * 300) % 360;
          sat = 90; bri = 65 + t * 30; alp = 70;
          break;
        }
        case 2: { // Angle around Y axis
          float t = (atan2(pz[i], px[i]) / TWO_PI + 0.5);
          hue = (t * 360 + sBeat * 60) % 360;
          sat = 95; bri = 70 + sBass * 20; alp = 75;
          break;
        }
        default: { // Phase — static per-particle hue cycling with time
          hue = (phase[i] * 360 + frameCount * 0.6) % 360;
          sat = 90; bri = 70 + sHigh * 25; alp = 70;
          break;
        }
      }
      alp *= beatBoost;
      if (alp > 100) alp = 100;
      int cStart = color(hue, sat, bri * 0.55, alp * 0.45);
      int cEnd   = color(hue, sat, bri,        alp);
      pg.stroke(cStart);
      pg.vertex(px[i] - vx * k, py[i] - vy * k, pz[i] - vz * k);
      pg.stroke(cEnd);
      pg.vertex(px[i], py[i], pz[i]);
    }
    pg.endShape();
  }

  // ── HUD ───────────────────────────────────────────────────────────────────

  void drawHUD(PGraphics pg) {
    float ts = uiScale();
    pg.textFont(monoFont);
    pg.textAlign(LEFT, TOP);
    pg.fill(255, 220);
    pg.textSize(17 * ts);
    String sysLabel = SYS_NAMES[activeIdx];
    if (nextIdx >= 0) sysLabel += " \u2192 " + SYS_NAMES[nextIdx] + "  (" + nf(morphT, 1, 2) + ")";
    pg.text("Strange Attractor: " + sysLabel, 18 * ts, 16 * ts);

    pg.fill(255, 140);
    pg.textSize(11 * ts);
    pg.text("color: " + COLOR_MODES[colorMode]
          + "   bias: " + nf(paramBias, 1, 2)
          + "   dt\u00d7: " + nf(timeScale, 1, 2)
          + "   orbit: " + (autoOrbit ? "auto" : "manual"),
          18 * ts, 44 * ts);

    pg.fill(255, 80);
    pg.textAlign(RIGHT, TOP);
    pg.text("RStick look  LStick zoom/bias  LT/RT time  A color  B next system  X explode  Y orbit",
            pg.width - 18 * ts, 16 * ts);
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    String[] lines = {
      "=== Strange Attractor ===",
      "",
      "Active: " + SYS_NAMES[activeIdx],
      "",
      "Each particle integrates a 3D ODE",
      "  dx/dt = f(x, y, z; \u03b8)",
      "",
      "with the active system's vector field.",
      "Morph between systems on beat by",
      "blending deltas in world coords:",
      "  \u0394 = (1-t)\u0394_old + t\u0394_new",
      "",
      "FFT live-modulates signature params:",
      "  bass \u2192 \u03c3 / a",
      "  mid  \u2192 \u03c1 / c",
      "  high \u2192 \u03b2 / d",
      "",
      "Colour maps from speed / depth /",
      "angle / phase \u2014 'A' cycles them."
    };
    return lines;
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("RStick \u2194", "Camera azimuth"),
      new ControllerLayout("RStick \u2195", "Camera pitch"),
      new ControllerLayout("LStick \u2195", "Zoom"),
      new ControllerLayout("LStick \u2194", "Param bias"),
      new ControllerLayout("LT / RT",       "Slow / fast"),
      new ControllerLayout("A",             "Cycle colour"),
      new ControllerLayout("B",             "Next attractor"),
      new ControllerLayout("X",             "Explode particles"),
      new ControllerLayout("Y",             "Toggle auto-orbit"),
    };
  }
}
