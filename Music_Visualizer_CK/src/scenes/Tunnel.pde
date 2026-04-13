class Tunnel {
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
    buffer = createImage(w, h, RGB);

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
    draw(pg, tunnelZoomIncrement, 0, xOffset, squareSize);
  }

  // twistOffset shifts the angle dimension of the texture independently of
  // the zoom — a value of ~32 produces a visible ~90° rotation twist.
  void draw(PGraphics pg, int tunnelZoomIncrement, int twistOffset, int xOffset, int squareSize) {
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
          ((val & 0x0000ffff) + ((config.logicalFrameCount + tunnelZoomIncrement) << 1) + (twistOffset << 8)) & ((128*128)-1)
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
