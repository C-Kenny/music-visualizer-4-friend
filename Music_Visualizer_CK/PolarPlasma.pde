class PolarPlasma {
  int[] radius;
  int[] angle;
  color[] sinePalette;
  int[] fsin1;
  int[] fsin2;
  int rang;
  float d2r;
  float d2b;
  int xc;
  int yc;
  int screenSize;

  PolarPlasma() {
    screenSize = width * height;
    xc = width / 2;
    yc = height / 2;
    rang = 512;
    d2r = 180/PI;
    d2b = (rang * d2r) / 360;

    radius = new int[screenSize];
    angle = new int[screenSize];
    sinePalette = new color[256];
    fsin1 = new int[width*4];
    fsin2 = new int[width*4];

    int count=0;
    for (int y=0; y<height; y++) {
      for (int x=0; x<width; x++) {
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

    for (int i = 0; i < 256; i++) {
      int r = int((cos(i * 2.0 * PI / 256.0) + 1) * 32);
      int g = int(sin(i * 2.0 * PI / 512.0) * 255 * cos(i * 2.0 * PI / 1024.0));
      int b = int(sin(i * 2.0 * PI / 512.0) * 255);
      sinePalette[i] = color(r, g, b);
    }
  }

  void draw() {
    int k = frameCount&0xff;
    loadPixels();
    for (int i=0; i<screenSize; i++) {
      pixels[i] = sinePalette[
        (angle[i] + fsin1[radius[i] + fsin2[radius[i]]+k]) &0xff
      ];
    }
    updatePixels();
  }
}