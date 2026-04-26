/**
 * KochSnowflakeRenderer — equilateral triangle, each edge replaced recursively
 * by 4 segments forming the Koch bump. Bass scales recursion depth.
 */
class KochSnowflakeRenderer implements FractalRenderer {
  String name() { return "Koch Snowflake"; }
  void draw(PGraphics pg, FractalParams p) {
    int depth = constrain(2 + (int)(p.bass * 4), 2, 5);
    float r = min(pg.width, pg.height) * 0.34;
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noFill();
    pg.stroke(p.hueShift % 360, 200, 255, 230);
    pg.strokeWeight(1.0 + p.high * 1.5);
    PVector[] tri = new PVector[3];
    for (int i = 0; i < 3; i++) {
      float a = -HALF_PI + TWO_PI * i / 3.0;
      tri[i] = new PVector(cos(a) * r, sin(a) * r);
    }
    for (int i = 0; i < 3; i++) kochSegment(pg, tri[i], tri[(i + 1) % 3], depth);
  }
}
