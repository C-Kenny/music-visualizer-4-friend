/**
 * ButtonChordsScene – Scene 27
 *
 * A multi-input wave-interference illusion.
 * Each of the six main buttons (A / B / X / Y / LB / RB) radiates a
 * circular sinusoidal wave from a unique position on screen.
 * Holding multiple buttons simultaneously superimposes their wave
 * fields, producing complex Moiré / standing-wave patterns that look
 * far richer than any single input alone.
 *
 * Button state is read from the held-state flags (_button), NOT from
 * the rising-edge flags (_just_pressed), so all six sources can be
 * active at once without flickering.  Activations are lerp-smoothed
 * to give a soft fade-in / fade-out on each press / release.
 *
 * Audio mapping:
 *   bass   → speeds up the wave animation
 *   beat   → pulses the brightness of all active sources
 *
 * Controller:
 *   A / B / X / Y  – hold to activate wave source (face buttons)
 *   LB / RB        – hold to activate shoulder wave sources
 *   LT             – slow all wave speeds
 *   RT             – tighten spatial frequency (finer fringes)
 *   L-Stick Y      – master brightness
 *
 * Keyboard (no controller):
 *   1 – 6          – toggle the six wave sources
 */
class ButtonChordsScene implements IScene {

  // ── Rendering ─────────────────────────────────────────────────────────────
  static final int   RSCALE           = 6;     // pixel-block size for fast render
  static final float BASE_FREQ        = 0.016; // spatial frequency (radians/pixel)
  static final float BASE_SPEED       = 0.035; // wave animation speed (radians/frame)
  static final float IRIDESCENCE_SHIFT = 28;   // hue rotation (degrees) driven by wave phase

  // ── Per-source layout ─────────────────────────────────────────────────────
  // A=bottom, B=right, X=left, Y=top, LB=upper-left, RB=upper-right
  PVector[] sources   = new PVector[6];
  int[]     hues      = {  0, 20, 215,  90, 270, 170 };  // hue (HSB 0-360)
  float[]   freqMults = { 1.00, 1.55, 0.78, 1.28, 0.92, 1.12 };
  float[]   spdMults  = { 1.00, 0.82, 1.18, 0.72, 1.35, 0.94 };
  String[]  labels    = { "A", "B", "X", "Y", "LB", "RB" };

  // ── Runtime state ─────────────────────────────────────────────────────────
  float[] activation = new float[6]; // lerp 0 → 1 while button is held
  boolean[] kbHeld   = new boolean[6]; // toggled by keys 1-6

  float time         = 0;
  float beatPulse    = 0;
  float freqScale    = 1.0;   // RT expands, LT contracts
  float speedScale   = 1.0;   // LT slows
  float masterBright = 0.85;  // L-Stick Y

  PImage canvas;
  int rw = 0, rh = 0;

  // ── IScene ────────────────────────────────────────────────────────────────

  void onEnter() {
    for (int i = 0; i < 6; i++) {
      activation[i] = 0;
      kbHeld[i]     = false;
    }
    beatPulse    = 0;
    freqScale    = 1.0;
    speedScale   = 1.0;
    masterBright = 0.85;
    rw = 0; rh = 0; canvas = null;
  }

  void onExit() {}

  // ── drawScene ─────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {

    // Recreate downsampled canvas if resolution has changed.
    int targetRw = pg.width  / RSCALE;
    int targetRh = pg.height / RSCALE;
    if (canvas == null || rw != targetRw || rh != targetRh) {
      rw = targetRw;
      rh = targetRh;
      canvas = createImage(rw, rh, RGB);
      positionSources(pg.width, pg.height);
    }

    // Audio
    if (analyzer.isBeat) beatPulse = 1.0;
    float bassBoost = 1.0 + analyzer.bass * 0.8;
    beatPulse = lerp(beatPulse, 0, 0.10);
    time += BASE_SPEED * speedScale * bassBoost;

    // ── Render wave-interference field into downsampled canvas ────────────
    colorMode(HSB, 360, 100, 100); // used by color() in pixel loop

    canvas.loadPixels();
    for (int py = 0; py < rh; py++) {
      for (int px = 0; px < rw; px++) {
        float wx = (px + 0.5) * RSCALE;
        float wy = (py + 0.5) * RSCALE;

        float sumWave   = 0;
        float sumWeight = 0;
        float hueAccum  = 0;

        for (int i = 0; i < 6; i++) {
          if (activation[i] < 0.003) continue;
          float d    = dist(wx, wy, sources[i].x, sources[i].y);
          float wave = sin(d * BASE_FREQ * freqMults[i] * freqScale
                          - time * spdMults[i]);
          sumWave   += wave * activation[i];
          sumWeight += activation[i];
          hueAccum  += hues[i] * activation[i];
        }

        if (sumWeight < 0.003) {
          canvas.pixels[py * rw + px] = color(0, 0, 6);
          continue;
        }

        float normWave = sumWave / sumWeight;              // −1 .. 1
        float blendHue = hueAccum / sumWeight;             // 0 .. 360
        float iridHue  = (blendHue + normWave * IRIDESCENCE_SHIFT + 360) % 360;
        float bri      = constrain(
                           map(normWave, -1, 1, 10, 100) * masterBright
                           + beatPulse * 18,
                           0, 100);
        float sat      = map(abs(normWave), 0, 1, 38, 95);

        canvas.pixels[py * rw + px] = color(iridHue, sat, bri);
      }
    }
    canvas.updatePixels();

    colorMode(RGB, 255); // restore global color mode

    // ── Composite onto pg ─────────────────────────────────────────────────
    pg.colorMode(RGB, 255);
    pg.background(0);
    pg.image(canvas, 0, 0, pg.width, pg.height);

    // ── Source indicator glows at wave origin points ──────────────────────
    pg.colorMode(HSB, 360, 100, 100, 100);
    pg.noStroke();
    for (int i = 0; i < 6; i++) {
      if (activation[i] < 0.01) continue;
      float sz = 16 + activation[i] * 26 + beatPulse * 12;
      // outer halo
      pg.fill(hues[i], 75, 100, activation[i] * 70);
      pg.ellipse(sources[i].x, sources[i].y, sz, sz);
      // inner core
      pg.fill(hues[i], 20, 100, activation[i] * 80);
      pg.ellipse(sources[i].x, sources[i].y, sz * 0.40, sz * 0.40);
    }
    pg.colorMode(RGB, 255);

    // ── Chord label ───────────────────────────────────────────────────────
    drawChordLabel(pg);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void positionSources(int w, int h) {
    float cx = w * 0.5;
    float cy = h * 0.5;
    float r  = min(w, h) * 0.36;
    sources[0] = new PVector(cx,           cy + r       ); // A  – bottom
    sources[1] = new PVector(cx + r,       cy           ); // B  – right
    sources[2] = new PVector(cx - r,       cy           ); // X  – left
    sources[3] = new PVector(cx,           cy - r       ); // Y  – top
    sources[4] = new PVector(cx - r * 0.7, cy - r * 0.7); // LB – upper-left
    sources[5] = new PVector(cx + r * 0.7, cy - r * 0.7); // RB – upper-right
  }

  void drawChordLabel(PGraphics pg) {
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < 6; i++) {
      if (activation[i] > 0.5) {
        if (sb.length() > 0) sb.append("+");
        sb.append(labels[i]);
      }
    }
    String chord = sb.length() > 0 ? sb.toString() : "\u2014"; // em-dash when idle

    pg.pushStyle();
    pg.colorMode(RGB, 255);
    pg.textAlign(CENTER, BOTTOM);
    pg.textSize(22 * uiScale());
    pg.noStroke();
    pg.fill(0, 0, 0, 160);
    float lw = pg.textWidth("Chord: " + chord) + 32;
    pg.rectMode(CENTER);
    pg.rect(pg.width / 2.0, pg.height - 28, lw, 34, 5);
    pg.fill(200, 255, 200);
    pg.text("Chord: " + chord, pg.width / 2.0, pg.height - 16);
    pg.popStyle();
  }

  // ── Controller ────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // Read HELD state (not just_pressed) so all six sources can be active
    // simultaneously.  Lerp toward target for smooth fade-in/out with no
    // per-frame flicker.
    boolean[] held = {
      c.a_button, c.b_button, c.x_button, c.y_button,
      c.lb_button, c.rb_button
    };
    for (int i = 0; i < 6; i++) {
      float target = (held[i] || kbHeld[i]) ? 1.0 : 0.0;
      activation[i] = lerp(activation[i], target, 0.12);
    }

    // LT → slow wave speed
    speedScale = map(c.lt, 0, 1, 1.0, 0.15);

    // RT → tighten fringes
    freqScale = map(c.rt, 0, 1, 1.0, 3.5);

    // L-Stick Y → master brightness (push up = brighter)
    masterBright = map(c.ly, 0, height, 1.0, 0.30);
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────

  void handleKey(char k) {
    // Keys 1-6 toggle the six wave sources for keyboard-only play
    if (k >= '1' && k <= '6') {
      int idx = k - '1';
      kbHeld[idx] = !kbHeld[idx];
    }
  }

  // ── Code overlay ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Button Chord Resonance — Scene 27",
      "",
      "Hold any combo of A / B / X / Y / LB / RB",
      "Keys 1-6 toggle sources without controller",
      "",
      "Each button → circular wave at fixed origin:",
      "  w_i = act_i * sin(d_i * freq_i - t * spd_i)",
      "",
      "Pixel colour = superposition of all active waves:",
      "  val = Σ w_i / Σ act_i   (normalised to −1..1)",
      "  hue = Σ hue_i * act_i / Σ act_i",
      "",
      "Single button  → simple ripple",
      "Two buttons    → beat-frequency Moiré fringes",
      "Four+ buttons  → complex standing-wave illusion",
      "",
      "LT: slow speed   RT: tighten fringes",
      "L-Stick Y: brightness",
    };
  }
}
