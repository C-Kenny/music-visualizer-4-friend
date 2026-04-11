import java.util.HashSet;

/**
 * MazePuzzleScene — Overhauled 3D (Grid-Locked)
 * 
 * A 3D geometry experience featuring a rolling sphere that shifts gravity 
 * when crossing edges of floating cube platforms.
 * 
 * Mechanics:
 *   Grid-locked: Moves exactly one block at a time.
 *   Snapping: Ball is always centered on paths.
 * 
 * Controls:
 *   L-Stick ↕: Move forward/back
 *   L-Stick ↔: Turn 90°
 *   R-Stick: Orbit Camera
 */
class MazePuzzleScene implements IScene {

  // ── Level Logic ──────────────────────────────────────────────────────────
  HashSet<String> blocks;     
  final float BLOCK_SIZE = 100;
  
  // ── Player State ─────────────────────────────────────────────────────────
  PVector pos;           // Current discrete position (in grid-space)
  PVector up;            // Current gravity UP vector
  PVector forward;       // Current forward heading
  float ballRoll = 0;
  float ballSpin = 0;
  
  // ── Animation State ──────────────────────────────────────────────────────
  PVector animStartPos;
  PVector animEndPos;
  float moveTimer = 1.0; // 0..1, 1.0 = stationary
  
  PVector animStartFwd;
  PVector animEndFwd;
  float turnTimer = 1.0; // 0..1, 1.0 = stationary
  
  // Audio physics
  float jumpY = 0;
  float jumpVel = 0;
  final float GRAVITY = 0.015;
  
  // ── Camera State ─────────────────────────────────────────────────────────
  float camAzim = 0;     // Orbit azimuth (offset from forward)
  float camElev = 0.4;   // Orbit elevation
  float camDist = 600;
  
  // ── Transition State (Gravity Shift) ──────────────────────────────────────
  PVector oldUp, targetUp;
  PVector oldForward, targetForward;
  float transitionFrac = 1.0; 
  
  // ── Visuals ──────────────────────────────────────────────────────────────
  color themeHue;
  float pulse = 0;
  
  MazePuzzleScene() {
    blocks = new HashSet<String>();
    setupLevel();
    resetPlayer();
  }

  void setupLevel() {
    blocks.clear();
    // Start platform
    for (int x = -2; x <= 2; x++) {
      for (int z = -2; z <= 2; z++) {
        addBlock(x, 0, z);
      }
    }
    // Pillars
    addBlock(3, 0, 0);
    addBlock(3, 1, 0);
    addBlock(3, 2, 0);
    addBlock(3, 2, 1);
    addBlock(3, 2, 2);
    
    addBlock(0, -3, 0);
    addBlock(1, -3, 0);
    addBlock(0, -3, 1);
    
    blocks.remove("0,0,0");
  }
  
  void addBlock(int x, int y, int z) {
    blocks.add(x + "," + y + "," + z);
  }
  
  boolean hasBlock(int x, int y, int z) {
    return blocks.contains(x + "," + y + "," + z);
  }

  void resetPlayer() {
    pos = new PVector(1, 1, 0); 
    up = new PVector(0, 1, 0);
    forward = new PVector(0, 0, 1);
    
    animStartPos = pos.copy();
    animEndPos = pos.copy();
    animStartFwd = forward.copy();
    animEndFwd = forward.copy();
    
    oldUp = up.copy();
    targetUp = up.copy();
    oldForward = forward.copy();
    targetForward = forward.copy();
    transitionFrac = 1.0;
  }

  void onEnter() {
    themeHue = color(40, 200, 255);
  }

  void onExit() {}

  void drawScene(PGraphics pg) {
    pg.beginDraw();
    pg.background(0);
    pg.colorMode(HSB, 360, 255, 255);
    
    // ── Update Logic ───────────────────────────────────────────────────────
    updateAudioPhysics();
    updateMovement();
    updateTransition();
    
    // ── Camera ─────────────────────────────────────────────────────────────
    setupCamera(pg);
    
    // ── Lighting ───────────────────────────────────────────────────────────
    pg.ambientLight(100, 50, 80);
    pg.directionalLight(0, 0, 255, 1, 1, -1);
    
    pulse = lerp(pulse, analyzer.isBeat ? 1.0 : 0.0, 0.2);
    
    // ── Render ─────────────────────────────────────────────────────────────
    for (String key : blocks) {
      String[] parts = key.split(",");
      drawBlock(pg, int(parts[0]), int(parts[1]), int(parts[2]));
    }
    drawBall(pg);
    
    pg.endDraw();
  }

  void updateAudioPhysics() {
    if (analyzer.bass > 0.8 && jumpY == 0) {
      jumpVel = 0.2 + analyzer.bass * 0.1;
    }
    if (jumpY > 0 || jumpVel != 0) {
      jumpY += jumpVel;
      jumpVel -= GRAVITY;
      if (jumpY <= 0) {
        jumpY = 0;
        jumpVel = 0;
      }
    }
    ballSpin += analyzer.mid * 0.2;
  }

  void updateMovement() {
    if (moveTimer < 1.0) {
      moveTimer += 0.08;
      if (moveTimer >= 1.0) {
        moveTimer = 1.0;
        pos = animEndPos.copy();
      }
    }
    if (turnTimer < 1.0) {
      turnTimer += 0.12;
      if (turnTimer >= 1.0) {
        turnTimer = 1.0;
        forward = animEndFwd.copy();
      }
    }
  }

  void updateTransition() {
    if (transitionFrac < 1.0) {
      transitionFrac += 0.06;
      if (transitionFrac > 1.0) transitionFrac = 1.0;
    }
  }

  void setupCamera(PGraphics pg) {
    PVector currentUp = PVector.lerp(oldUp, targetUp, transitionFrac);
    currentUp.normalize();
    
    PVector currentFwd = PVector.lerp(oldForward, targetForward, transitionFrac);
    currentFwd.normalize();
    
    // Interpolate visual forward/pos if animating
    PVector visualFwd = PVector.lerp(animStartFwd, animEndFwd, transitionFrac < 1.0 ? 1.0 : turnTimer);
    visualFwd.normalize();
    PVector visualPos = PVector.lerp(animStartPos, animEndPos, transitionFrac < 1.0 ? 1.0 : moveTimer);

    PVector right = visualFwd.cross(currentUp).normalize();
    PVector rotatedFwd = PVector.add(PVector.mult(visualFwd, cos(camAzim)), PVector.mult(right, sin(camAzim)));
    
    PVector ballWorldPos = PVector.mult(visualPos, BLOCK_SIZE);
    ballWorldPos.add(PVector.mult(currentUp, jumpY * BLOCK_SIZE));
    
    PVector camOffset = PVector.add(PVector.mult(rotatedFwd, -camDist * cos(camElev)), PVector.mult(currentUp, camDist * sin(camElev)));
    PVector camPos = PVector.add(ballWorldPos, camOffset);
    
    pg.camera(camPos.x, camPos.y, camPos.z, ballWorldPos.x, ballWorldPos.y, ballWorldPos.z, currentUp.x, currentUp.y, currentUp.z);
    pg.perspective(PI/3.0, (float)pg.width/pg.height, 10, 10000);
  }

  void drawBlock(PGraphics pg, int x, int y, int z) {
    pg.pushMatrix();
    pg.translate(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE);
    float glow = pulse * 40;
    pg.stroke(200, 150, 255, 100);
    pg.noFill();
    pg.box(BLOCK_SIZE * 0.98); 
    pg.fill(200, 100, 100 + glow, 150);
    pg.noStroke();
    pg.box(BLOCK_SIZE * 0.90); 
    pg.popMatrix();
  }

  void drawBall(PGraphics pg) {
    PVector visualPos = PVector.lerp(animStartPos, animEndPos, moveTimer);
    PVector visualFwd = PVector.lerp(animStartFwd, animEndFwd, turnTimer);
    visualFwd.normalize();
    
    pg.pushMatrix();
    pg.translate(visualPos.x * BLOCK_SIZE, visualPos.y * BLOCK_SIZE, visualPos.z * BLOCK_SIZE);
    pg.translate(up.x * jumpY * BLOCK_SIZE, up.y * jumpY * BLOCK_SIZE, up.z * jumpY * BLOCK_SIZE);
    
    PVector yAxis = up;
    PVector zAxis = visualFwd;
    PVector xAxis = yAxis.cross(zAxis);
    pg.applyMatrix(xAxis.x, yAxis.x, zAxis.x, 0, xAxis.y, yAxis.y, zAxis.y, 0, xAxis.z, yAxis.z, zAxis.z, 0, 0, 0, 0, 1);
                   
    pg.rotateX(ballRoll + (moveTimer * PI));
    pg.rotateY(ballSpin);
    
    pg.fill(40, 255, 255);
    pg.noStroke();
    pg.sphere(35);
    pg.fill(0, 255, 255);
    pg.box(10, 75, 10);
    pg.rotateZ(HALF_PI);
    pg.box(10, 75, 10);
    pg.popMatrix();
  }

  void applyController(Controller c) {
    if (moveTimer < 1.0 || turnTimer < 1.0 || transitionFrac < 1.0) return; 
    
    if (c.isConnected()) {
      float dy = -map(c.ly, 0, height, -1, 1);
      float dx = map(c.lx, 0, width, -1, 1);
      
      if (dy > 0.5) tryMove(1);
      else if (dy < -0.5) tryMove(-1);
      else if (dx > 0.5) tryTurn(1);
      else if (dx < -0.5) tryTurn(-1);
      
      float ry = -map(c.ry, 0, height, -1, 1);
      float rx = map(c.rx, 0, width, -1, 1);
      camAzim += rx * 0.05;
      camElev = constrain(camElev + ry * 0.04, 0.1, 1.4);
      
      if (c.aJustPressed) jumpVel = 0.3;
    }
  }

  void tryMove(int dir) {
    PVector localMove = PVector.mult(forward, dir);
    PVector nextPos = PVector.add(pos, localMove);
    
    int bx = round(nextPos.x - up.x);
    int by = round(nextPos.y - up.y);
    int bz = round(nextPos.z - up.z);
    
    if (hasBlock(bx, by, bz)) {
      animStartPos = pos.copy();
      animEndPos = nextPos.copy();
      moveTimer = 0;
    } else {
      // Wall / Edge
      int fx = round(nextPos.x + localMove.x/dir - up.x);
      int fy = round(nextPos.y + localMove.y/dir - up.y);
      int fz = round(nextPos.z + localMove.z/dir - up.z);
      
      if (hasBlock(fx, fy, fz)) {
         startGravityShift(PVector.mult(forward, -dir), up.copy());
      } else {
         startGravityShift(PVector.mult(forward, dir), PVector.mult(up, -1));
         animStartPos = pos.copy();
         animEndPos = new PVector(round(nextPos.x), round(nextPos.y), round(nextPos.z));
         moveTimer = 0;
      }
    }
  }

  void tryTurn(int dir) {
    animStartFwd = forward.copy();
    PVector right = forward.cross(up);
    animEndFwd = PVector.add(PVector.mult(forward, 0), PVector.mult(right, dir));
    animEndFwd.normalize(); // Should already be unit 90 deg
    turnTimer = 0;
  }

  void startGravityShift(PVector newUp, PVector newForward) {
    oldUp = up.copy();
    targetUp = newUp.copy();
    oldForward = forward.copy();
    targetForward = newForward.copy();
    up = targetUp;
    forward = targetForward;
    animStartFwd = forward.copy();
    animEndFwd = forward.copy();
    transitionFrac = 0.0;
    camAzim = 0;
  }

  void handleKey(char k) {
    if (moveTimer < 1.0 || turnTimer < 1.0 || transitionFrac < 1.0) return;
    if (k == 'w') tryMove(1);
    if (k == 's') tryMove(-1);
    if (k == 'a') tryTurn(-1);
    if (k == 'd') tryTurn(1);
    if (k == ' ') jumpVel = 0.3;
  }

  String[] getCodeLines() {
    return new String[] {
      "// Maze Puzzle (Grid Locked)",
      "Mode: Discrete Steps",
      "p: " + pos + " up: " + up,
      "R-Stick -> Orbit Cam"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("L-Stick Tap", "Move / Turn (Discrete)"),
      new ControllerLayout("R-Stick", "Orbit Camera"),
      new ControllerLayout("A Button", "Manual Jump")
    };
  }
}
