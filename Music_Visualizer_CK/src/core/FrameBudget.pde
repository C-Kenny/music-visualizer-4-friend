/**
 * FrameBudget - per-phase frametime probe.
 *
 * Wraps phases of draw() with nanoTime taps. Renders a small bottom-left
 * panel showing rolling avg ms/frame per phase + total. F8 toggles.
 *
 * Phases:
 *   AUDIO - audio.forward + detectBeat + analyzer.update
 *   INPUT - getUserInput (controller poll + key routing)
 *   SCENE - scenes[STATE].drawScene(sceneBuffer)
 *   POSTFX - postFX.process
 *   COMPOSE - image() blit + strobe + recorder/streamer ticks
 *   HUD - overlays, badges, web-control badge, text overlay
 *
 * Cost: ~6 nanoTime calls per frame, <1us total. Zero when hidden - phase
 * start/stop still increments counters but the draw path is skipped.
 */
class FrameBudget {
  static final int P_AUDIO   = 0;
  static final int P_INPUT   = 1;
  static final int P_SCENE   = 2;
  static final int P_POSTFX  = 3;
  static final int P_COMPOSE = 4;
  static final int P_HUD     = 5;
  static final int N_PHASES  = 6;

  final String[] LABELS = {"audio", "input", "scene", "postfx", "compose", "hud"};

  boolean visible = false;
  long[] curUs    = new long[N_PHASES];   // accumulator for current frame (us)
  float[] avgUs   = new float[N_PHASES];  // EMA in microseconds
  float avgTotalUs = 0;
  float avgFrameUs = 0;                   // wall-clock frame ms (independent)
  long  frameStartNs = 0;
  int   activePhase  = -1;
  long  activeStartNs = 0;

  void toggle() {
    visible = !visible;
    println("[FrameBudget] " + (visible ? "ON" : "OFF"));
  }

  void frameStart() {
    frameStartNs = System.nanoTime();
    for (int i = 0; i < N_PHASES; i++) curUs[i] = 0;
  }

  void begin(int phase) {
    activePhase   = phase;
    activeStartNs = System.nanoTime();
  }

  void end() {
    if (activePhase < 0) return;
    curUs[activePhase] += (System.nanoTime() - activeStartNs) / 1000L;
    activePhase = -1;
  }

  void frameEnd() {
    long frameUs = (System.nanoTime() - frameStartNs) / 1000L;
    final float a = 0.08;   // EMA - ~12-frame window
    long total = 0;
    for (int i = 0; i < N_PHASES; i++) {
      avgUs[i] = avgUs[i] * (1 - a) + curUs[i] * a;
      total += curUs[i];
    }
    avgTotalUs = avgTotalUs * (1 - a) + total    * a;
    avgFrameUs = avgFrameUs * (1 - a) + frameUs  * a;
  }

  void draw() {
    if (!visible) return;
    float s = uiScale();
    float pad = 8 * s;
    float lineH = 16 * s;
    float w = 230 * s;
    float h = (N_PHASES + 3) * lineH + pad * 2;
    float x = pad;
    float y = height - h - pad;

    pushStyle();
    noStroke();
    fill(0, 200);
    rect(x, y, w, h, 4 * s);
    if (monoFont != null) textFont(monoFont);
    textSize(12 * s);
    textAlign(LEFT, TOP);
    fill(120, 255, 180);
    text("FRAME BUDGET (F8)", x + pad, y + pad);

    float ty = y + pad + lineH;
    for (int i = 0; i < N_PHASES; i++) {
      float ms = avgUs[i] / 1000.0;
      float pct = avgTotalUs > 0 ? (avgUs[i] / avgTotalUs) : 0;
      // colour: green <2ms, yellow <6ms, red beyond
      if (ms < 2)      fill(180, 230, 180);
      else if (ms < 6) fill(230, 220, 140);
      else             fill(240, 150, 140);
      text(String.format("%-8s %5.2f ms  %3d%%", LABELS[i], ms, (int)(pct * 100)),
           x + pad, ty);
      // mini bar
      float barX = x + pad + 165 * s;
      float barW = (w - pad * 2 - 165 * s) * pct;
      rect(barX, ty + lineH * 0.25, barW, lineH * 0.5);
      ty += lineH;
    }

    fill(200);
    text(String.format("sum      %5.2f ms",   avgTotalUs / 1000.0), x + pad, ty);
    ty += lineH;
    fill(180, 200, 230);
    text(String.format("frame    %5.2f ms / %.0ffps",
        avgFrameUs / 1000.0,
        avgFrameUs > 0 ? 1_000_000.0 / avgFrameUs : 0),
        x + pad, ty);

    popStyle();
  }
}
