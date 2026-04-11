import java.util.HashSet;

/**
 * MazePuzzleScene — Kula World Mechanics Restoration
 * 
 * Features:
 *   - Rigid Grid Movement (Discrete Taps)
 *   - Forward Jumping (Jump over 1-block gaps)
 *   - Intelligent Edge Wrapping (Gravity shifts to stay on blocks)
 *   - Falling (Reset on void)
 *   - Hazards (Spikes)
 */
enum MazeState { STATIONARY, MOVING, TURNING, JUMPING, FALLING }

/**
 * MazePuzzleScene — Kula World Mechanics Restoration
 * 
 * Features:
 *   - Rigid Grid Movement (Discrete Taps)
 *   - Forward Jumping (Jump over 1-block gaps)
 *   - Intelligent Edge Wrapping (Gravity shifts to stay on blocks)
 *   - Falling (Reset on void)
 *   - Hazards (Spikes)
 */
class MazePuzzleScene implements IScene {

  // ── Level Logic ──────────────────────────────────────────────────────────
  HashSet<String> blocks;     // "x,y,z"
  HashSet<String> spikes;     // "x,y,z"
  final float BLOCK_SIZE = 100;
  
  // ── State ───────────────────────────────────────────────────────────────
  MazeState state = MazeState.STATIONARY;
  
  PVector pos;           // Current discrete grid position (center of tile)
  PVector up;            // Current gravity UP
  PVector forward;       // Current forward heading
  
  PVector animStartPos, animEndPos;
  PVector animStartFwd, animEndFwd;
  float animTimer = 1.0;
  
  float ballRoll = 0;
  float ballSpin = 0;
  
  // Audio physics
  float jumpY = 0;
  float jumpVel = 0;
  final float GRAVITY_CONST = 0.015;
  
  // ── Camera ─────────────────────────────────────────────────────────────
  float camAzim = 0;     
  float camElev = 0.4;   
  float camDist = 600;
  
  PVector oldUp, targetUp;
  PVector oldForward, targetForward;
  float transitionFrac = 1.0; 
  
  float pulse = 0;
  
  MazePuzzleScene() {
    blocks = new HashSet<String>();
    spikes = new HashSet<String>();
    setupLevel();
    resetPlayer();
  }

  void setupLevel() {
    blocks.clear();
    spikes.clear();
    
    // Core Platform
    for (int x = -2; x <= 2; x++) {
      for (int z = -2; z <= 2; z++) {
        addBlock(x, 0, z);
      }
    }
    
    // A jump puzzle
    addBlock(0, 0, 4);
    addBlock(0, 0, 5);
    
    // A vertical pillar with spikes
    addBlock(3, 0, 0);
    addBlock(3, 1, 0);
    addBlock(3, 2, 0);
    spikes.add("3,3,0"); // Spike on top of pillar
    
    // Another island
    addBlock(-4, 0, 0);
    addBlock(-5, 0, 0);
    
    blocks.remove("0,0,0");
  }
  
  void addBlock(int x, int y, int z) { blocks.add(x + "," + y + "," + z); }
  boolean hasBlock(int x, int y, int z) { return blocks.contains(x + "," + y + "," + z); }
  boolean hasSpike(int x, int y, int z) { return spikes.contains(x + "," + y + "," + z); }

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
    
    state = MazeState.STATIONARY;
    animTimer = 1.0;
    transitionFrac = 1.0;
    jumpY = 0;
    jumpVel = 0;
    ballRoll = 0;
  }

  void onEnter() { }
  void onExit() {}

  void drawScene(PGraphics pg) {
    pg.beginDraw();
    drawBackground(pg);
    pg.colorMode(HSB, 360, 255, 255);
    
    updateLogic();
    setupCamera(pg);
    
    pg.ambientLight(100, 50, 80);
    pg.directionalLight(0, 0, 255, 1, 1, -1);
    pulse = lerp(pulse, analyzer.isBeat ? 1.0 : 0.0, 0.2);
    
    // Level
    for (String key : blocks) {
      String[] p = key.split(",");
      drawBlock(pg, int(p[0]), int(p[1]), int(p[2]), false);
    }
    for (String key : spikes) {
      String[] p = key.split(",");
      drawBlock(pg, int(p[0]), int(p[1]), int(p[2]), true);
    }
    
    drawBall(pg);
    drawRetroHUD(pg);
    
    pg.endDraw();
  }

  void drawBackground(PGraphics pg) {
    pg.hint(PConstants.DISABLE_DEPTH_TEST);
    pg.resetMatrix();
    pg.noStroke();
    
    float t = u_time * 0.5;
    float h1 = (t * 20) % 360;
    float h2 = (h1 + 60 + analyzer.high * 100) % 360;
    
    pg.beginShape(QUADS);
    pg.fill(h1, 255, 60); pg.vertex(0, 0);
    pg.fill(h1, 255, 40); pg.vertex(pg.width, 0);
    pg.fill(h2, 255, 30); pg.vertex(pg.width, pg.height);
    pg.fill(h2, 255, 50); pg.vertex(0, pg.height);
    pg.endShape();
    
    pg.hint(PConstants.ENABLE_DEPTH_TEST);
  }

  float u_time = 0;
  void updateAudioPhysics() {
    u_time += 0.016;
    ballSpin += analyzer.mid * 0.1;
  }

  void updateLogic() {
    updateAudioPhysics();
    
    // 2. Animation State Machine
    if (state != MazeState.STATIONARY) {
      float speed = (state == MazeState.JUMPING) ? 0.04 : 0.12;
      animTimer += speed;
      
      if (state == MazeState.MOVING) ballRoll += speed * PI;
      if (state == MazeState.JUMPING) jumpY = sin(animTimer * PI) * 0.5;

      if (animTimer >= 1.0) {
        completeAction();
      }
    }

    if (transitionFrac < 1.0) {
      transitionFrac += 0.08;
      if (transitionFrac > 1.0) transitionFrac = 1.0;
    }
    
    // 3. Hazard Check
    if (state == MazeState.STATIONARY) {
      int headX = round(pos.x);
      int headY = round(pos.y);
      int headZ = round(pos.z);
      if (hasSpike(headX, headY, headZ)) resetPlayer();
    }
    
    if (state == MazeState.FALLING) {
      pos.add(PVector.mult(up, jumpVel));
      jumpVel -= GRAVITY_CONST;
      if (pos.y < -20) resetPlayer();
    }
  }

  void completeAction() {
    pos = animEndPos.copy();
    forward = animEndFwd.copy();
    animTimer = 1.0;
    jumpY = 0;
    state = MazeState.STATIONARY;
    
    // Check for landing in void
    int bx = round(pos.x - up.x);
    int by = round(pos.y - up.y);
    int bz = round(pos.z - up.z);
    if (!hasBlock(bx, by, bz)) {
      state = MazeState.FALLING;
      jumpVel = 0;
    }
  }

  void setupCamera(PGraphics pg) {
    PVector curUp = PVector.lerp(oldUp, targetUp, transitionFrac).normalize();
    PVector curFwd = PVector.lerp(oldForward, targetForward, transitionFrac).normalize();
    
    PVector vPos = PVector.lerp(animStartPos, animEndPos, animTimer);
    PVector vFwd = PVector.lerp(animStartFwd, animEndFwd, animTimer).normalize();
    
    PVector right = vFwd.cross(curUp).normalize();
    PVector rotFwd = PVector.add(PVector.mult(vFwd, cos(camAzim)), PVector.mult(right, sin(camAzim)));
    
    PVector worldBall = PVector.mult(vPos, BLOCK_SIZE).add(PVector.mult(curUp, jumpY * BLOCK_SIZE));
    PVector camOff = PVector.add(PVector.mult(rotFwd, -camDist * cos(camElev)), PVector.mult(curUp, camDist * sin(camElev)));
    
    pg.camera(worldBall.x + camOff.x, worldBall.y + camOff.y, worldBall.z + camOff.z, 
              worldBall.x, worldBall.y, worldBall.z, 
              curUp.x, curUp.y, curUp.z);
    pg.perspective(PI/3.0, (float)pg.width/pg.height, 10, 10000);
  }

  void drawBlock(PGraphics pg, int x, int y, int z, boolean isSpike) {
    pg.pushMatrix();
    pg.translate(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE);
    
    float bassScale = 1.0 + (analyzer.bass * 0.15);
    float midHue = (analyzer.mid * 100 + 200) % 360;
    
    if (isSpike) {
      pg.fill(0, 255, 255);
      pg.stroke(0, 255, 255);
      pg.box(BLOCK_SIZE * 0.4 * bassScale);
      pg.translate(0, BLOCK_SIZE * 0.3, 0);
      pg.fill(0, 255, 200, 150);
      pg.box(BLOCK_SIZE * 0.2, BLOCK_SIZE * 0.6, BLOCK_SIZE * 0.2);
    } else {
      pg.stroke(midHue, 200, 255, 100 + pulse * 100); 
      pg.noFill(); 
      pg.box(BLOCK_SIZE * 0.98 * bassScale);
      
      pg.fill(midHue, 150, 100 + pulse * 100, 180); 
      pg.noStroke(); 
      pg.box(BLOCK_SIZE * 0.9 * bassScale);
    }
    pg.popMatrix();
  }

  void drawBall(PGraphics pg) {
    PVector vPos = PVector.lerp(animStartPos, animEndPos, animTimer);
    PVector vFwd = PVector.lerp(animStartFwd, animEndFwd, animTimer).normalize();
    
    pg.pushMatrix();
    pg.translate(vPos.x * BLOCK_SIZE, vPos.y * BLOCK_SIZE, vPos.z * BLOCK_SIZE);
    pg.translate(up.x * jumpY * BLOCK_SIZE, up.y * jumpY * BLOCK_SIZE, up.z * jumpY * BLOCK_SIZE);
    
    PVector yAxis = up;
    PVector zAxis = vFwd;
    PVector xAxis = yAxis.cross(zAxis);
    pg.applyMatrix(xAxis.x, yAxis.x, zAxis.x, 0, xAxis.y, yAxis.y, zAxis.y, 0, xAxis.z, yAxis.z, zAxis.z, 0, 0, 0, 0, 1);
                   
    pg.rotateX(ballRoll); 
    pg.rotateY(ballSpin);
    
    pg.noStroke();
    // Top Half (Red)
    pg.fill(0, 255, 255); 
    pg.sphere(35); 
    
    // Middle Band (Yellow)
    pg.fill(50, 255, 255);
    pg.pushMatrix();
    pg.scale(1.02);
    pg.box(71, 15, 71);
    pg.popMatrix();
    
    // Decor
    pg.fill(200, 255, 255);
    pg.box(10, 75, 10);
    pg.rotateZ(HALF_PI);
    pg.box(10, 75, 10);
    pg.popMatrix();
  }

  void drawRetroHUD(PGraphics pg) {
    pg.hint(PConstants.DISABLE_DEPTH_TEST);
    pg.resetMatrix();
    pg.pushStyle();
    
    float ts = 24 * uiScale();
    pg.textSize(ts);
    pg.textAlign(CENTER, BOTTOM);
    
    // "BONUS" text with double shadow for retro look
    String bonusText = "BONUS";
    float boff = 2 * uiScale();
    pg.fill(0, 255, 255); // Red-ish shadow
    pg.text(bonusText, pg.width/2 + boff, pg.height - 40*uiScale() + boff);
    pg.fill(60, 255, 255); // Yellow
    pg.text(bonusText, pg.width/2, pg.height - 40*uiScale());
    
    pg.textSize(ts * 0.7);
    pg.text("SC0RE: " + nf((int)(analyzer.bass*1000), 6), pg.width/2, pg.height - 10*uiScale());
    
    pg.popStyle();
    pg.hint(PConstants.ENABLE_DEPTH_TEST);
  }

  void applyController(Controller c) {
    if (state != MazeState.STATIONARY || transitionFrac < 1.0) return;
    
    float dy = -map(c.ly, 0, height, -1, 1);
    float dx = map(c.lx, 0, width, -1, 1);
    
    if (dy > 0.6) tryMove(1);
    else if (dy < -0.6) tryMove(-1);
    else if (dx > 0.6) tryTurn(1);
    else if (dx < -0.6) tryTurn(-1);
    
    if (c.xJustPressed || c.aJustPressed) tryJump();
    
    float ry = -map(c.ry, 0, height, -1, 1);
    float rx = map(c.rx, 0, width, -1, 1);
    camAzim += rx * 0.05;
    camElev = constrain(camElev + ry * 0.04, 0.1, 1.4);
  }

  void handleKey(char k) {
    if (state != MazeState.STATIONARY || transitionFrac < 1.0) return;
    if (k == 'w') tryMove(1);
    if (k == 's') tryMove(-1);
    if (k == 'a') tryTurn(-1);
    if (k == 'd') tryTurn(1);
    if (k == ' ') tryJump();
  }

  void tryMove(int dir) {
    PVector target = PVector.add(pos, PVector.mult(forward, dir));
    
    // Check Wall (Forward and Up)
    if (hasBlock(round(target.x + forward.x * (dir>0?0:0) - up.x), 
                 round(target.y - up.y), 
                 round(target.z - up.z))) {
        // Normal floor exists
        animStartPos = pos.copy();
        animEndPos = target.copy();
        animTimer = 0;
        state = MazeState.MOVING;
    } else {
        // No floor. Is there a wall to climb?
        PVector wallCheck = PVector.add(target, up);
        if (hasBlock(round(wallCheck.x - forward.x * dir), round(wallCheck.y - forward.y * dir), round(wallCheck.z - forward.z * dir))) {
            startGravityShift(PVector.mult(forward, -dir), up.copy());
        } else {
            // No floor, no wall. Flip over edge.
            startGravityShift(PVector.mult(forward, dir), PVector.mult(up, -1));
            animStartPos = pos.copy();
            animEndPos = target.copy(); // wrap onto the side
            animTimer = 0;
            state = MazeState.MOVING;
        }
    }
  }

  void tryTurn(int dir) {
    animStartFwd = forward.copy();
    PVector right = forward.cross(up);
    animEndFwd = PVector.mult(right, dir).normalize();
    animTimer = 0;
    state = MazeState.TURNING;
  }

  void tryJump() {
    state = MazeState.JUMPING;
    animStartPos = pos.copy();
    animEndPos = PVector.add(pos, PVector.mult(forward, 2));
    animTimer = 0;
    ballRoll += PI;
  }

  void startGravityShift(PVector newUp, PVector newForward) {
    oldUp = up.copy(); targetUp = newUp.copy();
    oldForward = forward.copy(); targetForward = newForward.copy();
    up = targetUp; forward = targetForward;
    animStartFwd = forward.copy(); animEndFwd = forward.copy();
    transitionFrac = 0.0; camAzim = 0;
  }

  String[] getCodeLines() {
    return new String[] {
      "// Maze Puzzle: Kula Mechanics",
      "p: " + pos + " up: " + up,
      "X/A: Jump | L-Stick: Grid Move",
      "R-Stick: Orbit Cam"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("L-Stick", "Grid Move / Turn"),
      new ControllerLayout("X / A", "Jump over gaps"),
      new ControllerLayout("R-Stick", "Orbit Camera")
    };
  }
}
