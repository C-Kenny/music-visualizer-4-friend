// WebController — phone/web input that overrides physical Controller state.
//
// HTTP handler threads write here; main thread reads in applyTo() each frame
// after Controller.read(). Stick values are normalised -1..1; -2 sentinel means
// "no value sent". Stick override expires after STICK_TIMEOUT_MS so a dropped
// connection doesn't peg the stick.

class WebController {
  static final int STICK_TIMEOUT_MS = 500;

  // Sticks (-1..1 normalized; -2 = inactive)
  volatile float wlx = -2, wly = -2, wrx = -2, wry = -2;
  volatile long lastStickUpdateMs = 0;

  // Held buttons
  volatile boolean wA, wB, wX, wY;

  // Pending tap events — consumed exactly once on next applyTo()
  volatile boolean wAEdge, wBEdge, wXEdge, wYEdge;

  void setSticks(float lx, float ly, float rx, float ry) {
    wlx = lx; wly = ly; wrx = rx; wry = ry;
    lastStickUpdateMs = System.currentTimeMillis();
  }

  void setButton(String btn, String action) {
    boolean down = action.equals("down");
    boolean tap  = action.equals("tap");
    if (btn.equalsIgnoreCase("A")) { if (action.equals("up")) wA = false; if (down) wA = true; if (tap) wAEdge = true; }
    if (btn.equalsIgnoreCase("B")) { if (action.equals("up")) wB = false; if (down) wB = true; if (tap) wBEdge = true; }
    if (btn.equalsIgnoreCase("X")) { if (action.equals("up")) wX = false; if (down) wX = true; if (tap) wXEdge = true; }
    if (btn.equalsIgnoreCase("Y")) { if (action.equals("up")) wY = false; if (down) wY = true; if (tap) wYEdge = true; }
  }

  boolean isActive() {
    return (System.currentTimeMillis() - lastStickUpdateMs) < STICK_TIMEOUT_MS
        || wA || wB || wX || wY;
  }

  void applyTo(Controller c) {
    boolean stickFresh = (System.currentTimeMillis() - lastStickUpdateMs) < STICK_TIMEOUT_MS;
    if (stickFresh && wlx > -1.5) {
      c.lx = map(wlx, -1, 1, 0, width);
      c.ly = map(wly, -1, 1, 0, height);
      c.rx = map(wrx, -1, 1, 0, width);
      c.ry = map(wry, -1, 1, 0, height);
    }

    // Held: web "down" forces button on (physical can also hold it).
    if (wA) c.aButton = true;
    if (wB) c.bButton = true;
    if (wX) c.xButton = true;
    if (wY) c.yButton = true;

    // Edge (tap): consume — fires just-pressed for a single frame.
    if (wAEdge) { c.aJustPressed = true; wAEdge = false; }
    if (wBEdge) { c.bJustPressed = true; wBEdge = false; }
    if (wXEdge) { c.xJustPressed = true; wXEdge = false; }
    if (wYEdge) { c.yJustPressed = true; wYEdge = false; }
  }
}
