/**
 * KillSwitch — instant fade-to-black for live-show emergencies.
 *
 * Bypasses all scene logic: a single black quad is composited over the final
 * frame (after scene render, crossfade, HUD overlays) with animated alpha.
 * Toggled via Esc on keyboard or Back+Start chord on the controller.
 *
 * The fade itself is time-based (not frame-based), so a hitch in the render
 * loop doesn't stretch the transition — fade-in/out always completes in
 * FADE_SECONDS regardless of current FPS.
 */
class KillSwitch {
  static final float FADE_SECONDS = 0.3;

  boolean active        = false;
  float   alpha         = 0.0;
  long    lastTickMs    = 0;
  boolean prevChord     = false;

  void toggle() { active = !active; }

  // Controller chord: Back+Start rising edge toggles.
  void pollController(Controller c) {
    if (c == null || !c.isConnected()) { prevChord = false; return; }
    boolean chordNow = c.chord(c.backButton, c.startButton);
    if (chordNow && !prevChord) toggle();
    prevChord = chordNow;
  }

  void tick() {
    long now = millis();
    if (lastTickMs == 0) lastTickMs = now;
    float dt = (now - lastTickMs) / 1000.0;
    lastTickMs = now;
    if (dt > 0.1) dt = 0.1;                       // clamp after a stall
    float rate   = 1.0 / FADE_SECONDS;
    float target = active ? 1.0 : 0.0;
    if (alpha < target)      alpha = min(target, alpha + rate * dt);
    else if (alpha > target) alpha = max(target, alpha - rate * dt);
  }

  // Called after image(sceneBuffer) and all overlays.
  void draw() {
    if (alpha <= 0.001) return;
    pushStyle();
    noStroke();
    rectMode(CORNER);
    blendMode(BLEND);
    fill(0, alpha * 255);
    rect(0, 0, width, height);

    if (active && alpha > 0.85) {
      fill(255, 40, 40, 200);
      textAlign(CENTER, CENTER);
      textFont(monoFont);
      textSize(14 * uiScale());
      text("OUTPUT KILLED  \u00b7  Esc to restore",
           width / 2.0, height - 28 * uiScale());
    }
    popStyle();
  }

  boolean isFullyBlack() { return alpha >= 0.999; }
  boolean isEngaged()    { return active || alpha > 0.001; }
}
