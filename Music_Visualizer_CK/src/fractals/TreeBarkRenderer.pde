/**
 * TreeBarkRenderer — recursive rectangle subdivision with offset cracks,
 * giving a bark-like cell pattern.
 */
class TreeBarkRenderer implements FractalRenderer {
  String name() { return "Tree Bark Cracks"; }
  void draw(PGraphics pg, FractalParams p) {
    randomSeed(p.seed);
    pg.colorMode(HSB, 360, 255, 255, 255);
    float w = pg.width * 0.7, h = pg.height * 0.7;
    int depth = constrain(4 + (int)(p.bass * 4), 4, 8);
    split(pg, p, -w * 0.5, -h * 0.5, w, h, depth);
  }
  void split(PGraphics pg, FractalParams p, float x, float y, float w, float h, int depth) {
    if (depth <= 0 || (w < 8 && h < 8)) return;
    float hue = (p.hueShift + 25 + depth * 8) % 360;
    pg.stroke(hue, 180, 60 + depth * 20, 200);
    pg.strokeWeight(0.6 + p.high * 1.2);
    if (w > h) {
      float sx = x + w * (0.35 + random(0.3));
      pg.line(sx, y, sx + random(-w * 0.05, w * 0.05), y + h);
      split(pg, p, x, y, sx - x, h, depth - 1);
      split(pg, p, sx, y, x + w - sx, h, depth - 1);
    } else {
      float sy = y + h * (0.35 + random(0.3));
      pg.line(x, sy, x + w, sy + random(-h * 0.05, h * 0.05));
      split(pg, p, x, y, w, sy - y, depth - 1);
      split(pg, p, x, sy, w, y + h - sy, depth - 1);
    }
  }
}
