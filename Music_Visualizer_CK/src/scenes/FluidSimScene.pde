/**
 * FluidSimScene (Reaction-Diffusion)
 * 
 * An organic simulation of two substances (A and B) reacting and diffusing.
 * Based on the Gray-Scott model.
 * 
 * Performance is kept high by simulating at a lower resolution (160x90)
 * and upscaling to the main buffer.
 */
class FluidSimScene implements IScene {
  int w = 160;
  int h = 90;
  
  float[][] gridA;
  float[][] gridB;
  float[][] nextA;
  float[][] nextB;
  
  // Model parameters
  float dA = 1.0;
  float dB = 0.5;
  float feed = 0.055;
  float kill = 0.062;
  
  PImage display;
  
  FluidSimScene() {
    gridA = new float[w][h];
    gridB = new float[w][h];
    nextA = new float[w][h];
    nextB = new float[w][h];
    
    display = createImage(w, h, RGB);
    resetGrids();
  }
  
  void resetGrids() {
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        gridA[x][y] = 1.0;
        gridB[x][y] = 0.0;
      }
    }
    // Seed center
    for (int x = w/2-5; x < w/2+5; x++) {
      for (int y = h/2-5; y < h/2+5; y++) {
        gridB[x][y] = 1.0;
      }
    }
  }

  void onEnter() {
    // Optional: reset on enter for a fresh start
    // resetGrids();
  }

  void onExit() {}

  void drawScene(PGraphics pg) {
    // Modulate parameters based on audio
    float bass = analyzer.bass;
    float high = analyzer.high;
    
    // Slight shifts in parameters create massive structural changes
    feed = 0.04 + bass * 0.04;
    kill = 0.06 + high * 0.01;
    
    if (analyzer.isBeat) {
      seedRandom();
    }
    
    // Simulation steps (run twice per frame for faster evolution)
    for (int step = 0; step < 2; step++) {
      updateSimulation();
    }
    
    renderToImage();
    
    pg.beginDraw();
    pg.background(0);
    // Upscale the sim image to fill the screen
    pg.image(display, 0, 0, pg.width, pg.height);
    pg.endDraw();
  }
  
  void updateSimulation() {
    for (int x = 1; x < w-1; x++) {
      for (int y = 1; y < h-1; y++) {
        float a = gridA[x][y];
        float b = gridB[x][y];
        
        float la = laplaceA(x, y);
        float lb = laplaceB(x, y);
        
        float abb = a * b * b;
        
        nextA[x][y] = a + (dA * la - abb + feed * (1 - a));
        nextB[x][y] = b + (dB * lb + abb - (kill + feed) * b);
        
        nextA[x][y] = constrain(nextA[x][y], 0, 1);
        nextB[x][y] = constrain(nextB[x][y], 0, 1);
      }
    }
    
    // Swap grids
    float[][] temp = gridA;
    gridA = nextA;
    nextA = temp;
    
    temp = gridB;
    gridB = nextB;
    nextB = temp;
  }
  
  float laplaceA(int x, int y) {
    float sum = 0;
    sum += gridA[x][y]   * -1.0;
    sum += gridA[x-1][y] * 0.2;
    sum += gridA[x+1][y] * 0.2;
    sum += gridA[x][y-1] * 0.2;
    sum += gridA[x][y+1] * 0.2;
    sum += gridA[x-1][y-1] * 0.05;
    sum += gridA[x+1][y-1] * 0.05;
    sum += gridA[x-1][y+1] * 0.05;
    sum += gridA[x+1][y+1] * 0.05;
    return sum;
  }
  
  float laplaceB(int x, int y) {
    float sum = 0;
    sum += gridB[x][y]   * -1.0;
    sum += gridB[x-1][y] * 0.2;
    sum += gridB[x+1][y] * 0.2;
    sum += gridB[x][y-1] * 0.2;
    sum += gridB[x][y+1] * 0.2;
    sum += gridB[x-1][y-1] * 0.05;
    sum += gridB[x+1][y-1] * 0.05;
    sum += gridB[x-1][y+1] * 0.05;
    sum += gridB[x+1][y+1] * 0.05;
    return sum;
  }
  
  void renderToImage() {
    display.loadPixels();
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        float val = gridA[x][y] - gridB[x][y];
        val = constrain(val, 0, 1);
        
        // Color mapping: Substance B is "hot", Substance A is "cool"
        // Red = B, Blue = A
        float r = gridB[x][y] * 255;
        float g = (gridA[x][y] * 0.2 + gridB[x][y] * 0.5) * 255;
        float b = gridA[x][y] * 150;
        
        display.pixels[x + y * w] = color(r, g, b);
      }
    }
    display.updatePixels();
  }
  
  void seedRandom() {
    int rx = (int)random(w);
    int ry = (int)random(h);
    int r  = 3;
    for (int i = rx - r; i < rx + r; i++) {
        for (int j = ry - r; j < ry + r; j++) {
            if (i > 0 && i < w && j > 0 && j < h) {
                gridB[i][j] = 1.0;
            }
        }
    }
  }

  void applyController(Controller c) {
    if (c.isConnected()) {
        if (c.aJustPressed) resetGrids();
        if (c.xJustPressed) seedRandom();
    }
  }

  void handleKey(char k) {
    if (k == 'r') resetGrids();
    if (k == ' ') seedRandom();
  }

  String[] getCodeLines() {
    return new String[] {
      "// Reaction-Diffusion (Gray-Scott)",
      "dA:" + nf(dA, 1, 2) + " dB:" + nf(dB, 1, 2),
      "feed:" + nf(feed, 1, 3) + " kill:" + nf(kill, 1, 3),
      "Grid: " + w + "x" + h
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("A Button", "Reset Sim"),
      new ControllerLayout("X Button", "Random Seed")
    };
  }
}
