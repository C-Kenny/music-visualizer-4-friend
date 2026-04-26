/**
 * FractalRenderer
 *
 * A reusable, music-reactive fractal that draws into any PGraphics.
 * Implementations live alongside this file in src/fractals/.
 * Drop one into any scene, feed it FractalParams each frame.
 *
 * Coordinate convention: implementations assume the caller has translated
 * to the desired centre and (optionally) rotated. They draw around (0, 0).
 */
interface FractalRenderer {
  void draw(PGraphics pg, FractalParams p);
  String name();
}

/**
 * FractalParams
 *
 * Per-frame inputs shared across all renderers. Caller fills these from the
 * global AudioAnalyser before calling draw().
 */
class FractalParams {
  float bass;     // 0..1 smoothed
  float mid;      // 0..1 smoothed
  float high;     // 0..1 smoothed
  float hueShift; // degrees, monotonically increasing
  boolean beat;   // true on onset frames
  long seed;      // bumped by caller to regenerate stochastic fractals

  FractalParams set(float b, float m, float h, float hue, boolean beat, long seed) {
    this.bass = b; this.mid = m; this.high = h;
    this.hueShift = hue; this.beat = beat; this.seed = seed;
    return this;
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────
// Koch construction: replace segment a→b with 4 sub-segments forming a
// triangular bump. Used by both Koch curve and snowflake renderers.
void kochSegment(PGraphics pg, PVector a, PVector b, int depth) {
  if (depth == 0) { pg.line(a.x, a.y, b.x, b.y); return; }
  PVector p1 = PVector.lerp(a, b, 1.0 / 3.0);
  PVector p2 = PVector.lerp(a, b, 2.0 / 3.0);
  PVector dir = PVector.sub(p2, p1);
  float ang = -PI / 3.0;
  PVector tip = new PVector(
    p1.x + dir.x * cos(ang) - dir.y * sin(ang),
    p1.y + dir.x * sin(ang) + dir.y * cos(ang)
  );
  kochSegment(pg, a, p1, depth - 1);
  kochSegment(pg, p1, tip, depth - 1);
  kochSegment(pg, tip, p2, depth - 1);
  kochSegment(pg, p2, b, depth - 1);
}
