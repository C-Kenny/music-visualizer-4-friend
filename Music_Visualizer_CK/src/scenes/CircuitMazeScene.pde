class CircuitGate {
  int x1, y1, x2, y2;
  boolean exists;
  boolean isOpen;
  float openVis;
  float glow;

  CircuitGate(int x1, int y1, int x2, int y2, boolean exists, boolean isOpen) {
    this.x1 = x1;
    this.y1 = y1;
    this.x2 = x2;
    this.y2 = y2;
    this.exists = exists;
    this.isOpen = isOpen;
    this.openVis = isOpen ? 1.0 : 0.0;
    this.glow = 0.0;
  }
}

class CircuitMazeScene implements IScene {
  int cols = 12;
  int rows = 8;

  CircuitGate[][] rightGates;
  CircuitGate[][] downGates;
  boolean[][] reachable;
  boolean[][] letterMask;

  boolean hasCompletePath = false;
  float lampGlow = 0.0;
  float beatFlash = 0.0;
  boolean debugOverrideOpen = false;

  float openBias = 0.72;

  CircuitMazeScene() {
    buildCircuit();
  }

  void updateLetterGrid(String text) {
    cols = max(12, text.length() * 6);
    letterMask = new boolean[cols][rows];
    
    PGraphics pg = createGraphics(cols, rows);
    pg.beginDraw();
    pg.noSmooth();
    pg.background(0);
    pg.fill(255);
    pg.stroke(255);
    pg.strokeWeight(1.2); // Fatten the letters
    pg.textAlign(CENTER, CENTER);
    pg.textFont(createFont("Arial Bold", 10)); // Force bold
    pg.textSize(rows * 0.9); 
    pg.text(text, cols/2.0, rows/2.0 - 0.6);
    pg.loadPixels();
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        letterMask[x][y] = (brightness(pg.pixels[y * cols + x]) > 100);
      }
    }
    pg.endDraw();
  }

  boolean isLetterNode(int x, int y) {
    if (x < 0 || x >= cols || y < 0 || y >= rows) return false;
    return letterMask[x][y];
  }

  boolean isLetterCell(int x, int y) {
    if (x < 0 || x >= cols - 1 || y < 0 || y >= rows - 1) return false;
    // A cell is "Letter" if most of its corners are letter nodes
    int count = 0;
    if (isLetterNode(x, y)) count++;
    if (isLetterNode(x + 1, y)) count++;
    if (isLetterNode(x, y + 1)) count++;
    if (isLetterNode(x + 1, y + 1)) count++;
    return count >= 3; 
  }

  boolean isLetterGate(CircuitGate g) {
    return isLetterNode(g.x1, g.y1) && isLetterNode(g.x2, g.y2);
  }

  void buildCircuit() {
    updateLetterGrid(config.CIRCUIT_TEXT);
    
    rightGates = new CircuitGate[cols - 1][rows];
    downGates = new CircuitGate[cols][rows - 1];
    reachable = new boolean[cols][rows];

    for (int x = 0; x < cols - 1; x++) {
      for (int y = 0; y < rows; y++) {
        boolean letter = isLetterNode(x, y) && isLetterNode(x + 1, y);
        boolean exists = letter || (random(1) < 0.18);
        boolean gateOpen = random(1) < openBias;
        rightGates[x][y] = new CircuitGate(x, y, x + 1, y, exists, gateOpen);
      }
    }

    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows - 1; y++) {
        boolean letter = isLetterNode(x, y) && isLetterNode(x, y + 1);
        boolean exists = letter || (random(1) < 0.12);
        boolean gateOpen = random(1) < openBias;
        downGates[x][y] = new CircuitGate(x, y, x, y + 1, exists, gateOpen);
      }
    }

    forceBackbonePath();
    refreshFlowState();
  }

  void forceBackbonePath() {
    int x = 0; int y = 0;
    while (x < cols - 1 || y < rows - 1) {
      if (x < cols - 1 && y < rows - 1) {
        if (random(1) < 0.5) { CircuitGate g = rightGates[x][y]; g.exists = true; g.isOpen = true; x++; }
        else { CircuitGate g = downGates[x][y]; g.exists = true; g.isOpen = true; y++; }
      } else if (x < cols - 1) { CircuitGate g = rightGates[x][y]; g.exists = true; g.isOpen = true; x++; }
      else { CircuitGate g = downGates[x][y]; g.exists = true; g.isOpen = true; y++; }
    }
  }

  void triggerBeatPulse(float bass, float high) {
    beatFlash = 1.0;
    int toggles = 4 + (int) map(constrain(bass, 0, 25), 0, 25, 0, 9);
    for (int i = 0; i < toggles; i++) toggleRandomGate();
    if (high > 7.0) for (int i = 0; i < 2; i++) toggleRandomGate();
  }

  void toggleRandomGate() {
    if (random(1) < 0.5) {
      int x = (int) random(cols - 1); int y = (int) random(rows);
      CircuitGate g = rightGates[x][y]; if (g.exists) g.isOpen = !g.isOpen;
    } else {
      int x = (int) random(cols); int y = (int) random(rows - 1);
      CircuitGate g = downGates[x][y]; if (g.exists) g.isOpen = !g.isOpen;
    }
  }

  void markReachable() {
    for (int x = 0; x < cols; x++) for (int y = 0; y < rows; y++) reachable[x][y] = false;
    int capacity = cols * rows;
    int[] qx = new int[capacity]; int[] qy = new int[capacity];
    int head = 0; int tail = 0;

    // Batteries: All nodes on the left, plus booster nodes every 12 columns
    for (int x = 0; x < cols; x += 12) {
      for (int y = 0; y < rows; y++) {
        if (x == 0 || (x > 0 && isLetterNode(x, y))) {
          reachable[x][y] = true; qx[tail] = x; qy[tail] = y; tail++;
        }
      }
    }

    while (head < tail) {
      int cx = qx[head]; int cy = qy[head]; head++;
      if (cx > 0) {
        CircuitGate g = rightGates[cx - 1][cy];
        if (g.exists && (g.isOpen || debugOverrideOpen) && !reachable[cx - 1][cy]) { reachable[cx - 1][cy] = true; qx[tail] = cx - 1; qy[tail] = cy; tail++; }
      }
      if (cx < cols - 1) {
        CircuitGate g = rightGates[cx][cy];
        if (g.exists && (g.isOpen || debugOverrideOpen) && !reachable[cx + 1][cy]) { reachable[cx + 1][cy] = true; qx[tail] = cx + 1; qy[tail] = cy; tail++; }
      }
      if (cy > 0) {
        CircuitGate g = downGates[cx][cy - 1];
        if (g.exists && (g.isOpen || debugOverrideOpen) && !reachable[cx][cy - 1]) { reachable[cx][cy - 1] = true; qx[tail] = cx; qy[tail] = cy - 1; tail++; }
      }
      if (cy < rows - 1) {
        CircuitGate g = downGates[cx][cy];
        if (g.exists && (g.isOpen || debugOverrideOpen) && !reachable[cx][cy + 1]) { reachable[cx][cy + 1] = true; qx[tail] = cx; qy[tail] = cy + 1; tail++; }
      }
    }
  }

  void refreshFlowState() { markReachable(); hasCompletePath = reachable[cols - 1][rows - 1]; if (hasCompletePath) lampGlow = 1.0; }

  float gateTargetGlow(CircuitGate g) {
    if (!g.exists) return 0.0;
    if (debugOverrideOpen) return 1.0;
    boolean e1 = reachable[g.x1][g.y1]; boolean e2 = reachable[g.x2][g.y2];
    if (g.isOpen && e1 && e2) return 1.0;
    if (g.isOpen && (e1 || e2)) return 0.35;
    return 0.06;
  }

  void updateVisualState() {
    for (int x = 0; x < cols - 1; x++) for (int y = 0; y < rows; y++) {
      CircuitGate g = rightGates[x][y];
      g.openVis = lerp(g.openVis, g.isOpen ? 1.0 : 0.0, 0.2);
      g.glow = lerp(g.glow, gateTargetGlow(g), 0.2);
    }
    for (int x = 0; x < cols; x++) for (int y = 0; y < rows - 1; y++) {
      CircuitGate g = downGates[x][y];
      g.openVis = lerp(g.openVis, g.isOpen ? 1.0 : 0.0, 0.2);
      g.glow = lerp(g.glow, gateTargetGlow(g), 0.2);
    }
    lampGlow = hasCompletePath ? min(1.0, lampGlow + 0.08) : lampGlow * 0.93;
    beatFlash *= 0.84;
  }

  void drawBlockUnderlays(PGraphics pg, float originX, float originY, float stepX, float stepY) {
    pg.noStroke();
    pg.rectMode(CORNER);
    float glowPulse = 0.5 + 0.5 * sin(frameCount * 0.1) + beatFlash * 0.5;
    
    for (int x = 0; x < cols - 1; x++) {
      for (int y = 0; y < rows - 1; y++) {
        if (isLetterCell(x, y)) {
          float px = originX + x * stepX;
          float py = originY + y * stepY;
          
          // Outer block glow
          pg.fill(30, 255, 100, 40 + glowPulse * 30);
          pg.rect(px - 2, py - 2, stepX + 4, stepY + 4, 4);
          
          // Inner block core
          pg.fill(35, 255, 200, 60 + beatFlash * 100);
          pg.rect(px + 4, py + 4, stepX - 8, stepY - 8, 2);
        }
      }
    }
  }

  void drawGridNodes(PGraphics pg, float originX, float originY, float stepX, float stepY) {
    pg.noStroke();
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        float px = originX + x * stepX; float py = originY + y * stepY;
        boolean energised = reachable[x][y];
        boolean isLetter = isLetterNode(x, y);
        float r = energised ? (isLetter ? 7.0 : 4.0) : 3.0; // Scale nodes
        
        if (x % 12 == 0) { // Battery / Booster
          pg.fill(140, 255, 255, 220); // Cyan Battery
          pg.ellipse(px, py, 14, 14);
          pg.fill(120, 255, 255, 180 + beatFlash * 70);
          pg.ellipse(px, py, 8 + beatFlash * 8, 8 + beatFlash * 8);
        }
        if (x == cols - 1 && y == rows - 1) {
          float lamp = constrain(lampGlow * 255.0, 0, 255);
          pg.fill(30, 255, 220, 80 + lamp); // Gold Lamp
          pg.ellipse(px, py, 32 + lampGlow * 12.0, 32 + lampGlow * 12.0);
          pg.fill(50, 255, 240, 130 + lamp * 0.45);
          pg.ellipse(px, py, 15 + lampGlow * 5.0, 15 + lampGlow * 5.0);
        }
        if (energised) {
          if (isLetter) pg.fill(30, 255, 255, 220); // Golden Letter
          else pg.fill(150, 255, 240, 160); // Dimmer Noise
        } else { pg.fill(160, 80, 70, 140); }
        pg.ellipse(px, py, r * 2, r * 2);
      }
    }
  }

  void drawGate(PGraphics pg, CircuitGate g, float originX, float originY, float stepX, float stepY) {
    if (!g.exists) return;
    float x1 = originX + g.x1 * stepX; float y1 = originY + g.y1 * stepY;
    float x2 = originX + g.x2 * stepX; float y2 = originY + g.y2 * stepY;
    float cx = (x1 + x2) * 0.5; float cy = (y1 + y2) * 0.5;
    float bright = 80 + g.glow * 175 + beatFlash * 40;
    float alpha = 70 + g.glow * 150;
    
    boolean isLet = isLetterGate(g);
    float baseW = max(1.2, (2.0 + g.glow * 1.5) * (12.0/cols));
    if (isLet) {
      pg.strokeWeight(baseW * 4.2); // Much Thicker
      pg.stroke(30, 255, bright, min(255, alpha * 1.2)); // Golden
    } else {
      pg.strokeWeight(baseW);
      pg.stroke(150, 255, bright, alpha * 0.6); // Dimmer Cyan
    }
    
    float gap = 12.0 * (1.0 - g.openVis) * (12.0/cols);
    if (abs(x2 - x1) > abs(y2 - y1)) {
      pg.line(x1, y1, cx - gap, cy); pg.line(cx + gap, cy, x2, y2);
      if (g.glow > 0.5) { 
        float p = (frameCount * 0.08) % 1.0; 
        float sx = lerp(x1, x2, p); 
        pg.strokeWeight(isLet ? 6 : 4); 
        pg.stroke(0, 0, 255, 200 * g.glow); 
        pg.line(sx - 5, y1, sx + 5, y1); 
      }
      if (gap > 1.0) { pg.noStroke(); pg.fill(0, 180, 120, 190); pg.rectMode(CENTER); pg.rect(cx, cy, 4 * (12.0/cols), 11 * (12.0/cols)); }
    } else {
      pg.line(x1, y1, cx, cy - gap); pg.line(cx, cy + gap, x2, y2);
      if (g.glow > 0.5) { 
        float p = (frameCount * 0.08) % 1.0; 
        float sy = lerp(y1, y2, p); 
        pg.strokeWeight(isLet ? 6 : 4); 
        pg.stroke(0, 0, 255, 200 * g.glow); 
        pg.line(x1, sy - 5, x1, sy + 5); 
      }
      if (gap > 1.0) { pg.noStroke(); pg.fill(0, 180, 120, 190); pg.rectMode(CENTER); pg.rect(cx, cy, 11 * (12.0/cols), 4 * (12.0/cols)); }
    }
  }

  void drawScene(PGraphics pg) {
    if (analyzer.isBeat) triggerBeatPulse(analyzer.bass, analyzer.high);
    if (config.logicalFrameCount % 60 == 0 && random(1) < 0.8) toggleRandomGate();
    refreshFlowState(); updateVisualState();
    pg.background(4, 10, 16);
    pg.colorMode(HSB, 255);
    
    float padX = pg.width * 0.05; float padY = pg.height * 0.14;
    float stepX = (pg.width - padX * 2.0) / (cols - 1); float stepY = (pg.height - padY * 2.0) / (rows - 1);
    pg.noStroke(); pg.fill(6, 25, 28, 190); pg.rectMode(CORNER); pg.rect(padX - 20, padY - 20, stepX * (cols-1) + 40, stepY * (rows-1) + 40, 24);
    
    drawBlockUnderlays(pg, padX, padY, stepX, stepY);
    
    for (int x = 0; x < cols - 1; x++) for (int y = 0; y < rows; y++) drawGate(pg, rightGates[x][y], padX, padY, stepX, stepY);
    for (int x = 0; x < cols; x++) for (int y = 0; y < rows - 1; y++) drawGate(pg, downGates[x][y], padX, padY, stepX, stepY);
    drawGridNodes(pg, padX, padY, stepX, stepY);
    sceneHUD(pg, "Circuit Maze: \"" + config.CIRCUIT_TEXT + "\"", new String[]{
      "Beat toggles random gates   Grid: " + cols + "x" + rows,
      "Complete path: " + (hasCompletePath ? "YES \u2014 lamp lit" : "NO"),
      debugOverrideOpen ? "[FORCE ON OVERRIDE ACTIVE]" : "A rebuild  Y force-open toggle"
    });
  }

  void onEnter() { buildCircuit(); }
  void onExit() {}
  void applyController(Controller c) { 
    if (c.aJustPressed) buildCircuit(); 
    if (c.yJustPressed) debugOverrideOpen = !debugOverrideOpen;
  }
  void handleKey(char k) { 
    if (k == 'r' || k == 'R') buildCircuit(); 
    if (k == 'f' || k == 'F') debugOverrideOpen = !debugOverrideOpen;
    if (k == ' ') triggerBeatPulse(analyzer.bass, analyzer.high);
  }

  String[] getCodeLines() { 
    return new String[] { 
      "=== Dynamic Circuit Maze ===", 
      "Text: " + config.CIRCUIT_TEXT,
      "R: Regenerate Maze",
      "F: Force ON (Debug)",
      "SPACE: Force Pulse"
    }; 
  }

  ControllerLayout[] getControllerLayout() { 
    return new ControllerLayout[] { 
      new ControllerLayout("A", "Regenerate circuit"),
      new ControllerLayout("X", "Manual pulse"),
      new ControllerLayout("Y", "Toggle Force ON")
    }; 
  }
}
