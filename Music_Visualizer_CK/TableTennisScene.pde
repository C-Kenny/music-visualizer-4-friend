// Table Tennis Scene — state 6
//
// Two AI paddles rally. First to 11 wins (must lead by 2).
// Serve alternates every 2 points.
//
// Physics: gravity, Magnus (topspin/backspin), air drag.
// Prediction uses step simulation for accurate multi-bounce targeting.
//
// Controls: +/-  gravity    [/]  Magnus strength

class TableTennisScene implements IScene {

  // ── ball ──────────────────────────────────────────────────────────────────
  float ballX, ballY;
  float ballVX, ballVY;
  float spin;
  final float BALL_RADIUS = 16;
  final float MIN_SPEED_X = 6.0;

  // ── paddles ───────────────────────────────────────────────────────────────
  float leftPaddleX, rightPaddleX;  // fixed X, 20% inset from each edge
  float leftPaddleY, rightPaddleY;
  float leftTargetY, rightTargetY;
  float leftLungeX,  rightLungeX;
  final float PADDLE_W     = 16;
  final float PADDLE_H     = 110;
  final float PADDLE_SPEED = 0.28;

  // ── AI miss system ────────────────────────────────────────────────────────
  final float MISS_CHANCE = 0.15;
  float leftMissOffset  = 0;
  float rightMissOffset = 0;
  int   lastDirSign     = 0;

  // ── table ─────────────────────────────────────────────────────────────────
  float tableY;
  final float NET_H = 55;

  // ── scoring / game state ──────────────────────────────────────────────────
  int leftPoints  = 0;   // points in current game
  int rightPoints = 0;
  int leftGames   = 0;   // games won overall
  int rightGames  = 0;
  int totalPoints = 0;   // total points played this game (drives serve rotation)
  int rallyCount  = 0;   // hits in the current rally (ramps speed slightly)
  boolean leftServes = true;

  // bounce-based point rule
  int lastBounceSide     = 0;
  int consecutiveBounces = 0;

  // serve state machine
  boolean inServeDrop  = true;   // ball falling toward paddle before being hit
  boolean serveBounced = false;  // ball has completed its server-side bounce

  // visual flash on point scored
  float pointFlash  = 0;
  int   pointWinner = 0;

  // ── score log ─────────────────────────────────────────────────────────────
  java.io.PrintWriter scoreLog = null;
  // session-level stats
  int statServerWins   = 0;
  int statReceiverWins = 0;
  int statTotalRallies = 0;
  int statLongRallies  = 0;   // rallies with 5+ hits
  int statMaxRally     = 0;

  // ── physics ───────────────────────────────────────────────────────────────
  float gravity        = 0.28;
  float magnusStrength = 0.045;
  final float DRAG     = 0.999;

  // ── visuals ───────────────────────────────────────────────────────────────
  float ballHue     = 40;
  float impactFlash = 0;
  ArrayList<PVector> trail = new ArrayList<PVector>();
  final int MAX_TRAIL = 45;

  // ── constructor ───────────────────────────────────────────────────────────

  TableTennisScene() {
    openScoreLog();
    tableY       = height * 0.68;
    leftPaddleX  = width * 0.20;
    rightPaddleX = width * 0.80;
    float restY  = tableY - 120;
    leftPaddleY  = rightPaddleY = restY;
    leftTargetY  = rightTargetY = restY;
    serve();
  }

  // ── serve ─────────────────────────────────────────────────────────────────

  void serve() {
    // Ball drops from ~100px above the server's paddle (like a real toss).
    // It falls under gravity; when it reaches paddle height it auto-fires.
    float paddleX = leftServes ? leftPaddleX : rightPaddleX;
    ballX  = paddleX;
    ballY  = tableY - 220;   // above the paddle (which rests at tableY-120)
    ballVX = leftServes ? 0.01 : -0.01;  // tiny drift so dirSign is correct
    ballVY = 0;
    spin   = random(-0.05, 0.05);
    trail.clear();
    impactFlash  = 0;
    inServeDrop  = true;
    serveBounced = false;

    leftMissOffset  = 0;
    rightMissOffset = 0;
    lastDirSign     = leftServes ? -1 : 1;
    lastBounceSide  = 0;
    consecutiveBounces = 0;
  }

  // ── main draw ─────────────────────────────────────────────────────────────

  void drawScene() {
    background(15, 35, 15);

    float bass = 0, mid = 0;
    for (int i = 0; i < 8; i++) bass += analyzer.spectrum[i];
    for (int i = 8; i < 24; i++) mid += analyzer.spectrum[i];
    bass /= 8.0;
    mid /= 16.0;

    if (analyzer.isBeat) onBeat(bass, mid);
    impactFlash *= 0.82;
    pointFlash  *= 0.88;

    drawTable();
    updatePaddleTargets();
    movePaddles();
    updatePhysics();
    drawTrail();
    drawPaddles();
    drawBall();

    drawScore();
    drawHUD();
    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
  }

  // ── beat ──────────────────────────────────────────────────────────────────

  void onBeat(float bass, float mid) {
    float lunge = 14 + bass * 1.2;
    if (ballVX < 0) leftLungeX  = lunge;
    else            rightLungeX = lunge;
    spin += map(mid, 0, 15, -0.03, 0.03);
    spin  = constrain(spin, -0.25, 0.25);
  }

  // ── paddle AI ─────────────────────────────────────────────────────────────

  void updatePaddleTargets() {
    float yMin  = PADDLE_H / 2;
    float yMax  = tableY - BALL_RADIUS;
    float restY = tableY - 120;

    // During serve drop, and while the ball is heading to the server's own side
    // for the mandatory first bounce, prediction is unreliable — the actual
    // serve bounce applies a critVY override that the step sim doesn't know about.
    // Both paddles stay at restY until serveBounced=true so the first real
    // prediction uses the corrected velocity.
    if (inServeDrop || !serveBounced) {
      leftTargetY  = constrain(restY, yMin, yMax);
      rightTargetY = constrain(restY, yMin, yMax);
      return;
    }

    int dirSign = ballVX > 0 ? 1 : -1;

    // Make a fresh miss/hit decision whenever ball changes direction
    if (dirSign != lastDirSign) {
      if (dirSign > 0) {
        // Ball heading toward right paddle
        rightMissOffset = random(1) < MISS_CHANCE
          ? random(-1, 1) * PADDLE_H * 1.5
          : random(-PADDLE_H * 0.15, PADDLE_H * 0.15);
      } else {
        // Ball heading toward left paddle
        leftMissOffset = random(1) < MISS_CHANCE
          ? random(-1, 1) * PADDLE_H * 1.5
          : random(-PADDLE_H * 0.15, PADDLE_H * 0.15);
      }
      lastDirSign = dirSign;
    }

    if (ballVX < 0) {
      float t = abs(ballX - leftPaddleX) / max(abs(ballVX), 0.5);
      leftTargetY  = constrain(predictBallY(t) + leftMissOffset,  yMin, yMax);
      rightTargetY = constrain(restY, yMin, yMax);
    } else {
      float t = abs(rightPaddleX - ballX) / max(abs(ballVX), 0.5);
      rightTargetY = constrain(predictBallY(t) + rightMissOffset, yMin, yMax);
      leftTargetY  = constrain(restY, yMin, yMax);
    }
  }

  // Step simulation — correctly handles any number of table bounces
  float predictBallY(float frames) {
    float py = ballY;
    float vy = ballVY;
    int   steps = min((int)frames, 240);
    for (int step = 0; step < steps; step++) {
      vy += gravity;
      py += vy;
      if (py + BALL_RADIUS > tableY && vy > 0) {
        py = tableY - BALL_RADIUS;
        vy *= -0.65;
      }
      if (py - BALL_RADIUS < 0 && vy < 0) {
        py = BALL_RADIUS;
        vy *= -0.75;
      }
    }
    return constrain(py, BALL_RADIUS, tableY - BALL_RADIUS);
  }

  // ── paddle movement ───────────────────────────────────────────────────────

  void movePaddles() {
    leftPaddleY  += (leftTargetY  - leftPaddleY)  * PADDLE_SPEED;
    rightPaddleY += (rightTargetY - rightPaddleY) * PADDLE_SPEED;
    leftLungeX  *= 0.80;
    rightLungeX *= 0.80;
  }

  // ── physics ───────────────────────────────────────────────────────────────

  void updatePhysics() {
    // ── Serve drop: ball falls under gravity until it reaches the paddle ──────
    if (inServeDrop) {
      ballVY += gravity;
      ballY  += ballVY;
      float serveHitY = leftServes ? leftPaddleY : rightPaddleY;
      if (ballY >= serveHitY && ballVY > 0) {
        // Auto-hit: launch the serve downward into server's table half
        float speed = 9 + rallyCount * 0.1;
        ballVX = leftServes ? speed : -speed;
        ballVY = 8;   // hits down so ball bounces on server's half first
        inServeDrop = false;
      }
      trail.add(new PVector(ballX, ballY));
      if (trail.size() > MAX_TRAIL) trail.remove(0);
      return;   // skip the rest until the ball is in play
    }

    // ── Normal physics ────────────────────────────────────────────────────────
    ballVY += spin * abs(ballVX) * magnusStrength;
    ballVY += gravity;
    ballVX *= DRAG;
    ballX  += ballVX;
    ballY  += ballVY;

    // Table bounce
    if (ballY + BALL_RADIUS > tableY && ballVY > 0) {
      ballY   = tableY - BALL_RADIUS;
      ballVY *= -0.65;
      ballVX *= 0.96;
      spin   *= 0.76;
      onTableBounce();
    }

    // Ceiling
    if (ballY - BALL_RADIUS < 0 && ballVY < 0) {
      ballY   = BALL_RADIUS;
      ballVY *= -0.75;
    }

    // Speed floor — ball must keep moving after serve bounce
    if (serveBounced && abs(ballVX) < MIN_SPEED_X) {
      ballVX = (ballVX >= 0 ? 1 : -1) * MIN_SPEED_X;
    }

    // Paddle collisions (receiver can't return during serve drop or serve bounce)
    if (!inServeDrop) {
      checkPaddleCollision(true,  leftPaddleX  + leftLungeX,  leftPaddleY);
      checkPaddleCollision(false, rightPaddleX - rightLungeX, rightPaddleY);
    }

    // Ball escaped past a paddle — award point
    if (ballX < leftPaddleX - 60) {
      awardPoint(false);  // right wins
    } else if (ballX > rightPaddleX + 60) {
      awardPoint(true);   // left wins
    }

    trail.add(new PVector(ballX, ballY));
    if (trail.size() > MAX_TRAIL) trail.remove(0);
  }

  void onTableBounce() {
    int side = ballX < width / 2.0 ? -1 : 1;

    // ── Serve bounce handling ─────────────────────────────────────────────────
    if (!serveBounced) {
      int serverSide = leftServes ? -1 : 1;
      if (side == serverSide) {
        // Correct: ball hit server's own half. Override VY so ball clears the net.
        float distToNet = abs(width / 2.0 - ballX);
        float tNet      = distToNet / max(abs(ballVX), 0.5);
        float critVY    = (tableY - BALL_RADIUS - ballY - 0.5 * gravity * tNet * tNet) / tNet;
        ballVY = constrain(critVY - 4, -22, -5);
        serveBounced = true;
      } else {
        // Wrong side — serve fault, server loses point
        awardPoint(!leftServes);
      }
      return;
    }

    // ── After serve bounce: first landing on opponent's side starts rally ─────
    if (serveBounced && lastBounceSide == 0) {
      int opponentSide = leftServes ? 1 : -1;
      if (side == opponentSide) {
        // Good serve — receiver must now return it
        lastBounceSide     = side;
        consecutiveBounces = 1;
      } else {
        // Ball landed on server's side again — serve fault
        awardPoint(!leftServes);
      }
      return;
    }

    // ── Normal rally bounce counting ──────────────────────────────────────────
    if (side == lastBounceSide) {
      consecutiveBounces++;
      if (consecutiveBounces >= 2) {
        // side == -1 (left) → left failed → right wins
        // side ==  1 (right) → right failed → left wins
        awardPoint(side > 0);
      }
    } else {
      lastBounceSide     = side;
      consecutiveBounces = 1;
    }
  }

  void checkPaddleCollision(boolean isLeft, float paddleX, float paddleY) {
    if (isLeft  && ballVX >= 0) return;
    if (!isLeft && ballVX <= 0) return;

    boolean inX = abs(ballX - paddleX) <= PADDLE_W / 2 + BALL_RADIUS + 6;
    boolean inY = abs(ballY - paddleY) <= PADDLE_H / 2 + BALL_RADIUS + 4;
    if (!inX || !inY) return;

    float hitPos = constrain((ballY - paddleY) / (PADDLE_H / 2), -1, 1);
    float power  = 9 + rallyCount * 0.12;
    ballVX  = isLeft
      ?  (abs(ballVX) * 1.05 + power * 0.25)
      : -(abs(ballVX) * 1.05 + power * 0.25);
    // Always launch upward — hitPos tilts the angle but the ball never goes flat
    ballVY  = hitPos * 3 - 7;
    spin    = -hitPos * 0.12;
    rallyCount++;
    impactFlash        = 1.0;
    ballHue            = (ballHue + random(50, 100)) % 360;
    lastBounceSide     = 0;
    consecutiveBounces = 0;
  }

  // ── scoring ───────────────────────────────────────────────────────────────

  void awardPoint(boolean leftScored) {
    if (leftScored) leftPoints++; else rightPoints++;
    totalPoints++;
    pointWinner = leftScored ? -1 : 1;
    pointFlash  = 1.0;

    // Server wins if scorer == current server
    boolean serverScored = (leftServes == leftScored);
    logPoint(leftScored, serverScored, rallyCount);
    rallyCount = 0;

    // Swap server every 2 points
    if (totalPoints % 2 == 0) leftServes = !leftServes;

    // Game won: first to 11, must lead by 2
    boolean leftWins  = leftPoints  >= 11 && leftPoints  - rightPoints >= 2;
    boolean rightWins = rightPoints >= 11 && rightPoints - leftPoints  >= 2;
    if (leftWins)  { leftGames++;  logGame(true);  resetGame(); return; }
    if (rightWins) { rightGames++; logGame(false); resetGame(); return; }

    serve();
  }

  void resetGame() {
    leftPoints   = 0;
    rightPoints  = 0;
    totalPoints  = 0;
    rallyCount   = 0;
    leftServes   = true;
    inServeDrop  = true;
    serveBounced = false;
    serve();
  }

  // ── score logging ──────────────────────────────────────────────────────────

  void openScoreLog() {
    try {
      // Append to scores.txt in the project root (one level above the sketch)
      java.io.File f = new java.io.File(sketchPath("../scores.txt"));
      scoreLog = new java.io.PrintWriter(new java.io.FileOutputStream(f, true));
      String ts = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss")
                      .format(new java.util.Date());
      scoreLog.println("=== session " + ts + " ===");
      scoreLog.flush();
    } catch (Exception e) {
      println("TableTennis: could not open score log — " + e.getMessage());
    }
  }

  void logPoint(boolean leftScored, boolean serverScored, int rally) {
    // Update session stats
    if (serverScored) statServerWins++; else statReceiverWins++;
    statTotalRallies++;
    if (rally >= 5) statLongRallies++;
    if (rally > statMaxRally) statMaxRally = rally;

    if (scoreLog == null) return;
    String scorer  = leftScored   ? "LEFT " : "RIGHT";
    String role    = serverScored ? "server  " : "receiver";
    String long5   = rally >= 5   ? " ***" : "";
    scoreLog.println("  point  " + scorer + "  [" + role + "]"
      + "  rally:" + rally + long5
      + "  score " + leftPoints + "-" + rightPoints);
    scoreLog.flush();
  }

  void logGame(boolean leftWon) {
    if (scoreLog == null) return;
    int total = statServerWins + statReceiverWins;
    float serverPct  = total > 0 ? 100.0 * statServerWins  / total : 0;
    float longPct    = statTotalRallies > 0
                       ? 100.0 * statLongRallies / statTotalRallies : 0;
    scoreLog.println("game  " + (leftWon ? "LEFT " : "RIGHT") + " wins"
      + "  " + (leftWon ? leftPoints : rightPoints)
      + "-" + (leftWon ? rightPoints : leftPoints)
      + "  (games L:" + leftGames + " R:" + rightGames + ")");
    scoreLog.println("  server won " + nf(serverPct, 1, 1) + "% of points"
      + "  |  rallies 5+: " + nf(longPct, 1, 1) + "%"
      + "  |  longest: " + statMaxRally + " hits");
    scoreLog.println("---");
    scoreLog.flush();
    // Reset game-level counters so each game is reported independently
    statServerWins   = 0;
    statReceiverWins = 0;
    statTotalRallies = 0;
    statLongRallies  = 0;
    statMaxRally     = 0;
  }

  void closeScoreLog() {
    if (scoreLog == null) return;
    // Final session summary
    int total = statServerWins + statReceiverWins;
    if (total > 0) {
      float serverPct = 100.0 * statServerWins  / total;
      float longPct   = 100.0 * statLongRallies / max(statTotalRallies, 1);
      scoreLog.println("session summary:");
      scoreLog.println("  server won " + nf(serverPct,1,1) + "% of points"
        + "  |  rallies 5+: " + nf(longPct,1,1) + "%"
        + "  |  longest rally: " + statMaxRally + " hits");
      scoreLog.println("  games  L:" + leftGames + "  R:" + rightGames);
    }
    scoreLog.println("=== session end ===\n");
    scoreLog.close();
    scoreLog = null;
  }

  // ── drawing ───────────────────────────────────────────────────────────────

  void drawTable() {
    pushStyle();
      noStroke();
      fill(0, 90, 0);
      rect(0, tableY, width, height - tableY);

      stroke(255, 255, 255, 200);
      strokeWeight(3);
      line(0, tableY, width, tableY);

      stroke(255, 255, 255, 55);
      strokeWeight(1.5);
      line(width / 2.0, tableY, width / 2.0, height);

      // Net
      float nx = width / 2.0;
      stroke(220, 220, 220, 240);
      strokeWeight(6);
      line(nx, tableY - NET_H, nx, tableY);
      strokeWeight(3);
      line(nx - 6, tableY - NET_H, nx + 6, tableY - NET_H);
      for (int dy = (int)(tableY - NET_H + 4); dy < tableY; dy += 7) {
        stroke(200, 200, 200, 120);
        strokeWeight(1.5);
        point(nx, dy);
      }
    popStyle();
  }

  void drawTrail() {
    if (trail.size() < 2) return;
    pushStyle();
      colorMode(HSB, 360, 255, 255, 255);
      noFill();
      for (int i = 1; i < trail.size(); i++) {
        float a = map(i, 0, trail.size(), 0, 150);
        float w = map(i, 0, trail.size(), 0.5, BALL_RADIUS * 0.7);
        stroke(ballHue, 180, 255, a);
        strokeWeight(w);
        PVector p = trail.get(i - 1), c = trail.get(i);
        line(p.x, p.y, c.x, c.y);
      }
      colorMode(RGB, 255);
    popStyle();
  }

  void drawPaddles() {
    float lx = leftPaddleX  + leftLungeX;
    float rx = rightPaddleX - rightLungeX;

    pushStyle();
      rectMode(CENTER);
      noStroke();

      if (impactFlash > 0.05) {
        fill(255, 255, 255, impactFlash * 120);
        rect(lx, leftPaddleY,  PADDLE_W + 10, PADDLE_H + 10, 4);
        rect(rx, rightPaddleY, PADDLE_W + 10, PADDLE_H + 10, 4);
      }

      fill(200, 40, 40);
      rect(lx, leftPaddleY, PADDLE_W, PADDLE_H, 3);
      fill(220, 70, 70, 140);
      rect(lx + 1, leftPaddleY, PADDLE_W * 0.4, PADDLE_H * 0.85, 2);

      fill(40, 40, 200);
      rect(rx, rightPaddleY, PADDLE_W, PADDLE_H, 3);
      fill(70, 70, 220, 140);
      rect(rx - 1, rightPaddleY, PADDLE_W * 0.4, PADDLE_H * 0.85, 2);

      // Serve indicator — small dot above the serving paddle
      fill(255, 220, 0, 180);
      float dotY = tableY - 150;
      ellipse(leftServes  ? lx : rx, dotY, 8, 8);
    popStyle();
  }

  void drawBall() {
    pushStyle();
      colorMode(HSB, 360, 255, 255, 255);
      if (impactFlash > 0.05) {
        float gr = BALL_RADIUS * 4 * impactFlash;
        noStroke();
        fill(ballHue, 200, 255, impactFlash * 70);
        ellipse(ballX, ballY, gr * 2, gr * 2);
      }
      noStroke();
      fill(ballHue, 160, 255);
      ellipse(ballX, ballY, BALL_RADIUS * 2, BALL_RADIUS * 2);

      stroke(ballHue, 255, 255, 200);
      strokeWeight(2.5);
      float angle = frameCount * spin * 4;
      float r     = BALL_RADIUS * 0.65;
      line(ballX + cos(angle)*r, ballY + sin(angle)*r,
           ballX - cos(angle)*r, ballY - sin(angle)*r);
      colorMode(RGB, 255);
    popStyle();
  }

  void drawScore() {
    pushStyle();
      float cx = width / 2.0;
      float sy = tableY - NET_H - 60;
      float sc = uiScale();

      // Subtle point flash on net post
      if (pointFlash > 0.05) {
        noStroke();
        colorMode(HSB, 360, 255, 255, 255);
        float hue = pointWinner < 0 ? 0 : 220;
        fill(hue, 200, 255, pointFlash * 100);
        rectMode(CENTER);
        rect(cx, tableY - NET_H / 2, 14, NET_H);
        colorMode(RGB, 255);
      }

      textAlign(CENTER, CENTER);
      float sf = 44 * sc;

      // Points (large)
      textSize(sf);
      fill(255, 80, 80);
      text(leftPoints,  cx - 110 * sc, sy);
      fill(200, 200, 200, 130);
      textSize(sf * 0.6);
      text("—", cx, sy);
      fill(80, 80, 255);
      textSize(sf);
      text(rightPoints, cx + 110 * sc, sy);

      // Games (small, below points)
      float gy = sy + sf * 0.9;
      textSize(15 * sc);
      fill(255, 120, 120, 200);
      text(leftGames,  cx - 110 * sc, gy);
      fill(160, 160, 160, 140);
      text("games", cx, gy);
      fill(120, 120, 255, 200);
      text(rightGames, cx + 110 * sc, gy);
    popStyle();
  }

  void drawHUD() {
    String sp = spin > 0.05 ? "topspin" : spin < -0.05 ? "backspin" : "flat";
    pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      fill(0, 150); noStroke(); rectMode(CORNER);
      rect(8, 8, 240 * uiScale(), mg + lh * 4);
      fill(255); textSize(ts); textAlign(LEFT, TOP);
      text("Table Tennis",                             12, 8 + mg);
      text("Spin: " + sp + " (" + nf(spin,1,2) + ")", 12, 8 + mg + lh);
      text("Gravity: " + nf(gravity,1,2) + "  (+/-)",  12, 8 + mg + lh*2);
      text("Magnus: " + nf(magnusStrength,1,3) + "  ([/])", 12, 8 + mg + lh*3);
    popStyle();
  }

  // ── keyboard tuning ───────────────────────────────────────────────────────

  void adjustGravity(float delta) {
    gravity = constrain(gravity + delta, 0.05, 1.0);
  }

  void adjustMagnus(float delta) {
    magnusStrength = constrain(magnusStrength + delta, 0.0, 0.15);
  }

  void applyController(Controller c) {
    // R Stick ↕ → gravity (incremental: push up = less, push down = more)
    float ry = map(c.ry, 0, height, -1, 1);
    if (abs(ry) > 0.2) adjustGravity(ry * 0.005);

    // L Stick ↕ → magnus strength (incremental: push up = more spin effect)
    float ly = map(c.ly, 0, height, -1, 1);
    if (abs(ly) > 0.2) adjustMagnus(-ly * 0.001);

    // A button → inject a serve-speed burst (ball speed floor up briefly)
    if (c.a_just_pressed) spin = constrain(spin + random(-0.15, 0.15), -0.25, 0.25);
  }

  // ── code overlay ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Table Tennis ===",
      "",
      "// First to 11, lead by 2",
      "// Serve swaps every 2 points",
      "// 2 bounces on one side = point",
      "",
      "// Step prediction (N bounces):",
      "for step in t: vy+=g; py+=vy",
      "  bounce if py>tableY",
      "",
      "// Miss offset reset each rally",
      "// 15% miss chance → ~6 hit rallies"
    };
  }

  void onEnter() {
    background(15, 35, 15);
  }

  void onExit() {}

  void handleKey(char k) {
    if (k == '+' || k == '=') adjustGravity(0.02);
    else if (k == '-') adjustGravity(-0.02);
    else if (k == '[') adjustMagnus(-0.005);
    else if (k == ']') adjustMagnus(0.005);
  }
}
