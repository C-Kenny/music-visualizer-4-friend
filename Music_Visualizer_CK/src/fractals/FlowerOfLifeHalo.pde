/**
 * FlowerOfLifeHalo
 *
 * Sacred-geometry decorative ring: outer circle + N petals.
 * Reusable as a frame around any scene. Draws around (0, 0).
 */
class FlowerOfLifeHalo {
  int petals = 12;
  float radiusFrac = 0.42;   // fraction of min(width, height)
  float petalScale = 0.55;

  FlowerOfLifeHalo() {}
  FlowerOfLifeHalo(int petals, float radiusFrac) {
    this.petals = petals;
    this.radiusFrac = radiusFrac;
  }

  void draw(PGraphics pg, FractalParams p) {
    pg.pushStyle();
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noFill();
    float r = min(pg.width, pg.height) * radiusFrac;
    pg.strokeWeight(1.0 + p.high * 1.2);
    pg.stroke((p.hueShift + 180) % 360, 180, 255, 70 + p.bass * 80);
    pg.ellipse(0, 0, r * 2, r * 2);
    for (int i = 0; i < petals; i++) {
      float a = TWO_PI * i / petals;
      float px = cos(a) * r, py = sin(a) * r;
      pg.stroke((p.hueShift + i * (360.0 / petals)) % 360, 200, 255, 50 + p.mid * 90);
      pg.ellipse(px, py, r * petalScale, r * petalScale);
    }
    pg.popStyle();
  }
}
