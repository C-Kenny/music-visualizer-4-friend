// 2D emblem-inspired scene (keeps class name so existing calls still work)
// Uses `h3_emblem` as a color reference only (not textured)
// Activated by pressing '3' (config.STATE = 3).

class Shapes3DScene implements IScene {
  float angle = 0.0;
  int blades = 8;
  float pulse = 0.0;
  // runtime-adjustable parameters
  float plateScale = 1.0; // multiplier for plate size
  float finWidthOverride = 0; // if <=0, computed from plateSize
  float pulseSensitivity = 0.5; // multiplier for audio pulse effect
  boolean emblemColorsInitialized = false;
  int baseR = 200;
  int baseG = 28;
  int baseB = 28;

  Shapes3DScene() {
  }

  // runtime setters
  void incrementBlades(int delta) {
    blades = max(3, blades + delta);
  }

  void setBlades(int b) {
    blades = constrain(b, 3, 64);
  }

  void adjustFinWidth(float delta) {
    finWidthOverride = max(2, finWidthOverride + delta);
  }

  void setFinWidth(float w) {
    finWidthOverride = constrain(w, 2, max(16, width * 0.2));
  }

  void adjustPlateScale(float delta) {
    plateScale = max(0.5, plateScale + delta);
  }

  void setPlateScale(float s) {
    plateScale = constrain(s, 0.5, 4.0);
  }

  void adjustPulseSensitivity(float delta) {
    pulseSensitivity = max(0.05, pulseSensitivity + delta);
  }

  void setPulseSensitivity(float s) {
    pulseSensitivity = constrain(s, 0.05, 2.0);
  }

  void drawScene() {
    // center scene
    translate(width/2.0, height/2.0);

    // sample emblem color center once
    if (!emblemColorsInitialized && h3_emblem != null) {
      int sx = constrain(h3_emblem.width/2, 0, h3_emblem.width-1);
      int sy = constrain(h3_emblem.height/2, 0, h3_emblem.height-1);
      color c = h3_emblem.get(sx, sy);
      baseR = int(red(c));
      baseG = int(green(c));
      baseB = int(blue(c));
      emblemColorsInitialized = true;
    }

    // audio-driven pulse
    if (analyzer.isBeat) {
      pulse = 1.0;
      angle += 0.18;
    }
    pulse *= 0.86;

    float radius = min(width, height) * 0.22;
    // gentle rotation for the whole emblem

    // compute sizes used across blocks
    float plateSize = radius * 1.4 * plateScale;

    // gentle rotation for the whole emblem
    rotate(angle + frameCount * 0.0006);
    // background plate (rotated square -> diamond) — darker for contrast
    pushMatrix();
      rotate(radians(45));
      noStroke();
      fill(185); // slightly darker gray to increase contrast with white diamonds
      rectMode(CENTER);
      rect(0, 0, plateSize, plateSize);
    popMatrix();

    // outer radial fins (2D bars) that pulse with audio — uniform, long and narrow
    pushMatrix();
      noStroke();
      float finBase = radius * 0.45;
      float finLen = radius * (1.05 + pulse * pulseSensitivity); // long
      float finWidth = finWidthOverride > 0 ? finWidthOverride : max(8, int(plateSize * 0.06)); // narrow, consistent
      fill(245); // off-white to avoid pure white glare
      for (int i = 0; i < blades; i++) {
        pushMatrix();
          float a = TWO_PI * i / blades;
          rotate(a); // precise alignment
          // draw main rectangular fin (precise alignment)
          rectMode(CORNERS);
          rect(finBase, -finWidth*0.5, finLen, finWidth*0.5);
          // tapered tip (triangle) for a sharper silhouette
          beginShape();
            vertex(finLen, -finWidth*0.6);
            vertex(finLen + finWidth*0.9, 0);
            vertex(finLen, finWidth*0.6);
          endShape(CLOSE);
        popMatrix();
      }
    popMatrix();

    // four corner off-white diamonds (less aggressive white)
    pushMatrix();
      noStroke();
      fill(250, 250, 250);
      float dOff = plateSize * 0.35;
      float dSize = plateSize * 0.45;
      for (int k = 0; k < 4; k++) {
        pushMatrix();
          rotate(k * HALF_PI);
          translate(dOff, 0);
          rotate(radians(45));
          rectMode(CENTER);
          rect(0, 0, dSize, dSize);
        popMatrix();
      }
    popMatrix();

    // central red ring and petal elements inspired by emblem
    pushMatrix();
      // add subtle inner shadow under center to separate layers
      noStroke();
      fill(0, 0, 0, 40);
      ellipse(0, 0, plateSize * 0.38, plateSize * 0.38);

      // ring
      stroke(max(0, baseR-20), max(0, baseG-10), max(0, baseB-10));
      strokeWeight(6);
      noFill();
      float ringSize = plateSize * 0.6 * (1.0 + pulse*0.12);
      ellipse(0, 0, ringSize, ringSize);

      // petals / star-like shapes (sharper polygonal forms)
      noStroke();
      fill(baseR, baseG, baseB);
      for (int p = 0; p < 4; p++) {
        pushMatrix();
          rotate(p * HALF_PI + radians(22.5));
          float px1 = ringSize*0.12;
          float px2 = ringSize*0.42;
          beginShape();
            vertex(px1, -ringSize*0.06);
            vertex(px2, 0);
            vertex(px1, ringSize*0.06);
            vertex(px1*0.3, 0);
          endShape(CLOSE);
        popMatrix();
      }

      // small inner dark disc
      fill(30);
      ellipse(0, 0, ringSize * 0.22, ringSize * 0.22);
    popMatrix();

      // (relative debug overlay removed; using absolute overlay below)
      
      
      // Absolute-position debug overlay (reset matrix to draw in screen coords)
      pushMatrix();
        resetMatrix();
        pushStyle();
          float finWPreview = finWidthOverride > 0 ? finWidthOverride : max(8, int(plateSize * 0.06));
          float ts = 12 * uiScale();
          float lh = ts * 1.3;
          float margin = 4 * uiScale();
          fill(0, 160);
          rectMode(CORNER);
          rect(8, 8, 270 * uiScale(), margin + lh * 5);
          fill(255);
          textSize(ts);
          textAlign(LEFT, TOP);
          text("Scene: Shapes3DScene",              12, 8 + margin);
          text("blades: " + blades,                 12, 8 + margin + lh);
          text("plateScale: " + nf(plateScale, 1, 2), 12, 8 + margin + lh*2);
          text("finWidth: " + nf(finWPreview, 1, 1), 12, 8 + margin + lh*3);
          text("pulseSens: " + nf(pulseSensitivity, 1, 2), 12, 8 + margin + lh*4);
        popStyle();
      popMatrix();
      
    rectMode(CORNER); // restore after CENTER/CORNERS usage above
  }

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void applyController(Controller c) {
    // controller.* values are mapped to screen coords (0..width or 0..height) by Controller
    // normalize them back to -1..1 before mapping to scene params
    float nx = map(c.rx, 0, width, -1, 1);
    float ny = map(c.ry, 0, height, -1, 1);
    float lx = map(c.lx, 0, width, -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);

    int bladesFromStick = int(map(nx, -1, 1, 4, 12));
    setBlades(bladesFromStick);

    float finW = map(ly, -1, 1, 8, min(width, height) * 0.08);
    setFinWidth(finW);

    float plateS = map(lx, -1, 1, 0.8, 1.6);
    setPlateScale(plateS);

    float pulseS = map(ny, -1, 1, 0.2, 1.2);
    setPulseSensitivity(pulseS);
  }

  void handleKey(char k) {
    if (k == 'k') incrementBlades(-1);
    else if (k == 'K') incrementBlades(1);
    else if (k == '[') adjustFinWidth(-2);
    else if (k == ']') adjustFinWidth(2);
    else if (k == ',') adjustPlateScale(-0.05);
    else if (k == '.') adjustPlateScale(0.05);
    else if (k == 'u') adjustPulseSensitivity(-0.05);
    else if (k == 'U') adjustPulseSensitivity(0.05);
  }

  String[] getCodeLines() {
    return new String[] {
      "=== 3D-Style Shapes (Emblem) ===",
      "// Logic: Symmetrical fins pulse with audio energy",
      "fin_length = radius * (1.0 + pulse * sensitivity)",
      "rotation = frameCount * speed + onset_kick"
    };
  }
}
