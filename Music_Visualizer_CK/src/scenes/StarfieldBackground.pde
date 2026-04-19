/**
 * StarfieldBackground — IBackground wrapping DeepSpaceScene's star warp effect.
 * Bass doubles speed, beat spikes it briefly. Very cheap (800 particles).
 */
class StarfieldBackground implements IBackground {

  class BgStar {
    float x, y, z, pz;
    BgStar() { reset(true); }

    void reset(boolean randomZ) {
      x  = random(-width, width);
      y  = random(-height, height);
      z  = randomZ ? random(width) : width;
      pz = z;
    }

    void update(float speed) {
      z -= speed;
      if (z < 1) { reset(false); }
    }

    void show(PGraphics pg) {
      pg.noStroke();
      pg.fill(255);
      float sx = map(x / z,  0, 1, 0, pg.width  / 2);
      float sy = map(y / z,  0, 1, 0, pg.height / 2);
      float r  = map(z, 0, width, 6, 0);
      pg.ellipse(sx, sy, r, r);

      float px = map(x / pz, 0, 1, 0, pg.width  / 2);
      float py = map(y / pz, 0, 1, 0, pg.height / 2);
      pz = z;
      pg.stroke(255, 120);
      pg.strokeWeight(map(z, 0, width, 1.5, 0));
      pg.line(px, py, sx, sy);
    }
  }

  BgStar[] stars = new BgStar[800];
  float speedSmooth = 5;

  StarfieldBackground() {
    for (int i = 0; i < stars.length; i++) stars[i] = new BgStar();
  }

  void drawBackground(PGraphics pg) {
    pg.background(0);
    pg.pushMatrix();
    pg.translate(pg.width / 2, pg.height / 2);

    float targetSpeed = map(analyzer.master, 0, 1, 2, 30);
    if (audio.beat.isOnset()) targetSpeed *= 2.5;
    speedSmooth = lerp(speedSmooth, targetSpeed, 0.12);

    for (BgStar s : stars) { s.update(speedSmooth); s.show(pg); }

    pg.popMatrix();
    pg.blendMode(BLEND);
  }

  String label() { return "Starfield"; }
}
