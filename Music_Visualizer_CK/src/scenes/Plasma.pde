class Plasma {
  PImage buffer;
  int[] pal;
  int[] cls;

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
    init(width, height);
  }

  void init(int w, int h) {
    cls = new int[w*h];
    buffer = createImage(w, h, RGB);
    float plasma_bubble_size = random(24.0, 128.0);
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        cls[x+y*w] = (int)(
          (127.5 + (127.5 * sin(x / plasma_bubble_size)))
          +
          (127.5 + (127.5 * cos(y / plasma_bubble_size)))
          +
          (127.5 + (127.5 * sin(sqrt((x * x + y * y)) / plasma_bubble_size)))
        ) / 4;
      }
    }
  }

  void draw(PGraphics pg, int plasmaSeed) {
    if (buffer == null || buffer.width != pg.width || buffer.height != pg.height) {
      init(pg.width, pg.height);
    }
    buffer.loadPixels();
    if (buffer.pixels.length != cls.length) return;
    for (int pixelCount = 0; pixelCount < cls.length; pixelCount++) {
      if (pixelCount >= buffer.pixels.length) break;
      int c = pal[(cls[pixelCount] + plasmaSeed) & (config.PLASMA_SIZE-1)];
      buffer.pixels[pixelCount] = 0xFF000000 | (c & 0xFFFFFF);
    }
    buffer.updatePixels();
    
    // Draw independently of any preceding pg.translate() offsets to prevent cutoff
    pg.pushMatrix();
    pg.image(buffer, 0, 0);
    pg.popMatrix();
  }
}
