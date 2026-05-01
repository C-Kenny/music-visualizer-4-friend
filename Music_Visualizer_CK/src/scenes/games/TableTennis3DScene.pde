// Table Tennis 3D Scene — state 25
//
// Extends TableTennisScene: inherits all physics, rules, AI, scoring,
// beat-glow, power shots, and bass breathing.
//
// Adds Z-axis shot variation: each paddle hit gives the ball a random
// lateral (Z) velocity. Ball bounces off the table's Z edges.
// Racket shapes: oval face (flattened sphere) + wooden handle.
//
// Psychedelic post-process styles (F / D-pad L/R to cycle):
//   0 = Normal  |  1 = Acid Warp  |  2 = Chromatic Glitch  |  3 = Neon Bloom
//
// Player control (V / B button to cycle):
//   0 = AI both  |  1 = human plays left (red)  |  2 = human plays right (blue)
//   Controller: left stick → paddle Y + Z   Keyboard: I/K = up/down, J/M = Z depth

class TableTennis3DScene extends TableTennisScene {

  // ── orbit camera ──────────────────────────────────────────────────────────
  float camAzim   =  0.15;
  float camElev   =  0.42;
  float camRadius = 1400;
  // Camera distance was calibrated for a ~1360-tall buffer. With the 1080p
  // stage render cap the world shrinks, so camRadius must scale with buffer
  // height to keep framing identical across resolutions.
  final float CAM_RADIUS_BASELINE_H = 1360.0;
  float shake     =  0;

  // ── table dimensions ──────────────────────────────────────────────────────
  float TABLE_DEPTH = 680;
  final float PADDLE_D    = 18;
  final float PADDLE_Z    = 130;

  // ── Z physics ─────────────────────────────────────────────────────────────
  float ballZ      = 0;
  float ballVZ     = 0;
  int   prevRallyCount = 0;

  // ── Out-of-bounds 2-bounce rule ───────────────────────────────────────────
  // Ball can go past the paddle. Only scored when it bounces twice on the floor
  // or exits through the back wall of the enclosure (ENV_HW).
  boolean outOfBounds    = false;   // ball has passed a paddle edge
  boolean outLeftScored  = false;   // if true → left scored (ball went right); if false → right scored
  int     outBounceCount = 0;       // floor bounces since ball passed paddle
  float   floorY         = 0;       // set on onEnter (tableY + ENV_BOT_OFFSET)

  // ── paddle Z positions ────────────────────────────────────────────────────
  float leftPaddleZ  = 0;
  float rightPaddleZ = 0;

  // ── 3D trail ──────────────────────────────────────────────────────────────
  ArrayList<PVector> trail3D = new ArrayList<PVector>();

  // ── shader / post-process ─────────────────────────────────────────────────
  // 0=Normal  1=Acid Warp  2=Chromatic Glitch  3=Neon Bloom
  int     shaderStyle = 0;
  final String[] STYLE_NAMES = {"Normal", "Acid Warp", "Chromatic Glitch", "Neon Bloom"};
  PShader acidShader, chromaticShader, neonShader;
  PGraphics innerBuf;      // 3D scene renders here; post-process blits to pg
  float   sceneTime = 0;   // seconds, accumulated

  // ── projection ────────────────────────────────────────────────────────────
  PGraphics tableTexture;
  int[] PROJECTABLE_SCENES = { 
    SCENE_KALEIDOSCOPE, SCENE_CYBER_GRID, SCENE_AURORA_RIBBONS, SCENE_FRACTAL,
    SCENE_VOID_BLOOM, SCENE_SACRED_GEOMETRY, SCENE_ROSE_CURVE, SCENE_SRI_YANTRA,
    SCENE_PSYCHEDELIC_EYE, SCENE_DOT_MANDALA, SCENE_CHLADNI_PLATE, SCENE_STRANGE_ATTRACTOR,
    SCENE_SACRED_FRACTALS, SCENE_TUNNEL_YANTRA, SCENE_PENTAGONAL_VORTEX, SCENE_MERKABA_STAR,
    SCENE_COSMIC_LATTICE, SCENE_NET_OF_BEING, SCENE_TORUS_KNOT, SCENE_RECURSIVE_MANDALA,
    SCENE_DEEP_SPACE, SCENE_WORM, SCENE_SHADER, SCENE_PRISM_CODEX, SCENE_HEART_GRID,
    SCENE_GRAVITY_STRINGS, SCENE_NEURAL_WEAVE, SCENE_SHOAL_LUMINA, SCENE_ANTIGRAVITY,
    SCENE_THEY_DONT_KNOW
  };
  int projectedSceneIdx = -1;

  // ── player control ────────────────────────────────────────────────────────
  // 0=AI both  1=human left (red)  2=human right (blue)
  int   playerSide    = 0;
  float playerTargetY = 0;
  float playerTargetZ = 0;

  // ── environment (expanded skybox) ─────────────────────────────────────────
  // Generous space — table is ~1689 × 680 at 1920p, so 4× that gives breathing room
  final float ENV_HW         = 2800;   // half-width  (X)  was 1400
  final float ENV_HD         = 1400;   // half-depth  (Z)  was 600
  final float ENV_TOP        = -900;   // ceiling Y        was -400
  float ENV_BOT_OFFSET =  320;   // floor offset below tableY

  TableTennis3DScene() {
    super();
  }

  void relayoutForBuffer(int w, int h) {
    super.relayoutForBuffer(w, h);
    float tw = w * 0.88;
    TABLE_DEPTH = tw * (1.525 / 2.74);
    NET_H = tw * (0.1525 / 2.74);
    ENV_BOT_OFFSET = tw * (0.76 / 2.74);
    
    // Update player home positions so they stand exactly at the table edges
    float cx = w / 2.0;
    leftHomeX = cx - tw / 2.0;
    rightHomeX = cx + tw / 2.0;
    
    floorY = tableY + ENV_BOT_OFFSET; 
  }

  void onEnter() {
    super.onEnter();
    playerTargetY = tableY - 120;
    playerTargetZ = 0;
    floorY = tableY + ENV_BOT_OFFSET;
    if (projectedSceneIdx != -1) {
      scenes[PROJECTABLE_SCENES[projectedSceneIdx]].onEnter();
    }
  }

  void onExit() {
    super.onExit();
    if (projectedSceneIdx != -1) {
      scenes[PROJECTABLE_SCENES[projectedSceneIdx]].onExit();
    }
  }

  // ── 2-bounce escape rule ──────────────────────────────────────────────────
  // Overrides the parent's instant-score so the ball can travel past the paddle
  // into the enclosure and only scores when it bounces twice on the floor or
  // exits through the back wall.
  void checkEscape() {
    if (!outOfBounds) {
      int escapedSide = 0;
      if (ballX < leftHomeX - 80)        escapedSide = -1;
      else if (ballX > rightHomeX + 80)  escapedSide = 1;
      if (escapedSide != 0) {
        outOfBounds    = true;
        // Determine winner now (uses lastBounceSide before further bounces),
        // then defer the actual score until the 2-bounce / wall-exit trigger.
        outLeftScored  = escapeWinnerLeft(escapedSide);
        outBounceCount = 0;
      }
      return;
    }

    float cx     = sceneBuffer.width / 2.0;
    float backWallL = cx - ENV_HW;   // X position of left enclosure wall
    float backWallR = cx + ENV_HW;   // X position of right enclosure wall

    // Back wall exit → immediate point
    if (ballX < backWallL || ballX > backWallR) {
      outOfBounds = false;
      awardPoint(outLeftScored);
      return;
    }

    // Back wall deflection (bounce off wall instead of exiting)
    if (ballX <= backWallL + BALL_RADIUS && ballVX < 0) {
      ballX  = backWallL + BALL_RADIUS;
      ballVX *= -0.55;
    } else if (ballX >= backWallR - BALL_RADIUS && ballVX > 0) {
      ballX  = backWallR - BALL_RADIUS;
      ballVX *= -0.55;
    }

    // Floor bounce tracking (floor is below the table surface)
    if (ballY + BALL_RADIUS >= floorY && ballVY > 0) {
      ballY  = floorY - BALL_RADIUS;
      ballVY *= -0.50;
      ballVX *= 0.80;
      outBounceCount++;
      if (outBounceCount >= 2) {
        outOfBounds = false;
        awardPoint(outLeftScored);
      }
    }
  }

  // ── lazy shader/buffer init ───────────────────────────────────────────────

  void ensureResources(PGraphics pg) {
    if (innerBuf == null || innerBuf.width != pg.width || innerBuf.height != pg.height) {
      innerBuf = createGraphics(pg.width, pg.height, P3D);
      innerBuf.smooth(4); // MSAA — removes jagged edges on net, table, paddles
    }
    if (tableTexture == null) {
      tableTexture = createGraphics(1024, 1024, P3D);
      tableTexture.smooth(2);
    }
    if (acidShader     == null) acidShader     = loadShader("tt3d_acid.glsl");
    if (chromaticShader == null) chromaticShader = loadShader("tt3d_chromatic.glsl");
    if (neonShader     == null) neonShader     = loadShader("tt3d_neon.glsl");
  }

  PShader activeShader() {
    if (shaderStyle == 1) return acidShader;
    if (shaderStyle == 2) return chromaticShader;
    if (shaderStyle == 3) return neonShader;
    return null;
  }

  void updateShaderUniforms(PShader sh, float bass) {
    sh.set("u_bass",      constrain(bass * 2.5, 0, 1));
    sh.set("u_intensity", 1.0);
    if (shaderStyle == 1 || shaderStyle == 2) sh.set("u_time", sceneTime);
  }

  // ── main draw ─────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    ensureResources(pg);
    
    if (projectedSceneIdx != -1) {
      isProjecting = true;
      tableTexture.beginDraw();
      tableTexture.pushStyle();
      tableTexture.pushMatrix();
      tableTexture.background(0);
      scenes[PROJECTABLE_SCENES[projectedSceneIdx]].drawScene(tableTexture);
      tableTexture.popMatrix();
      tableTexture.popStyle();
      tableTexture.endDraw();
      isProjecting = false;
    }

    // Re-derive table layout from current buffer dims, same as the parent's
    // drawScene does. Without this, tableY is frozen to constructor-time dims
    // and the camera lookAt point drifts whenever the buffer is resized.
    relayoutForBuffer(pg.width, pg.height);
    sceneTime += 1.0 / 60.0;

    float bass = 0, mid = 0;
    for (int i = 0;  i < 8;  i++) bass += analyzer.spectrum[i];
    for (int i = 8;  i < 24; i++) mid  += analyzer.spectrum[i];
    bass /= 8.0;
    mid  /= 16.0;

    if (analyzer.isBeat) onBeat(bass, mid);
    impactFlash *= 0.82;
    pointFlash  *= 0.88;
    beatGlow    *= 0.93;
    powerFlash  *= 0.85;
    bassSmooth   = lerp(bassSmooth, bass, 0.15);
    powerReady   = beatGlow > 0.4;
    shake       *= 0.80;
    if (powerFlash > 0.7) shake = powerFlash * 7;

    applyPlayerKeyboard();
    updatePaddleTargets();
    movePaddles();
    updateZPhysics();   // Z first so paddle Z is fresh when collision fires
    updatePhysics();

    trail3D.add(new PVector(ballX, ballY, ballZ));
    if (trail3D.size() > MAX_TRAIL) trail3D.remove(0);

    // ── Render 3D scene to innerBuf ──────────────────────────────────────────
    innerBuf.beginDraw();
    innerBuf.background(10, 28, 10);

    float scale = pg.height / CAM_RADIUS_BASELINE_H;
    float radius = (camRadius - powerFlash * 80) * scale;
    float cx = pg.width / 2.0;
    float cy = tableY - 60;
    float cz = 0;

    float shakeX = shake > 0.1 ? random(-shake, shake) : 0;
    float shakeY = shake > 0.1 ? random(-shake, shake) * 0.3 : 0;
    float eyeX = cx + radius * cos(camElev) * sin(camAzim) + shakeX;
    float eyeY = cy - radius * sin(camElev)                + shakeY;
    float eyeZ = cz + radius * cos(camElev) * cos(camAzim);

    innerBuf.camera(eyeX, eyeY, eyeZ, cx, cy, cz, 0, 1, 0);
    innerBuf.perspective(PI / 3.0, (float)innerBuf.width / innerBuf.height, 10, 12000);

    innerBuf.ambientLight(25, 55, 25);
    innerBuf.directionalLight(160, 200, 160, 0.2, 1.0, -0.4);
    float bl = 80 + beatGlow * 175;
    innerBuf.pointLight((int)(bl * 0.85), (int)bl, (int)(bl * 0.5), ballX, ballY, ballZ);
    if (powerFlash > 0.05)
      innerBuf.pointLight(255, 210, 60, ballX, ballY, ballZ);

    drawEnvironmentFloor(innerBuf);
    drawTable(innerBuf);
    drawTrail(innerBuf);
    drawPaddles(innerBuf);
    drawBall(innerBuf);
    drawEnvironmentWalls(innerBuf, bass, mid);

    innerBuf.endDraw();

    // ── Post-process blit to pg ───────────────────────────────────────────────
    pg.camera();
    pg.perspective();
    pg.noLights();
    pg.hint(DISABLE_DEPTH_TEST);

    PShader sh = activeShader();
    if (sh != null) {
      updateShaderUniforms(sh, bass);
      pg.shader(sh);
    }
    pg.image(innerBuf, 0, 0);
    if (sh != null) pg.resetShader();

    // ── HUD draws directly on pg (no post-process) ───────────────────────────
    drawScore(pg);
    drawHUD(pg);
    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);

    pg.hint(ENABLE_DEPTH_TEST);
  }

  // ── Z physics ─────────────────────────────────────────────────────────────

  void updateZPhysics() {
    if (inServeDrop) {
      ballZ        = lerp(ballZ, 0, 0.06);
      ballVZ      *= 0.88;
      leftPaddleZ  = lerp(leftPaddleZ,  0, 0.08);
      rightPaddleZ = lerp(rightPaddleZ, 0, 0.08);
      prevRallyCount = 0;
      return;
    }

    if (rallyCount > prevRallyCount) {
      float maxZ = powerReady ? 7.0 : 4.5;
      ballVZ = random(-maxZ, maxZ);
    }
    if (rallyCount == 0 && prevRallyCount > 0) {
      ballZ  = 0;
      ballVZ = 0;
      trail3D.clear();
    }
    prevRallyCount = rallyCount;

    ballVZ *= 0.994;
    ballZ  += ballVZ;

    float zEdge = TABLE_DEPTH / 2.0 - BALL_RADIUS * 2;
    if (ballZ > zEdge) {
      ballZ  =  zEdge;
      ballVZ *= -0.65;
    } else if (ballZ < -zEdge) {
      ballZ  = -zEdge;
      ballVZ *= -0.65;
    }

    // Predict ball Z at intercept so AI doesn't chase current position but destination.
    float zEdgePred = TABLE_DEPTH / 2.0 - BALL_RADIUS * 2;
    float tLeft  = abs(ballX - leftPaddleX)  / max(abs(ballVX), 0.5);
    float tRight = abs(rightPaddleX - ballX) / max(abs(ballVX), 0.5);
    // Simple linear prediction with Z drag (0.994^t ≈ well-approximated as linear for typical t)
    float predZL = constrain(ballZ + ballVZ * tLeft,  -zEdgePred, zEdgePred);
    float predZR = constrain(ballZ + ballVZ * tRight, -zEdgePred, zEdgePred);
    float zSpeed = 0.09;   // faster tracking now that prediction is accurate

    if (playerSide == 1) {
      leftPaddleZ  = lerp(leftPaddleZ, playerTargetZ, 0.18);
      rightPaddleZ = lerp(rightPaddleZ, ballVX > 0 ? predZR : 0, zSpeed);
    } else if (playerSide == 2) {
      rightPaddleZ = lerp(rightPaddleZ, playerTargetZ, 0.18);
      leftPaddleZ  = lerp(leftPaddleZ, ballVX < 0 ? predZL : 0, zSpeed);
    } else {
      if (ballVX < 0) {
        leftPaddleZ  = lerp(leftPaddleZ,  predZL, zSpeed);
        rightPaddleZ = lerp(rightPaddleZ, 0,      zSpeed * 0.5);
      } else {
        rightPaddleZ = lerp(rightPaddleZ, predZR, zSpeed);
        leftPaddleZ  = lerp(leftPaddleZ,  0,      zSpeed * 0.5);
      }
    }
  }

  void checkPaddleCollision(boolean isLeft, float paddleX, float paddleY) {
    float pz = isLeft ? leftPaddleZ : rightPaddleZ;
    if (abs(ballZ - pz) > PADDLE_Z / 2.0 + BALL_RADIUS) return;
    super.checkPaddleCollision(isLeft, paddleX, paddleY);
  }

  // ── player control helpers ────────────────────────────────────────────────

  // Override AI target-setting so the human side uses playerTargetY instead.
  void updatePaddleTargets() {
    super.updatePaddleTargets();
    if (playerSide == 0) return;
    float yMin = PADDLE_H / 2;
    float yMax = tableY - PADDLE_H / 2 - 4;
    playerTargetY = constrain(playerTargetY, yMin, yMax);
    if (playerSide == 1) {
      leftTargetY = playerTargetY;
      leftTargetX = leftHomeX;
    } else {
      rightTargetY = playerTargetY;
      rightTargetX = rightHomeX;
    }
  }

  // Poll held keyboard keys each frame for smooth paddle movement.
  void applyPlayerKeyboard() {
    if (playerSide == 0 || !keyPressed) return;
    float ySpeed = 6.0;
    float zSpeed = 5.0;
    if (key == 'i' || key == 'I') playerTargetY -= ySpeed;
    if (key == 'k' || key == 'K') playerTargetY += ySpeed;
    if (key == 'j' || key == 'J') playerTargetZ -= zSpeed;
    if (key == 'm' || key == 'M') playerTargetZ += zSpeed;
  }

  // Reset out-of-bounds state on each serve
  void serve() {
    outOfBounds    = false;
    outBounceCount = 0;
    super.serve();
  }

  void cyclePlayer() {
    playerSide = (playerSide + 1) % 3;
    // Snap player target to current AI paddle position so there's no jump
    if (playerSide == 1) { playerTargetY = leftPaddleY;  playerTargetZ = leftPaddleZ; }
    if (playerSide == 2) { playerTargetY = rightPaddleY; playerTargetZ = rightPaddleZ; }
  }

  // ── environment floor ─────────────────────────────────────────────────────

  void drawEnvironmentFloor(PGraphics pg) {
    float cx   = pg.width / 2.0;
    float yBot = tableY + ENV_BOT_OFFSET;

    pg.pushStyle();
    pg.noStroke();

    pg.fill(12, 28, 12);
    pg.pushMatrix();
    pg.translate(cx, yBot + 3, 0);
    pg.box(ENV_HW * 2, 6, ENV_HD * 2);
    pg.popMatrix();

    pg.noLights();
    pg.stroke(0, 90, 0, 90);
    pg.strokeWeight(1);
    float step = 140;
    for (float gx = cx - ENV_HW; gx <= cx + ENV_HW + 1; gx += step) {
      pg.line(gx, yBot, -ENV_HD, gx, yBot, ENV_HD);
    }
    for (float gz = -ENV_HD; gz <= ENV_HD + 1; gz += step) {
      pg.line(cx - ENV_HW, yBot, gz, cx + ENV_HW, yBot, gz);
    }
    pg.noStroke();
    pg.lights();

    pg.popStyle();
  }

  // ── environment walls (expanded + animated) ───────────────────────────────

  void drawEnvironmentWalls(PGraphics pg, float bass, float mid) {
    float cx   = pg.width / 2.0;
    float yTop = ENV_TOP;
    float yBot = tableY + ENV_BOT_OFFSET;
    float roomH = yBot - yTop;
    float xL   = cx - ENV_HW;
    float xR   = cx + ENV_HW;
    float zN   =  ENV_HD;
    float zF   = -ENV_HD;

    pg.pushStyle();
    pg.noStroke();
    pg.noLights();
    pg.hint(DISABLE_DEPTH_MASK);

    // ── Base semi-transparent walls ───────────────────────────────────────────
    pg.blendMode(ADD);
    pg.fill(30, 60, 100, 14);

    pg.beginShape(QUADS);
    pg.vertex(xL, yTop, zN); pg.vertex(xR, yTop, zN);
    pg.vertex(xR, yBot, zN); pg.vertex(xL, yBot, zN);
    pg.endShape();

    pg.beginShape(QUADS);
    pg.vertex(xL, yTop, zF); pg.vertex(xR, yTop, zF);
    pg.vertex(xR, yBot, zF); pg.vertex(xL, yBot, zF);
    pg.endShape();

    pg.beginShape(QUADS);
    pg.vertex(xL, yTop, zF); pg.vertex(xL, yTop, zN);
    pg.vertex(xL, yBot, zN); pg.vertex(xL, yBot, zF);
    pg.endShape();

    pg.beginShape(QUADS);
    pg.vertex(xR, yTop, zF); pg.vertex(xR, yTop, zN);
    pg.vertex(xR, yBot, zN); pg.vertex(xR, yBot, zF);
    pg.endShape();

    pg.fill(15, 35, 60, 9);
    pg.beginShape(QUADS);
    pg.vertex(xL, yTop, zF); pg.vertex(xR, yTop, zF);
    pg.vertex(xR, yTop, zN); pg.vertex(xL, yTop, zN);
    pg.endShape();

    // ── Animated scan ring (moves down the walls over time) ──────────────────
    // Position oscillates based on sceneTime
    float scanFrac  = (sceneTime * 0.18) % 1.0;
    float scanY     = yTop + roomH * scanFrac;
    float scanBand  = 18 + bassSmooth * 45;
    float scanAlpha = 22 + bassSmooth * 60;

    pg.colorMode(HSB, 360, 255, 255, 255);
    // Slow hue drift — 8°/sec feels smooth without flickering
    float scanHue = (sceneTime * 8) % 360;
    pg.fill((int)scanHue, 200, 255, (int)scanAlpha);

    // Near + far wall horizontal band
    pg.beginShape(QUADS);
    pg.vertex(xL, scanY - scanBand, zN); pg.vertex(xR, scanY - scanBand, zN);
    pg.vertex(xR, scanY + scanBand, zN); pg.vertex(xL, scanY + scanBand, zN);
    pg.endShape();
    pg.beginShape(QUADS);
    pg.vertex(xL, scanY - scanBand, zF); pg.vertex(xR, scanY - scanBand, zF);
    pg.vertex(xR, scanY + scanBand, zF); pg.vertex(xL, scanY + scanBand, zF);
    pg.endShape();
    // Side walls
    pg.beginShape(QUADS);
    pg.vertex(xL, scanY - scanBand, zF); pg.vertex(xL, scanY - scanBand, zN);
    pg.vertex(xL, scanY + scanBand, zN); pg.vertex(xL, scanY + scanBand, zF);
    pg.endShape();
    pg.beginShape(QUADS);
    pg.vertex(xR, scanY - scanBand, zF); pg.vertex(xR, scanY - scanBand, zN);
    pg.vertex(xR, scanY + scanBand, zN); pg.vertex(xR, scanY + scanBand, zF);
    pg.endShape();

    // ── Vertical neon bars on walls (pulse with bass) ──────────────────────
    // Evenly spaced bars on near/far walls; colour shifts with time
    float barStep = ENV_HW * 2 / 7.0;
    for (int bi = 0; bi <= 7; bi++) {
      float bx   = xL + bi * barStep;
      float bHue = (scanHue + bi * 50) % 360;
      float bAlpha = 22 + bassSmooth * 70;
      float bWidth = 4 + bassSmooth * 18;

      pg.fill((int)bHue, 220, 255, (int)bAlpha);
      // Near wall bar
      pg.beginShape(QUADS);
      pg.vertex(bx - bWidth, yTop, zN); pg.vertex(bx + bWidth, yTop, zN);
      pg.vertex(bx + bWidth, yBot, zN); pg.vertex(bx - bWidth, yBot, zN);
      pg.endShape();
      // Far wall bar
      pg.beginShape(QUADS);
      pg.vertex(bx - bWidth, yTop, zF); pg.vertex(bx + bWidth, yTop, zF);
      pg.vertex(bx + bWidth, yBot, zF); pg.vertex(bx - bWidth, yBot, zF);
      pg.endShape();
    }

    // Horizontal bars on side walls
    float hBarStep = ENV_HD * 2 / 5.0;
    for (int bi = 0; bi <= 5; bi++) {
      float bz   = zF + bi * hBarStep;
      float bHue = (scanHue + bi * 65 + 120) % 360;
      float bAlpha = 18 + bassSmooth * 55;
      float bWidth = 4 + bassSmooth * 14;

      pg.fill((int)bHue, 210, 255, (int)bAlpha);
      pg.beginShape(QUADS);
      pg.vertex(xL, yTop, bz - bWidth); pg.vertex(xL, yTop, bz + bWidth);
      pg.vertex(xL, yBot, bz + bWidth); pg.vertex(xL, yBot, bz - bWidth);
      pg.endShape();
      pg.beginShape(QUADS);
      pg.vertex(xR, yTop, bz - bWidth); pg.vertex(xR, yTop, bz + bWidth);
      pg.vertex(xR, yBot, bz + bWidth); pg.vertex(xR, yBot, bz - bWidth);
      pg.endShape();
    }

    pg.colorMode(RGB, 255);

    // ── Structural edge lines ─────────────────────────────────────────────────
    pg.stroke(60, 120, 200, 45);
    pg.strokeWeight(1.5);
    pg.line(xL, yTop, zN,  xL, yBot, zN);
    pg.line(xR, yTop, zN,  xR, yBot, zN);
    pg.line(xL, yTop, zF,  xL, yBot, zF);
    pg.line(xR, yTop, zF,  xR, yBot, zF);
    pg.line(xL, yTop, zN,  xR, yTop, zN);
    pg.line(xL, yTop, zF,  xR, yTop, zF);
    pg.line(xL, yTop, zF,  xL, yTop, zN);
    pg.line(xR, yTop, zF,  xR, yTop, zN);
    pg.line(xL, yBot, zN,  xR, yBot, zN);
    pg.line(xL, yBot, zF,  xR, yBot, zF);
    pg.line(xL, yBot, zF,  xL, yBot, zN);
    pg.line(xR, yBot, zF,  xR, yBot, zN);

    pg.hint(ENABLE_DEPTH_MASK);
    pg.noStroke();
    pg.blendMode(BLEND);
    pg.lights();
    pg.popStyle();
  }

  // ── 3D table ──────────────────────────────────────────────────────────────

  void drawTable(PGraphics pg) {
    float th    = 18;
    float halfD = TABLE_DEPTH / 2.0;
    float tw    = pg.width * 0.88;
    float tx    = pg.width / 2.0;

    pg.pushStyle();
    pg.noStroke();

    pg.fill(0, 110, 0);
    pg.pushMatrix();
    pg.translate(tx, tableY + th / 2.0, 0);
    pg.box(tw, th, TABLE_DEPTH);
    pg.popMatrix();

    pg.fill(0, 75, 0);
    pg.pushMatrix();
    pg.translate(tx - tw / 2.0, tableY + th / 2.0, 0);
    pg.box(12, th + 4, TABLE_DEPTH + 4);
    pg.popMatrix();
    pg.pushMatrix();
    pg.translate(tx + tw / 2.0, tableY + th / 2.0, 0);
    pg.box(12, th + 4, TABLE_DEPTH + 4);
    pg.popMatrix();

    pg.noLights();
    pg.fill(255, 255, 255, 220);
    pg.pushMatrix();
    pg.translate(tx - tw / 2.0, tableY - 1, 0);
    pg.box(3, 3, TABLE_DEPTH);
    pg.popMatrix();
    pg.pushMatrix();
    pg.translate(tx + tw / 2.0, tableY - 1, 0);
    pg.box(3, 3, TABLE_DEPTH);
    pg.popMatrix();
    pg.pushMatrix();
    pg.translate(tx, tableY - 1, -halfD);
    pg.box(tw, 3, 3);
    pg.popMatrix();
    pg.pushMatrix();
    pg.translate(tx, tableY - 1, halfD);
    pg.box(tw, 3, 3);
    pg.popMatrix();
    
    // Center line (divides the table lengthwise)
    pg.pushMatrix();
    pg.translate(tx, tableY - 1, 0);
    pg.box(tw, 3, 3);
    pg.popMatrix();

    if (projectedSceneIdx != -1) {
      pg.pushStyle();
      pg.noStroke();
      pg.noLights();
      float yTop = tableY - 1.0; // Place it 1px ABOVE the table (Y grows downwards)
      pg.pushMatrix();
      pg.translate(tx, yTop, 0);
      pg.rotateX(HALF_PI); // Lay flat on the table
      pg.imageMode(CENTER);
      pg.noTint(); // Don't let previous fill colors tint the texture
      pg.image(tableTexture, 0, 0, tw, TABLE_DEPTH);
      pg.popMatrix();
      pg.popStyle();
      pg.lights();
    } else {
      pg.fill(255, 255, 255, 255);
      pg.pushMatrix();
      pg.translate(tx, tableY - 2, 0);
      pg.box(4, 4, TABLE_DEPTH);
      pg.popMatrix();
      pg.lights();
    }

    pg.fill(230, 230, 230, 220);
    pg.pushMatrix();
    pg.translate(tx, tableY - NET_H / 2.0, 0);
    pg.box(6, NET_H, TABLE_DEPTH + 16);
    pg.popMatrix();
    pg.fill(160, 160, 160);
    pg.pushMatrix();
    pg.translate(tx, tableY - NET_H / 2.0, -(halfD + 8));
    pg.box(14, NET_H + 8, 14);
    pg.popMatrix();
    pg.pushMatrix();
    pg.translate(tx, tableY - NET_H / 2.0, halfD + 8);
    pg.box(14, NET_H + 8, 14);
    pg.popMatrix();

    pg.popStyle();
  }

  // ── 3D paddles ────────────────────────────────────────────────────────────

  void drawPaddles(PGraphics pg) {
    float lx      = leftPaddleX  + leftLungeX;
    float rx      = rightPaddleX - rightLungeX;
    float breathe = bassSmooth * 18;
    float lh      = PADDLE_H + breathe;
    float rh      = PADDLE_H + breathe;
    float faceR   = PADDLE_Z * 0.46 + breathe * 0.25;
    float lpz = leftPaddleZ;
    float rpz = rightPaddleZ;

    pg.pushStyle();
    pg.noStroke();

    if (beatGlow > 0.05) {
      boolean leftActive = ballVX < 0;
      float ax = leftActive ? lx : rx;
      float ay = leftActive ? leftPaddleY : rightPaddleY;
      float az = leftActive ? lpz : rpz;
      float ah = leftActive ? lh : rh;
      pg.colorMode(HSB, 360, 255, 255, 255);
      float hue = powerReady ? 45 : 200;
      pg.noLights();
      pg.blendMode(ADD);
      pg.hint(DISABLE_DEPTH_MASK);
      for (int ring = 3; ring >= 1; ring--) {
        float sp = ring * 14 * beatGlow;
        pg.fill((int)hue, 220, 255, (int)(beatGlow * 55 / ring));
        pg.pushMatrix();
        pg.translate(ax, ay, az);
        pg.scale(PADDLE_D * 0.5 / faceR, 1.0, 1.0);
        pg.sphere(faceR + sp);
        pg.popMatrix();
      }
      pg.hint(ENABLE_DEPTH_MASK);
      pg.blendMode(BLEND);
      pg.colorMode(RGB, 255);
      pg.lights();
    }

    if (powerFlash > 0.05) {
      pg.noLights();
      pg.blendMode(ADD);
      pg.hint(DISABLE_DEPTH_MASK);
      pg.fill(255, 200, 50, (int)(powerFlash * 70));
      float burstR = powerFlash * 80;
      pg.pushMatrix(); pg.translate(lx, leftPaddleY,  lpz); pg.sphere(burstR); pg.popMatrix();
      pg.pushMatrix(); pg.translate(rx, rightPaddleY, rpz); pg.sphere(burstR); pg.popMatrix();
      pg.hint(ENABLE_DEPTH_MASK);
      pg.blendMode(BLEND);
      pg.lights();
    }

    if (impactFlash > 0.05) {
      pg.noLights();
      pg.hint(DISABLE_DEPTH_MASK);
      pg.fill(255, 255, 255, (int)(impactFlash * 90));
      pg.pushMatrix(); pg.translate(lx, leftPaddleY,  lpz); pg.scale(PADDLE_D * 0.5 / faceR, 1.0, 1.0); pg.sphere(faceR + 14); pg.popMatrix();
      pg.pushMatrix(); pg.translate(rx, rightPaddleY, rpz); pg.scale(PADDLE_D * 0.5 / faceR, 1.0, 1.0); pg.sphere(faceR + 14); pg.popMatrix();
      pg.hint(ENABLE_DEPTH_MASK);
      pg.lights();
    }

    pg.fill(200, 35, 35);
    drawRacket(pg, lx, leftPaddleY, lpz, faceR);

    pg.fill(35, 35, 200);
    drawRacket(pg, rx, rightPaddleY, rpz, faceR);

    pg.popStyle();
  }

  void drawRacket(PGraphics pg, float px, float py, float pz, float faceR) {
    float faceY   = py - PADDLE_H * 0.08;
    float handleH = PADDLE_H * 0.50;
    float handleW = PADDLE_Z * 0.21;
    float handleY = faceY + faceR + handleH * 0.52 + 3;

    pg.pushMatrix();
    pg.translate(px, faceY, pz);
    pg.scale(PADDLE_D * 0.5 / faceR, 1.0, 1.0);
    pg.sphere(faceR);
    pg.popMatrix();

    pg.fill(135, 78, 28);
    pg.pushMatrix();
    pg.translate(px, handleY, pz);
    pg.box(PADDLE_D, handleH, handleW);
    pg.popMatrix();
  }

  // ── 3D ball ───────────────────────────────────────────────────────────────

  void drawBall(PGraphics pg) {
    pg.pushStyle();

    // ── Shadow on table surface — shows exact X/Z position ───────────────────
    // Scales down as ball rises; disappears above roughly 3× ball radius off table.
    float ballAbove = tableY - ballY;   // >0 means ball is above table (Y goes down)
    if (ballAbove > 0 && ballAbove < 500) {
      float shadowFade = max(0, 1.0 - ballAbove / 400.0);
      float shadowR    = BALL_RADIUS * (0.4 + shadowFade * 0.6);
      pg.noLights();
      pg.blendMode(BLEND);
      pg.noStroke();
      pg.hint(DISABLE_DEPTH_MASK);
      pg.fill(0, 0, 0, (int)(shadowFade * 110));
      pg.pushMatrix();
      pg.translate(ballX, tableY - 1, ballZ);
      pg.rotateX(HALF_PI);
      pg.ellipse(0, 0, shadowR * 2, shadowR * 2);
      pg.popMatrix();
      pg.hint(ENABLE_DEPTH_MASK);
      pg.lights();
    }

    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();

    float gf = max(impactFlash, powerFlash);
    if (gf > 0.05) {
      pg.noLights();
      pg.blendMode(ADD);
      pg.hint(DISABLE_DEPTH_MASK);
      pg.fill((int)ballHue, 200, 255, (int)(gf * 75));
      pg.pushMatrix();
      pg.translate(ballX, ballY, ballZ);
      pg.sphere(BALL_RADIUS * 4.5 * gf);
      pg.popMatrix();
      pg.hint(ENABLE_DEPTH_MASK);
      pg.blendMode(BLEND);
      pg.lights();
    }

    pg.fill((int)ballHue, 160, 255);
    pg.pushMatrix();
    pg.translate(ballX, ballY, ballZ);
    pg.sphere(BALL_RADIUS);
    pg.popMatrix();

    pg.colorMode(RGB, 255);
    pg.popStyle();
  }

  // ── 3D trail ──────────────────────────────────────────────────────────────

  void drawTrail(PGraphics pg) {
    if (trail3D.size() < 2) return;
    pg.pushStyle();
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noFill();
    pg.noLights();
    for (int i = 1; i < trail3D.size(); i++) {
      float a = map(i, 0, trail3D.size(), 0, 130);
      float w = map(i, 0, trail3D.size(), 0.5, BALL_RADIUS * 0.65);
      pg.stroke((int)ballHue, 180, 255, (int)a);
      pg.strokeWeight(w);
      PVector p = trail3D.get(i - 1);
      PVector c = trail3D.get(i);
      pg.line(p.x, p.y, p.z, c.x, c.y, c.z);
    }
    pg.lights();
    pg.colorMode(RGB, 255);
    pg.popStyle();
  }

  // ── camera control ────────────────────────────────────────────────────────

  void applyController(Controller c) {
    float lxN = map(c.lx, 0, width,  -1, 1);
    float lyN = map(c.ly, 0, height, -1, 1);

    if (playerSide > 0) {
      // Left stick → move player paddle
      float yMin = PADDLE_H / 2;
      float yMax = tableY - PADDLE_H / 2 - 4;
      float zLim = TABLE_DEPTH / 2.0 - PADDLE_Z / 2.0;
      if (abs(lyN) > 0.10) playerTargetY = constrain(playerTargetY + lyN * 8, yMin, yMax);
      if (abs(lxN) > 0.10) playerTargetZ = constrain(playerTargetZ + lxN * 7, -zLim, zLim);
    } else {
      // Left stick Y → camera zoom (only in AI mode)
      if (abs(lyN) > 0.15) camRadius = constrain(camRadius + lyN * 12, 350, 2200);
    }

    // Right stick → always orbits camera
    float rxN = map(c.rx, 0, width,  -1, 1);
    float ryN = map(c.ry, 0, height, -1, 1);
    if (abs(rxN) > 0.15) camAzim += rxN * 0.030;
    if (abs(ryN) > 0.15) camElev  = constrain(camElev + ryN * 0.020, 0.08, PI / 2 - 0.05);

    if (c.xJustPressed) adjustSpeed(-0.1);
    if (c.yJustPressed) adjustSpeed( 0.1);
    if (c.bJustPressed) cyclePlayer();

    // D-pad L/R → cycle shader style
    if (c.dpadLeftJustPressed)  cycleShader(-1);
    if (c.dpadRightJustPressed) cycleShader( 1);
    if (c.dpadUpJustPressed)    cycleProjectedScene();
    if (c.dpadDownJustPressed)  disableProjectedScene();
  }

  void cycleProjectedScene() {
    if (projectedSceneIdx != -1) {
      scenes[PROJECTABLE_SCENES[projectedSceneIdx]].onExit();
    }
    projectedSceneIdx++;
    if (projectedSceneIdx >= PROJECTABLE_SCENES.length) {
      projectedSceneIdx = -1;
    } else {
      scenes[PROJECTABLE_SCENES[projectedSceneIdx]].onEnter();
    }
  }

  void disableProjectedScene() {
    if (projectedSceneIdx != -1) {
      scenes[PROJECTABLE_SCENES[projectedSceneIdx]].onExit();
      projectedSceneIdx = -1;
    }
  }

  // a/d → orbit  |  w/e → tilt  |  z/x → zoom
  // f → cycle FX shader  |  v → cycle player control
  // i/k → paddle up/down (player mode)  |  j/m → paddle Z depth (player mode)
  // u → cycle projected scene  |  o → disable projection
  void handleKey(char k) {
    if      (k == 'a' || k == 'A') camAzim -= 0.12;
    else if (k == 'd' || k == 'D') camAzim += 0.12;
    else if (k == 'w' || k == 'W') camElev  = constrain(camElev + 0.10, 0.08, PI / 2 - 0.05);
    else if (k == 'e' || k == 'E') camElev  = constrain(camElev - 0.10, 0.08, PI / 2 - 0.05);
    else if (k == 'z' || k == 'Z') camRadius = constrain(camRadius - 80, 350, 2200);
    else if (k == 'x' || k == 'X') camRadius = constrain(camRadius + 80, 350, 2200);
    else if (k == 'f' || k == 'F') cycleShader(1);
    else if (k == 'v' || k == 'V') cyclePlayer();
    else if (k == 'u' || k == 'U') cycleProjectedScene();
    else if (k == 'o' || k == 'O') disableProjectedScene();
    else super.handleKey(k);
  }

  void cycleShader(int dir) {
    shaderStyle = (shaderStyle + dir + STYLE_NAMES.length) % STYLE_NAMES.length;
  }

  // ── HUD (override to add shader style line) ───────────────────────────────

  void drawHUD(PGraphics pg) {
    String sp = spin > 0.05 ? "topspin" : spin < -0.05 ? "backspin" : "flat";
    String[] playerLabels = {"AI vs AI", "YOU (left/red)", "YOU (right/blue)"};
    sceneHUD(pg, "Table Tennis 3D", new String[]{
      "Spin: " + sp + " (" + nf(spin,1,2) + ")",
      "Gravity: " + nf(gravity,1,2) + "  (+/-)   Magnus: " + nf(magnusStrength,1,3) + "  ([/])",
      "Speed: " + nf(speedMult,1,1) + "x  (,/.)   Cam: WASD/EZ or R-stick",
      "FX: " + STYLE_NAMES[shaderStyle] + "  (F / D-pad)",
      "Player: " + playerLabels[playerSide] + "  (V / B btn)"
    });
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
