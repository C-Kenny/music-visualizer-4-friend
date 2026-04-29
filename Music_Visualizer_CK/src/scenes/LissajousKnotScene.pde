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
  
  int displayMode = 3; // 0=Lissajous, 1=Torus, 2=Combined, 3=Combined+Interaction
  boolean autoPan = true;
  
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
    skybox.load(resourcePath("media/skyboxes/" + SKYBOX_PATHS[skyboxIndex]));
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
    if (autoPan) camRotY += 0.002;
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
    pg.strokeWeight(6 + bassIntensity * 12);
    
    int resolution = 600;
    int p = max(2, round(A));
    int q = max(2, round(B));
    if (p == q) q++;
    float torusScale = 120 * scale;

    float[] lx = new float[resolution + 1];
    float[] ly = new float[resolution + 1];
    float[] lz = new float[resolution + 1];

    float[] tx = new float[resolution + 1];
    float[] ty = new float[resolution + 1];
    float[] tz = new float[resolution + 1];

    // Compute Lissajous and Torus points
    for (int i = 0; i <= resolution; i++) {
        float t = map(i, 0, resolution, 0, TWO_PI * 3);
        
        float x = sin(A * t + delta) * rx * scale;
        float y = sin(B * t) * ry * scale;
        float z = cos(C * t) * rz * scale;
        
        float phi = map(i, 0, resolution, 0, TWO_PI);
        float rT = cos(q * phi) + 2.0;
        float tX = rT * cos(p * phi) * torusScale;
        float tY = rT * sin(p * phi) * torusScale;
        float tZ = -sin(q * phi) * torusScale;

        // Audio-Reactive Physics: Bass shakes the knot vertices violently
        if (bassIntensity > 0.3) {
            float jitter = pow((bassIntensity - 0.3), 1.5) * 45.0; 
            float jx = random(-jitter, jitter), jy = random(-jitter, jitter), jz = random(-jitter, jitter);
            x += jx; y += jy; z += jz;
            tX += jx; tY += jy; tZ += jz;
        }
        
        lx[i] = x; ly[i] = y; lz[i] = z;
        tx[i] = tX; ty[i] = tY; tz[i] = tZ;
    }

    // Draw Lissajous Knot
    if (displayMode == 0 || displayMode >= 2) {
        // Outline
        pg.strokeWeight(10 + bassIntensity * 12);
        pg.beginShape();
        for (int i = 0; i <= resolution; i++) {
            pg.stroke(0, 150);
            pg.vertex(lx[i], ly[i], lz[i]);
        }
        pg.endShape();
        
        // Inner
        pg.strokeWeight(6 + bassIntensity * 12);
        pg.beginShape();
        for (int i = 0; i <= resolution; i++) {
            pg.stroke(color((hueShift + i * 0.2) % 360, 200, 255));
            pg.vertex(lx[i], ly[i], lz[i]);
        }
        pg.endShape();
    }

    // Draw Torus Knot
    if (displayMode == 1 || displayMode >= 2) {
        // Outline
        pg.strokeWeight(8 + bassIntensity * 8);
        pg.beginShape();
        for (int i = 0; i <= resolution; i++) {
            pg.stroke(0, 150);
            pg.vertex(tx[i], ty[i], tz[i]);
        }
        pg.endShape();

        // Inner
        pg.strokeWeight(4 + bassIntensity * 8);
        pg.beginShape();
        for (int i = 0; i <= resolution; i++) {
            pg.stroke(color((hueShift + 180 + i * 0.2) % 360, 200, 255));
            pg.vertex(tx[i], ty[i], tz[i]);
        }
        pg.endShape();
    }

    // Interaction lines on high energy
    if (displayMode == 3 && analyzer.high > 0.5) {
        pg.strokeWeight(2);
        pg.beginShape(LINES);
        for (int i = 0; i < resolution; i += 5) {
            pg.stroke(color((hueShift + 90 + i * 0.2) % 360, 180, 255, 120));
            pg.vertex(lx[i], ly[i], lz[i]);
            pg.vertex(tx[i], ty[i], tz[i]);
        }
        pg.endShape();
    }
    
    // Glowing points on high energy
    if (analyzer.high > 0.6) {
      pg.strokeWeight(4);
      for (int i = 0; i < resolution; i += 20) {
          float x = lx[i];
          float y = ly[i];
          float z = lz[i];
          pg.point(x, y, z);
          pg.point(tx[i], ty[i], tz[i]);
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
      if (c.bJustPressed) displayMode = (displayMode + 1) % 4;
      if (c.yJustPressed) autoPan = !autoPan;
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
    if (k == 'm' || k == 'M') displayMode = (displayMode + 1) % 4;
    if (k == 'y' || k == 'Y') autoPan = !autoPan;
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
      "Torus: r = cos(B * phi) + 2;",
      "A:" + nf(A, 1, 1) + " B:" + nf(B, 1, 1) + " C:" + nf(C, 1, 1) + " Skybox:" + SKYBOX_PATHS[skyboxIndex].split("_")[0]
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("L-Stick ↔ ↕", "Frequency Multipliers (A/B)"),
      new ControllerLayout("R-Stick ↔ ↕", "Orbit / Scale"),
      new ControllerLayout("LT / RT",     "Phase Shift (Delta)"),
      new ControllerLayout("A Button",    "Randomize Ratios"),
      new ControllerLayout("B Button",    "Cycle View Mode"),
      new ControllerLayout("X Button",    "Color Cycle Spin"),
      new ControllerLayout("Y Button",    "Toggle Auto-Pan"),
      new ControllerLayout("D-Pad ↔",     "Cycle Skybox")
    };
  }
}
