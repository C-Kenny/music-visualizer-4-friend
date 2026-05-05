/**
 * PixelSortFX — CPU-side pixel sort / glitch effect.
 *
 * On beats, a number of random pixel columns in sceneBuffer are sorted by
 * brightness (descending), creating vertical streaks that look like digital
 * corruption. The number of sorted columns decays back toward zero between beats
 * to give a "heal" effect.
 *
 * Performance: capped at MAX_COLS columns per frame.
 * Each column sort is O(height log height) — fast at sceneBuffer scale.
 */
class PixelSortFX implements IPostFX {
  private boolean enabled;
  private float   numCols      = 0;  // current number of columns to sort (float for smooth lerp)
  private float   targetCols   = 0;
  private int     MAX_COLS     = 60;
  private int     HEAL_RATE    = 3;  // columns healed per frame

  PixelSortFX() {
    enabled = false;
  }

  String  label()               { return "Glitch"; }
  boolean isEnabled()           { return enabled; }
  void    setEnabled(boolean v) { enabled = v; if (!v) { numCols = 0; targetCols = 0; } }
  boolean isCPUEffect()         { return true; }
  void    applyGLSL(PGraphics src, PGraphics dst) {}

  void onUpdate() {
    // Spike on beat drop; scale with bass energy
    if (analyzer.isBeat) {
      float spike = MAX_COLS * (0.4 + analyzer.bass * 0.7);
      targetCols = min(MAX_COLS, max(targetCols, spike));
    }
    // Heal: target decays each frame; actual follows via lerp
    targetCols = max(0, targetCols - HEAL_RATE);
    numCols    = lerp(numCols, targetCols, 0.25);
  }

  void applyCPU(PGraphics pg) {
    int cols = round(numCols);
    if (cols <= 0) return;

    pg.loadPixels();
    int w = pg.width;
    int h = pg.height;

    for (int i = 0; i < cols; i++) {
      int col = (int) random(w);
      sortColumn(pg.pixels, col, w, h);
    }

    pg.updatePixels();
  }

  // Sort a single pixel column by brightness descending.
  private void sortColumn(int[] pixels, int col, int w, int h) {
    // Extract column brightnesses alongside original indices
    float[] brightness = new float[h];
    for (int row = 0; row < h; row++) {
      int c = pixels[row * w + col];
      float r = red(c)   / 255.0;
      float g = green(c) / 255.0;
      float b = blue(c)  / 255.0;
      brightness[row] = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    // Insertion sort (fast for nearly-sorted columns, correct for all)
    // Only sort the brighter half so dark rows stay anchored — better glitch look
    int splitRow = h / 2;
    for (int j = 1; j < splitRow; j++) {
      float keyB = brightness[j];
      int   pixJ = pixels[j * w + col];
      int k = j - 1;
      while (k >= 0 && brightness[k] < keyB) {
        brightness[k + 1]           = brightness[k];
        pixels[(k + 1) * w + col]   = pixels[k * w + col];
        k--;
      }
      brightness[k + 1]         = keyB;
      pixels[(k + 1) * w + col] = pixJ;
    }
  }
}
