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

  // A is already reserved (cycles geometryType) so sticks are mapped by hand
  // below rather than via routeParamsToSticks' default A-reset binding.
  SceneParam pSpin  = new SceneParam("spin",  "Rotation Speed", -2, 2, 1);
  SceneParam pScale = new SceneParam("scale", "Pattern Scale",  0.5, 2.0, 1);
  SceneParam pHue   = new SceneParam("hue",   "Hue Shift",      0, 360, 0);
  SceneParam pDepth = new SceneParam("depth", "Detail",         1, 4, 3);
  SceneParam[] params = { pSpin, pScale, pHue, pDepth };

  SacredGeometryScene() {}

  void onEnter() { rotation = 0; }
  void onExit() {}

  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.1);
    sMid = lerp(sMid, analyzer.mid, 0.1);
    sHigh = lerp(sHigh, analyzer.high, 0.1);
    
    rotation += analyzer.rotDir * (0.005 + sMid * 0.02) * pSpin.value;

    pg.background(5, 5, 10);
    pg.translate(pg.width/2, pg.height/2);
    pg.rotate(rotation);

    pg.noFill();
    pg.strokeWeight(1.5 + sHigh * 2.5);

    if (geometryType == 0) {
      // Always draw all levels up to pDepth; deeper levels fade in with bass
      float baseR = (80 + sBass * 30) * pScale.value;
      drawFlowerOfLife(pg, 0, 0, baseR, round(pDepth.value));
    } else if (geometryType == 1) {
      drawMetatron(pg, (120 + sBass * 60) * pScale.value);
    } else if (geometryType == 2) {
      drawSeedOfLife(pg, (150 + sBass * 80) * pScale.value);
    } else if (geometryType == 3) {
      int detail = 12 + (int)(sMid * 20) + round((pDepth.value - 3) * 4);
      drawTorus(pg, (100 + sBass * 50) * pScale.value, max(4, detail));
    }
    
    drawHUD(pg);
  }

  // Self-similar Flower of Life: center circle + 6 petals at radius r,
  // each petal containing its own sub-flower at half scale.
  // depth=3 is the outermost (always visible).
  // depth=2 fades in with mid energy.
  // depth=1 fades in with bass — the "innermost bloom".
  void drawFlowerOfLife(PGraphics pg, float cx, float cy, float r, int depth) {
    if (depth <= 0 || r < 5) return;

    // Alpha per level: outer always on, inner driven by audio
    float alpha;
    if      (depth == 3) alpha = 180;
    else if (depth == 2) alpha = 30 + sMid * 170;   // 30..200 with mids
    else                 alpha = sBass * 140;         // 0..140 with bass

    if (alpha < 4) return;  // skip invisible levels

    float hue = (180 + (3 - depth) * 50 + config.logicalFrameCount * 0.2 + pHue.value) % 360;
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.stroke(hue, 210, 255, alpha);
    pg.colorMode(RGB, 255);

    pg.ellipse(cx, cy, r * 2, r * 2);

    for (int i = 0; i < 6; i++) {
      float angle = TWO_PI * i / 6.0;
      float px = cx + cos(angle) * r;
      float py = cy + sin(angle) * r;
      pg.ellipse(px, py, r * 2, r * 2);
      drawFlowerOfLife(pg, px, py, r * 0.5, depth - 1);
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

    pg.colorMode(HSB, 360, 255, 255, 255);
    // Draw all connecting lines
    pg.stroke((60 + pHue.value) % 360, 255, 255, 100);
    for (int i = 0; i < centers.length; i++) {
      for (int j = i + 1; j < centers.length; j++) {
        pg.line(centers[i].x, centers[i].y, centers[j].x, centers[j].y);
      }
    }

    // Draw circles at centers
    for (int i = 0; i < centers.length; i++) {
      float size = (i == 0) ? r * 0.8 : r * 0.6;
      pg.stroke((200 + pHue.value) % 360, 255, 255, 200);
      pg.ellipse(centers[i].x, centers[i].y, size, size);
    }
    pg.colorMode(RGB, 255);
  }

  void drawSeedOfLife(PGraphics pg, float r) {
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.stroke((180 + pHue.value) % 360, 255, 255, 200);
    pg.ellipse(0, 0, r*2, r*2);
    for (int i = 0; i < 6; i++) {
       float angle = TWO_PI * i / 6.0;
       pg.stroke((180 + i * 15 + pHue.value) % 360, 255, 255, 180);
       pg.ellipse(cos(angle) * r, sin(angle) * r, r*2, r*2);
    }
    pg.colorMode(RGB, 255);
  }

  void drawTorus(PGraphics pg, float r, int detail) {
    pg.strokeWeight(1.0 + sHigh * 1.5);
    pg.colorMode(HSB, 360, 255, 255, 255);
    for (int i = 0; i < detail; i++) {
       float angle = TWO_PI * i / detail;
       float x = cos(angle) * r * 0.5;
       float y = sin(angle) * r * 0.5;
       pg.stroke((180 + i * (180.0/detail) + frameCount + pHue.value) % 360, 255, 255, 120);
       pg.ellipse(x, y, r*1.5, r*1.5);
    }
    pg.colorMode(RGB, 255);
  }

  void drawHUD(PGraphics pg) {
    pg.resetMatrix();
    String typeName = "Flower of Life";
    if (geometryType == 1) typeName = "Metatron's Cube";
    if (geometryType == 2) typeName = "Seed of Life";
    if (geometryType == 3) typeName = "Tube Torus";
    sceneHUD(pg, "Sacred Geometry", new String[]{
      "Type: " + typeName,
      "A (controller) or SPACE to cycle",
      "spin " + nf(pSpin.value,1,2) + "  scale " + nf(pScale.value,1,2)
        + "  hue " + nf(pHue.value,0,0) + "  detail " + round(pDepth.value)
    });
  }

  void applyController(Controller c) {
    if (c.aJustPressed) geometryType = (geometryType + 1) % 4;
    // A already cycles the type, so sticks are mapped by hand instead of
    // routeParamsToSticks (which would bind A to a knob reset).
    float dz = 0.12;
    float lx = (c.lx - width  * 0.5) / (width  * 0.5);
    float ly = (c.ly - height * 0.5) / (height * 0.5);
    float rx = (c.rx - width  * 0.5) / (width  * 0.5);
    float ry = (c.ry - height * 0.5) / (height * 0.5);
    if (abs(lx) > dz) pSpin.nudgeNorm(lx * 0.02);
    if (abs(ly) > dz) pScale.nudgeNorm(-ly * 0.02);
    if (abs(rx) > dz) pHue.nudgeNorm(rx * 0.02);
    if (abs(ry) > dz) pDepth.nudgeNorm(-ry * 0.02);
  }
  void handleKey(char k) {
    if (k == ' ') { geometryType = (geometryType + 1) % 4; return; }
    handleParamKey(k);
  }

  SceneParam[] getParams() { return params; }

  String[] getCodeLines() { return new String[]{"Procedural Sacred Geometry", "Hexagonal tiling + Metatron graph"}; }
  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("A", "Cycle geometry type"),
      new ControllerLayout("LStick ↔", "Rotation speed"),
      new ControllerLayout("LStick ↕", "Pattern scale"),
      new ControllerLayout("RStick ↔", "Hue shift"),
      new ControllerLayout("RStick ↕", "Detail (flower depth / torus segments)"),
    };
  }
}
