/**
 * BarnsleyFernRenderer — chaos-game IFS fern. Bass scales point count.
 */
class BarnsleyFernRenderer implements FractalRenderer {
  String name() { return "Barnsley Fern"; }
  void draw(PGraphics pg, FractalParams p) {
    int pts = 6000 + (int)(p.bass * 14000);
    float scale = min(pg.width, pg.height) * 0.045;
    pg.pushMatrix();
    pg.scale(1, -1);
    pg.translate(0, -pg.height * 0.35);
    randomSeed(p.seed);
    pg.colorMode(HSB, 360, 255, 255, 255);
    // Dot radius only depends on this frame's `high`, not on i — constant
    // across all points, so the whole cloud batches into one draw call via
    // beginShape(POINTS) instead of one ellipse() call per point (was up to
    // 20000 individual draw calls/frame).
    pg.noFill();
    pg.strokeCap(ROUND);
    pg.strokeWeight(1.6 + p.high * 1.4);
    float x = 0, y = 0;
    pg.beginShape(POINTS);
    for (int i = 0; i < pts; i++) {
      float r = random(1);
      float nx, ny;
      if      (r < 0.01) { nx = 0;             ny = 0.16 * y; }
      else if (r < 0.86) { nx =  0.85 * x + 0.04 * y; ny = -0.04 * x + 0.85 * y + 1.6; }
      else if (r < 0.93) { nx =  0.20 * x - 0.26 * y; ny =  0.23 * x + 0.22 * y + 1.6; }
      else               { nx = -0.15 * x + 0.28 * y; ny =  0.26 * x + 0.24 * y + 0.44; }
      x = nx; y = ny;
      float h = (p.hueShift + 110 + y * 6) % 360;
      pg.stroke(h, 200, 255, 180);
      pg.vertex(x * scale, y * scale);
    }
    pg.endShape();
    pg.popMatrix();
  }
}
