/**
 * SierpinskiRenderer — recursive subdivision of an equilateral triangle into
 * 3 corner sub-triangles. Bass scales depth; level drives hue cycling.
 */
class SierpinskiRenderer implements FractalRenderer {
  String name() { return "Sierpinski Triangle"; }
  void draw(PGraphics pg, FractalParams p) {
    int depth = constrain(3 + (int)(p.bass * 5), 3, 8);
    float r = min(pg.width, pg.height) * 0.4;
    PVector a = new PVector(0,           -r);
    PVector b = new PVector(-r * 0.866,  r * 0.5);
    PVector c = new PVector( r * 0.866,  r * 0.5);
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noFill();
    pg.strokeWeight(0.8 + p.high * 1.4);
    sub(pg, p, a, b, c, depth, 0);
  }
  void sub(PGraphics pg, FractalParams p, PVector a, PVector b, PVector c, int depth, int level) {
    float h = (p.hueShift + level * 35) % 360;
    pg.stroke(h, 220, 255, 200);
    pg.triangle(a.x, a.y, b.x, b.y, c.x, c.y);
    if (depth <= 0) return;
    PVector ab = PVector.lerp(a, b, 0.5);
    PVector bc = PVector.lerp(b, c, 0.5);
    PVector ca = PVector.lerp(c, a, 0.5);
    sub(pg, p, a, ab, ca, depth - 1, level + 1);
    sub(pg, p, ab, b, bc, depth - 1, level + 1);
    sub(pg, p, ca, bc, c, depth - 1, level + 1);
  }
}
