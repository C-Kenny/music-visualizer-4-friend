/**
 * DemoInputDriver — synthetic controller input for unattended demo capture.
 *
 * When enabled, overrides the live Controller fields each frame with a slow
 * Lissajous stick sweep plus beat-reactive button taps and direction snaps.
 * Lets capture.sh record per-scene preview videos that look "played" without
 * a human at the pad.
 *
 * Activation:
 *   MV_DEMO_MODE=1     env var
 *   .devdemo           file in sketch dir (gitignored)
 *
 * Suppressed inputs: LB/RB (scene cycle), Back/Start (song stop/start),
 * stick-clicks (auto-switcher) — capture must stay on the chosen scene.
 */
class DemoInputDriver {
  boolean enabled    = false;
  float   startMs    = 0;
  long    lastBeatMs = 0;
  int     beatCount  = 0;

  DemoInputDriver() {
    String env = System.getenv("MV_DEMO_MODE");
    boolean envOn  = env != null && (env.equals("1") || env.equalsIgnoreCase("true"));
    boolean fileOn = new java.io.File(sketchPath(".devdemo")).exists();
    enabled = envOn || fileOn;
    startMs = millis();
    if (enabled) println("[DEMO] DemoInputDriver active — synthetic controller input ON");
  }

  boolean isActive() { return enabled; }

  void applyTo(Controller c) {
    if (!enabled || c == null) return;

    float t = (millis() - startMs) / 1000.0;

    boolean beatNow = (audio != null && audio.beat != null && audio.beat.isOnset());
    if (beatNow) {
      lastBeatMs = millis();
      beatCount++;
    }
    float sinceBeat = (millis() - lastBeatMs) / 1000.0;

    // Stick targets: slow phase-shifted Lissajous, with cumulative beat offset
    // so direction nudges every onset.
    float phase = t + beatCount * 0.65;
    c.lx = width  * (0.5 + 0.42 * sin(phase * 0.31));
    c.ly = height * (0.5 + 0.42 * cos(phase * 0.43 + 1.2));
    c.rx = width  * (0.5 + 0.36 * sin(phase * 0.71 + 2.1));
    c.ry = height * (0.5 + 0.36 * cos(phase * 0.57 + 0.4));
    c.lt = 0.5 + 0.5 * sin(t * 1.1);
    c.rt = 0.5 + 0.5 * cos(t * 0.9);

    // Hold A briefly after each beat for continuous-modifier scenes.
    c.aButton = sinceBeat < 0.22;

    // Rotate face-button rising edges across A/B/X/Y on every beat —
    // many scenes use these to cycle colour palette / blend mode.
    c.aJustPressed = false;
    c.bJustPressed = false;
    c.xJustPressed = false;
    c.yJustPressed = false;
    if (beatNow) {
      int slot = beatCount % 4;
      if      (slot == 0) c.aJustPressed = true;
      else if (slot == 1) c.bJustPressed = true;
      else if (slot == 2) c.xJustPressed = true;
      else                c.yJustPressed = true;
    }

    // Suppress anything that would change scene / song / mode.
    c.lbButton = false; c.rbButton = false;
    c.lbJustPressed = false; c.rbJustPressed = false;
    c.lbJustReleased = false; c.rbJustReleased = false;
    c.backJustReleased = false; c.startJustReleased = false;
    c.leftStickClickJustReleased  = false;
    c.rightStickClickJustReleased = false;
  }
}
