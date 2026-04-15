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
  float leftPaddleX,  rightPaddleX;   // current X (can slide to reach short balls)
  float leftHomeX,    rightHomeX;     // default rest X positions
  float leftPaddleY,  rightPaddleY;
  float leftTargetY,  rightTargetY;
  float leftTargetX,  rightTargetX;   // target X for horizontal movement
  float leftLungeX,   rightLungeX;
  final float PADDLE_W      = 16;
  final float PADDLE_H      = 110;
  final float PADDLE_SPEED   = 0.38;   // bumped up — paddle waits for bounce so needs faster catch-up
  final float PADDLE_X_SPEED = 0.28;

  // ── AI miss system ────────────────────────────────────────────────────────
  final float MISS_CHANCE = 0.07;
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
  int lastHitSide        = 0;    // which side (-1/1) last struck the ball with a paddle
  boolean rallyStarted   = false; // true once the serve has landed on the opponent's side

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
  float speedMult      = 1.3;    // global speed multiplier — adjustable in-game
  final float DRAG     = 0.999;

  // ── visuals ───────────────────────────────────────────────────────────────
  float ballHue     = 40;
  float impactFlash = 0;
  float beatGlow    = 0;   // 1.0 on beat, decays — drives paddle aura
  float bassSmooth  = 0;   // smoothed bass level — drives paddle height breathing
  boolean powerReady = false; // true while beatGlow is hot enough for a power shot
  float powerFlash  = 0;   // extra burst when power shot lands
  ArrayList<PVector> trail = new ArrayList<PVector>();
  final int MAX_TRAIL = 45;

  // ── constructor ───────────────────────────────────────────────────────────

  TableTennisScene() {
    openScoreLog();
    tableY       = height * 0.68;
    leftHomeX    = width * 0.20;
    rightHomeX   = width * 0.80;
    leftPaddleX  = leftHomeX;
    rightPaddleX = rightHomeX;
    leftTargetX  = leftHomeX;
    rightTargetX = rightHomeX;
    float restY  = tableY - 120;
    leftPaddleY  = rightPaddleY = restY;
    leftTargetY  = rightTargetY = restY;
    serve();
  }

  // ── serve ─────────────────────────────────────────────────────────────────

  void serve() {
    // Reset paddles to home X before using their positions — they may have
    // retreated during the previous rally, which would place the serve ball
    // at the wrong X and trigger a spurious "ball escaped" point.
    leftPaddleX  = leftHomeX;  rightPaddleX  = rightHomeX;
    leftTargetX  = leftHomeX;  rightTargetX  = rightHomeX;

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
    lastHitSide     = 0;
    rallyStarted    = false;
  }

  // ── main draw ─────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    pg.background(15, 35, 15);

    float bass = 0, mid = 0;
    for (int i = 0; i < 8; i++) bass += analyzer.spectrum[i];
    for (int i = 8; i < 24; i++) mid += analyzer.spectrum[i];
    bass /= 8.0;
    mid /= 16.0;

    if (analyzer.isBeat) onBeat(bass, mid);
    impactFlash *= 0.82;
    pointFlash  *= 0.88;
    beatGlow    *= 0.93;
    powerFlash  *= 0.85;
    bassSmooth   = lerp(bassSmooth, bass, 0.15);
    powerReady   = beatGlow > 0.4;

    drawTable(pg);
    updatePaddleTargets();
    movePaddles();
    updatePhysics();
    drawTrail(pg);
    drawPaddles(pg);
    drawBall(pg);

    drawScore(pg);
    drawHUD(pg);
    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  // ── beat ──────────────────────────────────────────────────────────────────

  void onBeat(float bass, float mid) {
    float lunge = 14 + bass * 1.2;
    if (ballVX < 0) leftLungeX  = lunge;
    else            rightLungeX = lunge;
    spin += map(mid, 0, 15, -0.03, 0.03);
    spin  = constrain(spin, -0.25, 0.25);
    beatGlow = 1.0;
  }

  // ── paddle AI ─────────────────────────────────────────────────────────────

  void updatePaddleTargets() {
    float yMin  = PADDLE_H / 2;
    float yMax  = tableY - PADDLE_H / 2 - 4;   // keep paddle above table surface
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

    float netX    = width / 2.0;
    float xMargin = PADDLE_W * 2;

    if (ballVX < 0) {
      // Ball heading left — right paddle rests
      rightTargetX = rightHomeX;
      rightTargetY = constrain(restY, yMin, yMax);
      leftTargetX  = leftHomeX - 20;
      // Left paddle only tracks AFTER ball has bounced on the left side.
      // lastBounceSide == -1 means it already landed there — legal to return.
      // If lastBounceSide is 0 or 1 the ball hasn't touched left's court yet — wait.
      if (lastBounceSide == -1) {
        float t = abs(ballX - leftPaddleX) / max(abs(ballVX), 0.5);
        leftTargetY = constrain(predictBallY(t) + leftMissOffset, yMin, yMax);
      } else {
        leftTargetY = constrain(restY, yMin, yMax);
      }
    } else {
      // Ball heading right — left paddle rests
      leftTargetX  = leftHomeX;
      leftTargetY  = constrain(restY, yMin, yMax);
      rightTargetX = rightHomeX + 20;
      // Right paddle only tracks AFTER ball has bounced on the right side.
      if (lastBounceSide == 1) {
        float t = abs(rightPaddleX - ballX) / max(abs(ballVX), 0.5);
        rightTargetY = constrain(predictBallY(t) + rightMissOffset, yMin, yMax);
      } else {
        rightTargetY = constrain(restY, yMin, yMax);
      }
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
    leftPaddleX  += (leftTargetX  - leftPaddleX)  * PADDLE_X_SPEED;
    rightPaddleX += (rightTargetX - rightPaddleX) * PADDLE_X_SPEED;
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
        float speed = (9 + rallyCount * 0.1) * speedMult;
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
    float prevBallX = ballX;
    ballX  += ballVX;
    ballY  += ballVY;

    // Net collision — block ball if it crosses the centre line below net height.
    // Skip during serve drop (ball is above the table, can't hit the net yet).
    if (!inServeDrop) {
      float netX   = width / 2.0;
      float netTop = tableY - NET_H;
      if (ballY + BALL_RADIUS > netTop && ballY + BALL_RADIUS < tableY) {
        boolean crossedNet = (prevBallX < netX) != (ballX < netX);
        if (crossedNet) {
          ballX  = prevBallX < netX ? netX - BALL_RADIUS - 1 : netX + BALL_RADIUS + 1;
          ballVX *= -0.4;
        }
      }
    }

    // Table bounce
    if (ballY + BALL_RADIUS > tableY && ballVY > 0) {
      ballY   = tableY - BALL_RADIUS;
      ballVY *= -0.65;
      ballVX *= 0.96;
      spin   *= 0.76;
      onTableBounce();
      // onTableBounce may have awarded a point and called serve() — bail out
      // to avoid the escape-check running on the freshly reset ball position.
      if (inServeDrop) {
        trail.add(new PVector(ballX, ballY));
        if (trail.size() > MAX_TRAIL) trail.remove(0);
        return;
      }
    }

    // Ceiling
    if (ballY - BALL_RADIUS < 0 && ballVY < 0) {
      ballY   = BALL_RADIUS;
      ballVY *= -0.75;
    }

    // Speed floor — ball must keep moving after serve bounce
    float speedFloor = MIN_SPEED_X * speedMult;
    if (serveBounced && abs(ballVX) < speedFloor) {
      ballVX = (ballVX >= 0 ? 1 : -1) * speedFloor;
    }

    // Paddle collisions (receiver can't return during serve drop or serve bounce)
    if (!inServeDrop) {
      checkPaddleCollision(true,  leftPaddleX  + leftLungeX,  leftPaddleY);
      if (inServeDrop) { trail.add(new PVector(ballX, ballY)); if (trail.size() > MAX_TRAIL) trail.remove(0); return; }
      checkPaddleCollision(false, rightPaddleX - rightLungeX, rightPaddleY);
      if (inServeDrop) { trail.add(new PVector(ballX, ballY)); if (trail.size() > MAX_TRAIL) trail.remove(0); return; }
    }

    // Ball escaped past a paddle — virtual so 3D subclass can override
    checkEscape();

    trail.add(new PVector(ballX, ballY));
    if (trail.size() > MAX_TRAIL) trail.remove(0);
  }

  // Overridable escape check. Default: immediate point at paddle bounds.
  void checkEscape() {
    if (ballX < leftHomeX - 80)  awardPoint(false);   // right wins
    else if (ballX > rightHomeX + 80) awardPoint(true);  // left wins
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
    if (!rallyStarted) {
      int opponentSide = leftServes ? 1 : -1;
      if (side == opponentSide) {
        // Good serve — receiver must now return it
        rallyStarted       = true;
        lastBounceSide     = side;
        consecutiveBounces = 1;
      } else {
        // Ball landed on server's side again — serve fault
        awardPoint(!leftServes);
      }
      return;
    }

    // ── Normal rally bounce counting ──────────────────────────────────────────
    if (lastBounceSide == 0) {
      // First bounce after a paddle hit — ball must land on the OPPONENT's side
      if (side == lastHitSide) {
        // Bounced back on the hitter's own side (didn't clear the net) — fault
        // lastHitSide > 0 means right hit and bounced right → left wins (true)
        // lastHitSide < 0 means left hit and bounced left  → right wins (false)
        awardPoint(lastHitSide > 0);
      } else {
        lastBounceSide     = side;
        consecutiveBounces = 1;
      }
    } else if (side == lastBounceSide) {
      consecutiveBounces++;
      if (consecutiveBounces >= 2) {
        // Bounced twice on same side without being returned
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

    // No volleying during a rally — ball must bounce on this player's side first
    if (rallyStarted) {
      int playerSide = isLeft ? -1 : 1;
      if (lastBounceSide != playerSide) {
        awardPoint(!isLeft);
        return;
      }
    }

    float hitPos = constrain((ballY - paddleY) / (PADDLE_H / 2), -1, 1);

    boolean isPowerShot = powerReady;
    float power    = isPowerShot ? random(14, 20) : random(6, 13);
    float speedMod = isPowerShot ? random(1.1, 1.35) : random(0.88, 1.14);
    float cap      = (isPowerShot ? 30 : 22) * speedMult;
    float newSpeed = constrain((abs(ballVX) * speedMod + power * 0.3) * speedMult, 6 * speedMult, cap);
    ballVX = isLeft ? newSpeed : -newSpeed;
    ballVY = constrain(hitPos * 2 + random(-14, -1), -16, -2);
    spin   = isPowerShot ? random(-0.35, 0.35) : random(-0.20, 0.20);

    rallyCount++;
    impactFlash        = isPowerShot ? 1.5 : 1.0;
    powerFlash         = isPowerShot ? 1.0 : 0;
    beatGlow           = isPowerShot ? 0 : beatGlow;   // consume the charge
    ballHue            = (ballHue + (isPowerShot ? random(120, 180) : random(50, 100))) % 360;
    lastHitSide        = isLeft ? -1 : 1;
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

    // Swap server every 2 points; at deuce (10-10) swap every point
    boolean inDeuce = leftPoints >= 10 && rightPoints >= 10;
    if (inDeuce || totalPoints % 2 == 0) leftServes = !leftServes;

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

  void drawTable(PGraphics pg) {
    pg.pushStyle();
      pg.noStroke();
      pg.fill(0, 90, 0);
      pg.rect(0, tableY, pg.width, pg.height - tableY);

      pg.stroke(255, 255, 255, 200);
      pg.strokeWeight(3);
      pg.line(0, tableY, pg.width, tableY);

      pg.stroke(255, 255, 255, 55);
      pg.strokeWeight(1.5);
      pg.line(pg.width / 2.0, tableY, pg.width / 2.0, pg.height);

      // Net
      float nx = pg.width / 2.0;
      pg.stroke(220, 220, 220, 240);
      pg.strokeWeight(6);
      pg.line(nx, tableY - NET_H, nx, tableY);
      pg.strokeWeight(3);
      pg.line(nx - 6, tableY - NET_H, nx + 6, tableY - NET_H);
      for (int dy = (int)(tableY - NET_H + 4); dy < tableY; dy += 7) {
        pg.stroke(200, 200, 200, 120);
        pg.strokeWeight(1.5);
        pg.point(nx, dy);
      }
    pg.popStyle();
  }

  void drawTrail(PGraphics pg) {
    if (trail.size() < 2) return;
    pg.pushStyle();
      pg.colorMode(HSB, 360, 255, 255, 255);
      pg.noFill();
      for (int i = 1; i < trail.size(); i++) {
        float a = map(i, 0, trail.size(), 0, 150);
        float w = map(i, 0, trail.size(), 0.5, BALL_RADIUS * 0.7);
        pg.stroke(ballHue, 180, 255, a);
        pg.strokeWeight(w);
        PVector p = trail.get(i - 1), c = trail.get(i);
        pg.line(p.x, p.y, c.x, c.y);
      }
      pg.colorMode(RGB, 255);
    pg.popStyle();
  }

  void drawPaddles(PGraphics pg) {
    float lx = leftPaddleX  + leftLungeX;
    float rx = rightPaddleX - rightLungeX;

    // Bass breathing — visual height only, not hitbox
    float breathe = bassSmooth * 18;
    float lh = PADDLE_H + breathe;
    float rh = PADDLE_H + breathe;

    pg.pushStyle();
      pg.rectMode(CENTER);
      pg.noStroke();
      pg.colorMode(HSB, 360, 255, 255, 255);

      // Beat-glow aura on the active (receiving) paddle
      if (beatGlow > 0.05) {
        boolean leftActive = ballVX < 0;
        float ax = leftActive ? lx : rx;
        float ay = leftActive ? leftPaddleY : rightPaddleY;
        float ah = leftActive ? lh : rh;
        float hue = powerReady ? 45 : 200;   // gold when power-ready, blue otherwise
        for (int ring = 3; ring >= 1; ring--) {
          float spread = ring * 12 * beatGlow;
          pg.fill(hue, 220, 255, beatGlow * 60 / ring);
          pg.rect(ax, ay, PADDLE_W + spread * 2, ah + spread * 2, 6);
        }
      }

      // Power-shot burst — wide radial flash at both paddles
      if (powerFlash > 0.05) {
        float spread = powerFlash * 60;
        pg.fill(45, 255, 255, powerFlash * 90);
        pg.ellipse(lx, leftPaddleY,  spread * 2, spread * 2);
        pg.ellipse(rx, rightPaddleY, spread * 2, spread * 2);
      }

      // Impact flash (white) on both paddles
      if (impactFlash > 0.05) {
        pg.fill(0, 0, 255, impactFlash * 120);
        pg.rect(lx, leftPaddleY,  PADDLE_W + 10, lh + 10, 4);
        pg.rect(rx, rightPaddleY, PADDLE_W + 10, rh + 10, 4);
      }

      pg.colorMode(RGB, 255);

      pg.fill(200, 40, 40);
      pg.rect(lx, leftPaddleY, PADDLE_W, lh, 3);
      pg.fill(220, 70, 70, 140);
      pg.rect(lx + 1, leftPaddleY, PADDLE_W * 0.4, lh * 0.85, 2);

      pg.fill(40, 40, 200);
      pg.rect(rx, rightPaddleY, PADDLE_W, rh, 3);
      pg.fill(70, 70, 220, 140);
      pg.rect(rx - 1, rightPaddleY, PADDLE_W * 0.4, rh * 0.85, 2);

      // Serve indicator — small dot above the serving paddle
      pg.fill(255, 220, 0, 180);
      float dotY = tableY - 150;
      pg.ellipse(leftServes  ? lx : rx, dotY, 8, 8);
    pg.popStyle();
  }

  void drawBall(PGraphics pg) {
    pg.pushStyle();
      pg.colorMode(HSB, 360, 255, 255, 255);
      if (impactFlash > 0.05) {
        float gr = BALL_RADIUS * 4 * impactFlash;
        pg.noStroke();
        pg.fill(ballHue, 200, 255, impactFlash * 70);
        pg.ellipse(ballX, ballY, gr * 2, gr * 2);
      }
      pg.noStroke();
      pg.fill(ballHue, 160, 255);
      pg.ellipse(ballX, ballY, BALL_RADIUS * 2, BALL_RADIUS * 2);

      pg.stroke(ballHue, 255, 255, 200);
      pg.strokeWeight(2.5);
      float angle = config.logicalFrameCount * spin * 4;
      float r     = BALL_RADIUS * 0.65;
      pg.line(ballX + cos(angle)*r, ballY + sin(angle)*r,
           ballX - cos(angle)*r, ballY - sin(angle)*r);
      pg.colorMode(RGB, 255);
    pg.popStyle();
  }

  void drawScore(PGraphics pg) {
    pg.pushStyle();
      float cx = pg.width / 2.0;
      float sy = tableY - NET_H - 60;
      float sc = uiScale();

      // Subtle point flash on net post
      if (pointFlash > 0.05) {
        pg.noStroke();
        pg.colorMode(HSB, 360, 255, 255, 255);
        float hue = pointWinner < 0 ? 0 : 220;
        pg.fill(hue, 200, 255, pointFlash * 100);
        pg.rectMode(CENTER);
        pg.rect(cx, tableY - NET_H / 2, 14, NET_H);
        pg.colorMode(RGB, 255);
      }

      pg.textAlign(CENTER, CENTER);
      float sf = 44 * sc;

      // Points (large)
      pg.textSize(sf);
      pg.fill(255, 80, 80);
      pg.text(leftPoints,  cx - 110 * sc, sy);
      pg.fill(200, 200, 200, 130);
      pg.textSize(sf * 0.6);
      pg.text("—", cx, sy);
      pg.fill(80, 80, 255);
      pg.textSize(sf);
      pg.text(rightPoints, cx + 110 * sc, sy);

      // Games (small, below points)
      float gy = sy + sf * 0.9;
      pg.textSize(15 * sc);
      pg.fill(255, 120, 120, 200);
      pg.text(leftGames,  cx - 110 * sc, gy);
      pg.fill(160, 160, 160, 140);
      pg.text("games", cx, gy);
      pg.fill(120, 120, 255, 200);
      pg.text(rightGames, cx + 110 * sc, gy);
    pg.popStyle();
  }

  void drawHUD(PGraphics pg) {
    String sp = spin > 0.05 ? "topspin" : spin < -0.05 ? "backspin" : "flat";
    sceneHUD(pg, "Table Tennis", new String[]{
      "Spin: " + sp + " (" + nf(spin,1,2) + ")",
      "Gravity: " + nf(gravity,1,2) + "  (+/-)   Magnus: " + nf(magnusStrength,1,3) + "  ([/])",
      "Speed: " + nf(speedMult,1,1) + "x  (,/.)"
    });
  }

  // ── keyboard tuning ───────────────────────────────────────────────────────

  void adjustGravity(float delta) {
    gravity = constrain(gravity + delta, 0.05, 1.0);
  }

  void adjustMagnus(float delta) {
    magnusStrength = constrain(magnusStrength + delta, 0.0, 0.15);
  }

  void adjustSpeed(float delta) {
    speedMult = constrain(speedMult + delta, 0.5, 3.0);
  }

  void applyController(Controller c) {
    // R Stick ↕ → gravity (incremental: push up = less, push down = more)
    float ry = map(c.ry, 0, height, -1, 1);
    if (abs(ry) > 0.2) adjustGravity(ry * 0.005);

    // L Stick ↕ → magnus strength (incremental: push up = more spin effect)
    float ly = map(c.ly, 0, height, -1, 1);
    if (abs(ly) > 0.2) adjustMagnus(-ly * 0.001);

    // A button → inject a serve-speed burst (ball speed floor up briefly)
    if (c.aJustPressed) spin = constrain(spin + random(-0.15, 0.15), -0.25, 0.25);

    // X / Y buttons → speed down / up
    if (c.xJustPressed) adjustSpeed(-0.1);
    if (c.yJustPressed) adjustSpeed( 0.1);
  }

  // ── code overlay ──────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Table Tennis ===",
      "",
      "// First to 11, lead by 2",
      "// Serve: every 2 pts, every 1 at deuce",
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
    else if (k == ',') adjustSpeed(-0.1);
    else if (k == '.') adjustSpeed(0.1);
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
