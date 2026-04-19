import java.util.HashSet;

enum MazeState { STATIONARY, MOVING, TURNING, JUMPING, FALLING }

/**
 * MazePuzzleScene — Kula World Mechanics Restoration
 *
 * Features:
 *   - 3 levels of increasing difficulty
 *   - Goal blocks (golden) trigger level advance when stood on
 *   - Snappy Follow Camera (Behind and Above)
 *   - Auto-Snapback for Camera Look
 *   - Rigid Grid Movement (No getting stuck)
 *   - Audio-Reactive Blocks & "Trippy" Background
 */
class MazePuzzleScene implements IScene {

  // ── Level Logic ──────────────────────────────────────────────────────────
  HashSet<String> blocks;
  HashSet<String> spikes;
  HashSet<String> goals;
  final float BLOCK_SIZE = 100;

  int   currentLevel       = 0;
  final int LEVEL_COUNT    = 3;
  boolean levelComplete    = false;
  int levelCompleteTimer   = 0;
  final int LEVEL_COMPLETE_FRAMES = 120;  // 2 s at 60 fps before loading next level

  // Per-level start position (set by setupLevel)
  PVector startPos;
  PVector startForward;

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

  // Movement constants
  final int MOVE_FORWARD = 1;
  final int MOVE_BACKWARD = -1;
  final int TURN_RIGHT = 1;
  final int TURN_LEFT = -1;
  final float ANALOG_MOVE_THRESHOLD = 0.6;
  final float ANALOG_FORWARD_JUMP_THRESHOLD = 0.35;
  final float ANALOG_CAMERA_THRESHOLD = 0.2;
  final float MOVE_ANIMATION_SPEED = 0.12;
  final float JUMP_ANIMATION_SPEED = 0.04;
  final float JUMP_HEIGHT = 0.5;
  final float ANIMATION_COMPLETE_FRACTION = 1.0;
  final float PULSE_LERP_SPEED = 0.2;
  final float PULSE_INTENSITY = 50;
  final int AMBIENT_HUE = 150;
  final int AMBIENT_SAT = 100;
  final int AMBIENT_BRIGHT_BASE = 100;
  final int AMBIENT_BRIGHT_PULSE = 50;
  final int DIR_LIGHT_R = 0;
  final int DIR_LIGHT_G = 0;
  final int DIR_LIGHT_B = 255;
  final float DIR_LIGHT_X = 1;
  final float DIR_LIGHT_Y = 1;
  final float DIR_LIGHT_Z = -1;
  final float DELTA_TIME = 0.016;
  final float BALL_SPIN_SCALE = 0.1;
  final float FALL_RESET_Y = -20;
  final float TRANSITION_SPEED = 0.08;
  final float CAMERA_SNAP_LERP = 0.1;
  final float CAMERA_ROTATION_SPEED = 0.05;
  final float CAMERA_PITCH_SPEED = 0.04;
  final float CAMERA_PITCH_MIN = 0.1;
  final float CAMERA_PITCH_MAX = 1.4;
  final float CAM_FOV = PI/3.0;
  final float CAM_NEAR_CLIP = 10;
  final float CAM_FAR_CLIP = 10000;
  final float BACKGROUND_SPEED = 0.5;
  final float BACKGROUND_HUE_SPEED = 20;
  final float BACKGROUND_HUE_OFFSET = 60;
  final float BACKGROUND_HIGH_SCALE = 100;
  final int BACKGROUND_SATURATION = 255;
  final int BACKGROUND_TOP_LEFT_BRIGHT = 60;
  final int BACKGROUND_TOP_RIGHT_BRIGHT = 40;
  final int BACKGROUND_BOTTOM_RIGHT_BRIGHT = 30;
  final int BACKGROUND_BOTTOM_LEFT_BRIGHT = 50;
  final float GOAL_PULSE_BASE = 0.8;
  final float GOAL_PULSE_MAG = 0.2;
  final float GOAL_PULSE_FREQ = 5;
  final float BALL_RADIUS = 35;
  final float BALL_DECOR_SCALE = 1.02;
  final float BALL_DECOR_SIDE = 71;
  final float BALL_CROSS_BAR_WIDTH = 10;
  final float BALL_CROSS_BAR_LENGTH = 75;
  // Ball colors: cyan for normal, matrix-green for auto mode
  final int BALL_NORMAL_HUE = 190;      // cyan
  final int BALL_NORMAL_SAT = 255;
  final int BALL_NORMAL_BRIGHT = 255;
  final int BALL_AUTO_HUE = 120;        // bright green
  final int BALL_AUTO_SAT = 255;
  final int BALL_AUTO_BRIGHT = 255;
  final int BALL_DECOR_HUE = 150;       // teal
  final int BALL_DECOR_SAT = 255;
  final int BALL_DECOR_BRIGHT = 255;
  final int BALL_CROSS_HUE = 180;       // cyan
  final int BALL_CROSS_SAT = 200;
  final int BALL_CROSS_BRIGHT = 255;
  final int BALL_FORWARD_HUE = 35;
  final int BALL_FORWARD_SAT = 255;
  final int BALL_FORWARD_BRIGHT = 255;
  final float BALL_FORWARD_MARKER_RADIUS = 12;
  final float BALL_FORWARD_MARKER_OFFSET = 32;
  final float BALL_FORWARD_ARROW_LENGTH = 24;
  final float BALL_FORWARD_ARROW_HALF_WIDTH = 14;
  final float AUTO_THINK_DOT_PERIOD = 15;
  final int AUTO_THINK_DOT_COUNT = 4;
  final float AUTO_THINK_MIN_WIDTH = 100;
  final float AUTO_THINK_PADDING = 18;
  
  // Block and spike rendering
  final float BLOCK_PULSE_SCALE = 0.15;
  final float SPIKE_BASE_SCALE = 0.4;
  final float SPIKE_TOWER_HEIGHT_SCALE = 0.3;
  final float SPIKE_TOWER_WIDTH_SCALE = 0.25;
  final float SPIKE_TOWER_DEPTH_SCALE = 0.25;
  final int SPIKE_GLOW_ALPHA = 200;
  final float BLOCK_STROKE_ALPHA_BASE = 100;
  final float BLOCK_BORDER_SCALE = 0.98;
  final float BLOCK_FILL_SCALE = 0.9;
  final int BLOCK_FILL_ALPHA = 120;
  final float GOAL_PULSE_RISE = 0.5;
  final float GOAL_PULSE_WIDTH_SCALE = 0.35;
  final float GOAL_PULSE_HEIGHT_SCALE = 1.2;
  final float GOAL_PULSE_TOP_OFFSET = 0.6;
  final float GOAL_PULSE_SPHERE_SCALE = 0.25;
  final float AUTO_THINK_HEIGHT = 20;
  final float AUTO_THINK_CORNER_RADIUS = 10;

  // ── Camera ─────────────────────────────────────────────────────────────
  float camAngle = 0;
  float camPitch = 0.4;
  float camDist = 550;
  float targetCamAngle = 0;
  float targetCamPitch = 0.4;
  int camIdleFrames = 0;
  final int SNAP_BACK_DELAY = 60;

  PVector oldUp, targetUp;
  PVector oldForward, targetForward;
  float transitionFrac = 1.0;

  float pulse = 0;
  float u_time = 0;

  boolean autoMode = false;
  float autoThinkTimer = 0;
  final float AUTO_THINK_FRAMES = 45; // how long it considers before moving
  final float AUTO_BEAT_MOVE_DELAY = 12; // frames between beat-triggered moves
  int autoBeatCooldown = 0;
  boolean stickTurnLatched = false;
  boolean stickMoveLatched = false;

  MazePuzzleScene() {
    blocks = new HashSet<String>();
    spikes = new HashSet<String>();
    goals  = new HashSet<String>();
    setupLevel(0);
    resetPlayer();
  }

  // ── Level definitions ─────────────────────────────────────────────────

  void setupLevel(int level) {
    blocks.clear(); spikes.clear(); goals.clear();
    currentLevel = level;
    switch (level) {
      case 0: setupLevel0(); break;
      case 1: setupLevel1(); break;
      case 2: setupLevel2(); break;
    }
  }

  // Level 1 — Tutorial: open platform, one ramp, one bridge, one spike.
  // Navigate north to the goal.
  void setupLevel0() {
    for (int x = -2; x <= 2; x++) for (int z = -2; z <= 2; z++) addBlock(x, 0, z);
    addBlock(0, 0, 4); addBlock(0, 0, 5);
    addBlock(3, 0, 0); addBlock(3, 1, 0); addBlock(3, 2, 0);
    spikes.add("3,3,0");   // spike at top of east ramp (player position)
    addBlock(-4, 0, 0); addBlock(-5, 0, 0);
    blocks.remove("0,0,0"); // hole in platform
    addGoal(0, 0, 5);       // goal at north bridge end
    startPos     = new PVector(0, 1, -2);
    startForward = new PVector(0, 0, 1);
  }

  // Level 2 — The L-Track: single-tile path forming an L-shape.
  // Dodge 3 spikes, turn right at the junction, reach the end.
  void setupLevel1() {
    for (int z = -4; z <= 4; z++) addBlock(0, 0, z);   // vertical leg
    for (int x = 1; x <= 6; x++) addBlock(x, 0, 4);    // horizontal leg
    spikes.add("0,1,-2");   // south stretch
    spikes.add("0,1,2");    // north stretch before turn
    spikes.add("4,1,4");    // east arm
    addGoal(6, 0, 4);
    startPos     = new PVector(0, 1, -4);
    startForward = new PVector(0, 0, 1);
  }

  // Level 3 — The Ring: outer square ring with a center cross.
  // Gaps in the ring require jumping. Center cross is spiked — use the ring.
  void setupLevel2() {
    // Outer ring
    for (int x = -4; x <= 4; x++) { addBlock(x, 0, 4); addBlock(x, 0, -4); }
    for (int z = -3; z <= 3; z++) { addBlock(-4, 0, z); addBlock(4, 0, z); }
    // Gaps in ring sides — must be jumped
    blocks.remove("0,0,4");   // top gap
    blocks.remove("0,0,-4");  // bottom gap
    blocks.remove("-4,0,0");  // left gap
    blocks.remove("4,0,0");   // right gap
    // Inner cross
    for (int x = -2; x <= 2; x++) addBlock(x, 0, 0);
    for (int z = -2; z <= 2; z++) addBlock(0, 0, z);
    // Spike the entire inner cross — player must stay on outer ring
    for (int x = -2; x <= 2; x++) spikes.add(x + ",1,0");
    for (int z = -1; z <= 1; z++) spikes.add("0,1," + z);
    // Additional ring spikes for challenge
    spikes.add("-4,1,2");
    spikes.add("4,1,-2");
    spikes.add("2,1,4");
    spikes.add("-2,1,-4");
    // Goal at bottom-right corner (opposite start)
    addGoal(4, 0, -4);
    startPos     = new PVector(-4, 1, 4);
    startForward = new PVector(1, 0, 0);   // face east along top ring
  }

  void addBlock(int x, int y, int z) { blocks.add(x + "," + y + "," + z); }
  boolean hasBlock(int x, int y, int z) { return blocks.contains(x + "," + y + "," + z); }
  boolean hasSpike(int x, int y, int z) { return spikes.contains(x + "," + y + "," + z); }

  void addGoal(int x, int y, int z)        { goals.add(x + "," + y + "," + z); }
  boolean hasGoalAt(int x, int y, int z)   { return goals.contains(x + "," + y + "," + z); }

  void resetPlayer() {
    pos     = startPos.copy();
    up      = new PVector(0, 1, 0);
    forward = startForward.copy();
    animStartPos = pos.copy(); animEndPos = pos.copy();
    animStartFwd = forward.copy(); animEndFwd = forward.copy();
    oldUp = up.copy(); targetUp = up.copy();
    oldForward = forward.copy(); targetForward = forward.copy();
    state = MazeState.STATIONARY;
    animTimer = 1.0; transitionFrac = 1.0;
    jumpY = 0; jumpVel = 0; ballRoll = 0; ballSpin = 0;
    camAngle = 0; camPitch = 0.4; targetCamAngle = 0; targetCamPitch = 0.4;
    camIdleFrames = 0;
    autoThinkTimer = 0;
    autoBeatCooldown = 0;
    stickTurnLatched = false;
    stickMoveLatched = false;
  }

  void onEnter() {
    setupLevel(0);
    levelComplete = false;
    levelCompleteTimer = 0;
    autoMode = false;
    resetPlayer();
  }
  void onExit()  { }

  void drawScene(PGraphics pg) {
    pg.beginDraw();
    pg.background(0);
    drawBackground(pg);
    pg.colorMode(HSB, 360, 255, 255);

    updateLogic();
    setupCamera(pg);

    pg.ambientLight(AMBIENT_HUE, AMBIENT_SAT, AMBIENT_BRIGHT_BASE + pulse * AMBIENT_BRIGHT_PULSE);
    pg.directionalLight(DIR_LIGHT_R, DIR_LIGHT_G, DIR_LIGHT_B, DIR_LIGHT_X, DIR_LIGHT_Y, DIR_LIGHT_Z);
    pulse = lerp(pulse, analyzer.isBeat ? 1.0 : 0.0, PULSE_LERP_SPEED);

    for (String key : blocks) {
      String[] p = key.split(",");
      drawBlock(pg, int(p[0]), int(p[1]), int(p[2]), false);
    }
    for (String key : spikes) {
      String[] p = key.split(",");
      drawBlock(pg, int(p[0]), int(p[1]), int(p[2]), true);
    }
    for (String key : goals) {
      String[] p = key.split(",");
      drawGoalBlock(pg, int(p[0]), int(p[1]), int(p[2]));
    }
    drawBall(pg);

    // ── 2D overlay ──────────────────────────────────────────────────────
    pg.hint(PConstants.DISABLE_DEPTH_TEST);
    pg.resetMatrix();
    pg.colorMode(RGB, 255);

    // Level indicator (top-left)
    float ts = uiScale();
    pg.textFont(monoFont);
    pg.textSize(11 * ts);
    pg.textAlign(LEFT, TOP);
    pg.fill(255, 215, 80, 200);
    pg.text("Level " + (currentLevel + 1) + " / " + LEVEL_COUNT,
            12 * ts, 12 * ts);
    pg.textSize(10 * ts);
    pg.fill(autoMode ? color(100, 255, 150) : color(255, 200, 80));
    pg.text(autoMode ? "AUTO MODE" : "PLAYER MODE",
            12 * ts, 30 * ts);

    if (autoMode && state == MazeState.STATIONARY && !levelComplete && autoThinkTimer > 0) {
      String dots = "";
      int dotCount = (frameCount / (int)AUTO_THINK_DOT_PERIOD) % AUTO_THINK_DOT_COUNT;
      for (int i = 0; i < dotCount; i++) dots += ".";
      String thinking = "Thinking" + dots;
      float bx = 12 * ts;
      float by = 48 * ts;
      float bw = max(pg.textWidth(thinking) + AUTO_THINK_PADDING * ts, AUTO_THINK_MIN_WIDTH * ts);
      float bh = AUTO_THINK_HEIGHT * ts;
      pg.noStroke();
      pg.fill(0, 0, 0, 170);
      pg.rect(bx, by, bw, bh, AUTO_THINK_CORNER_RADIUS * ts);
      pg.stroke(255, 255, 255, 200);
      pg.strokeWeight(1);
      pg.noFill();
      pg.rect(bx, by, bw, bh, AUTO_THINK_CORNER_RADIUS * ts);
      pg.noStroke();
      pg.fill(255);
      pg.textAlign(LEFT, CENTER);
      pg.textSize(9 * ts);
      pg.text(thinking, bx + 9 * ts, by + bh * 0.52);
    }

    // Level complete flash
    if (levelComplete) {
      float alpha = map(levelCompleteTimer, LEVEL_COMPLETE_FRAMES, 0, 220, 0);
      pg.noStroke();
      pg.fill(255, 215, 0, (int)(alpha * 0.4));
      pg.rect(0, 0, pg.width, pg.height);
      pg.fill(255, 255, 255, (int)alpha);
      pg.textSize(32 * ts);
      pg.textAlign(CENTER, CENTER);
      pg.text("LEVEL COMPLETE!", pg.width / 2, pg.height / 2);
      if (currentLevel + 1 < LEVEL_COUNT) {
        pg.textSize(14 * ts);
        pg.fill(255, 215, 80, (int)(alpha * 0.8));
        pg.text("Loading level " + (currentLevel + 2) + "...",
                pg.width / 2, pg.height / 2 + 40 * ts);
      } else {
        pg.textSize(14 * ts);
        pg.fill(255, 215, 80, (int)(alpha * 0.8));
        pg.text("All levels complete! Restarting...",
                pg.width / 2, pg.height / 2 + 40 * ts);
      }
    }

    pg.hint(PConstants.ENABLE_DEPTH_TEST);
    pg.endDraw();
  }

  void drawBackground(PGraphics pg) {
    pg.hint(PConstants.DISABLE_DEPTH_TEST);
    pg.resetMatrix();
    pg.noStroke();
    float t = u_time * BACKGROUND_SPEED;
    float h1 = (t * BACKGROUND_HUE_SPEED) % 360;
    float h2 = (h1 + BACKGROUND_HUE_OFFSET + analyzer.high * BACKGROUND_HIGH_SCALE) % 360;
    pg.beginShape(QUADS);
    pg.fill(h1, BACKGROUND_SATURATION, BACKGROUND_TOP_LEFT_BRIGHT); pg.vertex(0, 0);
    pg.fill(h1, BACKGROUND_SATURATION, BACKGROUND_TOP_RIGHT_BRIGHT); pg.vertex(pg.width, 0);
    pg.fill(h2, BACKGROUND_SATURATION, BACKGROUND_BOTTOM_RIGHT_BRIGHT); pg.vertex(pg.width, pg.height);
    pg.fill(h2, BACKGROUND_SATURATION, BACKGROUND_BOTTOM_LEFT_BRIGHT); pg.vertex(0, pg.height);
    pg.endShape();
    pg.hint(PConstants.ENABLE_DEPTH_TEST);
  }

  void updateLogic() {
    u_time += DELTA_TIME;
    ballSpin += analyzer.mid * BALL_SPIN_SCALE;

    // Level complete countdown
    if (levelComplete) {
      levelCompleteTimer--;
      if (levelCompleteTimer <= 0) {
        int next = (currentLevel + 1) % LEVEL_COUNT;
        setupLevel(next);
        resetPlayer();
        levelComplete = false;
      }
      return;  // freeze movement during transition
    }

    if (state != MazeState.STATIONARY) {
      float speed = (state == MazeState.JUMPING) ? JUMP_ANIMATION_SPEED : MOVE_ANIMATION_SPEED;
      animTimer += speed;
      if (state == MazeState.MOVING) ballRoll += speed * PI;
      if (state == MazeState.JUMPING) jumpY = sin(animTimer * PI) * JUMP_HEIGHT;
      if (animTimer >= ANIMATION_COMPLETE_FRACTION) completeAction();
    }

    if (transitionFrac < 1.0) {
      transitionFrac += TRANSITION_SPEED;
      if (transitionFrac > 1.0) transitionFrac = 1.0;
    }

    if (state == MazeState.STATIONARY) {
      // Death check
      if (hasSpike(round(pos.x), round(pos.y), round(pos.z))) resetPlayer();
      // Goal check — standing on a goal block?
      int floorX = round(pos.x - up.x);
      int floorY = round(pos.y - up.y);
      int floorZ = round(pos.z - up.z);
      if (!levelComplete && hasGoalAt(floorX, floorY, floorZ)) {
        levelComplete = true;
        levelCompleteTimer = LEVEL_COMPLETE_FRAMES;
      }
    }

    if (state == MazeState.FALLING) {
      pos.add(PVector.mult(up, jumpVel));
      jumpVel -= GRAVITY_CONST;
      if (pos.y < FALL_RESET_Y) resetPlayer();
    }

    if (autoMode && state == MazeState.STATIONARY && !levelComplete) {
      autoThinkTimer += 1;
      if (autoBeatCooldown > 0) autoBeatCooldown--;
      if (analyzer.isBeat && autoBeatCooldown == 0) {
        attemptAutoMove();
        autoBeatCooldown = (int)AUTO_BEAT_MOVE_DELAY;
      } else if (autoThinkTimer >= AUTO_THINK_FRAMES) {
        attemptAutoMove();
      }
    }

    // Camera snapback
    camIdleFrames++;
    if (camIdleFrames > SNAP_BACK_DELAY) {
      camAngle = lerp(camAngle, targetCamAngle, CAMERA_SNAP_LERP);
      camPitch = lerp(camPitch, targetCamPitch, CAMERA_SNAP_LERP);
    }
  }

  void completeAction() {
    pos = new PVector(round(animEndPos.x), round(animEndPos.y), round(animEndPos.z));
    forward = animEndFwd.copy();
    animTimer = 1.0; jumpY = 0;
    state = MazeState.STATIONARY;
    autoThinkTimer = 0;
    if (!hasBlock(round(pos.x - up.x), round(pos.y - up.y), round(pos.z - up.z))) {
      state = MazeState.FALLING; jumpVel = 0;
    }
  }

  void setupCamera(PGraphics pg) {
    PVector curUp = PVector.lerp(oldUp, targetUp, transitionFrac).normalize();
    PVector curFwd = getCameraForward(curUp);
    PVector vPos = PVector.lerp(animStartPos, animEndPos, animTimer);

    PVector right = curUp.cross(curFwd).normalize();
    PVector rotFwd = PVector.add(PVector.mult(curFwd, cos(camAngle)), PVector.mult(right, sin(camAngle)));

    PVector worldBall = PVector.mult(vPos, BLOCK_SIZE).add(PVector.mult(curUp, jumpY * BLOCK_SIZE));
    PVector camOff = PVector.add(PVector.mult(rotFwd, -camDist * cos(camPitch)), PVector.mult(curUp, camDist * sin(camPitch)));

    pg.camera(worldBall.x + camOff.x, worldBall.y + camOff.y, worldBall.z + camOff.z,
              worldBall.x, worldBall.y, worldBall.z,
              -curUp.x, -curUp.y, -curUp.z);
    pg.perspective(CAM_FOV, (float)pg.width/pg.height, CAM_NEAR_CLIP, CAM_FAR_CLIP);
  }

  PVector getCameraForward(PVector curUp) {
    if (state == MazeState.TURNING) {
      PVector turningForward = PVector.lerp(animStartFwd, animEndFwd, animTimer);
      if (turningForward.magSq() > 0) return turningForward.normalize();
    }

    if (transitionFrac < 1.0) {
      PVector shiftingForward = PVector.lerp(oldForward, targetForward, transitionFrac);
      if (shiftingForward.magSq() > 0) return shiftingForward.normalize();
    }

    PVector stableForward = forward.copy();
    if (abs(stableForward.dot(curUp)) > 0.99) stableForward = targetForward.copy();
    if (stableForward.magSq() == 0) stableForward = new PVector(0, 0, 1);
    return stableForward.normalize();
  }

  void drawBlock(PGraphics pg, int x, int y, int z, boolean isSpike) {
    pg.pushMatrix();
    pg.translate(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE);
    float bassScale = 1.0 + (analyzer.bass * BLOCK_PULSE_SCALE);
    float midHue = (analyzer.mid * 100 + 200) % 360;
    if (isSpike) {
      pg.fill(0, 255, 255); pg.stroke(0, 255, 255);
      pg.box(BLOCK_SIZE * SPIKE_BASE_SCALE * bassScale);
      pg.translate(0, BLOCK_SIZE * SPIKE_TOWER_HEIGHT_SCALE, 0);
      pg.fill(0, 255, 200, SPIKE_GLOW_ALPHA); pg.box(BLOCK_SIZE * SPIKE_TOWER_WIDTH_SCALE, BLOCK_SIZE * SPIKE_TOWER_DEPTH_SCALE, BLOCK_SIZE * SPIKE_TOWER_WIDTH_SCALE);
    } else {
      pg.stroke(midHue, 200, 255, BLOCK_STROKE_ALPHA_BASE + pulse * BLOCK_STROKE_ALPHA_BASE);
      pg.noFill();
      pg.box(BLOCK_SIZE * BLOCK_BORDER_SCALE * bassScale);
      pg.fill(midHue, 150, BLOCK_STROKE_ALPHA_BASE + pulse * BLOCK_STROKE_ALPHA_BASE, BLOCK_FILL_ALPHA);
      pg.noStroke();
      pg.box(BLOCK_SIZE * BLOCK_FILL_SCALE * bassScale);
    }
    pg.popMatrix();
  }

  // Goal block: golden pulsing pillar. Stored as floor-block position.
  void drawGoalBlock(PGraphics pg, int x, int y, int z) {
    pg.pushMatrix();
    pg.translate(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE);
    float puls = GOAL_PULSE_BASE + GOAL_PULSE_MAG * sin(u_time * GOAL_PULSE_FREQ + analyzer.high * 2.0);
    float beatGlow = 1.0 + pulse * 0.4;
    // Pillar rising from block surface
    pg.translate(0, BLOCK_SIZE * GOAL_PULSE_RISE, 0);
    pg.fill(45, 255, 255);          // gold hue in HSB
    pg.stroke(45, 180, 255, 200);
    pg.box(BLOCK_SIZE * GOAL_PULSE_WIDTH_SCALE * puls * beatGlow,
           BLOCK_SIZE * GOAL_PULSE_HEIGHT_SCALE * beatGlow,
           BLOCK_SIZE * GOAL_PULSE_WIDTH_SCALE * puls * beatGlow);
    // Glowing top cap
    pg.translate(0, -BLOCK_SIZE * GOAL_PULSE_TOP_OFFSET * puls, 0);
    pg.fill(50, 200, 255, 180);
    pg.noStroke();
    pg.sphere(BLOCK_SIZE * GOAL_PULSE_SPHERE_SCALE * puls * beatGlow);
    pg.popMatrix();
  }

  void drawBall(PGraphics pg) {
    PVector vPos = PVector.lerp(animStartPos, animEndPos, animTimer);
    PVector vFwd = PVector.lerp(animStartFwd, animEndFwd, animTimer).normalize();
    pg.pushMatrix();
    pg.translate(vPos.x * BLOCK_SIZE, vPos.y * BLOCK_SIZE, vPos.z * BLOCK_SIZE);
    pg.translate(up.x * jumpY * BLOCK_SIZE, up.y * jumpY * BLOCK_SIZE, up.z * jumpY * BLOCK_SIZE);
    PVector xAxis = up.cross(vFwd);
    pg.applyMatrix(xAxis.x, up.x, vFwd.x, 0, xAxis.y, up.y, vFwd.y, 0, xAxis.z, up.z, vFwd.z, 0, 0, 0, 0, 1);
    drawBallForwardMarker(pg);

    pg.pushMatrix();
    pg.rotateX(ballRoll); pg.rotateY(ballSpin);
    pg.noStroke();
    // Main sphere: cyan normal, bright matrix-green in auto mode
    int ballHue = autoMode ? BALL_AUTO_HUE : BALL_NORMAL_HUE;
    int ballSat = autoMode ? BALL_AUTO_SAT : BALL_NORMAL_SAT;
    int ballBright = autoMode ? BALL_AUTO_BRIGHT : BALL_NORMAL_BRIGHT;
    pg.fill(ballHue, ballSat, ballBright);
    pg.sphere(BALL_RADIUS);
    // Decorative band
    pg.fill(BALL_DECOR_HUE, BALL_DECOR_SAT, BALL_DECOR_BRIGHT);
    pg.pushMatrix();
    pg.scale(BALL_DECOR_SCALE);
    pg.box(BALL_DECOR_SIDE, BALL_CROSS_BAR_WIDTH, BALL_DECOR_SIDE);
    pg.popMatrix();
    // Cross bars
    pg.fill(BALL_CROSS_HUE, BALL_CROSS_SAT, BALL_CROSS_BRIGHT);
    pg.box(BALL_CROSS_BAR_WIDTH, BALL_CROSS_BAR_LENGTH, BALL_CROSS_BAR_WIDTH);
    pg.rotateZ(HALF_PI);
    pg.box(BALL_CROSS_BAR_WIDTH, BALL_CROSS_BAR_LENGTH, BALL_CROSS_BAR_WIDTH);
    pg.popMatrix();
    pg.popMatrix();
  }

  void drawBallForwardMarker(PGraphics pg) {
    pg.noStroke();
    pg.fill(BALL_FORWARD_HUE, BALL_FORWARD_SAT, BALL_FORWARD_BRIGHT);
    pg.pushMatrix();
    pg.translate(0, 0, BALL_RADIUS + BALL_FORWARD_MARKER_OFFSET);
    pg.sphere(BALL_FORWARD_MARKER_RADIUS);
    pg.popMatrix();

    pg.fill(BALL_FORWARD_HUE, BALL_FORWARD_SAT, BALL_FORWARD_BRIGHT, 220);
    pg.beginShape(TRIANGLES);
    pg.vertex(0, 0, BALL_RADIUS + BALL_FORWARD_MARKER_OFFSET + BALL_FORWARD_ARROW_LENGTH);
    pg.vertex(-BALL_FORWARD_ARROW_HALF_WIDTH, 0, BALL_RADIUS + BALL_FORWARD_MARKER_OFFSET);
    pg.vertex(BALL_FORWARD_ARROW_HALF_WIDTH, 0, BALL_RADIUS + BALL_FORWARD_MARKER_OFFSET);
    pg.endShape();
  }

  void applyController(Controller c) {
    if (levelComplete) return;
    if (autoMode) {
      float lx = map(c.lx, 0, width, -1, 1);
      float ly = map(c.ly, 0, height, -1, 1);
      float rx = map(c.rx, 0, width, -1, 1);
      float ry = map(c.ry, 0, height, -1, 1);
      if (c.aJustPressed || c.bJustPressed || c.xJustPressed || c.yJustPressed || c.lbJustPressed || c.rbJustPressed || c.startJustPressed || c.backJustPressed
          || abs(lx) > ANALOG_CAMERA_THRESHOLD || abs(ly) > ANALOG_CAMERA_THRESHOLD
          || abs(rx) > ANALOG_CAMERA_THRESHOLD || abs(ry) > ANALOG_CAMERA_THRESHOLD) {
        autoMode = false;
      }
      return;
    }
    if ((state != MazeState.STATIONARY && state != MazeState.TURNING) || transitionFrac < 1.0) return;

    float dy = -map(c.ly, 0, height, -1, 1);
    float dx = map(c.lx, 0, width, -1, 1);

    if (state == MazeState.TURNING) {
      if (c.aJustPressed) {
        completeAction();
        tryJump(isForwardJumpHeld(dy));
      }
      return;
    }

    if (abs(dx) < ANALOG_MOVE_THRESHOLD * 0.5) stickTurnLatched = false;
    if (dy < ANALOG_MOVE_THRESHOLD * 0.5) stickMoveLatched = false;

    if (c.aJustPressed) {
      tryJump(isForwardJumpHeld(dy));
      return;
    }

    if (dy > ANALOG_MOVE_THRESHOLD && !stickMoveLatched) {
      tryMove(MOVE_FORWARD);
      stickMoveLatched = true;
    } else if (dx > ANALOG_MOVE_THRESHOLD && !stickTurnLatched) {
      tryTurn(TURN_RIGHT);
      stickTurnLatched = true;
    } else if (dx < -ANALOG_MOVE_THRESHOLD && !stickTurnLatched) {
      tryTurn(TURN_LEFT);
      stickTurnLatched = true;
    }

    float ry = -map(c.ry, 0, height, -1, 1);
    float rx = map(c.rx, 0, width, -1, 1);
    if (abs(rx) > ANALOG_CAMERA_THRESHOLD || abs(ry) > ANALOG_CAMERA_THRESHOLD) {
      camAngle += rx * CAMERA_ROTATION_SPEED;
      camPitch = constrain(camPitch + ry * CAMERA_PITCH_SPEED, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX);
      camIdleFrames = 0;
    }
  }

  void handleKey(char k) {
    if (levelComplete) return;
    if ((state != MazeState.STATIONARY && state != MazeState.TURNING) || transitionFrac < 1.0) return;

    if (state == MazeState.TURNING) {
      if (k == ' ' || k == 'x' || k == 'X') {
        completeAction();
        tryJump(false);
      }
      return;
    }

    if (k == 'u' || k == 'U') {
      autoMode = !autoMode;
      autoThinkTimer = 0;
      return;
    }
    if (autoMode && k != 'r' && k != 'R' && k != 'n' && k != 'N') return;
    if (k == 'w') tryMove(MOVE_FORWARD); if (k == 's') tryMove(MOVE_BACKWARD);
    if (k == 'a') tryTurn(TURN_LEFT); if (k == 'd') tryTurn(TURN_RIGHT);
    if (k == ' ') tryJump(false);
    if (k == 'n' || k == 'N') {
      // Debug: skip to next level
      int next = (currentLevel + 1) % LEVEL_COUNT;
      setupLevel(next); resetPlayer();
    }
    if (k == 'r' || k == 'R') resetPlayer();
  }

  void tryMove(int moveDir) {
    // moveDir should be MOVE_FORWARD or MOVE_BACKWARD
    PVector fwd = PVector.mult(forward, moveDir);
    PVector target = PVector.add(pos, fwd);

    int floorX = round(target.x - up.x);
    int floorY = round(target.y - up.y);
    int floorZ = round(target.z - up.z);
    if (hasBlock(floorX, floorY, floorZ)) {
      animStartPos = pos.copy();
      animEndPos = target.copy();
      animTimer = 0;
      state = MazeState.MOVING;
      return;
    }

    int wallX = round(target.x);
    int wallY = round(target.y);
    int wallZ = round(target.z);
    if (hasBlock(wallX, wallY, wallZ)) {
      animStartPos = pos.copy();
      animEndPos = PVector.add(target, fwd);
      animTimer = 0;
      state = MazeState.MOVING;
      startGravityShift(fwd, PVector.mult(up.copy(), moveDir));
      return;
    }

    PVector curFloor = PVector.sub(pos, up);
    animStartPos = pos.copy();
    PVector rollDirVec = PVector.mult(forward, moveDir);
    animEndPos = PVector.add(curFloor, rollDirVec);
    animTimer = 0;
    state = MazeState.MOVING;
    PVector newUp = rollDirVec.copy();
    PVector newFwd = PVector.mult(up, -moveDir);
    startGravityShift(newUp, newFwd);
    return;
  }

  void tryTurn(int dir) {
    animStartFwd = forward.copy();
    animEndFwd = findTurnDirection(dir);
    animTimer = 0; state = MazeState.TURNING;
  }

  PVector findTurnDirection(int dir) {
    PVector candidate = forward.copy();
    for (int i = 0; i < 4; i++) {
      candidate = up.cross(candidate).mult(dir).normalize();
      if (isPlayableFacing(candidate)) return candidate;
    }
    return up.cross(forward).mult(dir).normalize();
  }

  void attemptAutoMove() {
    ArrayList<Integer> choices = getValidAutoMoves();
    if (choices.size() == 0) return;
    int bestIndex = chooseAutoMove(choices);
    int move = choices.get(bestIndex);
    if (move == 0) tryMove(MOVE_FORWARD);
    else if (move == 1) tryMove(MOVE_BACKWARD);
    else if (move == 2) tryTurn(TURN_RIGHT);
    else if (move == 3) tryTurn(TURN_LEFT);
    else if (move == 4) tryJump(true);
    autoThinkTimer = 0;
  }

  ArrayList<Integer> getValidAutoMoves() {
    ArrayList<Integer> valid = new ArrayList<Integer>();
    if (canMove(1)) valid.add(0);
    if (canMove(-1)) valid.add(1);
    if (canJump()) valid.add(4);
    if (true) {
      valid.add(2); // allow turns always as part of consideration
      valid.add(3);
    }
    return valid;
  }

  boolean canMove(int dir) {
    PVector fwd = PVector.mult(forward, dir);
    return canMoveInDirection(fwd);
  }

  boolean canMoveInDirection(PVector dir) {
    PVector fwd = dir.copy().normalize();
    PVector target = PVector.add(pos, fwd);
    int floorX = round(target.x - up.x);
    int floorY = round(target.y - up.y);
    int floorZ = round(target.z - up.z);
    if (hasBlock(floorX, floorY, floorZ)) return isSafeAutoLanding(target);
    int wallX = round(target.x);
    int wallY = round(target.y);
    int wallZ = round(target.z);
    if (hasBlock(wallX, wallY, wallZ)) return isSafeAutoLanding(PVector.add(target, fwd));
    return isSafeAutoLanding(PVector.add(PVector.sub(pos, up), fwd));
  }

  boolean canJump() {
    return canJumpInDirection(forward);
  }

  boolean canJumpInDirection(PVector dir) {
    PVector target = PVector.add(pos, PVector.mult(dir.copy().normalize(), 2));
    return hasSupportBelow(target) && !isSolidCell(target) && !hasSpikeAtPosition(target);
  }

  boolean isPlayableFacing(PVector dir) {
    return canMoveInDirection(dir) || canMoveInDirection(PVector.mult(dir, -1)) || canJumpInDirection(dir);
  }

  boolean isForwardJumpHeld(float dy) {
    return dy > ANALOG_FORWARD_JUMP_THRESHOLD;
  }

  int chooseAutoMove(ArrayList<Integer> moves) {
    PVector goal = getGoalPosition();
    if (goal == null) return (int)random(moves.size());
    float bestScore = -1;
    int bestIndex = 0;
    for (int i = 0; i < moves.size(); i++) {
      int m = moves.get(i);
      PVector candidatePos = pos.copy();
      PVector candidateFwd = forward.copy();
      if (m == 0) candidatePos.add(PVector.mult(candidateFwd, 1));
      else if (m == 1) candidatePos.add(PVector.mult(candidateFwd, -1));
      else if (m == 2) candidateFwd = candidateFwd.cross(up).normalize();
      else if (m == 3) candidateFwd = PVector.mult(candidateFwd.cross(up), -1).normalize();
      else if (m == 4) candidatePos.add(PVector.mult(candidateFwd, 2));
      float dist = abs(candidatePos.x - goal.x) + abs(candidatePos.y - goal.y) + abs(candidatePos.z - goal.z);
      float score = 1.0f / (dist + 1.0f);
      if (m == 4) score *= 1.2f;
      score *= 0.6 + random(0, 0.8);
      if (score > bestScore) { bestScore = score; bestIndex = i; }
    }
    return bestIndex;
  }

  PVector getGoalPosition() {
    for (String key : goals) {
      String[] parts = key.split(",");
      return new PVector(parseInt(parts[0]), parseInt(parts[1]), parseInt(parts[2]));
    }
    return null;
  }

  void tryJump(boolean jumpForward) {
    PVector target = pos.copy();
    if (jumpForward) {
      target = PVector.add(pos, PVector.mult(forward, 2));
      if (!hasSupportBelow(target) || isSolidCell(target)) return;
    }
    state = MazeState.JUMPING;
    animStartPos = pos.copy();
    animEndPos = target.copy();
    animTimer = 0; ballRoll += PI;
  }

  boolean hasSupportBelow(PVector target) {
    int floorX = round(target.x - up.x);
    int floorY = round(target.y - up.y);
    int floorZ = round(target.z - up.z);
    return hasBlock(floorX, floorY, floorZ);
  }

  boolean isSolidCell(PVector target) {
    return hasBlock(round(target.x), round(target.y), round(target.z));
  }

  boolean hasSpikeAtPosition(PVector target) {
    return hasSpike(round(target.x), round(target.y), round(target.z));
  }

  boolean isSafeAutoLanding(PVector target) {
    return !isSolidCell(target) && !hasSpikeAtPosition(target);
  }

  void startGravityShift(PVector nUp, PVector nFwd) {
    oldUp = up.copy(); targetUp = nUp.copy();
    oldForward = forward.copy(); targetForward = nFwd.copy();
    up = targetUp; forward = targetForward;
    animStartFwd = forward.copy(); animEndFwd = forward.copy();
    transitionFrac = 0.0; camIdleFrames = SNAP_BACK_DELAY + 1;
  }

  String[] getCodeLines() {
    return new String[]{
      "// Maze: Kula Mechanics",
      "Level " + (currentLevel + 1) + " of " + LEVEL_COUNT,
      "",
      "Reach the gold pillar",
      "",
      "WASD: Move / Turn",
      "L-Stick Up: Roll forward",
      "L-Stick Left/Right: Turn",
      "A: Jump up",
      "Hold forward + A: Jump forward",
      "Space: Jump up",
      "U: Toggle Auto / Manual",
      "Auto can jump gaps on beat",
      "R-Stick: Look / Auto-Snap",
      "N: Skip level  R: Restart",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("L-Stick", "Up rolls, left/right turns"),
      new ControllerLayout("A",       "Jump up / hold forward to leap"),
      new ControllerLayout("R-Stick", "Look / Auto-Snap"),
      new ControllerLayout("U",       "Toggle Auto / Manual"),
    };
  }
}
