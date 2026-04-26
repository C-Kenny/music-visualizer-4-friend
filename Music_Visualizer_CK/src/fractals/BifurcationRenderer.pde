/**
 * BifurcationRenderer — logistic map x_{n+1} = r·x·(1-x) sweep over r,
 * showing period-doubling cascade into chaos. Bass adds samples.
 */
class BifurcationRenderer implements FractalRenderer {
  String name() { return "Logistic Bifurcation"; }
  void draw(PGraphics pg, FractalParams p) {
    float w = pg.width * 0.85, h = pg.height * 0.7;
    pg.pushMatrix();
    pg.translate(-w * 0.5, -h * 0.5);
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();
    int cols = 360;
    int settle = 80, samples = 80 + (int)(p.bass * 200);
    float rMin = 2.5, rMax = 4.0;
    for (int i = 0; i < cols; i++) {
      float r = rMin + (rMax - rMin) * i / cols;
      float x = 0.5;
      for (int s = 0; s < settle; s++) x = r * x * (1 - x);
      float h2 = (p.hueShift + i * 0.5) % 360;
      pg.fill(h2, 220, 255, 60 + p.mid * 100);
      for (int s = 0; s < samples; s++) {
        x = r * x * (1 - x);
        pg.ellipse(i * (w / cols), h - x * h, 1.4, 1.4);
      }
    }
    pg.popMatrix();
  }
}
