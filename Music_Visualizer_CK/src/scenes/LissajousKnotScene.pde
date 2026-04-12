/**
 * LissajousKnotScene
 * 
 * A 3D parametric curve that visualizes the harmonic relationship between audio bands.
 * The curve is a 3D Lissajous figure:
 *   x = sin(A * t + delta) * rx
 *   y = sin(B * t) * ry
 *   z = cos(C * t) * rz
 * 
 * A, B, and C are derived from bass, mid, and high intensities.
 */
class LissajousKnotScene implements IScene {
  float rx, ry, rz;
  float A, B, C;
  float delta;
  float tOffset = 0;
  
  float targetA, targetB, targetC;
  
  color baseCol;
  float hueShift = 0;
  float userHueOffset = 0;
  float userScale = 1.0;
  
  LissajousKnotScene() {
    rx = 300;
    ry = 300;
    rz = 300;
    A = 2;
    B = 3;
    C = 5;
    targetA = A;
    targetB = B;
    targetC = C;
    delta = 0;
  }

  void onEnter() {
    baseCol = color(180, 255, 255);
  }

  void onExit() {}

  void drawScene(PGraphics pg) {
    pg.beginDraw();
    pg.background(0);
    pg.translate(pg.width / 2, pg.height / 2, 0);
    
    // Smoothly lerp frequency ratios
    A = lerp(A, targetA, 0.05);
    B = lerp(B, targetB, 0.05);
    C = lerp(C, targetC, 0.05);
    
    // Apply camera rotation
    pg.rotateX(frameCount * 0.005);
    pg.rotateY(frameCount * 0.007);
    
    // Audio influences
    float bassIntensity = analyzer.bass;
    float midIntensity  = analyzer.mid;
    
    // If no manual override recently, auto-rotate ratios on beat
    if (!controller.isConnected() && analyzer.isBeat && frameCount % 60 == 0) {
      targetA = floor(random(1, 6));
      targetB = floor(random(1, 8));
      targetC = floor(random(1, 5));
      delta += PI/4;
    }
    
    float scale = (1.0 + bassIntensity * 0.5) * userScale;
    hueShift = (hueShift + midIntensity * 2 + userHueOffset) % 360;
    
    pg.noFill();
    pg.strokeWeight(2 + bassIntensity * 10);
    
    pg.beginShape();
    int resolution = 600;
    for (int i = 0; i <= resolution; i++) {
        float t = map(i, 0, resolution, 0, TWO_PI * 3);
        
        float x = sin(A * t + delta) * rx * scale;
        float y = sin(B * t) * ry * scale;
        float z = cos(C * t) * rz * scale;
        
        pg.stroke(color((hueShift + i * 0.2) % 360, 200, 255));
        pg.vertex(x, y, z);
    }
    pg.endShape();
    
    // Glowing points on high energy
    if (analyzer.high > 0.6) {
      pg.strokeWeight(4);
      for (int i = 0; i < resolution; i += 20) {
          float t = map(i, 0, resolution, 0, TWO_PI * 3);
          float x = sin(A * t + delta) * rx * scale;
          float y = sin(B * t) * ry * scale;
          float z = cos(C * t) * rz * scale;
          pg.point(x, y, z);
      }
    }
    
    pg.endDraw();
    
    // Reset transient offsets slowly
    userHueOffset *= 0.95;
  }

  void applyController(Controller c) {
    if (c.isConnected()) {
      // L-Stick: Interactive multipliers (round for neatness)
      if (abs(c.lx - width/2) > 20 || abs(c.ly - height/2) > 20) {
          targetA = map(c.lx, 0, width, 1, 8);
          targetB = map(c.ly, 0, height, 1, 8);
      }
      
      // R-Stick: Radius scaling
      userScale = map(c.ry, height, 0, 0.5, 2.0);
      
      // Triggers: Spin the knot's phase (delta)
      delta += (c.rt - c.lt) * 0.1;

      // Buttons
      if (c.aJustPressed) {
          targetA = floor(random(1, 6));
          targetB = floor(random(1, 8));
          targetC = floor(random(1, 5));
      }
      if (c.xButton) userHueOffset += 5;
    }
  }

  void handleKey(char k) {
    if (k == ' ') {
      targetA = floor(random(1, 6));
      targetB = floor(random(1, 8));
      targetC = floor(random(1, 5));
    }
    if (k == 'u' || k == 'U') targetA = max(1, targetA + 1);
    if (k == 'd' || k == 'D') targetA = max(1, targetA - 1);
    if (k == 'r' || k == 'R') targetB = max(1, targetB + 1);
    if (k == 'f' || k == 'F') targetB = max(1, targetB - 1);
  }

  String[] getCodeLines() {
    return new String[] {
      "// Lissajous Knot (3D Parametric)",
      "x = sin(A * t + delta) * rx;",
      "y = sin(B * t) * ry;",
      "z = cos(C * t) * rz;",
      "A:" + nf(A, 1, 1) + " B:" + nf(B, 1, 1) + " C:" + nf(C, 1, 1) + " Delta:" + nf(delta, 1, 2)
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("L-Stick ↔ ↕", "Frequency Multipliers (A/B)"),
      new ControllerLayout("R-Stick ↕",   "Scale / Zoom"),
      new ControllerLayout("LT / RT",     "Phase Shift (Delta)"),
      new ControllerLayout("A Button",     "Randomize Ratios"),
      new ControllerLayout("X Button",     "Color Cycle Spin")
    };
  }
}
