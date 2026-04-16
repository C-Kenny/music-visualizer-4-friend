class Tunnel {
  PImage buffer;
  int[] lookUpTable;
  int[] texture;
  final int RENDER_SCALE = 3;

  Tunnel() {
    int textureSize = 128;
    texture = new int[textureSize*textureSize];
    for (int yCoord = 0; yCoord < textureSize; yCoord++) {
      for (int xCoord = 0; xCoord < textureSize; xCoord++) {
        int redColor = (xCoord ^ yCoord);
        int greenColor = (((xCoord>>6)&1)^((yCoord>>6)&1))*255;
        greenColor = (greenColor * 5 + 3 * redColor) >> 3;
        texture[textureSize * yCoord + xCoord] = 0xff000000 | (greenColor<<16) | (greenColor<<8) | greenColor;
      }
    }
    init(width, height);
  }

  void init(int screenWidth, int screenHeight) {
    int renderWidth = screenWidth / RENDER_SCALE;
    int renderHeight = screenHeight / RENDER_SCALE;
    lookUpTable = new int[renderWidth * renderHeight];
    buffer = createImage(renderWidth, renderHeight, RGB);

    for (int rowIdx = renderHeight - 1; rowIdx > 0; rowIdx--) {
      for (int colIdx = renderWidth - 1; colIdx > 0; colIdx--) {
        float xNorm = -1.0f + (float)colIdx * (2.0f / (float)renderWidth);
        float yNorm =  1.0f - (float)rowIdx * (2.0f / (float)renderHeight);
        float radius = sqrt(xNorm * xNorm + yNorm * yNorm);
        float angle  = atan2(xNorm, yNorm);

        float distance = 1.0f / radius;
        float texAngle = angle * (1.0f / 3.14159f);
        float lightIntensity = radius * radius;
        if (lightIntensity > 1.0f) lightIntensity = 1.0f;

        int finalDistance = (int)(distance * 255.0f);
        int finalAngle = (int)(texAngle * 255.0f);
        int finalIntensity = (int)(lightIntensity * 255.0f);

        lookUpTable[renderWidth * rowIdx + colIdx] = ((finalIntensity & 255) << 16) | ((finalAngle & 255) << 8) | (finalDistance & 255);
      }
    }
  }

  void draw(PGraphics pg, int tunnelZoomIncrement, int xOffset, int squareSize) {
    draw(pg, tunnelZoomIncrement, 0, xOffset, squareSize);
  }

  // twistOffset shifts the angle dimension of the texture independently of
  // the zoom — a value of ~32 produces a visible ~90° rotation twist.
  void draw(PGraphics pg, int tunnelZoomIncrement, int twistOffset, int xOffset, int squareSize) {
    int renderWidth = pg.width / RENDER_SCALE;
    int renderHeight = pg.height / RENDER_SCALE;
    if (buffer == null || buffer.width != renderWidth || buffer.height != renderHeight) {
      init(pg.width, pg.height);
      renderWidth = pg.width / RENDER_SCALE;
      renderHeight = pg.height / RENDER_SCALE;
    }
    buffer.loadPixels();
    
    int scaledXOffset = xOffset / RENDER_SCALE;
    int scaledSquareSize = squareSize / RENDER_SCALE;
    int scanEndLimit = min(scaledXOffset + scaledSquareSize, renderWidth);
    
    for (int rowIndex = 0; rowIndex < renderHeight; rowIndex++) {
      for (int columnIndex = scaledXOffset; columnIndex < scanEndLimit; columnIndex++) {
        int pixelIndex  = rowIndex * renderWidth + columnIndex;
        int lookupValue = lookUpTable[pixelIndex];
        int colorTexel = texture[
          ((lookupValue & 0x0000ffff) + ((config.logicalFrameCount + tunnelZoomIncrement) << 1) + (twistOffset << 8)) & ((128*128)-1)
        ];
        int pixelAlpha = (lookupValue >> 16) & 0xFF;
        buffer.pixels[pixelIndex] = (pixelAlpha << 24) | (colorTexel & 0xFFFFFF);
      }
    }
    buffer.updatePixels();
    // We expect the translated context to shift it if drawn within a translate. 
    // Tunnel is drawn before translation, so pg.image(buffer, 0, 0) is perfectly centered.
    pg.image(buffer, scaledXOffset * RENDER_SCALE, 0, scaledSquareSize * RENDER_SCALE, pg.height);
  }
}
