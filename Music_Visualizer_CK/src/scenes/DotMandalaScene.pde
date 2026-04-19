/**
 * DotMandalaScene (scene 41) — v2
 *
 * Concentric rings of dots forming a sacred geometry mandala.
 * Each ring maps to a distinct band of the frequency spectrum so individual
 * dots ripple and flare independently to their frequency content.
 *
 * Visual layers:
 *   Outer 2 rings → sub-bass/bass  (analyzer.spectrum bands 0–5)
 *   Middle 4 rings → mid           (bands 6–15)
 *   Inner 4 rings  → high          (bands 16–41)
 *   Beat bloom wave — radial shockwave expanding outward from center
 *   Polar waveform ring — raw oscilloscope at circumference (toggle with B)
 *
 * Audio:
 *   Bass        — outer ring size + rotation speed boost
 *   Mid         — mid ring brightness + inner rotation reversal
 *   High        — inner ring sparkle + waveform amplitude
 *   Beat        — bloom shockwave propagating outward
 *
 * Controller:
 *   LStick ↕    — zoom
 *   LT (hold)   — slow rotation
 *   RT (hold)   — fast rotation
 *   A           — cycle colour mode (blue/gold → rainbow → ice → ember)
 *   B           — toggle waveform ring
 *   X           — manual beat burst
 *   LB / RB     — reverse / step ring count
 */
class DotMandalaScene implements IScene, IForeground {

  // ── Audio smoothing ────────────────────────────────────────────────────────
  float sBass = 0, sMid = 0, sHigh = 0;

  // ── Per-dot elastic spring physics ────────────────────────────────────────
  // dotRadOff[ring][dot] = radial displacement from rest position (pixels)
  // dotRadVel[ring][dot] = radial velocity
  float[][] dotRadOff = new float[10][56];
  float[][] dotRadVel = new float[10][56];

  // ── Beat bloom wave ────────────────────────────────────────────────────────
  // wavePhase: 0 = just fired from center, 1 = reached edge
  float wavePhase = 2.0;   // start past edge (inactive)
  float waveSpeed = 0.022; // fraction of S advanced per frame
  float waveAlpha = 0.0;   // brightness of the wave

  // ── Visual state ──────────────────────────────────────────────────────────
  float rotation    = 0;
  float targetScale = 1.0;
  float userScale   = 1.0;
  float targetRot   = 0.003;   // target rotation speed
  float rotSpeed    = 0.003;
  int   colorMode   = 0;       // 0=blue/gold  1=rainbow  2=ice  3=ember
  boolean showWave  = true;    // polar waveform ring

  // ── Ring layout ───────────────────────────────────────────────────────────
  // [radius_tenths, dot_count, diam_hundredths, specBandLo, specBandHi]
  // radius  = S * radius_tenths / 10
  // dotDiam = S * diam_hundredths / 100  (before audio modulation)
  // spectrum band range maps to analyzer.spectrum[lo..hi]
  int[][] RINGS = {
    {10, 56,  3,  0,  2},   // sub-bass
    { 9, 46,  3,  2,  5},   // bass
    { 8, 38,  4,  5,  8},   // upper-bass
    { 7, 30,  4,  6, 10},   // low-mid
    { 6, 24,  5,  8, 14},   // mid
    { 5, 18,  6, 12, 18},   // upper-mid
    { 4, 14,  7, 16, 24},   // presence
    { 3, 10,  8, 22, 32},   // high
    { 2,  6, 11, 30, 40},   // very high
    { 1,  4, 15, 36, 47},   // air
  };

  // Per-ring smoothed audio levels
  float[] ringLevels = new float[10];

  // ── IScene lifecycle ───────────────────────────────────────────────────────
  void onEnter()  {
    rotation = 0;
    userScale = 1.0;
    wavePhase = 2.0;
    for (int i = 0; i < ringLevels.length; i++) ringLevels[i] = 0;
    for (int ri = 0; ri < 10; ri++)
      for (int di = 0; di < 56; di++) { dotRadOff[ri][di] = 0; dotRadVel[ri][di] = 0; }
  }
  void onExit() {}

  // ── Controller ────────────────────────────────────────────────────────────
  void applyController(Controller c) {
    if (c.aJustPressed) colorMode = (colorMode + 1) % 4;
    if (c.bJustPressed) showWave  = !showWave;
    if (c.xJustPressed) fireBoom();

    float ly = (c.ly - height * 0.5f) / (height * 0.5f);
    if (abs(ly) > 0.08) targetScale = constrain(targetScale - ly * 0.02, 0.4, 2.0);

    // LT/RT: rotation speed
    if (c.lt > 0.15) targetRot = lerp(targetRot, 0.0002, 0.08);
    if (c.rt > 0.15) targetRot = lerp(targetRot, 0.022, 0.08);
  }

  void handleKey(char k) {
    switch (k) {
      case 'c': case 'C': colorMode = (colorMode + 1) % 4; break;
      case 'w': case 'W': showWave  = !showWave;            break;
      case ' ':            fireBoom();                        break;
    }
  }

  void handleMouseWheel(int delta) {
    targetScale = constrain(targetScale - delta * 0.08, 0.35, 2.2);
  }

  // ── Draw ──────────────────────────────────────────────────────────────────
  String fgLabel() { return "Dot Mandala"; }

  void drawScene(PGraphics pg) {
    pg.beginDraw();
    pg.background(5, 8, 22);
    pg.blendMode(ADD);
    drawForeground(pg);
    pg.blendMode(BLEND);

    // ── HUD ───────────────────────────────────────────────────────────────
    float ts = uiScale();
    String[] modeNames = {"Blue/Gold", "Rainbow", "Ice", "Ember"};
    pg.textFont(monoFont);
    pg.textSize(9 * ts);
    pg.textAlign(RIGHT, BOTTOM);
    pg.fill(255, 255, 255, 70);
    pg.text("Dot Mandala \u2502 " + modeNames[colorMode] + (showWave ? " \u2502 wave" : ""),
            pg.width - 12 * ts, pg.height - 10 * ts);
    pg.textAlign(LEFT, BOTTOM);
    pg.text("A colour  B wave  X burst  LT/RT speed", 12 * ts, pg.height - 10 * ts);

    pg.endDraw();
  }

  void drawForeground(PGraphics pg) {
    // -- Audio update --
    sBass = lerp(sBass, analyzer.bass, 0.08);
    sMid  = lerp(sMid,  analyzer.mid,  0.08);
    sHigh = lerp(sHigh, analyzer.high, 0.08);

    // Per-ring spectrum levels
    for (int ri = 0; ri < RINGS.length; ri++) {
      int lo = RINGS[ri][3], hi = RINGS[ri][4];
      float sum = 0;
      for (int b = lo; b < hi && b < analyzer.spectrum.length; b++) {
        sum += analyzer.spectrum[b];
      }
      ringLevels[ri] = lerp(ringLevels[ri], sum / max(1, hi - lo), 0.10);
    }

    // Beat bloom
    if (audio.beat.isOnset()) fireBoom();
    wavePhase += waveSpeed;
    waveAlpha  = lerp(waveAlpha, 0, 0.07);

    // Rotation
    rotSpeed = lerp(rotSpeed, targetRot + sBass * 0.006, 0.04);
    rotation += rotSpeed;
    userScale = lerp(userScale, targetScale, 0.05);

    pg.noStroke();
    pg.pushMatrix();
    pg.translate(pg.width * 0.5, pg.height * 0.5);

    float S  = min(pg.width, pg.height) * 0.44 * userScale;
    float ts = uiScale();

    // ── Polar waveform ring ────────────────────────────────────────────────
    if (showWave && audio.player != null) {
      drawWaveformRing(pg, S * 1.13, ts);
    }

    // ── Rings of dots ─────────────────────────────────────────────────────
    for (int ri = 0; ri < RINGS.length; ri++) {
      int[] ring  = RINGS[ri];
      float r     = S * ring[0] / 10.0;
      int   nDots = ring[1];
      float baseD = S * ring[2] / 100.0;

      float av = ringLevels[ri];

      // Bloom wave: pulse when the shockwave radius passes this ring
      float ringFrac = ring[0] / 10.0; // 0.1 to 1.0
      float waveDist  = abs(ringFrac - (1.0 - wavePhase)); // distance to wave front
      float wavePulse = waveAlpha * max(0, 1.0 - waveDist / 0.18);

      float d     = baseD * (1.0 + av * 0.7 + wavePulse * 0.6);
      float rPulse = r * (1.0 + av * 0.03 + wavePulse * 0.04);

      // Alternating direction; inner rings run faster
      float dir     = (ri % 2 == 0) ? 1.0 : -0.7;
      float speed   = 1.0 + ri * 0.14;
      float ringRot = rotation * dir * speed;

      for (int i = 0; i < nDots; i++) {
        // Per-dot spectrum variation: map dot position to sub-band within ring's range
        int   lo    = ring[3], hi = ring[4];
        int   bin   = lo + (int)((float)i / nDots * (hi - lo));
        float dotAv = (bin < analyzer.spectrum.length) ? analyzer.spectrum[bin] : av;
        dotAv = lerp(av, dotAv, 0.5); // blend global ring level with per-dot bin

        // ── Elastic spring physics ──────────────────────────────────────────
        // Audio pushes dots outward; spring pulls them back to rest (offset=0)
        float audioForce = dotAv * 6.0 + wavePulse * 10.0;
        float springF    = -dotRadOff[ri][i] * 0.085;   // restoring force
        dotRadVel[ri][i] = dotRadVel[ri][i] * 0.70 + audioForce + springF;
        dotRadOff[ri][i] += dotRadVel[ri][i];
        dotRadOff[ri][i]  = constrain(dotRadOff[ri][i], -rPulse * 0.35, rPulse * 0.65);

        float angle  = TWO_PI * i / nDots + ringRot;
        float dotR   = rPulse + dotRadOff[ri][i];   // elastic radius
        float x      = cos(angle) * dotR;
        float y      = sin(angle) * dotR;

        float bright = constrain(0.38 + dotAv * 0.62 + wavePulse * 0.55, 0, 1);
        float dotD   = d * (0.7 + dotAv * 0.55 + wavePulse * 0.4);

        setDotColor(pg, ri, i, bright, wavePulse);
        pg.ellipse(x, y, dotD, dotD);
      }
    }

    // ── Center bindu ──────────────────────────────────────────────────────
    float cr = S * 0.042 * (1.0 + sBass * 0.4 + waveAlpha * 0.6);
    setBeatBinduColor(pg);
    pg.ellipse(0, 0, cr * 2, cr * 2);

    pg.popMatrix();
    pg.blendMode(BLEND);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void fireBoom() {
    wavePhase = 0.0;
    waveAlpha = 1.0;
  }

  void drawWaveformRing(PGraphics pg, float r, float ts) {
    int total = audio.player.left.size();
    if (total < 2) return;
    int useN  = min(256, total);
    int step  = max(1, total / useN);

    pg.strokeWeight(ts * 1.1);
    pg.noFill();

    // Color by mode
    switch (colorMode) {
      case 0: pg.stroke(60, 150, 255, 40 + (int)(sHigh * 40)); break;
      case 1:
        pg.colorMode(HSB, 360, 100, 100, 255);
        pg.stroke((config.logicalFrameCount * 1.5) % 360, 70, 80, 50);
        pg.colorMode(RGB, 255);
        break;
      case 2: pg.stroke(140, 220, 255, 38 + (int)(sHigh * 38)); break;
      case 3: pg.stroke(255, 140, 40, 38 + (int)(sHigh * 38));  break;
    }

    pg.beginShape();
    for (int i = 0; i < useN; i++) {
      float amp   = audio.player.left.get(i * step);
      float angle = TWO_PI * i / useN;
      float rad   = r + amp * r * 0.22 * (1.0 + sHigh * 0.5);
      pg.vertex(cos(angle) * rad, sin(angle) * rad);
    }
    pg.endShape(CLOSE);
  }

  void setDotColor(PGraphics pg, int ri, int di, float bright, float wave) {
    switch (colorMode) {
      case 0: // blue/gold alternating
        if (wave > 0.1) {
          pg.fill(255, 255, 255, (int)(wave * 200));
        } else if (ri % 2 == 0) {
          pg.fill(55, 130 + (int)(bright * 125), 240, 160 + (int)(bright * 95));
        } else {
          pg.fill(245, 195 + (int)(bright * 45), 30, 145 + (int)(bright * 110));
        }
        break;
      case 1: // rainbow
        pg.colorMode(HSB, 360, 100, 100, 255);
        float h = (ri * 36 + di * 6 + config.logicalFrameCount * 0.5f) % 360;
        pg.fill(h, 70, 55 + (int)(bright * 45), 150 + (int)(bright * 105) + (int)(wave * 60));
        pg.colorMode(RGB, 255);
        break;
      case 2: // ice
        float ic = 120 + (int)(bright * 135);
        pg.fill((int)(ic * 0.65f), (int)(ic * 0.88f), (int)ic,
                155 + (int)(bright * 100) + (int)(wave * 60));
        break;
      case 3: // ember — outer cool, inner hot
        float t = 1.0 - (float)(ri) / RINGS.length;
        int er = (int)(200 + t * 55);
        int eg = (int)(60 + t * 80 + bright * 60);
        int eb = (int)(10 + t * 30);
        pg.fill(er, eg, eb, 145 + (int)(bright * 110) + (int)(wave * 60));
        break;
    }
  }

  void setBeatBinduColor(PGraphics pg) {
    switch (colorMode) {
      case 0: pg.fill(210, 240, 255, 210); break;
      case 1:
        pg.colorMode(HSB, 360, 100, 100, 255);
        pg.fill((config.logicalFrameCount * 1.2f) % 360, 60, 100, 215);
        pg.colorMode(RGB, 255);
        break;
      case 2: pg.fill(180, 240, 255, 220); break;
      case 3: pg.fill(255, 200, 80, 220);  break;
    }
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────
  String[] getCodeLines() {
    return new String[]{
      "=== Dot Mandala ===",
      "",
      "10 rings, each mapped to",
      "a distinct spectrum band.",
      "Per-dot bin interpolation.",
      "",
      "Beat \u2192 shockwave from center",
      "Outer \u2192 sub-bass / bass",
      "Mid rings \u2192 mid",
      "Inner \u2192 high / air",
      "",
      "A colour  B waveform ring",
      "X burst   LT/RT speed",
      "scroll  zoom",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LStick \u2195",  "Zoom"),
      new ControllerLayout("LT / RT",       "Rotation speed"),
      new ControllerLayout("A",              "Cycle colour mode"),
      new ControllerLayout("B",              "Toggle waveform ring"),
      new ControllerLayout("X",              "Manual beat burst"),
    };
  }
}
