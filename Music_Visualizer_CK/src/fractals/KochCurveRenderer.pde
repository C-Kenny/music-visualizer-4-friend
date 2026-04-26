/**
 * KochCurveRenderer — Koch construction repeated as a 6-armed star.
 */
class KochCurveRenderer implements FractalRenderer {
  String name() { return "Koch Curve"; }
  void draw(PGraphics pg, FractalParams p) {
    int depth = constrain(2 + (int)(p.bass * 4), 2, 5);
    float r = min(pg.width, pg.height) * 0.4;
    int arms = 6;
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noFill();
    pg.strokeWeight(1.0 + p.high * 1.2);
    for (int i = 0; i < arms; i++) {
      pg.pushMatrix();
      pg.rotate(TWO_PI * i / arms);
      pg.stroke((p.hueShift + i * (360.0 / arms)) % 360, 220, 255, 220);
      kochSegment(pg, new PVector(-r, 0), new PVector(r, 0), depth);
      pg.popMatrix();
    }
  }
}
