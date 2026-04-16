class FractalScene implements IScene {
  float globalZoom = 0.0;
  float globalRotation = 0.0;
  float rotationSpeed = 0.005;
  int symmetries = 6;
  float shrinkFactor = 0.65;
  int maxDepth = 6;
  float baseAngle = PI / 4;
  int paletteIndex = 0;
  
  String[] paletteNames = {"Cosmic Bloom", "Neon Synth", "Vaporwave", "Golden Ratio"};
  float[] paletteHues = { 280, 180, 320, 40 };

  FractalScene() {}

  void applyController(Controller c) {
    // Right stick Y handles zooming in/out velocity
    float ry = map(c.ry, 0, height, -1, 1);
    if (abs(ry) > 0.1) {
      globalZoom -= ry * 0.05; // Pushing up (ry = -1) zooms in
    }

    // Right stick X handles global rotation speed
    float rx = map(c.rx, 0, width, -1, 1);
    if (abs(rx) > 0.1) {
      rotationSpeed = rx * 0.05;
    }

    // Left stick X handles the angle of the recursive branches
    float lx = map(c.lx, 0, width, -1, 1);
    if (abs(lx) > 0.1) {
      baseAngle = map(lx, -1, 1, PI/12, PI/2);
    }

    // Buttons
    if (c.aJustPressed) {
      symmetries = (symmetries % 8) + 3; // cycles 3..10
    }
    if (c.yJustPressed) cyclePalette();
    if (c.xJustPressed) {
      globalZoom = 0;
      rotationSpeed = 0.005;
    }
  }

  void cyclePalette() {
    paletteIndex = (paletteIndex + 1) % paletteNames.length;
  }
  
  void adjustZoom(float delta) {
    globalZoom += delta;
  }

  void adjustRotationSpeed(float delta) {
    rotationSpeed += delta;
  }

  void adjustAngle(float delta) {
    baseAngle = constrain(baseAngle + delta, PI/12, PI/2);
  }

  void drawScene(PGraphics pg) {
    // Hard clear to prevent white blob
    pg.background(5, 5, 10);

    // Get frequencies
    float basRaw = analyzer.bass;
    float midRaw = analyzer.mid;
    float higRaw = analyzer.high;

    globalRotation += analyzer.rotDir * (rotationSpeed + higRaw * 0.01 * sign(rotationSpeed));

    // Calculate dynamic properties
    float dynamicBaseLen = pg.height * 0.15 + (basRaw * pg.height * 0.05); // Bass pumps the base length
    float dynamicAngle = baseAngle + (midRaw * PI / 8);              // Mid shifts the breathing angle

    pg.pushMatrix();
    pg.translate(pg.width / 2.0, pg.height / 2.0);

    // Infinite zoom illusion mechanics
    // Zoom scale mathematically loops when it crosses the shrinkFactor boundary
    // globalZoom is open-ended.
    float actualZoom = globalZoom % 1.0; 
    if (actualZoom < 0) actualZoom += 1.0;
    
    // Calculate logarithmic scaling so zooming looks perfectly smooth
    // scale factor goes from 1.0 to (1.0 / shrinkFactor) gracefully
    float scaleFactor = pow(1.0 / shrinkFactor, actualZoom);
    pg.scale(scaleFactor);
    
    // Slowly rotate globally
    pg.rotate(globalRotation);

    pg.blendMode(ADD);
    
    // Draw the multi-symmetrical structure
    pg.colorMode(HSB, 360, 255, 255);
    for (int i = 0; i < symmetries; i++) {
        pg.pushMatrix();
        pg.rotate(TWO_PI * i / symmetries);
        
        // Initial drawing states
        pg.strokeWeight(4);
        pg.strokeCap(ROUND);
        
        drawBranch(pg, dynamicBaseLen, dynamicAngle, maxDepth, 0, basRaw, midRaw, higRaw);
        pg.popMatrix();
    }
    pg.colorMode(RGB, 255);
    
    pg.blendMode(BLEND);
    pg.popMatrix();

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
    drawHud(pg, basRaw, midRaw, higRaw);
  }

  void drawBranch(PGraphics pg, float len, float angle, int depthRemaining, int currentDepth, float basRaw, float midRaw, float higRaw) {
    if (depthRemaining <= 0) return;

    // Color shifting along the depth
    float hue = (paletteHues[paletteIndex] + (currentDepth * 20) + (higRaw * 40)) % 360;
    float sat = 200 - (currentDepth * 15);
    float bri = 255 - (currentDepth * 10) + (midRaw * 50);
    
    // High frequency jitter makes thin ends shine intensely
    if (depthRemaining == 1 && higRaw > 0.5) {
        bri = 255;
        pg.strokeWeight(8 * higRaw);
    } else {
        pg.strokeWeight(map(depthRemaining, 0, maxDepth, 0.5, 5));
    }
    
    // The deeper the recursion, the less alpha it gets, fading it in
    // This allows the infinite zoom trick to fade in new branches at the edge gracefully
    float depthAlphaFactor = map(depthRemaining, 1, 3, 0, 255);
    depthAlphaFactor = constrain(depthAlphaFactor, 0, 255);
    
    // Add pulsing alpha to the core based on bass
    float alpha = constrain(depthAlphaFactor + (basRaw * 50), 0, 255);

    pg.stroke(hue, sat, bri, alpha);
    
    // Draw the branch
    pg.line(0, 0, 0, -len);

    // Move to end of branch to spawn children
    pg.translate(0, -len);

    // Recursive calls
    float newLen = len * shrinkFactor;
    
    // Right branch
    pg.pushMatrix();
    pg.rotate(angle);
    drawBranch(pg, newLen, angle, depthRemaining - 1, currentDepth + 1, basRaw, midRaw, higRaw);
    pg.popMatrix();

    // Left branch
    pg.pushMatrix();
    pg.rotate(-angle);
    drawBranch(pg, newLen, angle, depthRemaining - 1, currentDepth + 1, basRaw, midRaw, higRaw);
    pg.popMatrix();
  }

  float sign(float v) {
    if (v < 0) return -1;
    if (v > 0) return 1;
    return 0;
  }

  void drawHud(PGraphics pg, float low, float mid, float high) {
    sceneHUD(pg, "Recursive Fractal", new String[]{
      "low / mid / high: " + nf(low,1,2) + " / " + nf(mid,1,2) + " / " + nf(high,1,2),
      "zoom: " + nf(globalZoom,1,2) + "  rotate: " + nf(rotationSpeed,1,3) + "  angle: " + nf(degrees(baseAngle),1,1) + "\u00b0",
      "symmetries: " + symmetries + "  palette: " + paletteNames[paletteIndex],
      "A sym  Y palette  X reset  [ ] zoom  -/= rotate"
    });
  }
  void onEnter() {
    globalZoom = 0;
    globalRotation = 0;
    background(5, 5, 10);
  }

  void onExit() {}

  void handleKey(char k) {
    if (k == '[') adjustZoom(-0.1);
    else if (k == ']') adjustZoom(0.1);
    else if (k == '-' || k == '_') adjustRotationSpeed(-0.01);
    else if (k == '=' || k == '+') adjustRotationSpeed(0.01);
    else if (k == 'y' || k == 'Y') cyclePalette();
    else if (k == 'x' || k == 'X') {
      globalZoom = 0;
      rotationSpeed = 0.005;
    }
    else if (k == 'a' || k == 'A') {
      symmetries = (symmetries % 8) + 3;
    }
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Recursive Fractal ===",
      "// Infinite zoom illusion via modulo and log-scaling",
      "actual_zoom = global_zoom % 1.0",
      "scale_factor = pow(1.0 / shrink_factor, actual_zoom)",
      "draw_branch(len * shrink_factor, angle + mid * offset)"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
