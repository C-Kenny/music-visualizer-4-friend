/**
 * StrobeSafety — photosensitive-seizure protection filter.
 *
 * Photosensitive epilepsy thresholds (UK Ofcom / W3C WCAG):
 *   - No more than 3 full-screen flashes per second.
 *   - Per-flash brightness delta capped (large rapid luminance jumps).
 *
 * This filter samples the final composite each frame, detects strobe spikes,
 * and dampens them by alpha-blending the previous frame back over the current
 * one. The blend ratio scales with how far the spike exceeds the cap, so a
 * gentle pulse passes through and only hard flashes get flattened.
 *
 * Off by default for private/home use. Auto-enables on fullscreen toggle —
 * if you're plugged into a venue projector, the cap should be on.
 *
 * Wired into the main draw() loop:
 *   1. After postFX.process() and the main blit.
 *   2. maybeDampen() may overlay the previous frame at window scale.
 *   3. snapshot() copies the current composite for next frame's reference.
 */
class StrobeSafety {
  // Tunables
  static final float MAX_LUMA_DELTA       = 0.22; // 0..1 jump cap per frame
  static final int   FLASH_WINDOW_MS      = 1000;
  static final int   MAX_FLASHES_PER_SEC  = 3;
  static final float BRIGHT_THRESHOLD     = 0.55; // luma considered "bright" for flash counting
  static final float MAX_DAMP_ALPHA       = 0.75; // upper bound on prev-frame mix
  static final int   ANALYZE_W            = 64;
  static final int   ANALYZE_H            = 36;

  boolean enabled = false;

  // Downscaled luminance probe — avoids full-resolution loadPixels readback.
  PGraphics analyzeBuf;
  // Snapshot of last frame's final composite, used as the damping source.
  PGraphics prevBuf;

  float prevLuma = -1;
  boolean lastWasBright = false;
  ArrayList<Long> flashTimes = new ArrayList<Long>();

  // Diagnostic — last computed dampening alpha (0..1). HUD reads this.
  float lastDampAlpha = 0;

  static final String PREFS_FILE = ".strobe";

  void toggle() { enabled = !enabled; savePref(); }
  void setEnabled(boolean on) { if (enabled != on) { enabled = on; savePref(); } }

  void loadPref() {
    try {
      String[] lines = loadStrings(userDataPath(PREFS_FILE));
      if (lines == null) return;
      for (String raw : lines) {
        String line = raw.trim();
        if (line.startsWith("enabled=")) enabled = line.substring(8).trim().equals("1");
      }
    } catch (Exception ignored) {}
  }

  void savePref() {
    try {
      saveStrings(userDataPath(PREFS_FILE), new String[]{
        "enabled=" + (enabled ? "1" : "0")
      });
    } catch (Exception ignored) {}
  }

  // Sample current frame's luma + flash rate. If unsafe, blend prevBuf at
  // window scale over what was just blitted. Caller must have already drawn
  // src to the window. Coordinates are window dimensions.
  void maybeDampen(PGraphics src, int winW, int winH) {
    lastDampAlpha = 0;
    if (!enabled || src == null) return;

    float luma = sampleLuma(src);
    long now = millis();

    // Per-frame delta cap
    float delta = (prevLuma >= 0) ? abs(luma - prevLuma) : 0;
    float deltaOver = max(0, delta - MAX_LUMA_DELTA);

    // Flash-rate cap (rising edges of "bright")
    boolean brightNow = luma > BRIGHT_THRESHOLD;
    if (brightNow && !lastWasBright) flashTimes.add(now);
    lastWasBright = brightNow;
    while (!flashTimes.isEmpty() && now - flashTimes.get(0) > FLASH_WINDOW_MS) {
      flashTimes.remove(0);
    }
    int flashesInWindow = flashTimes.size();
    float flashOver = max(0, flashesInWindow - MAX_FLASHES_PER_SEC) / 3.0;

    // Combine spike contributors. Square root to soften the curve.
    float spike = sqrt(deltaOver * 2.5 + flashOver);
    float alpha = constrain(spike, 0, 1) * MAX_DAMP_ALPHA;

    if (alpha > 0.02 && prevBuf != null) {
      blendMode(BLEND);
      tint(255, alpha * 255);
      image(prevBuf, 0, 0, winW, winH);
      noTint();
      lastDampAlpha = alpha;
    }

    prevLuma = luma;
  }

  // Save the current composite for next frame's damping source.
  void snapshot(PGraphics src) {
    if (src == null) return;
    if (prevBuf == null || prevBuf.width != src.width || prevBuf.height != src.height) {
      prevBuf = createGraphics(src.width, src.height, P3D);
      prevBuf.smooth(0);
    }
    prevBuf.beginDraw();
    prevBuf.imageMode(CORNER);
    prevBuf.image(src, 0, 0);
    prevBuf.endDraw();
  }

  float sampleLuma(PGraphics src) {
    if (analyzeBuf == null) {
      analyzeBuf = createGraphics(ANALYZE_W, ANALYZE_H, P2D);
      analyzeBuf.smooth(0);
    }
    analyzeBuf.beginDraw();
    analyzeBuf.background(0);
    analyzeBuf.imageMode(CORNER);
    analyzeBuf.image(src, 0, 0, ANALYZE_W, ANALYZE_H);
    analyzeBuf.endDraw();
    analyzeBuf.loadPixels();

    int n = analyzeBuf.pixels.length;
    if (n == 0) return 0;
    long sum = 0;
    for (int i = 0; i < n; i++) {
      int c = analyzeBuf.pixels[i];
      int r = (c >> 16) & 0xff;
      int g = (c >> 8)  & 0xff;
      int b = c & 0xff;
      // Rec. 601 luma weights, kept in 0..255 to dodge per-pixel division.
      sum += (299 * r + 587 * g + 114 * b);
    }
    return (sum / (float) n) / (1000.0 * 255.0);
  }
}
