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

boolean isLetterNode(int x, int y) {
  // C (Columns 2-5, rows 1-6)
  if (x >= 2 && x <= 5 && y >= 1 && y <= 6) {
    if (x == 2) return true; // Left bar
    if (y == 1 || y == 6) return true; // Top/Bottom bars
  }
  // K (Columns 7-10, rows 1-6)
  if (x >= 7 && x <= 10 && y >= 1 && y <= 6) {
    if (x == 7) return true; // Left bar
    // diagonal from (10,1) to (8,3) and (8,4) to (10,6)
    if (x == 8 && (y == 3 || y == 4)) return true;
    if (x == 9 && (y == 2 || y == 5)) return true;
    if (x == 10 && (y == 1 || y == 6)) return true;
  }
  return false;
}

boolean isLetterGate(CircuitGate g) {
  return isLetterNode(g.x1, g.y1) && isLetterNode(g.x2, g.y2);
}

class CircuitMazeScene implements IScene {
  int cols = 12;
  int rows = 8;

  CircuitGate[][] rightGates;
  CircuitGate[][] downGates;
  boolean[][] reachable;

  boolean hasCompletePath = false;
  float lampGlow = 0.0;
  float beatFlash = 0.0;

  float openBias = 0.72;

  CircuitMazeScene() {
    buildCircuit();
  }

  void buildCircuit() {
    rightGates = new CircuitGate[cols - 1][rows];
    downGates = new CircuitGate[cols][rows - 1];
    reachable = new boolean[cols][rows];

    for (int x = 0; x < cols - 1; x++) {
      for (int y = 0; y < rows; y++) {
        boolean letter = isLetterNode(x, y) && isLetterNode(x+1, y);
        boolean exists = letter || (random(1) < 0.2); // Less random noise
        boolean gateOpen = random(1) < openBias;
        rightGates[x][y] = new CircuitGate(x, y, x + 1, y, exists, gateOpen);
      }
    }

    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows - 1; y++) {
        boolean letter = isLetterNode(x, y) && isLetterNode(x, y+1);
        boolean exists = letter || (random(1) < 0.15);
        boolean gateOpen = random(1) < openBias;
        downGates[x][y] = new CircuitGate(x, y, x, y + 1, exists, gateOpen);
      }
    }

    forceBackbonePath();
    refreshFlowState();
  }

  void forceBackbonePath() {
    int x = 0;
    int y = 0;

    while (x < cols - 1 || y < rows - 1) {
      boolean canMoveRight = x < cols - 1;
      boolean canMoveDown = y < rows - 1;

      if (canMoveRight && canMoveDown) {
        if (random(1) < 0.5) {
          CircuitGate g = rightGates[x][y];
          g.exists = true;
          g.isOpen = true;
          x++;
        } else {
          CircuitGate g = downGates[x][y];
          g.exists = true;
          g.isOpen = true;
          y++;
        }
      } else if (canMoveRight) {
        CircuitGate g = rightGates[x][y];
        g.exists = true;
        g.isOpen = true;
        x++;
      } else {
        CircuitGate g = downGates[x][y];
        g.exists = true;
        g.isOpen = true;
        y++;
      }
    }
  }

  void triggerBeatPulse(float bass, float high) {
    beatFlash = 1.0;

    int toggles = 4 + (int) map(constrain(bass, 0, 25), 0, 25, 0, 9);
    for (int i = 0; i < toggles; i++) {
      toggleRandomGate();
    }

    if (high > 7.0) {
      for (int i = 0; i < 2; i++) toggleRandomGate();
    }
  }

  void toggleRandomGate() {
    boolean chooseRight = random(1) < 0.5;
    if (chooseRight) {
      int x = (int) random(cols - 1);
      int y = (int) random(rows);
      CircuitGate g = rightGates[x][y];
      if (g.exists) g.isOpen = !g.isOpen;
    } else {
      int x = (int) random(cols);
      int y = (int) random(rows - 1);
      CircuitGate g = downGates[x][y];
      if (g.exists) g.isOpen = !g.isOpen;
    }
  }

  void markReachable() {
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        reachable[x][y] = false;
      }
    }

    int capacity = cols * rows;
    int[] qx = new int[capacity];
    int[] qy = new int[capacity];
    int head = 0;
    int tail = 0;

    reachable[0][0] = true;
    for (int y = 0; y < rows; y++) {
      reachable[0][y] = true;
      qx[tail] = 0;
      qy[tail] = y;
      tail++;
    }

    while (head < tail) {
      int cx = qx[head];
      int cy = qy[head];
      head++;

      if (cx > 0) {
        CircuitGate g = rightGates[cx - 1][cy];
        if (g.exists && g.isOpen && !reachable[cx - 1][cy]) {
          reachable[cx - 1][cy] = true;
          qx[tail] = cx - 1;
          qy[tail] = cy;
          tail++;
        }
      }
      if (cx < cols - 1) {
        CircuitGate g = rightGates[cx][cy];
        if (g.exists && g.isOpen && !reachable[cx + 1][cy]) {
          reachable[cx + 1][cy] = true;
          qx[tail] = cx + 1;
          qy[tail] = cy;
          tail++;
        }
      }
      if (cy > 0) {
        CircuitGate g = downGates[cx][cy - 1];
        if (g.exists && g.isOpen && !reachable[cx][cy - 1]) {
          reachable[cx][cy - 1] = true;
          qx[tail] = cx;
          qy[tail] = cy - 1;
          tail++;
        }
      }
      if (cy < rows - 1) {
        CircuitGate g = downGates[cx][cy];
        if (g.exists && g.isOpen && !reachable[cx][cy + 1]) {
          reachable[cx][cy + 1] = true;
          qx[tail] = cx;
          qy[tail] = cy + 1;
          tail++;
        }
      }
    }
  }

  void refreshFlowState() {
    markReachable();
    hasCompletePath = reachable[cols - 1][rows - 1];
    if (hasCompletePath) lampGlow = 1.0;
  }

  float gateTargetGlow(CircuitGate g) {
    if (!g.exists) return 0.0;
    boolean e1 = reachable[g.x1][g.y1];
    boolean e2 = reachable[g.x2][g.y2];
    if (g.isOpen && e1 && e2) return 1.0;
    if (g.isOpen && (e1 || e2)) return 0.35;
    return 0.06;
  }

  void updateVisualState() {
    for (int x = 0; x < cols - 1; x++) {
      for (int y = 0; y < rows; y++) {
        CircuitGate g = rightGates[x][y];
        g.openVis = lerp(g.openVis, g.isOpen ? 1.0 : 0.0, 0.2);
        g.glow = lerp(g.glow, gateTargetGlow(g), 0.2);
      }
    }

    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows - 1; y++) {
        CircuitGate g = downGates[x][y];
        g.openVis = lerp(g.openVis, g.isOpen ? 1.0 : 0.0, 0.2);
        g.glow = lerp(g.glow, gateTargetGlow(g), 0.2);
      }
    }

    if (!hasCompletePath) {
      lampGlow *= 0.93;
    } else {
      lampGlow = min(1.0, lampGlow + 0.08);
    }

    beatFlash *= 0.84;
  }

  void drawGridNodes(PGraphics pg, float originX, float originY, float stepX, float stepY) {
    pg.noStroke();

    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        float px = originX + x * stepX;
        float py = originY + y * stepY;

        boolean energised = reachable[x][y];
        float r = energised ? 5.0 : 3.0;

        if (x == 0) {
          pg.fill(90, 255, 255, 220); // Bright Battery
          pg.ellipse(px, py, 14, 14);
          pg.fill(40, 255, 255, 180 + beatFlash * 70);
          pg.ellipse(px, py, 8 + beatFlash * 8, 8 + beatFlash * 8);
        }

        if (x == cols - 1 && y == rows - 1) {
          float lamp = constrain(lampGlow * 255.0, 0, 255);
          pg.fill(70, 255, 220, 80 + lamp);
          pg.ellipse(px, py, 32 + lampGlow * 12.0, 32 + lampGlow * 12.0);
          pg.fill(120, 255, 240, 130 + lamp * 0.45);
          pg.ellipse(px, py, 15 + lampGlow * 5.0, 15 + lampGlow * 5.0);
        }

        if (energised) {
          if (isLetterNode(x, y)) pg.fill(50, 255, 255, 220); // Gold-ish Neon
          else pg.fill(90, 255, 240, 200);
        } else {
          pg.fill(55, 80, 90, 180);
        }
        pg.ellipse(px, py, r * 2, r * 2);
      }
    }
  }

  void drawGate(PGraphics pg, CircuitGate g, float originX, float originY, float stepX, float stepY) {
    if (!g.exists) return;

    float x1 = originX + g.x1 * stepX;
    float y1 = originY + g.y1 * stepY;
    float x2 = originX + g.x2 * stepX;
    float y2 = originY + g.y2 * stepY;

    float cx = (x1 + x2) * 0.5;
    float cy = (y1 + y2) * 0.5;

    float bright = 80 + g.glow * 175 + beatFlash * 40;
    float alpha = 70 + g.glow * 150;

    pg.strokeWeight(2.4 + g.glow * 1.7);
    if (isLetterGate(g) && g.glow > 0.3) {
      pg.stroke(50, 255, bright, alpha); // Golden highlight
    } else {
      pg.stroke(90, 255, bright, alpha);
    }

    float gap = 12.0 * (1.0 - g.openVis);

    if (abs(x2 - x1) > abs(y2 - y1)) {
      // Horizontal gate wire.
      pg.line(x1, y1, cx - gap, cy);
      pg.line(cx + gap, cy, x2, y2);
      
      // Electric Spark
      if (g.glow > 0.5) {
        float p = (frameCount * 0.1) % 1.0;
        float sx = lerp(x1, x2, p);
        pg.strokeWeight(4);
        pg.stroke(0, 0, 255, 200 * g.glow); // White-hot
        pg.line(sx - 5, y1, sx + 5, y1);
      }
      
      if (gap > 1.0) {
        pg.noStroke();
        pg.fill(255, 90, 90, 190);
        pg.rectMode(CENTER);
        pg.rect(cx, cy, 4, 11);
      }
    } else {
      // Vertical gate wire.
      pg.line(x1, y1, cx, cy - gap);
      pg.line(cx, cy + gap, x2, y2);
      
      // Electric Spark
      if (g.glow > 0.5) {
        float p = (frameCount * 0.1) % 1.0;
        float sy = lerp(y1, y2, p);
        pg.strokeWeight(4);
        pg.stroke(0, 0, 255, 200 * g.glow);
        pg.line(x1, sy - 5, x1, sy + 5);
      }
      
      if (gap > 1.0) {
        pg.noStroke();
        pg.fill(255, 90, 90, 190);
        pg.rectMode(CENTER);
        pg.rect(cx, cy, 11, 4);
      }
    }
  }

  void drawScene(PGraphics pg) {
    float bass = analyzer.bass;
    float high = analyzer.high;

    if (analyzer.isBeat) {
      triggerBeatPulse(bass, high);
    }

    if (config.logicalFrameCount % 60 == 0) {
      if (random(1) < 0.8) toggleRandomGate();
    }

    refreshFlowState();
    updateVisualState();

    pg.background(4, 10, 16);

    float padX = pg.width * 0.1;
    float padY = pg.height * 0.14;
    float stepX = (pg.width - padX * 2.0) / (cols - 1);
    float stepY = (pg.height - padY * 2.0) / (rows - 1);

    // Soft board glow under the maze.
    pg.noStroke();
    pg.fill(6, 25, 28, 190);
    pg.rectMode(CORNER);
    pg.rect(padX - 30, padY - 30, stepX * (cols - 1) + 60, stepY * (rows - 1) + 60, 24);

    for (int x = 0; x < cols - 1; x++) {
      for (int y = 0; y < rows; y++) {
        drawGate(pg, rightGates[x][y], padX, padY, stepX, stepY);
      }
    }

    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows - 1; y++) {
        drawGate(pg, downGates[x][y], padX, padY, stepX, stepY);
      }
    }

    drawGridNodes(pg, padX, padY, stepX, stepY);

    pg.pushStyle();
    float ts = 11 * uiScale();
    float lh = ts * 1.35;
    float boxW = 360 * uiScale();
    float boxH = lh * 4.2;

    pg.fill(0, 165);
    pg.noStroke();
    pg.rectMode(CORNER);
    pg.rect(10, 10, boxW, boxH, 8);

    pg.fill(100, 255, 230);
    pg.textSize(ts);
    pg.textAlign(LEFT, TOP);
    pg.text("Circuit Maze", 16, 14);
    pg.fill(200, 255, 230);
    pg.text("Beat toggles random gates", 16, 14 + lh);
    pg.text("Complete path: " + (hasCompletePath ? "YES - lamp lit" : "NO"), 16, 14 + lh * 2);
    pg.text("Open bias: " + nf(openBias, 1, 2) + "  ([ / ] keys)", 16, 14 + lh * 3);
    pg.popStyle();
  }

  void onEnter() {
    buildCircuit();
  }

  void onExit() {
  }

  void applyController(Controller c) {
    if (c.aJustPressed) buildCircuit();
    if (c.xJustPressed) triggerBeatPulse(analyzer.bass, analyzer.high);

    // LT opens more gates on rebuilds/drift, RT closes more.
    float t = constrain(c.lt - c.rt, -1, 1);
    openBias = constrain(0.58 + t * 0.22, 0.25, 0.88);
  }

  void handleKey(char k) {
    if (k == 'r' || k == 'R') buildCircuit();
    if (k == '[') openBias = constrain(openBias - 0.03, 0.25, 0.88);
    if (k == ']') openBias = constrain(openBias + 0.03, 0.25, 0.88);
    if (k == ' ') triggerBeatPulse(analyzer.bass, analyzer.high);
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Circuit Maze Controls ===",
      "R                 regenerate maze",
      "[ / ]             lower / raise open-gate bias",
      "SPACE             force gate pulse",
      "A (controller)    regenerate maze",
      "X (controller)    force pulse",
      "LT / RT           bias more open / more closed",
      "",
      "=== Audio Mapping ===",
      "Beat              toggles random gates",
      "Bass              stronger pulse flash",
      "When start->end path exists,",
      "the end neon lamp lights up."
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("A", "Regenerate circuit maze"),
      new ControllerLayout("X", "Manual gate pulse"),
      new ControllerLayout("LT / RT", "Open/close bias")
    };
  }
}
