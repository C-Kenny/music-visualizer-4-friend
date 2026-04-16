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

  // Skybox implementation
  Skybox skybox = new Skybox();
  int skyboxIndex = 0;
  String[] SKYBOX_PATHS = {
    "cloudy_01", "cloudy_02", "cloudy_03", "cloudy_04", "cloudy_05",
    "cloudy_06", "cloudy_07", "cloudy_08", "cloudy_09", "cloudy_10",
    "cloudy_11", "cloudy_12", "cloudy_13", "cloudy_14", "cloudy_15",
    "cloudy_16", "cloudy_17", "cloudy_18", "cloudy_19", "cloudy_20",
    "cloudy_21", "cloudy_22", "cloudy_23", "cloudy_24", "cloudy_25"
  };

  // Camera Orbit
  float camRotX = 0;
  float camRotY = 0;
  
  // Dynamic rotation
  float rotDir = 1.0;
  int lastDirChangeFrame = 0;
  
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

  void loadSkybox(int idx) {
    skyboxIndex = ((idx % SKYBOX_PATHS.length) + SKYBOX_PATHS.length) % SKYBOX_PATHS.length;
    skybox = new Skybox();
    skybox.load(sketchPath("../../media/skyboxes/" + SKYBOX_PATHS[skyboxIndex]));
  }

  void onEnter() {
    baseCol = color(180, 255, 255);
    camRotX = 0;
    camRotY = 0;
    if (!skybox.loaded) loadSkybox(0);
  }

  void onExit() {}

  void drawScene(PGraphics pg) {
    pg.beginDraw();
    pg.background(0);
    
    if (!skybox.loaded) loadSkybox(0);

    // Audio influences
    float bassIntensity = analyzer.bass;
    float midIntensity  = analyzer.mid;

    pg.pushMatrix();
    pg.translate(pg.width / 2, pg.height / 2, 0);

    // Camera Orbit 
    pg.rotateX(camRotX);
    pg.rotateY(camRotY);
    
    // Draw skybox before knot rotations
    skybox.draw(pg);
    
    // Smoothly lerp frequency ratios
    A = lerp(A, targetA, 0.05);
    B = lerp(B, targetB, 0.05);
    C = lerp(C, targetC, 0.05);
    
    // Apply baseline rotation + beat rotation
    pg.rotateX((frameCount * 0.005 + (midIntensity * 0.1)) * rotDir);
    pg.rotateY((frameCount * 0.007 + (midIntensity * 0.1)) * rotDir);
    
    // Dynamic Rotation Direction Change on Heavy Beats (20 sec cooldown)
    if (analyzer.bass > 0.8 && analyzer.isBeat && frameCount - lastDirChangeFrame > 1200) {
      rotDir *= -1.0;
      lastDirChangeFrame = frameCount;
    }
    
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
        
        // Audio-Reactive Physics: Bass shakes the knot vertices violently
        if (bassIntensity > 0.3) {
            float jitter = pow((bassIntensity - 0.3), 1.5) * 45.0; // scales up rapidly on massive beats
            x += random(-jitter, jitter);
            y += random(-jitter, jitter);
            z += random(-jitter, jitter);
        }
        
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
    pg.popMatrix();
    
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
      
      // R-Stick ↕: Radius scaling
      userScale = map(c.ry, height, 0, 0.5, 2.0);
      
      // R-Stick ↔: Camera orbit
      float nx = (c.rx / (float)width) - 0.5;
      if (abs(nx) > 0.12) camRotY += nx * 0.04;
      
      // Triggers: Spin the knot's phase (delta)
      delta += (c.rt - c.lt) * 0.1;

      // Buttons
      if (c.aJustPressed) {
          targetA = floor(random(1, 6));
          targetB = floor(random(1, 8));
          targetC = floor(random(1, 5));
      }
      if (c.xButton) userHueOffset += 5;
      if (c.dpadRightJustPressed) loadSkybox(skyboxIndex + 1);
      if (c.dpadLeftJustPressed) loadSkybox(skyboxIndex - 1);
    }
  }

  void handleKey(char k) {
    if (k == ' ') {
      targetA = floor(random(1, 6));
      targetB = floor(random(1, 8));
      targetC = floor(random(1, 5));
    }
    if (k == ']') loadSkybox(skyboxIndex + 1);
    if (k == '[') loadSkybox(skyboxIndex - 1);
    
    // Camera Orbit Fallbacks
    if (k == 'd' || k == 'D') camRotY += 0.05;
    if (k == 'a' || k == 'A') camRotY -= 0.05;
    if (k == 'w' || k == 'W') camRotX -= 0.05;
    if (k == 's' || k == 'S') camRotX += 0.05;
    camRotX = constrain(camRotX, -PI/2, PI/2);

    if (k == 'u' || k == 'U') targetA = max(1, targetA + 1);
    if (k == 'j' || k == 'J') targetA = max(1, targetA - 1); // Note: Original was 'd' causing a conflict
    if (k == 'r' || k == 'R') targetB = max(1, targetB + 1);
    if (k == 'f' || k == 'F') targetB = max(1, targetB - 1);
  }

  String[] getCodeLines() {
    return new String[] {
      "// Lissajous Knot (3D Parametric)",
      "x = sin(A * t + delta) * rx;",
      "y = sin(B * t) * ry;",
      "z = cos(C * t) * rz;",
      "A:" + nf(A, 1, 1) + " B:" + nf(B, 1, 1) + " C:" + nf(C, 1, 1) + " Skybox:" + SKYBOX_PATHS[skyboxIndex].split("_")[0]
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("L-Stick ↔ ↕", "Frequency Multipliers (A/B)"),
      new ControllerLayout("R-Stick ↔ ↕", "Orbit / Scale"),
      new ControllerLayout("LT / RT",     "Phase Shift (Delta)"),
      new ControllerLayout("A Button",    "Randomize Ratios"),
      new ControllerLayout("X Button",    "Color Cycle Spin"),
      new ControllerLayout("D-Pad ↔",     "Cycle Skybox")
    };
  }
}
