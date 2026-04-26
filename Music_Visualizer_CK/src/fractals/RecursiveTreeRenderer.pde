/**
 * RecursiveTreeRenderer — classic L-system-style binary branching tree.
 * Bass deepens recursion; mid widens branch angle.
 */
class RecursiveTreeRenderer implements FractalRenderer {
  String name() { return "Recursive Tree"; }
  void draw(PGraphics pg, FractalParams p) {
    pg.pushMatrix();
    pg.translate(0, pg.height * 0.35);
    pg.rotate(PI); // grow up
    pg.colorMode(HSB, 360, 255, 255, 255);
    float len = min(pg.width, pg.height) * 0.18;
    int depth = constrain(7 + (int)(p.bass * 5), 7, 12);
    float angle = radians(20 + p.mid * 35);
    branch(pg, p, len, depth, angle, 0);
    pg.popMatrix();
  }
  void branch(PGraphics pg, FractalParams p, float len, int depth, float angle, int level) {
    if (depth <= 0) return;
    float h = (p.hueShift + level * 18) % 360;
    pg.stroke(h, 200, 255, 220);
    pg.strokeWeight(map(depth, 0, 12, 0.5, 4.0) * (1.0 + p.high * 0.6));
    pg.line(0, 0, 0, -len);
    pg.translate(0, -len);
    pg.pushMatrix();
    pg.rotate(angle);
    branch(pg, p, len * 0.72, depth - 1, angle, level + 1);
    pg.popMatrix();
    pg.pushMatrix();
    pg.rotate(-angle);
    branch(pg, p, len * 0.72, depth - 1, angle, level + 1);
    pg.popMatrix();
  }
}
