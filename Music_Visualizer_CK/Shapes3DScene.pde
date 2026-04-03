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

  void drawScene(PGraphics pg) {
    // center scene
    pg.translate(pg.width/2.0, pg.height/2.0);

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

    float radius = min(pg.width, pg.height) * 0.22;
    // gentle rotation for the whole emblem

    // compute sizes used across blocks
    float plateSize = radius * 1.4 * plateScale;

    // gentle rotation for the whole emblem
    pg.rotate(angle + pg.parent.frameCount * 0.0006);
    // background plate (rotated square -> diamond) — darker for contrast
    pg.pushMatrix();
      pg.rotate(radians(45));
      pg.noStroke();
      pg.fill(185); // slightly darker gray to increase contrast with white diamonds
      pg.rectMode(CENTER);
      pg.rect(0, 0, plateSize, plateSize);
    pg.popMatrix();

    // outer radial fins (2D bars) that pulse with audio — uniform, long and narrow
    pg.pushMatrix();
      pg.noStroke();
      float finBase = radius * 0.45;
      float finLen = radius * (1.05 + pulse * pulseSensitivity); // long
      float finWidth = finWidthOverride > 0 ? finWidthOverride : max(8, int(plateSize * 0.06)); // narrow, consistent
      pg.fill(245); // off-white to avoid pure white glare
      for (int i = 0; i < blades; i++) {
        pg.pushMatrix();
          float a = TWO_PI * i / blades;
          pg.rotate(a); // precise alignment
          // draw main rectangular fin (precise alignment)
          pg.rectMode(CORNERS);
          pg.rect(finBase, -finWidth*0.5, finLen, finWidth*0.5);
          // tapered tip (triangle) for a sharper silhouette
          pg.beginShape();
            pg.vertex(finLen, -finWidth*0.6);
            pg.vertex(finLen + finWidth*0.9, 0);
            pg.vertex(finLen, finWidth*0.6);
          pg.endShape(CLOSE);
        pg.popMatrix();
      }
    pg.popMatrix();

    // four corner off-white diamonds (less aggressive white)
    pg.pushMatrix();
      pg.noStroke();
      pg.fill(250, 250, 250);
      float dOff = plateSize * 0.35;
      float dSize = plateSize * 0.45;
      for (int k = 0; k < 4; k++) {
        pg.pushMatrix();
          pg.rotate(k * HALF_PI);
          pg.translate(dOff, 0);
          pg.rotate(radians(45));
          pg.rectMode(CENTER);
          pg.rect(0, 0, dSize, dSize);
        pg.popMatrix();
      }
    pg.popMatrix();

    // central red ring and petal elements inspired by emblem
    pg.pushMatrix();
      // add subtle inner shadow under center to separate layers
      pg.noStroke();
      pg.fill(0, 0, 0, 40);
      pg.ellipse(0, 0, plateSize * 0.38, plateSize * 0.38);

      // ring
      pg.stroke(max(0, baseR-20), max(0, baseG-10), max(0, baseB-10));
      pg.strokeWeight(6);
      pg.noFill();
      float ringSize = plateSize * 0.6 * (1.0 + pulse*0.12);
      pg.ellipse(0, 0, ringSize, ringSize);

      // petals / star-like shapes (sharper polygonal forms)
      pg.noStroke();
      pg.fill(baseR, baseG, baseB);
      for (int p = 0; p < 4; p++) {
        pg.pushMatrix();
          pg.rotate(p * HALF_PI + radians(22.5));
          float px1 = ringSize*0.12;
          float px2 = ringSize*0.42;
          pg.beginShape();
            pg.vertex(px1, -ringSize*0.06);
            pg.vertex(px2, 0);
            pg.vertex(px1, ringSize*0.06);
            pg.vertex(px1*0.3, 0);
          pg.endShape(CLOSE);
        pg.popMatrix();
      }

      // small inner dark disc
      pg.fill(30);
      pg.ellipse(0, 0, ringSize * 0.22, ringSize * 0.22);
    pg.popMatrix();

      // (relative debug overlay removed; using absolute overlay below)
      
      
      // Absolute-position debug overlay (reset matrix to draw in screen coords)
      pg.pushMatrix();
        pg.resetMatrix();
        pg.pushStyle();
          float finWPreview = finWidthOverride > 0 ? finWidthOverride : max(8, int(plateSize * 0.06));
          float ts = 12 * uiScale();
          float lh = ts * 1.3;
          float margin = 4 * uiScale();
          pg.fill(0, 160);
          pg.rectMode(CORNER);
          pg.rect(8, 8, 270 * uiScale(), margin + lh * 5);
          pg.fill(255);
          pg.textSize(ts);
          pg.textAlign(LEFT, TOP);
          pg.text("Scene: Shapes3DScene",              12, 8 + margin);
          pg.text("blades: " + blades,                 12, 8 + margin + lh);
          pg.text("plateScale: " + nf(plateScale, 1, 2), 12, 8 + margin + lh*2);
          pg.text("finWidth: " + nf(finWPreview, 1, 1), 12, 8 + margin + lh*3);
          pg.text("pulseSens: " + nf(pulseSensitivity, 1, 2), 12, 8 + margin + lh*4);
        pg.popStyle();
      pg.popMatrix();
      
    pg.rectMode(CORNER); // restore after CENTER/CORNERS usage above
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
