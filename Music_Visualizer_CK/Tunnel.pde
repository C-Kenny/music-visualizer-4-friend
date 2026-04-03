class Tunnel {
  int[] lookUpTable;
  int[] texture;

  Tunnel() {
    lookUpTable = new int[width*height];
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

    for (int j=height-1; j>0; j--) {
      for (int i=width-1; i>0; i--) {
        float x = -1.0f + (float)i*(2.0f/(float)width);
        float y =  1.0f - (float)j*(2.0f/(float)height);
        float r = sqrt(x*x+y*y);
        float a = atan2(x, y);

        float u = 1.0f/r;
        float v = a*(1.0f/3.14159f);
        float w = r*r;
        if (w>1.0f) w=1.0f;

        int iu = (int)(u*255.0f);
        int iv = (int)(v*255.0f);
        int iw = (int)(w*255.0f);

        lookUpTable[width*j+i] = ((iw&255)<<16) | ((iv&255)<<8) | (iu&255);
      }
    }
  }

  // xOffset / squareSize limit rendering to the scene's square viewport so the
  // tunnel doesn't bleed into the letterbox margins. Pixel coordinates outside
  // [xOffset, xOffset+squareSize) are left untouched.
  void draw(PGraphics pg, int tunnelZoomIncrement, int xOffset, int squareSize) {
    pg.loadPixels();
    int pgW = pg.width;
    int pgH = pg.height;
    int xEnd = min(xOffset + squareSize, pgW);
    for (int row = 0; row < pgH; row++) {
      for (int col = xOffset; col < xEnd; col++) {
        int pgIdx  = row * pgW + col;
        int luIdx  = row * width + col; // lookUpTable was built against global width
        if (luIdx >= lookUpTable.length) continue;
        int val = lookUpTable[luIdx];
        int texel = texture[
          ((val & 0x0000ffff) + ((frameCount + tunnelZoomIncrement) << 1)) & ((128*128)-1)
        ];
        int alpha = (val >> 16) & 0xFF;
        pg.pixels[pgIdx] = (alpha << 24) | (texel & 0xFFFFFF);
      }
    }
    pg.updatePixels();
  }
}