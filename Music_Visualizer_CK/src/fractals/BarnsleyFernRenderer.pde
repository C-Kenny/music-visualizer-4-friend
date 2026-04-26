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
    pg.noStroke();
    float x = 0, y = 0;
    for (int i = 0; i < pts; i++) {
      float r = random(1);
      float nx, ny;
      if      (r < 0.01) { nx = 0;             ny = 0.16 * y; }
      else if (r < 0.86) { nx =  0.85 * x + 0.04 * y; ny = -0.04 * x + 0.85 * y + 1.6; }
      else if (r < 0.93) { nx =  0.20 * x - 0.26 * y; ny =  0.23 * x + 0.22 * y + 1.6; }
      else               { nx = -0.15 * x + 0.28 * y; ny =  0.26 * x + 0.24 * y + 0.44; }
      x = nx; y = ny;
      float h = (p.hueShift + 110 + y * 6) % 360;
      pg.fill(h, 200, 255, 180);
      pg.ellipse(x * scale, y * scale, 1.6 + p.high * 1.4, 1.6 + p.high * 1.4);
    }
    pg.popMatrix();
  }
}
