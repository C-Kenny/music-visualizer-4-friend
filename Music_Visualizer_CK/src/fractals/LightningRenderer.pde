/**
 * LightningRenderer — recursive midpoint-displacement bolts. Bass adds bolts;
 * high boosts jitter / weight.
 */
class LightningRenderer implements FractalRenderer {
  String name() { return "Lightning"; }
  void draw(PGraphics pg, FractalParams p) {
    randomSeed(p.seed);
    pg.colorMode(HSB, 360, 255, 255, 255);
    int bolts = 1 + (int)(p.bass * 5);
    float len = min(pg.width, pg.height) * 0.42;
    for (int i = 0; i < bolts; i++) {
      float ang = random(TWO_PI);
      branch(pg, p, 0, 0, cos(ang) * len, sin(ang) * len, 6 + (int)(p.mid * 4), 1);
    }
  }
  void branch(PGraphics pg, FractalParams p, float x1, float y1, float x2, float y2, int depth, float w) {
    if (depth <= 0) return;
    float mx = (x1 + x2) * 0.5, my = (y1 + y2) * 0.5;
    float dx = x2 - x1, dy = y2 - y1;
    float jitter = sqrt(dx * dx + dy * dy) * 0.18 * (1.0 + p.high);
    mx += random(-jitter, jitter);
    my += random(-jitter, jitter);
    float h = (p.hueShift + 200) % 360;
    pg.stroke(h, 80, 255, 200);
    pg.strokeWeight(w * (1.0 + p.high * 0.8));
    pg.line(x1, y1, mx, my);
    pg.line(mx, my, x2, y2);
    branch(pg, p, x1, y1, mx, my, depth - 1, w * 0.7);
    branch(pg, p, mx, my, x2, y2, depth - 1, w * 0.7);
    if (random(1) < 0.35 + p.bass * 0.4) {
      float fx = mx + random(-jitter, jitter) * 1.5;
      float fy = my + random(-jitter, jitter) * 1.5;
      branch(pg, p, mx, my, fx, fy, depth - 2, w * 0.5);
    }
  }
}
