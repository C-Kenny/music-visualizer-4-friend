class Plasma {
  PImage buffer;
  int[] pal;
  float plasma_bubble_size;
  float t = 0;

  // Two circular origins that drift slowly around the canvas
  float cx1, cy1, cx2, cy2;

  Plasma() {
    pal = new int[config.PLASMA_SIZE];
    float s1, s2;
    for (int i=0; i<config.PLASMA_SIZE; i++) {
      s1=sin(i*PI/25);
      s2=sin(i*PI/50+PI/4);
      float r_color = 128+s1*128;
      float g_color = random(0, 255);
      float b_color = random(0, 255);
      pal[i]=color(r_color, g_color, b_color);
    }
    plasma_bubble_size = random(24.0, 128.0);
    buffer = createImage(width, height, RGB);
    cx1 = width  * 0.5;
    cy1 = height * 0.5;
    cx2 = width  * 0.25;
    cy2 = height * 0.75;
  }

  void draw(PGraphics pg, int plasmaSeed) {
    // Half linear resolution (quarter pixel count) — 4× cheaper than full res.
    // Drawn scaled up; P3D bilinear filtering keeps it smooth.
    int bw = pg.width  / 2;
    int bh = pg.height / 2;
    if (buffer == null || buffer.width != bw || buffer.height != bh) {
      buffer = createImage(bw, bh, RGB);
      cx1 = bw * 0.5;  cy1 = bh * 0.5;
      cx2 = bw * 0.25; cy2 = bh * 0.75;
    }

    t += 0.5;
    float bs = plasma_bubble_size / 2.0;  // scale to half-res space

    cx1 = bw * (0.5 + 0.38 * sin(t * 0.007));
    cy1 = bh * (0.5 + 0.38 * cos(t * 0.005));
    cx2 = bw * (0.5 + 0.38 * cos(t * 0.009 + 1.3));
    cy2 = bh * (0.5 + 0.38 * sin(t * 0.006 + 2.1));

    buffer.loadPixels();
    for (int y = 0; y < bh; y++) {
      for (int x = 0; x < bw; x++) {
        float dx1 = x - cx1, dy1 = y - cy1;
        float dx2 = x - cx2, dy2 = y - cy2;
        float d1 = sqrt(dx1*dx1 + dy1*dy1);
        float d2 = sqrt(dx2*dx2 + dy2*dy2);

        int v = (int)(
          (127.5 + 127.5 * sin(x  / bs))
          + (127.5 + 127.5 * cos(y  / bs))
          + (127.5 + 127.5 * sin(d1 / bs))
          + (127.5 + 127.5 * cos(d2 / bs))
        ) >> 2;

        int c = pal[(v + plasmaSeed) & (config.PLASMA_SIZE - 1)];
        buffer.pixels[y * bw + x] = 0xFF000000 | (c & 0xFFFFFF);
      }
    }
    buffer.updatePixels();
    pg.pushMatrix();
    pg.image(buffer, 0, 0, pg.width, pg.height);
    pg.popMatrix();
  }
}
