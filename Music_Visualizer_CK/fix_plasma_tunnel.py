import re

# ------------- TUNNEL -------------
tunnel_code = """class Tunnel {
  PImage buffer;
  int[] lookUpTable;
  int[] texture;

  Tunnel() {
    int texSize = 128;
    texture = new int[texSize*texSize];
    for (int j=0; j<texSize; j++) {
      for (int i=0; i<texSize; i++) {
        int r = (i ^ j);
        int g = (((i>>6)&1)^((j>>6)&1))*255;
        g = (g*5 + 3*r)>>3;
        texture[texSize*j+i] = 0xff000000 | (g<<16) | (g<<8) | g;
      }
    }
    init(width, height);
  }

  void init(int w, int h) {
    lookUpTable = new int[w*h];
    buffer = createImage(w, h, ARGB);

    for (int j=h-1; j>0; j--) {
      for (int i=w-1; i>0; i--) {
        float x = -1.0f + (float)i*(2.0f/(float)w);
        float y =  1.0f - (float)j*(2.0f/(float)h);
        float r = sqrt(x*x+y*y);
        float a = atan2(x, y);

        float u = 1.0f/r;
        float v = a*(1.0f/3.14159f);
        float w2 = r*r;
        if (w2>1.0f) w2=1.0f;

        int iu = (int)(u*255.0f);
        int iv = (int)(v*255.0f);
        int iw = (int)(w2*255.0f);

        lookUpTable[w*j+i] = ((iw&255)<<16) | ((iv&255)<<8) | (iu&255);
      }
    }
  }

  void draw(PGraphics pg, int tunnelZoomIncrement, int xOffset, int squareSize) {
    if (buffer == null || buffer.width != pg.width || buffer.height != pg.height) {
      init(pg.width, pg.height);
    }
    buffer.loadPixels();
    int pgW = pg.width;
    int pgH = pg.height;
    int xEnd = min(xOffset + squareSize, pgW);
    for (int row = 0; row < pgH; row++) {
      for (int col = xOffset; col < xEnd; col++) {
        int pgIdx  = row * pgW + col;
        int luIdx  = row * buffer.width + col;
        if (luIdx >= lookUpTable.length) continue;
        int val = lookUpTable[luIdx];
        int texel = texture[
          ((val & 0x0000ffff) + ((config.logicalFrameCount + tunnelZoomIncrement) << 1)) & ((128*128)-1)
        ];
        int alpha = (val >> 16) & 0xFF;
        buffer.pixels[pgIdx] = (alpha << 24) | (texel & 0xFFFFFF);
      }
    }
    buffer.updatePixels();
    // We expect the translated context to shift it if drawn within a translate. 
    // Tunnel is drawn before translation, so pg.image(buffer, 0, 0) is perfectly centered.
    pg.image(buffer, 0, 0);
  }
}
"""
open("Tunnel.pde", "w").write(tunnel_code)

# ------------- PLASMA -------------
plasma_code = """class Plasma {
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
    pg.resetMatrix();
    pg.image(buffer, 0, 0);
    pg.popMatrix();
  }
}
"""
open("Plasma.pde", "w").write(plasma_code)

# ------------- POLAR PLASMA -------------
polar_plasma_code = """class PolarPlasma {
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
    pg.resetMatrix();
    pg.image(buffer, 0, 0);
    pg.popMatrix();
  }
}
"""
open("PolarPlasma.pde", "w").write(polar_plasma_code)

