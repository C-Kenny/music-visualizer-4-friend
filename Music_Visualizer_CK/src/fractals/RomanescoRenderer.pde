/**
 * RomanescoRenderer — phyllotaxis spiral with self-similar bumps per floret.
 */
class RomanescoRenderer implements FractalRenderer {
  String name() { return "Romanesco Spiral"; }
  void draw(PGraphics pg, FractalParams p) {
    int n = 600 + (int)(p.bass * 900);
    float baseR = min(pg.width, pg.height) * 0.012;
    float phi = PI * (3.0 - sqrt(5.0));
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();
    for (int i = 0; i < n; i++) {
      float a = i * phi;
      float rad = baseR * sqrt(i) * (1.0 + p.mid * 0.4);
      float x = cos(a) * rad, y = sin(a) * rad;
      float sz = baseR * (3.0 - 2.0 * (float)i / n) * (1.0 + p.high * 0.6);
      float h = (p.hueShift + i * 0.6) % 360;
      pg.fill(h, 220, 255, 200);
      pg.ellipse(x, y, sz, sz);
      int bumps = 5;
      for (int b = 0; b < bumps; b++) {
        float ba = b * TWO_PI / bumps + a;
        pg.fill(h, 180, 255, 140);
        pg.ellipse(x + cos(ba) * sz * 0.45, y + sin(ba) * sz * 0.45, sz * 0.35, sz * 0.35);
      }
    }
  }
}
