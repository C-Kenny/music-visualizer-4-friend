/**
 * SacredGeometryScene
 * 
 * Procedural geometric patterns: Flower of Life and Metatron's Cube.
 * Responds to frequency bands by increasing layering and complexity.
 */
class SacredGeometryScene implements IScene {
  float rotation = 0;
  float sBass = 0, sMid = 0, sHigh = 0;
  int geometryType = 0; // 0: Flower, 1: Metatron, 2: Seed, 3: Torus
  
  SacredGeometryScene() {}

  void onEnter() { rotation = 0; }
  void onExit() {}

  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.1);
    sMid = lerp(sMid, analyzer.mid, 0.1);
    sHigh = lerp(sHigh, analyzer.high, 0.1);
    
    rotation += 0.005 + sMid * 0.02;

    pg.background(5, 5, 10);
    pg.translate(pg.width/2, pg.height/2);
    pg.rotate(rotation);
    
    pg.noFill();
    pg.strokeWeight(1.5 + sHigh * 2.5);
    
    if (geometryType == 0) {
      drawFlowerOfLife(pg, 80 + sBass * 40, 3 + (int)(sMid * 3));
    } else if (geometryType == 1) {
      drawMetatron(pg, 120 + sBass * 60);
    } else if (geometryType == 2) {
      drawSeedOfLife(pg, 150 + sBass * 80);
    } else if (geometryType == 3) {
      drawTorus(pg, 100 + sBass * 50, 12 + (int)(sMid * 20));
    }
    
    drawHUD(pg);
  }

  void drawFlowerOfLife(PGraphics pg, float r, int depth) {
    pg.stroke(180, 255, 255, 180);
    pg.ellipse(0, 0, r*2, r*2);
    
    for (int d = 1; d <= depth; d++) {
      float alpha = map(d, 1, depth, 150, 40);
      pg.stroke(180 + d * 10, 255, 255, alpha);
      for (int i = 0; i < 6 * d; i++) {
         float angle = TWO_PI * i / (6.0 * d);
         float x = cos(angle) * r * d;
         float y = sin(angle) * r * d;
         pg.ellipse(x, y, r*2, r*2);
      }
    }
  }

  void drawMetatron(PGraphics pg, float r) {
    PVector[] centers = new PVector[13];
    centers[0] = new PVector(0, 0);
    
    // 6 around center
    for (int i = 0; i < 6; i++) {
      float angle = TWO_PI * i / 6.0;
      centers[i+1] = new PVector(cos(angle) * r, sin(angle) * r);
    }
    
    // 6 more in outer ring
    for (int i = 0; i < 6; i++) {
      float angle = TWO_PI * i / 6.0;
      centers[i+7] = new PVector(cos(angle) * r * 2, sin(angle) * r * 2);
    }

    // Draw all connecting lines
    pg.stroke(60, 255, 255, 100);
    for (int i = 0; i < centers.length; i++) {
      for (int j = i + 1; j < centers.length; j++) {
        pg.line(centers[i].x, centers[i].y, centers[j].x, centers[j].y);
      }
    }
    
    // Draw circles at centers
    for (int i = 0; i < centers.length; i++) {
      float size = (i == 0) ? r * 0.8 : r * 0.6;
      pg.stroke(200, 255, 255, 200);
      pg.ellipse(centers[i].x, centers[i].y, size, size);
    }
  }

  void drawSeedOfLife(PGraphics pg, float r) {
    pg.stroke(180, 255, 255, 200);
    pg.ellipse(0, 0, r*2, r*2);
    for (int i = 0; i < 6; i++) {
       float angle = TWO_PI * i / 6.0;
       pg.stroke(180 + i * 15, 255, 255, 180);
       pg.ellipse(cos(angle) * r, sin(angle) * r, r*2, r*2);
    }
  }

  void drawTorus(PGraphics pg, float r, int detail) {
    pg.strokeWeight(1.0 + sHigh * 1.5);
    for (int i = 0; i < detail; i++) {
       float angle = TWO_PI * i / detail;
       float x = cos(angle) * r * 0.5;
       float y = sin(angle) * r * 0.5;
       pg.stroke((180 + i * (180.0/detail) + frameCount) % 360, 255, 255, 120);
       pg.ellipse(x, y, r*1.5, r*1.5);
    }
  }

  void drawHUD(PGraphics pg) {
    pg.pushStyle();
    pg.resetMatrix();
    float ts = 11 * uiScale();
    pg.fill(200, 255, 230);
    pg.textSize(ts);
    pg.textAlign(LEFT, TOP);
    String typeName = "Flower of Life";
    if (geometryType == 1) typeName = "Metatron's Cube";
    if (geometryType == 2) typeName = "Seed of Life";
    if (geometryType == 3) typeName = "Tube Torus";
    pg.text("Sacred Geometry: " + typeName, 20, 20);
    pg.text("Press A (Controller) or SPACE (Key) to toggle", 20, 20 + ts * 1.5);
    pg.popStyle();
  }

  void applyController(Controller c) {
    if (c.aJustPressed) geometryType = (geometryType + 1) % 4;
  }
  void handleKey(char k) {
    if (k == ' ') geometryType = (geometryType + 1) % 4;
  }

  String[] getCodeLines() { return new String[]{"Procedural Sacred Geometry", "Hexagonal tiling + Metatron graph"}; }
  ControllerLayout[] getControllerLayout() { return new ControllerLayout[]{}; }
}
