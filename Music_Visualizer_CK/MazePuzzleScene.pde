import java.util.HashSet;

/**
 * MazePuzzleScene — Overhauled 3D
 * 
 * A 3D geometry experience featuring a rolling sphere that shifts gravity 
 * when crossing edges of floating cube platforms.
 * 
 * Controls:
 *   L-Stick: Move and Turn
 *   R-Stick: Orbit Camera
 *   C-Key: Calibrate Controller
 */
class MazePuzzleScene implements IScene {

  // ── Level Logic ──────────────────────────────────────────────────────────
  HashSet<String> blocks;     // Keys as "x,y,z"
  final float BLOCK_SIZE = 100;
  
  // ── Player State ─────────────────────────────────────────────────────────
  PVector pos;           // Position in grid-space (center of cube-surface)
  PVector up;            // Current gravity UP vector
  PVector forward;       // Current forward heading
  float ballRoll = 0;
  float ballSpin = 0;
  
  // Audio physics
  float jumpY = 0;
  float jumpVel = 0;
  final float GRAVITY = 0.015;
  
  // ── Camera State ─────────────────────────────────────────────────────────
  float camAzim = 0;     // Manual orbit azimuth (offset from forward)
  float camElev = 0.4;   // Manual orbit elevation
  float camDist = 600;
  
  // ── Transition State ─────────────────────────────────────────────────────
  PVector oldUp, targetUp;
  PVector oldForward, targetForward;
  float transitionFrac = 1.0; // 0..1, 1.0 = stable
  
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
    // Create a 3x3 platform
    for (int x = -2; x <= 2; x++) {
      for (int z = -2; z <= 2; z++) {
        addBlock(x, 0, z);
      }
    }
    // Vertical pillars (wrapping opportunities)
    addBlock(3, 0, 0);
    addBlock(3, 1, 0);
    addBlock(3, 2, 0);
    addBlock(3, 2, 1);
    addBlock(3, 2, 2);
    
    // Remote puzzle structure
    addBlock(0, -3, 0);
    addBlock(1, -3, 0);
    addBlock(0, -3, 1);
    
    // Add a hole in the middle for gravity testing
    blocks.remove("0,0,0");
  }
  
  void addBlock(int x, int y, int z) {
    blocks.add(x + "," + y + "," + z);
  }
  
  boolean hasBlock(int x, int y, int z) {
    return blocks.contains(x + "," + y + "," + z);
  }

  void resetPlayer() {
    pos = new PVector(1, 1, 0); // start atop a block
    up = new PVector(0, 1, 0);
    forward = new PVector(0, 0, 1);
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
    
    // ── Audio Physics ──────────────────────────────────────────────────────
    updateAudioPhysics();
    
    // ── Update Logic ───────────────────────────────────────────────────────
    updateTransition();
    
    // ── Camera ─────────────────────────────────────────────────────────────
    setupCamera(pg);
    
    // ── Lighting / Effects ─────────────────────────────────────────────────
    pg.ambientLight(100, 50, 80);
    pg.directionalLight(0, 0, 255, 1, 1, -1);
    
    pulse = lerp(pulse, analyzer.isBeat ? 1.0 : 0.0, 0.2);
    
    // ── Draw Level ─────────────────────────────────────────────────────────
    for (String key : blocks) {
      String[] parts = key.split(",");
      int x = int(parts[0]);
      int y = int(parts[1]);
      int z = int(parts[2]);
      drawBlock(pg, x, y, z);
    }
    
    // ── Draw Ball ──────────────────────────────────────────────────────────
    drawBall(pg);
    
    pg.endDraw();
  }

  void updateAudioPhysics() {
    // 1. Jump on Bass
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
    
    // 2. Extra spin on Mids
    ballSpin += analyzer.mid * 0.2;
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
    
    // We want the primary orbit to be around 'currentUp' and 'currentFwd'
    PVector right = currentFwd.cross(currentUp).normalize();
    
    // Apply user orbit offset (camAzim/camElev)
    // Rotated forward vector
    PVector rotatedFwd = currentFwd.copy();
    // Azimuth rotation around currentUp
    float angle = camAzim;
    rotatedFwd = PVector.add(PVector.mult(currentFwd, cos(angle)), PVector.mult(right, sin(angle)));
    
    PVector camOffset = PVector.add(PVector.mult(rotatedFwd, -camDist * cos(camElev)), PVector.mult(currentUp, camDist * sin(camElev)));
    PVector ballWorldPos = PVector.mult(pos, BLOCK_SIZE);
    ballWorldPos.add(PVector.mult(up, jumpY * BLOCK_SIZE)); // camera follows the jump
    
    PVector camPos = PVector.add(ballWorldPos, camOffset);
    PVector lookAt = ballWorldPos;
    
    pg.camera(camPos.x, camPos.y, camPos.z, 
              lookAt.x, lookAt.y, lookAt.z, 
              currentUp.x, currentUp.y, currentUp.z);
    
    pg.perspective(PI/3.0, (float)pg.width/pg.height, 10, 10000);
  }

  void drawBlock(PGraphics pg, int x, int y, int z) {
    pg.pushMatrix();
    pg.translate(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE);
    
    float glow = pulse * 40;
    pg.stroke(200, 150, 255, 100);
    pg.noFill();
    pg.box(BLOCK_SIZE * 0.98); // Wireframe look
    
    pg.fill(200, 100, 100 + glow, 150);
    pg.noStroke();
    pg.box(BLOCK_SIZE * 0.90); // Solid core
    
    pg.popMatrix();
  }

  void drawBall(PGraphics pg) {
    pg.pushMatrix();
    pg.translate(pos.x * BLOCK_SIZE, pos.y * BLOCK_SIZE, pos.z * BLOCK_SIZE);
    
    // Jump offset locally
    pg.translate(up.x * jumpY * BLOCK_SIZE, up.y * jumpY * BLOCK_SIZE, up.z * jumpY * BLOCK_SIZE);
    
    // Orientation matrix
    PVector yAxis = up;
    PVector zAxis = forward;
    PVector xAxis = yAxis.cross(zAxis);
    
    pg.applyMatrix(xAxis.x, yAxis.x, zAxis.x, 0,
                   xAxis.y, yAxis.y, zAxis.y, 0,
                   xAxis.z, yAxis.z, zAxis.z, 0,
                   0,       0,       0,       1);
                   
    pg.rotateX(ballRoll);
    pg.rotateY(ballSpin);
    
    pg.fill(40, 255, 255);
    pg.noStroke();
    pg.sphere(35);
    
    // Inner structure (spinning)
    pg.fill(0, 255, 255);
    pg.box(10, 75, 10);
    pg.rotateZ(HALF_PI);
    pg.box(10, 75, 10);
    
    pg.popMatrix();
  }

  void applyController(Controller c) {
    if (transitionFrac < 1.0) return; 
    
    if (c.isConnected()) {
      // Left Stick: Move & Turn
      float dy = -map(c.ly, 0, height, -1, 1);
      float dx = map(c.lx, 0, width, -1, 1);
      if (abs(dy) > 0.2) move(dy * 0.1);
      if (abs(dx) > 0.2) rotateHeading(dx * 0.08);
      
      // Right Stick: Camera Orbit
      float ry = -map(c.ry, 0, height, -1, 1);
      float rx = map(c.rx, 0, width, -1, 1);
      camAzim += rx * 0.05;
      camElev = constrain(camElev + ry * 0.04, 0.1, 1.4);
      
      if (c.aJustPressed) { jumpVel = 0.3; } // manual jump
    }
  }

  void move(float step) {
    PVector nextPos = PVector.add(pos, PVector.mult(forward, step));
    
    // Detect edge/wall
    int bx = round(nextPos.x - up.x);
    int by = round(nextPos.y - up.y);
    int bz = round(nextPos.z - up.z);
    
    if (hasBlock(bx, by, bz)) {
      pos = nextPos;
      ballRoll += step * 2.5;
    } else {
      // Wall in front?
      int fx = round(nextPos.x + forward.x - up.x);
      int fy = round(nextPos.y + forward.y - up.y);
      int fz = round(nextPos.z + forward.z - up.z);
      
      if (hasBlock(fx, fy, fz)) {
         // Snap to corner and walk UP
         pos = new PVector(round(pos.x), round(pos.y), round(pos.z));
         startGravityShift(PVector.mult(forward, -1), up.copy());
      } else {
         // Walk OVER edge
         pos = new PVector(round(nextPos.x), round(nextPos.y), round(nextPos.z));
         startGravityShift(forward.copy(), PVector.mult(up, -1));
      }
    }
  }

  void rotateHeading(float angle) {
    PVector right = forward.cross(up);
    forward.mult(cos(angle));
    forward.add(PVector.mult(right, sin(angle)));
    forward.normalize();
    // Keep camera following reasonably behind
    camAzim *= 0.9; 
  }

  void startGravityShift(PVector newUp, PVector newForward) {
    oldUp = up.copy();
    targetUp = newUp.copy();
    oldForward = forward.copy();
    targetForward = newForward.copy();
    
    up = targetUp;
    forward = targetForward;
    transitionFrac = 0.0;
    
    // Lock camera snap to back
    camAzim = 0;
  }

  void handleKey(char k) {
    if (k == 'w') move(0.25);
    if (k == 's') move(-0.25);
    if (k == 'a') rotateHeading(-0.15);
    if (k == 'd') rotateHeading(0.15);
    if (k == ' ') jumpVel = 0.3;
  }

  String[] getCodeLines() {
    return new String[] {
      "// Maze Puzzle",
      "p: " + pos + " up: " + up,
      "Bass -> Jump | Mid -> Spin",
      "R-Stick -> Orbit Cam"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("L-Stick", "Move / Turn Ball"),
      new ControllerLayout("R-Stick", "Orbit Camera"),
      new ControllerLayout("A Button", "Manual Jump"),
      new ControllerLayout("Music", "Auto Jump & Spin")
    };
  }
}
