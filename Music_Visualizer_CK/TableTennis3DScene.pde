// Table Tennis 3D Scene — state 25
//
// Extends TableTennisScene: inherits all physics, rules, AI, scoring,
// beat-glow, power shots, and bass breathing.
//
// Adds Z-axis shot variation: each paddle hit gives the ball a random
// lateral (Z) velocity. Ball bounces off the table's Z edges.
// Racket shapes: oval face (flattened sphere) + wooden handle.

class TableTennis3DScene extends TableTennisScene {

  // ── orbit camera ──────────────────────────────────────────────────────────
  float camAzim   =  0.15;    // horizontal angle around table (radians)
  float camElev   =  0.42;    // vertical tilt (radians; 0=horizontal, PI/2=straight down)
  float camRadius = 950;      // distance from orbit centre
  float shake     =  0;

  // ── table dimensions ──────────────────────────────────────────────────────
  final float TABLE_DEPTH = 680;   // Z extent of the table
  final float PADDLE_D    = 18;    // racket face thickness (X axis, thin)
  final float PADDLE_Z    = 130;   // racket face Z width (bat-sized)

  // ── Z physics (supplementary — ball Z is 0 in parent) ────────────────────
  float ballZ      = 0;
  float ballVZ     = 0;
  int   prevRallyCount = 0;

  // ── paddle Z positions (3D only — parent only tracks X/Y) ────────────────
  float leftPaddleZ  = 0;
  float rightPaddleZ = 0;

  // ── 3D trail (includes Z) ─────────────────────────────────────────────────
  ArrayList<PVector> trail3D = new ArrayList<PVector>();

  TableTennis3DScene() {
    super();
  }

  // ── main draw ─────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    pg.background(10, 28, 10);

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

    // Physics — inherited 2D physics + our Z layer
    updatePaddleTargets();
    movePaddles();
    updatePhysics();
    updateZPhysics();

    // Build the 3D trail (replaces parent's 2D trail in rendering)
    trail3D.add(new PVector(ballX, ballY, ballZ));
    if (trail3D.size() > MAX_TRAIL) trail3D.remove(0);

    // Power-shot zoom: temporarily shrink radius
    float radius = camRadius - powerFlash * 80;

    // Orbit centre — middle of the table/rally area
    float cx = width / 2.0;
    float cy = tableY - 60;    // slightly above the table surface
    float cz = 0;

    // Spherical → Cartesian (Y-down P3D convention: elevation raises the eye = decreases Y)
    float shakeX = shake > 0.1 ? random(-shake, shake) : 0;
    float shakeY = shake > 0.1 ? random(-shake, shake) * 0.3 : 0;
    float eyeX = cx + radius * cos(camElev) * sin(camAzim) + shakeX;
    float eyeY = cy - radius * sin(camElev)                + shakeY;
    float eyeZ = cz + radius * cos(camElev) * cos(camAzim);

    pg.camera(eyeX, eyeY, eyeZ, cx, cy, cz, 0, 1, 0);
    pg.perspective(PI / 3.0, (float)pg.width / pg.height, 10, 8000);

    // Lighting
    pg.ambientLight(25, 55, 25);
    pg.directionalLight(160, 200, 160, 0.2, 1.0, -0.4);
    float bl = 80 + beatGlow * 175;
    pg.pointLight((int)(bl * 0.85), (int)bl, (int)(bl * 0.5), ballX, ballY, ballZ);
    if (powerFlash > 0.05)
      pg.pointLight(255, 210, 60, ballX, ballY, ballZ);

    drawEnvironmentFloor(pg);
    drawTable(pg);
    drawTrail(pg);
    drawPaddles(pg);
    drawBall(pg);
    drawEnvironmentWalls(pg);

    // Reset to screen-space for 2D HUD
    pg.camera();
    pg.perspective();
    pg.noLights();
    pg.hint(DISABLE_DEPTH_TEST);
    drawScore(pg);
    drawHUD(pg);
    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
    pg.hint(ENABLE_DEPTH_TEST);
  }

  // ── Z physics ─────────────────────────────────────────────────────────────

  void updateZPhysics() {
    // During serve drop, drift everything smoothly back to centre
    if (inServeDrop) {
      ballZ        = lerp(ballZ, 0, 0.06);
      ballVZ      *= 0.88;
      leftPaddleZ  = lerp(leftPaddleZ,  0, 0.08);
      rightPaddleZ = lerp(rightPaddleZ, 0, 0.08);
      prevRallyCount = 0;
      return;
    }

    // Detect a new paddle hit (rallyCount just increased)
    if (rallyCount > prevRallyCount) {
      // Power shots get stronger lateral angle
      float maxZ = powerReady ? 7.0 : 4.5;
      ballVZ = random(-maxZ, maxZ);
    }
    // Point scored — rally restarted
    if (rallyCount == 0 && prevRallyCount > 0) {
      ballZ  = 0;
      ballVZ = 0;
      trail3D.clear();
    }
    prevRallyCount = rallyCount;

    ballVZ *= 0.994;
    ballZ  += ballVZ;

    // Bounce off Z table edges
    float zEdge = TABLE_DEPTH / 2.0 - BALL_RADIUS * 2;
    if (ballZ > zEdge) {
      ballZ  =  zEdge;
      ballVZ *= -0.65;
    } else if (ballZ < -zEdge) {
      ballZ  = -zEdge;
      ballVZ *= -0.65;
    }

    // Paddle Z tracking — receiving paddle follows ball Z, other returns to centre
    float zLerpSpeed = 0.06;
    if (ballVX < 0) {
      // Ball heading left — left paddle is the receiver
      leftPaddleZ  = lerp(leftPaddleZ,  ballZ, zLerpSpeed);
      rightPaddleZ = lerp(rightPaddleZ, 0,     zLerpSpeed * 0.5);
    } else {
      // Ball heading right — right paddle is the receiver
      rightPaddleZ = lerp(rightPaddleZ, ballZ, zLerpSpeed);
      leftPaddleZ  = lerp(leftPaddleZ,  0,     zLerpSpeed * 0.5);
    }
  }

  // Override collision to add Z gating — parent only checks X/Y.
  // Ball must be within the paddle's Z half-extent to register a hit.
  void checkPaddleCollision(boolean isLeft, float paddleX, float paddleY) {
    float pz = isLeft ? leftPaddleZ : rightPaddleZ;
    if (abs(ballZ - pz) > PADDLE_Z / 2.0 + BALL_RADIUS) return;
    super.checkPaddleCollision(isLeft, paddleX, paddleY);
  }

  // ── environment (ground + enclosure box) ─────────────────────────────────

  // Shared box dimensions
  final float ENV_HW  = 1400;   // half-width  (X)
  final float ENV_HD  = 600;    // half-depth  (Z)
  final float ENV_TOP = -400;   // ceiling Y
  final float ENV_BOT_OFFSET = 260; // how far below tableY the floor sits

  void drawEnvironmentFloor(PGraphics pg) {
    float cx   = width / 2.0;
    float yBot = tableY + ENV_BOT_OFFSET;

    pg.pushStyle();
    pg.noStroke();

    // Solid floor slab
    pg.fill(12, 28, 12);
    pg.pushMatrix();
    pg.translate(cx, yBot + 3, 0);
    pg.box(ENV_HW * 2, 6, ENV_HD * 2);
    pg.popMatrix();

    // Grid on floor — drawn as 3D lines
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

  void drawEnvironmentWalls(PGraphics pg) {
    float cx   = width / 2.0;
    float yTop = ENV_TOP;
    float yBot = tableY + ENV_BOT_OFFSET;
    float xL   = cx - ENV_HW;
    float xR   = cx + ENV_HW;
    float zN   =  ENV_HD;   // near (toward viewer at +Z)
    float zF   = -ENV_HD;   // far

    pg.pushStyle();
    pg.noStroke();
    pg.noLights();
    pg.blendMode(ADD);

    // Four side walls — very faint blue tint
    pg.fill(30, 60, 100, 18);

    // Near wall
    pg.beginShape(QUADS);
    pg.vertex(xL, yTop, zN); pg.vertex(xR, yTop, zN);
    pg.vertex(xR, yBot, zN); pg.vertex(xL, yBot, zN);
    pg.endShape();

    // Far wall
    pg.beginShape(QUADS);
    pg.vertex(xL, yTop, zF); pg.vertex(xR, yTop, zF);
    pg.vertex(xR, yBot, zF); pg.vertex(xL, yBot, zF);
    pg.endShape();

    // Left wall
    pg.beginShape(QUADS);
    pg.vertex(xL, yTop, zF); pg.vertex(xL, yTop, zN);
    pg.vertex(xL, yBot, zN); pg.vertex(xL, yBot, zF);
    pg.endShape();

    // Right wall
    pg.beginShape(QUADS);
    pg.vertex(xR, yTop, zF); pg.vertex(xR, yTop, zN);
    pg.vertex(xR, yBot, zN); pg.vertex(xR, yBot, zF);
    pg.endShape();

    // Ceiling — even fainter
    pg.fill(20, 40, 70, 10);
    pg.beginShape(QUADS);
    pg.vertex(xL, yTop, zF); pg.vertex(xR, yTop, zF);
    pg.vertex(xR, yTop, zN); pg.vertex(xL, yTop, zN);
    pg.endShape();

    // Edge lines — slightly brighter so the box reads as a solid structure
    pg.stroke(60, 120, 200, 55);
    pg.strokeWeight(1.5);
    // Vertical edges
    pg.line(xL, yTop, zN,  xL, yBot, zN);
    pg.line(xR, yTop, zN,  xR, yBot, zN);
    pg.line(xL, yTop, zF,  xL, yBot, zF);
    pg.line(xR, yTop, zF,  xR, yBot, zF);
    // Top edges
    pg.line(xL, yTop, zN,  xR, yTop, zN);
    pg.line(xL, yTop, zF,  xR, yTop, zF);
    pg.line(xL, yTop, zF,  xL, yTop, zN);
    pg.line(xR, yTop, zF,  xR, yTop, zN);
    // Bottom edges
    pg.line(xL, yBot, zN,  xR, yBot, zN);
    pg.line(xL, yBot, zF,  xR, yBot, zF);
    pg.line(xL, yBot, zF,  xL, yBot, zN);
    pg.line(xR, yBot, zF,  xR, yBot, zN);

    pg.noStroke();
    pg.blendMode(BLEND);
    pg.lights();
    pg.popStyle();
  }

  // ── 3D table ──────────────────────────────────────────────────────────────

  void drawTable(PGraphics pg) {
    float th    = 18;
    float halfD = TABLE_DEPTH / 2.0;
    float tw    = width * 0.88;
    float tx    = width / 2.0;

    pg.pushStyle();
    pg.noStroke();

    // Main surface
    pg.fill(0, 110, 0);
    pg.pushMatrix();
    pg.translate(tx, tableY + th / 2.0, 0);
    pg.box(tw, th, TABLE_DEPTH);
    pg.popMatrix();

    // Side frame rails
    pg.fill(0, 75, 0);
    pg.pushMatrix();
    pg.translate(tx - tw / 2.0, tableY + th / 2.0, 0);
    pg.box(12, th + 4, TABLE_DEPTH + 4);
    pg.popMatrix();
    pg.pushMatrix();
    pg.translate(tx + tw / 2.0, tableY + th / 2.0, 0);
    pg.box(12, th + 4, TABLE_DEPTH + 4);
    pg.popMatrix();

    // White line markings — drawn without lights so they read bright white
    pg.noLights();
    pg.fill(255, 255, 255, 220);
    // Left edge line
    pg.pushMatrix();
    pg.translate(tx - tw / 2.0, tableY - 1, 0);
    pg.box(3, 3, TABLE_DEPTH);
    pg.popMatrix();
    // Right edge line
    pg.pushMatrix();
    pg.translate(tx + tw / 2.0, tableY - 1, 0);
    pg.box(3, 3, TABLE_DEPTH);
    pg.popMatrix();
    // Near end line
    pg.pushMatrix();
    pg.translate(tx, tableY - 1, -halfD);
    pg.box(tw, 3, 3);
    pg.popMatrix();
    // Far end line
    pg.pushMatrix();
    pg.translate(tx, tableY - 1, halfD);
    pg.box(tw, 3, 3);
    pg.popMatrix();
    // Centre line — runs the full Z length, prominent white
    pg.fill(255, 255, 255, 255);
    pg.pushMatrix();
    pg.translate(tx, tableY - 2, 0);
    pg.box(4, 4, TABLE_DEPTH);
    pg.popMatrix();
    pg.lights();

    // Net — spanning full table depth
    pg.fill(230, 230, 230, 220);
    pg.pushMatrix();
    pg.translate(tx, tableY - NET_H / 2.0, 0);
    pg.box(6, NET_H, TABLE_DEPTH + 16);
    pg.popMatrix();
    // Net posts
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

  // ── 3D paddles (rackets) ──────────────────────────────────────────────────

  void drawPaddles(PGraphics pg) {
    float lx      = leftPaddleX  + leftLungeX;
    float rx      = rightPaddleX - rightLungeX;
    float breathe = bassSmooth * 18;
    float lh      = PADDLE_H + breathe;
    float rh      = PADDLE_H + breathe;
    float faceR   = PADDLE_Z * 0.46 + breathe * 0.25;   // oval radius breathes with bass
    float lpz = leftPaddleZ;
    float rpz = rightPaddleZ;

    pg.pushStyle();
    pg.noStroke();

    // ── Beat-glow aura on the receiving paddle ────────────────────────────
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
      for (int ring = 3; ring >= 1; ring--) {
        float sp = ring * 14 * beatGlow;
        pg.fill((int)hue, 220, 255, (int)(beatGlow * 55 / ring));
        pg.pushMatrix();
        pg.translate(ax, ay, az);
        pg.scale(PADDLE_D * 0.5 / faceR, 1.0, 1.0);
        pg.sphere(faceR + sp);
        pg.popMatrix();
      }
      pg.blendMode(BLEND);
      pg.colorMode(RGB, 255);
      pg.lights();
    }

    // ── Power-shot burst ─────────────────────────────────────────────────
    if (powerFlash > 0.05) {
      pg.noLights();
      pg.blendMode(ADD);
      pg.fill(255, 200, 50, (int)(powerFlash * 70));
      float burstR = powerFlash * 80;
      pg.pushMatrix(); pg.translate(lx, leftPaddleY,  lpz); pg.sphere(burstR); pg.popMatrix();
      pg.pushMatrix(); pg.translate(rx, rightPaddleY, rpz); pg.sphere(burstR); pg.popMatrix();
      pg.blendMode(BLEND);
      pg.lights();
    }

    // ── Impact flash ─────────────────────────────────────────────────────
    if (impactFlash > 0.05) {
      pg.noLights();
      pg.fill(255, 255, 255, (int)(impactFlash * 90));
      pg.pushMatrix(); pg.translate(lx, leftPaddleY,  lpz); pg.scale(PADDLE_D * 0.5 / faceR, 1.0, 1.0); pg.sphere(faceR + 14); pg.popMatrix();
      pg.pushMatrix(); pg.translate(rx, rightPaddleY, rpz); pg.scale(PADDLE_D * 0.5 / faceR, 1.0, 1.0); pg.sphere(faceR + 14); pg.popMatrix();
      pg.lights();
    }

    // ── Left racket — red face ────────────────────────────────────────────
    pg.fill(200, 35, 35);
    drawRacket(pg, lx, leftPaddleY, lpz, faceR);

    // ── Right racket — blue face ──────────────────────────────────────────
    pg.fill(35, 35, 200);
    drawRacket(pg, rx, rightPaddleY, rpz, faceR);

    // ── Serve indicator ───────────────────────────────────────────────────
    pg.noLights();
    pg.fill(255, 220, 0, 200);
    pg.pushMatrix();
    pg.translate(leftServes ? lx : rx, tableY - 160, leftServes ? lpz : rpz);
    pg.sphere(9);
    pg.popMatrix();
    pg.lights();

    pg.popStyle();
  }

  // Draws one racket at (px, py, 0): oval face (flattened sphere) + wooden handle.
  // Caller sets pg.fill() for the face colour before calling.
  void drawRacket(PGraphics pg, float px, float py, float pz, float faceR) {
    float faceY   = py - PADDLE_H * 0.08;
    float handleH = PADDLE_H * 0.50;
    float handleW = PADDLE_Z * 0.21;
    float handleY = faceY + faceR + handleH * 0.52 + 3;

    // Oval face — scale a sphere to make it thin in X
    pg.pushMatrix();
    pg.translate(px, faceY, pz);
    pg.scale(PADDLE_D * 0.5 / faceR, 1.0, 1.0);
    pg.sphere(faceR);
    pg.popMatrix();

    // Handle — wood grain colour
    pg.fill(135, 78, 28);
    pg.pushMatrix();
    pg.translate(px, handleY, pz);
    pg.box(PADDLE_D, handleH, handleW);
    pg.popMatrix();
  }

  // ── 3D ball ───────────────────────────────────────────────────────────────

  void drawBall(PGraphics pg) {
    pg.pushStyle();
    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();

    float gf = max(impactFlash, powerFlash);
    if (gf > 0.05) {
      pg.noLights();
      pg.blendMode(ADD);
      pg.fill((int)ballHue, 200, 255, (int)(gf * 75));
      pg.pushMatrix();
      pg.translate(ballX, ballY, ballZ);
      pg.sphere(BALL_RADIUS * 4.5 * gf);
      pg.popMatrix();
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

  // ── camera control ───────────────────────────────────────────────────────

  // Left stick Y → zoom.  Right stick XY → orbit azimuth / elevation.
  // X/Y buttons → ball speed (inherited behaviour kept on those buttons).
  void applyController(Controller c) {
    float ly = map(c.ly, 0, height, -1, 1);
    if (abs(ly) > 0.15) camRadius = constrain(camRadius + ly * 12, 350, 2200);

    float rx = map(c.rx, 0, width,  -1, 1);
    float ry = map(c.ry, 0, height, -1, 1);
    if (abs(rx) > 0.15) camAzim += rx * 0.030;
    if (abs(ry) > 0.15) camElev  = constrain(camElev + ry * 0.020, 0.08, PI / 2 - 0.05);

    // Speed from parent mapping (X=slower, Y=faster)
    if (c.x_just_pressed) adjustSpeed(-0.1);
    if (c.y_just_pressed) adjustSpeed( 0.1);
  }

  // a/d → orbit left/right  |  w/e → tilt up/down  |  z/x → zoom
  // All other keys forwarded to parent (speed ,/. gravity +/- magnus [/])
  void handleKey(char k) {
    if      (k == 'a' || k == 'A') camAzim -= 0.12;
    else if (k == 'd' || k == 'D') camAzim += 0.12;
    else if (k == 'w' || k == 'W') camElev  = constrain(camElev + 0.10, 0.08, PI / 2 - 0.05);
    else if (k == 'e' || k == 'E') camElev  = constrain(camElev - 0.10, 0.08, PI / 2 - 0.05);
    else if (k == 'z' || k == 'Z') camRadius = constrain(camRadius - 80, 350, 2200);
    else if (k == 'x' || k == 'X') camRadius = constrain(camRadius + 80, 350, 2200);
    else super.handleKey(k);
  }

  // ── 3D trail (uses trail3D which has real Z values) ───────────────────────

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
}
