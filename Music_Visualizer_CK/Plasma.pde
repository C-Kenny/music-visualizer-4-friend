class Plasma {
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

    cls = new int[width*height];

    float plasma_bubble_size = random(24.0, 128.0);

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        cls[x+y*width] = (int)(
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
    pg.loadPixels();
    for (int pixelCount = 0; pixelCount < cls.length; pixelCount++) {
      if (pixelCount >= pg.pixels.length) break;
      int c = pal[(cls[pixelCount] + plasmaSeed) & (config.PLASMA_SIZE-1)];
      pg.pixels[pixelCount] = 0xFF000000 | (c & 0xFFFFFF);
    }
    pg.updatePixels();
  }
}