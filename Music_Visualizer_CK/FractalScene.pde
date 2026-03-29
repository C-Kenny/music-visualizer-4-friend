class FractalScene {
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
    if (c.a_just_pressed) {
      symmetries = (symmetries % 8) + 3; // cycles 3..10
    }
    if (c.y_just_pressed) cyclePalette();
    if (c.x_just_pressed) {
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

  void drawScene() {
    // Hard clear to prevent white blob
    background(5, 5, 10);

    // Get frequencies
    float basRaw = audio.normalisedAvg(1);
    float midRaw = audio.normalisedAvg(12);
    float higRaw = audio.normalisedAvg(22);

    globalRotation += rotationSpeed + (higRaw * 0.01 * sign(rotationSpeed));

    // Calculate dynamic properties
    float dynamicBaseLen = height * 0.15 + (basRaw * height * 0.05); // Bass pumps the base length
    float dynamicAngle = baseAngle + (midRaw * PI / 8);              // Mid shifts the breathing angle

    pushMatrix();
    translate(width / 2.0, height / 2.0);

    // Infinite zoom illusion mechanics
    // Zoom scale mathematically loops when it crosses the shrinkFactor boundary
    // globalZoom is open-ended.
    float actualZoom = globalZoom % 1.0; 
    if (actualZoom < 0) actualZoom += 1.0;
    
    // Calculate logarithmic scaling so zooming looks perfectly smooth
    // scale factor goes from 1.0 to (1.0 / shrinkFactor) gracefully
    float scaleFactor = pow(1.0 / shrinkFactor, actualZoom);
    scale(scaleFactor);
    
    // Slowly rotate globally
    rotate(globalRotation);

    blendMode(ADD);
    
    // Draw the multi-symmetrical structure
    colorMode(HSB, 360, 255, 255);
    for (int i = 0; i < symmetries; i++) {
        pushMatrix();
        rotate(TWO_PI * i / symmetries);
        
        // Initial drawing states
        strokeWeight(4);
        strokeCap(ROUND);
        
        drawBranch(dynamicBaseLen, dynamicAngle, maxDepth, 0, basRaw, midRaw, higRaw);
        popMatrix();
    }
    colorMode(RGB, 255);
    
    blendMode(BLEND);
    popMatrix();

    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
    drawHud(basRaw, midRaw, higRaw);
  }

  void drawBranch(float len, float angle, int depthRemaining, int currentDepth, float basRaw, float midRaw, float higRaw) {
    if (depthRemaining <= 0) return;

    // Color shifting along the depth
    float hue = (paletteHues[paletteIndex] + (currentDepth * 20) + (higRaw * 40)) % 360;
    float sat = 200 - (currentDepth * 15);
    float bri = 255 - (currentDepth * 10) + (midRaw * 50);
    
    // High frequency jitter makes thin ends shine intensely
    if (depthRemaining == 1 && higRaw > 0.5) {
        bri = 255;
        strokeWeight(8 * higRaw);
    } else {
        strokeWeight(map(depthRemaining, 0, maxDepth, 0.5, 5));
    }
    
    // The deeper the recursion, the less alpha it gets, fading it in
    // This allows the infinite zoom trick to fade in new branches at the edge gracefully
    float depthAlphaFactor = map(depthRemaining, 1, 3, 0, 255);
    depthAlphaFactor = constrain(depthAlphaFactor, 0, 255);
    
    // Add pulsing alpha to the core based on bass
    float alpha = constrain(depthAlphaFactor + (basRaw * 50), 0, 255);

    stroke(hue, sat, bri, alpha);
    
    // Draw the branch
    line(0, 0, 0, -len);

    // Move to end of branch to spawn children
    translate(0, -len);

    // Recursive calls
    float newLen = len * shrinkFactor;
    
    // Right branch
    pushMatrix();
    rotate(angle);
    drawBranch(newLen, angle, depthRemaining - 1, currentDepth + 1, basRaw, midRaw, higRaw);
    popMatrix();

    // Left branch
    pushMatrix();
    rotate(-angle);
    drawBranch(newLen, angle, depthRemaining - 1, currentDepth + 1, basRaw, midRaw, higRaw);
    popMatrix();
  }

  float sign(float v) {
    if (v < 0) return -1;
    if (v > 0) return 1;
    return 0;
  }

  void drawHud(float low, float mid, float high) {
    pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      fill(0, 125);
      noStroke();
      rectMode(CORNER);
      rect(8, 8, 380 * uiScale(), 8 + lh * 6);
      fill(255);
      textSize(ts);
      textAlign(LEFT, TOP);
      text("Scene: Recursive Fractal", 12, 12);
      text("low / mid / high (norm): " + nf(low, 1, 2) + " / " + nf(mid, 1, 2) + " / " + nf(high, 1, 2), 12, 12 + lh);
      text("zoom lvl: " + nf(globalZoom, 1, 2) + "  rotate speed: " + nf(rotationSpeed, 1, 3), 12, 12 + lh * 2);
      text("angle base: " + nf(degrees(baseAngle), 1, 1) + "  symmetries: " + symmetries, 12, 12 + lh * 3);
      text("palette: " + paletteNames[paletteIndex], 12, 12 + lh * 4);
      text("A symmetries  Y palette  X reset zoom  [ ] zoom  -/= rotate", 12, 12 + lh * 5);
    popStyle();
  }
}
