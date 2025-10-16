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

  void draw(int tunnelZoomIncrement) {
    loadPixels();
    for (int i=0; i<width*height; i++) {
      int val = lookUpTable[i];
      int col = texture[
        ((val&0x0000ffff) + ((frameCount + tunnelZoomIncrement)<<1)) & ((128*128)-1)
      ];
      pixels[i] =  color(col, (val>>16));
    }
    updatePixels();
  }
}