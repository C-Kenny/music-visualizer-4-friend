class PolarPlasma {
  PImage buffer;
  int[] radius;
  int[] angle;
  color[] sinePalette;
  int[] fsin1;
  int[] fsin2;
  int rang;
  float d2r;
  float d2b;

  PolarPlasma() {
    rang = 512;
    d2r = 180/PI;
    d2b = (rang * d2r) / 360;
    sinePalette = new color[256];
    
    for (int i = 0; i < 256; i++) {
      int r = int((cos(i * 2.0 * PI / 256.0) + 1) * 32);
      int g = int(sin(i * 2.0 * PI / 512.0) * 255 * cos(i * 2.0 * PI / 1024.0));
      int b = int(sin(i * 2.0 * PI / 512.0) * 255);
      sinePalette[i] = color(r, g, b);
    }
    init(width, height);
  }

  void init(int w, int h) {
    int screenSize = w * h;
    int xc = w / 2;
    int yc = h / 2;
    radius = new int[screenSize];
    angle = new int[screenSize];
    fsin1 = new int[w*4];
    fsin2 = new int[w*4];
    buffer = createImage(w, h, RGB);

    int count=0;
    for (int y=0; y<h; y++) {
      for (int x=0; x<w; x++) {
        int xs = x - xc;
        int ys = y - yc;
        radius[count] = (int)(sqrt(pow(xs, 2) + pow(ys, 2)));
        angle[count] = (int) (atan2(xs, ys) * d2b);
        count++;
      }
    }

    float l = 0.25;
    for (int x=0; x<fsin1.length; x++) {
      fsin1[x] = (int)(cos(x/(l*d2b))*48+64);
      fsin2[x] = (int)(sin(x/(l*d2b/2))*40+48);
    }
  }

  void draw(PGraphics pg) {
    if (buffer == null || buffer.width != pg.width || buffer.height != pg.height) {
      init(pg.width, pg.height);
    }
    int k = config.logicalFrameCount&0xff;
    buffer.loadPixels();
    for (int i=0; i < buffer.pixels.length; i++) {
      if (i >= radius.length) break;
      int c = sinePalette[(angle[i] + fsin1[radius[i] + fsin2[radius[i]]+k]) & 0xFF];
      buffer.pixels[i] = 0xFF000000 | (c & 0xFFFFFF);
    }
    buffer.updatePixels();
    
    // Draw independently of any preceding pg.translate() offsets to prevent cutoff
    pg.pushMatrix();
    pg.image(buffer, 0, 0);
    pg.popMatrix();
  }
}
