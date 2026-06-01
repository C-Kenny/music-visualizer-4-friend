/**
 * TableTennisSimScene (scene 53) — "Sim Lab"
 *
 * 32 headless table-tennis matches play in parallel in a 4×8 grid, each driven
 * by the SAME physics as TableTennis3DScene (ported into TTSimGame, no PGraphics
 * / audio coupling) but with a DIFFERENT parameter vector (a "genome"). A small
 * genetic algorithm watches how each genome plays and breeds the good ones:
 *
 *   - Each generation, every game's play is scored by a fitness function that
 *     combines STABILITY (no "to the moon" shots, legal serves) with REALISM
 *     (balanced server/receiver wins, human-length rallies).
 *   - On each beat (or a timeout) the worst genomes are culled and replaced with
 *     mutated copies of the best — you watch the population converge live.
 *
 * The grid cells are tinted by fitness (red = unstable/blows up, green = clean),
 * and a bottom panel shows the generation, the all-time best genome, and the
 * aggregate "training data" (moon %, avg rally, server-win %). This is a live,
 * visual view of the same sweep that tools/tt_sim/TTSim.java does headless.
 *
 * Audio:
 *   Bass → sim speed (more physics sub-steps per frame = faster fast-forward)
 *   Beat → advance a learning generation (cull + breed)
 *
 * Controller / keys:
 *   A — force a generation now      X — reseed the whole population
 *   B — toggle detail panel         LStick/RStick — unused
 */
class TableTennisSimScene implements IScene {

  // ── Virtual court (matches the real scene's 1920×1080 buffer layout so the
  //    physics constants are identical and the lab genuinely tunes the game). ──
  static final float VW = 1920, VH = 1080;
  static final float NETX     = VW / 2.0;            // 960
  static final float TABLEY   = VH * 0.68;           // 734.4
  static final float TW       = VW * 0.88;           // 1689.6
  static final float NET_H    = TW * (0.1525 / 2.74);// 94.0
  static final float TABLE_DEPTH = TW * (1.525 / 2.74); // 940.6 — Z extent (for the 3D cube)
  static final float PADDLE_Z = 130;
  static final float BALL_R   = 16;
  static final float PADDLE_H = 110, PADDLE_W = 16;
  static final float LHOMEX   = NETX - TW / 2.0;     // 115.2
  static final float RHOMEX   = NETX + TW / 2.0;     // 1804.8
  static final float GRAVITY  = 0.28;
  static final float DRAG     = 0.999;
  static final float SPEEDMULT = 1.3;

  static final int COLS = 8, ROWS = 4, POP = COLS * ROWS;   // 32 games
  static final int ELITES = 8;                              // survivors per gen
  static final int MIN_GEN_STEPS = 240;   // gather at least this many steps/gen
  static final int MAX_GEN_STEPS = 1400;  // force a generation if no beat lands

  TTSimGame[] games = new TTSimGame[POP];
  TTGenome bestEver;            // all-time best genome
  float bestEverFitness = -1;
  int generation = 0;
  int stepsThisGen = 0;
  boolean showPanel = true;
  float beatFlash = 0;
  int lastEvolveFlash = 0;      // frame stamp for a brief grid pulse

  // aggregate stats for the panel (recomputed each evolve)
  float aggMoon, aggRally, aggServerWin, aggFitness;

  void onEnter() { reseed(); }
  void onExit() {}

  void reseed() {
    for (int i = 0; i < POP; i++) {
      TTGenome g;
      if (i == 0)      g = genomeTuned();     // our shipped "good" values
      else if (i == 1) g = genomeMoony();     // the old runaway baseline (contrast)
      else             g = genomeRandom();
      games[i] = new TTSimGame(g, i * 7919 + 13);
    }
    generation = 0; stepsThisGen = 0; bestEver = null; bestEverFitness = -1;
  }

  // ── genome factories (here, not on TTGenome — inner classes can't be static) ─
  TTGenome genomeMake(float a, float b, float c, float d, float e, float f) {
    TTGenome g = new TTGenome();
    g.magnusStrength = a; g.magnusTermMax = b; g.spinFlightDecay = c;
    g.brushCoeff = d; g.launchVyMax = e; g.aiSpeed = f; return g;
  }
  TTGenome genomeTuned() { return genomeMake(0.045, 0.10, 0.98, 0.015, 12, 0.34); }
  TTGenome genomeMoony() { return genomeMake(0.045, 9.99, 1.00, 0.030, 16, 0.34); } // old runaway
  TTGenome genomeRandom() {
    return genomeMake(random(0.02, 0.07), random(0.04, 0.30), random(0.95, 1.0),
                      random(0.005, 0.05), random(10, 22), random(0.20, 0.45));
  }

  void drawScene(PGraphics pg) {
    pg.colorMode(RGB, 255);

    // ── Sim speed from bass: 1..8 physics steps this frame ──────────────────
    int subSteps = 1 + round(constrain(analyzer.bass, 0, 1) * 7);
    for (int s = 0; s < subSteps; s++) {
      for (int i = 0; i < POP; i++) games[i].step();
      stepsThisGen += 1;
    }

    // ── Generation advance: on beat (after min data) or timeout ─────────────
    boolean beat = audio.beat.isOnset();
    if (beat) beatFlash = 1.0;
    beatFlash = lerp(beatFlash, 0, 0.08);
    if ((beat && stepsThisGen >= MIN_GEN_STEPS) || stepsThisGen >= MAX_GEN_STEPS) {
      evolve();
    }

    // ── Layout: grid on top, stats panel at the bottom ──────────────────────
    float panelH = showPanel ? pg.height * 0.20 : pg.height * 0.05;
    float gridH  = pg.height - panelH;
    float cellW  = pg.width / (float) COLS;
    float cellH  = gridH / (float) ROWS;

    pg.background(8, 10, 14);
    pg.noStroke();

    for (int i = 0; i < POP; i++) {
      int cx = i % COLS, cy = i / COLS;
      float ox = cx * cellW, oy = cy * cellH;
      drawCell(pg, games[i], ox, oy, cellW, cellH);
    }
    drawPanel(pg, 0, gridH, pg.width, panelH);
  }

  // ── one game in its cell ──────────────────────────────────────────────────
  void drawCell(PGraphics pg, TTSimGame g, float ox, float oy, float w, float h) {
    float pad = 3;
    ox += pad; oy += pad; w -= pad * 2; h -= pad * 2;
    float sx = w / VW, sy = h / VH;

    // background
    pg.noStroke();
    pg.fill(16, 18, 24);
    pg.rect(ox, oy, w, h);

    // fitness-tinted border (red = unstable, green = clean). Use live running
    // fitness so cells react before the generation flips.
    float f = constrain(g.liveFitness(), 0, 1);
    float pulse = (frameCount - lastEvolveFlash < 8) ? 60 : 0;
    pg.noFill();
    pg.strokeWeight(g.genome == bestEver ? 3 : 1.5);
    pg.stroke(255 * (1 - f), 200 * f + 30 + pulse, 60 * f + pulse * 0.5,
              g.genome == bestEver ? 255 : 170);
    pg.rect(ox, oy, w, h);

    // table surface + net
    pg.stroke(70, 80, 95); pg.strokeWeight(1.2);
    pg.line(ox, oy + TABLEY * sy, ox + w, oy + TABLEY * sy);
    pg.stroke(120, 130, 150);
    pg.line(ox + NETX * sx, oy + (TABLEY - NET_H) * sy, ox + NETX * sx, oy + TABLEY * sy);

    // paddles
    pg.noStroke(); pg.fill(90, 170, 255);
    pg.rect(ox + g.leftPaddleX * sx - 2, oy + g.leftPaddleY * sy - PADDLE_H * sy / 2,
            max(2, PADDLE_W * sx), PADDLE_H * sy);
    pg.fill(255, 130, 90);
    pg.rect(ox + g.rightPaddleX * sx - 2, oy + g.rightPaddleY * sy - PADDLE_H * sy / 2,
            max(2, PADDLE_W * sx), PADDLE_H * sy);

    // ball (clamp y into the cell so a moon shot shows as a ball pinned to the
    // top edge rather than vanishing — visually flags the runaway)
    float by = constrain(g.ballY, -BALL_R, VH);
    boolean mooning = g.ballY < -BALL_R;
    pg.fill(mooning ? color(255, 60, 60) : color(255, 250, 200));
    pg.ellipse(ox + g.ballX * sx, oy + by * sy, max(3, BALL_R * sx * 1.6), max(3, BALL_R * sy * 1.6));

    // mini score
    pg.fill(180, 190, 200);
    pg.textAlign(LEFT, TOP); pg.textSize(max(8, h * 0.10));
    pg.text(g.leftPoints + ":" + g.rightPoints, ox + 4, oy + 3);
  }

  // ── stats / training-data panel ─────────────────────────────────────────────
  void drawPanel(PGraphics pg, float x, float y, float w, float h) {
    pg.noStroke(); pg.fill(6, 8, 11); pg.rect(x, y, w, h);
    pg.stroke(40, 200, 90, 120); pg.strokeWeight(1);
    pg.line(x, y, x + w, y);

    pg.textAlign(LEFT, TOP);
    float ts = constrain(h * 0.22, 11, 22);
    pg.textSize(ts);
    pg.fill(60, 230, 120);
    pg.text("SIM LAB — genetic tuner   gen " + generation
          + "   pop " + POP + "   speed x" + (1 + round(constrain(analyzer.bass,0,1)*7)),
          x + 16, y + 8);

    if (!showPanel) return;

    pg.textSize(constrain(h * 0.16, 9, 16));
    float ly = y + 8 + ts + 6;
    pg.fill(190, 200, 210);
    pg.text(String.format("aggregate:  moon %4.1f%%   avgRally %4.1f   serverWin %4.1f%%   meanFitness %.2f",
            aggMoon * 100, aggRally, aggServerWin * 100, aggFitness), x + 16, ly);

    if (bestEver != null) {
      ly += constrain(h * 0.16, 9, 16) + 4;
      pg.fill(120, 240, 160);
      pg.text(String.format("best (fit %.3f):  magnus %.3f  cap %.3f  spinDecay %.3f  brush %.3f  launch %.1f  ai %.2f",
              bestEverFitness, bestEver.magnusStrength, bestEver.magnusTermMax,
              bestEver.spinFlightDecay, bestEver.brushCoeff, bestEver.launchVyMax, bestEver.aiSpeed),
              x + 16, ly);
      // gravity reference so the cap<gravity insight is visible
      ly += constrain(h * 0.16, 9, 16) + 2;
      pg.fill(150, 150, 160);
      pg.text("(gravity = " + nf(GRAVITY, 1, 2) + "  → Magnus cap must stay below it or the ball runs away upward)",
              x + 16, ly);
    }
  }

  // ── genetic step: score, cull, breed ────────────────────────────────────────
  void evolve() {
    // fitness for everyone
    float[] fit = new float[POP];
    float sumMoon = 0, sumRally = 0, sumSrv = 0, sumFit = 0; int counted = 0;
    for (int i = 0; i < POP; i++) {
      fit[i] = games[i].fitness();
      games[i].genome.fitness = fit[i];
      if (games[i].pointsPlayed > 0) {
        sumMoon  += (float) games[i].moonPoints / games[i].pointsPlayed;
        sumRally += (float) games[i].rallyLenSum / games[i].pointsPlayed;
        sumSrv   += (float) games[i].serverWins / games[i].pointsPlayed;
        sumFit   += fit[i];
        counted++;
      }
    }
    if (counted > 0) {
      aggMoon = sumMoon / counted; aggRally = sumRally / counted;
      aggServerWin = sumSrv / counted; aggFitness = sumFit / counted;
    }

    // rank indices by fitness (desc), simple selection sort over 32 — trivial
    Integer[] order = new Integer[POP];
    for (int i = 0; i < POP; i++) order[i] = i;
    for (int a = 0; a < POP; a++)
      for (int b = a + 1; b < POP; b++)
        if (fit[order[b]] > fit[order[a]]) { Integer t = order[a]; order[a] = order[b]; order[b] = t; }

    // track all-time best
    int top = order[0];
    if (fit[top] > bestEverFitness) { bestEverFitness = fit[top]; bestEver = games[top].genome.copy(); }

    // auto-export: best ball-physics + top-N styles → tt_genome.cfg (the real
    // TableTennis3D scene loads this on entry). Written every generation.
    writeGenomeFile(order);

    // breed: keep elites (just reset their accumulators); replace the rest with
    // mutated children of random elites.
    TTGenome[] elites = new TTGenome[ELITES];
    for (int e = 0; e < ELITES; e++) elites[e] = games[order[e]].genome.copy();

    for (int rank = 0; rank < POP; rank++) {
      int gi = order[rank];
      if (rank < ELITES) {
        games[gi].resetStats();                       // elite survives unchanged
      } else {
        TTGenome parent = elites[(int) random(ELITES)];
        games[gi] = new TTSimGame(parent.mutate(), gi * 104729 + generation * 31 + 5);
      }
    }
    generation++; stepsThisGen = 0; lastEvolveFlash = frameCount;
  }

  // Export the current best genome to tt_genome.cfg. `order` is the fitness-
  // ranked index list from evolve(). Physics block = single best; style roster
  // = the top-N genomes' per-paddle genes. The real TableTennis3D scene reads
  // this on onEnter() and falls back to its shipped defaults if it's absent.
  void writeGenomeFile(Integer[] order) {
    if (bestEver == null) return;
    int n = min(8, POP);
    try {
      java.io.PrintWriter w = new java.io.PrintWriter(new java.io.FileWriter(userDataPath("tt_genome.cfg")));
      w.println("# Sim Lab evolved genome — gen " + generation + "  bestFit " + nf(bestEverFitness, 1, 3));
      w.println("# physics <magnusStrength> <magnusTermMax> <spinFlightDecay>");
      w.println("physics " + bestEver.magnusStrength + " " + bestEver.magnusTermMax + " " + bestEver.spinFlightDecay);
      w.println("# style <launchVyMax> <brushCoeff> <aiSpeed>");
      for (int r = 0; r < n; r++) {
        TTGenome g = games[order[r]].genome;
        w.println("style " + g.launchVyMax + " " + g.brushCoeff + " " + g.aiSpeed);
      }
      w.close();
    } catch (Exception e) {
      println("SimLab: genome write failed — " + e.getMessage());
    }
  }

  void applyController(Controller c) {
    if (c.aJustPressed) evolve();
    if (c.xJustPressed) reseed();
    if (c.bJustPressed) showPanel = !showPanel;
  }

  void handleKey(char k) {
    if (k == 'a' || k == 'A') evolve();
    else if (k == 'x' || k == 'X') reseed();
    else if (k == 'b' || k == 'B') showPanel = !showPanel;
  }

  String[] getCodeLines() {
    return new String[] {
      "SIM LAB — live genetic tuner",
      "",
      "32 parallel matches, one genome each:",
      "  magnusStrength, magnusTermMax (cap),",
      "  spinFlightDecay, brushCoeff,",
      "  launchVyMax, aiSpeed",
      "",
      "per-frame ball physics:",
      "  vy += clamp(spin*|vx|*magnus, ±cap)",
      "  spin *= spinDecay   // bleed in flight",
      "  vy += gravity (" + nf(GRAVITY,1,2) + ")",
      "",
      "fitness = 0.40*stability + 0.20*serveOK",
      "        + 0.20*winBalance + 0.20*rally",
      "",
      "beat → cull worst, breed best",
      "bass → sim speed (x1..x8)",
      "A force gen   X reseed   B panel"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("A", "Force a generation"),
      new ControllerLayout("X", "Reseed population"),
      new ControllerLayout("B", "Toggle data panel")
    };
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TTGenome — the per-game parameter vector the GA evolves. Plain inner class
// (NOT static) so its methods can call Processing's random()/constrain(). The
// factory methods live on TableTennisSimScene (inner classes can't be static).
// ════════════════════════════════════════════════════════════════════════════
class TTGenome {
  float magnusStrength;   // [0.02 .. 0.07]   real = 0.045
  float magnusTermMax;    // [0.04 .. 0.30]   real = 0.10  (must stay < gravity 0.28)
  float spinFlightDecay;  // [0.95 .. 1.00]   real = 0.98  (1.0 = no decay = runaway)
  float brushCoeff;       // [0.005 .. 0.05]  real = 0.015
  float launchVyMax;      // [10 .. 22]       real = 12
  float aiSpeed;          // [0.20 .. 0.45]   paddle tracking lerp
  float fitness = 0;

  TTGenome copy() {
    TTGenome g = new TTGenome();
    g.magnusStrength = magnusStrength; g.magnusTermMax = magnusTermMax;
    g.spinFlightDecay = spinFlightDecay; g.brushCoeff = brushCoeff;
    g.launchVyMax = launchVyMax; g.aiSpeed = aiSpeed; g.fitness = fitness;
    return g;
  }
  TTGenome mutate() {
    TTGenome g = copy(); g.fitness = 0;
    if (random(1) < 0.6) g.magnusStrength  = constrain(g.magnusStrength  + randomGaussian() * 0.008, 0.02, 0.07);
    if (random(1) < 0.6) g.magnusTermMax   = constrain(g.magnusTermMax   + randomGaussian() * 0.04,  0.04, 0.30);
    if (random(1) < 0.6) g.spinFlightDecay = constrain(g.spinFlightDecay + randomGaussian() * 0.01,  0.95, 1.0);
    if (random(1) < 0.6) g.brushCoeff      = constrain(g.brushCoeff      + randomGaussian() * 0.006, 0.005, 0.05);
    if (random(1) < 0.6) g.launchVyMax     = constrain(g.launchVyMax     + randomGaussian() * 1.5,   10, 22);
    if (random(1) < 0.4) g.aiSpeed         = constrain(g.aiSpeed         + randomGaussian() * 0.03,  0.20, 0.45);
    return g;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TTSimGame — headless port of the TableTennis3D physics (X/Y only). One ball,
// two simple-AI paddles, full serve/rally/scoring, plus stat accumulators the
// GA reads. Self-contained: no PGraphics, no audio.
// ════════════════════════════════════════════════════════════════════════════
class TTSimGame {
  TTGenome genome;

  float ballX, ballY, ballVX, ballVY, spin;
  // Depth (Z) — purely cosmetic for the 3D Sim Cube (scene 54). Independent of
  // the X/Y physics, so the 2D lab's behaviour and fitness are unaffected.
  float ballZ, ballVZ, leftPaddleZ, rightPaddleZ;
  boolean inServeDrop, serveBounced, rallyStarted, leftServes;
  int lastBounceSide, lastHitSide, consecutiveBounces, rallyCount;
  float leftPaddleY, rightPaddleY, leftPaddleX, rightPaddleX;
  float prevLeftPaddleY, prevRightPaddleY;   // for paddle-brush spin
  float leftMiss, rightMiss;                 // AI miss offsets
  int   lastDirSign;
  int   leftPoints, rightPoints;
  int   pointPauseFrames;
  int   pointFrames;                          // watchdog against stuck rallies

  // per-point flags / per-generation accumulators
  boolean moonThisPoint, faultThisPoint;
  int pointsPlayed, moonPoints, faults, serverWins, receiverWins, rallyLenSum;

  TTSimGame(TTGenome g, int seed) {
    genome = g;
    // alternate which side opens, derived from the seed. (No randomSeed() here —
    // it would reset Processing's GLOBAL RNG and starve every other game/scene.)
    leftServes = (seed & 1) == 0;
    leftPaddleX = TableTennisSimScene.LHOMEX; rightPaddleX = TableTennisSimScene.RHOMEX;
    leftPaddleY = rightPaddleY = TableTennisSimScene.TABLEY - 120;
    resetStats();
    serve();
  }

  void resetStats() {
    pointsPlayed = moonPoints = faults = serverWins = receiverWins = rallyLenSum = 0;
  }

  // shorthands
  float G()    { return TableTennisSimScene.GRAVITY; }
  float netX() { return TableTennisSimScene.NETX; }
  float tableY(){ return TableTennisSimScene.TABLEY; }
  float ballR(){ return TableTennisSimScene.BALL_R; }
  float netH() { return TableTennisSimScene.NET_H; }
  float ph()   { return TableTennisSimScene.PADDLE_H; }
  float pw()   { return TableTennisSimScene.PADDLE_W; }

  void serve() {
    float lhome = TableTennisSimScene.LHOMEX, rhome = TableTennisSimScene.RHOMEX;
    leftPaddleX = lhome; rightPaddleX = rhome;
    float backOffset = random(40, 220);
    float paddleX = leftServes ? (lhome - backOffset) : (rhome + backOffset);
    ballX = paddleX;
    if (leftServes) leftPaddleX = paddleX; else rightPaddleX = paddleX;
    ballY  = tableY() - 60 + random(-6, 6);
    ballVY = random(-9, -7);
    float toNetSign = (netX() > paddleX) ? 1 : -1;
    ballVX = toNetSign * random(0.2, 0.5);
    ballZ  = random(-1, 1) * (TableTennisSimScene.TABLE_DEPTH / 2 - ballR() * 2);
    ballVZ = 0; leftPaddleZ = rightPaddleZ = 0;
    spin = random(-0.12, 0.12);
    inServeDrop = true; serveBounced = false; rallyStarted = false;
    lastBounceSide = 0; lastHitSide = 0; consecutiveBounces = 0; rallyCount = 0;
    lastDirSign = leftServes ? -1 : 1;
    moonThisPoint = false; faultThisPoint = false; pointFrames = 0;
  }

  void reshapeServeLaunch() {
    float dir = (netX() > ballX) ? 1 : -1;
    ballVX = dir * 10.0; ballVY = 2.0;
  }

  void step() {
    // ── post-point pause: coast, then serve ─────────────────────────────────
    if (pointPauseFrames > 0) {
      pointPauseFrames--;
      ballVY += G(); ballVX *= TableTennisSimScene.DRAG; ballX += ballVX; ballY += ballVY;
      if (pointPauseFrames == 0) serve();
      return;
    }
    pointFrames++;
    if (pointFrames > 2000) { awardPoint(random(1) < 0.5); return; }  // stuck → break

    // ── serve toss → auto-hit ───────────────────────────────────────────────
    if (inServeDrop) {
      ballVY += G(); ballY += ballVY;
      float serveHitY = leftServes ? leftPaddleY : rightPaddleY;
      if (ballY >= serveHitY && ballVY > 0) {
        float speed = (9 + rallyCount * 0.1) * TableTennisSimScene.SPEEDMULT;
        ballVX = leftServes ? speed : -speed; ballVY = 8; inServeDrop = false;
        reshapeServeLaunch();
      }
      return;
    }

    moveAI();

    // ── normal flight (with the Magnus runaway guard) ───────────────────────
    float magnusTerm = constrain(spin * abs(ballVX) * genome.magnusStrength,
                                 -genome.magnusTermMax, genome.magnusTermMax);
    ballVY += magnusTerm;
    spin   *= genome.spinFlightDecay;
    ballVX *= TableTennisSimScene.DRAG;
    float prevX = ballX;
    ballX += ballVX; ballY += ballVY;
    if (ballY < -ballR()) moonThisPoint = true;   // arced above the court top

    // depth (cosmetic; X/Y physics above are untouched so fitness is unchanged)
    ballZ += ballVZ;
    float halfD = TableTennisSimScene.TABLE_DEPTH / 2 - ballR();
    if (ballZ >  halfD) { ballZ =  halfD; ballVZ *= -0.65; }
    if (ballZ < -halfD) { ballZ = -halfD; ballVZ *= -0.65; }
    ballVZ *= 0.994;

    // net collision
    float netTop = tableY() - netH();
    if (ballY + ballR() > netTop && ballY - ballR() < tableY()) {
      boolean crossed = (prevX < netX()) != (ballX < netX());
      if (crossed) {
        ballX = prevX < netX() ? netX() - ballR() - 1 : netX() + ballR() + 1;
        ballVX *= -0.4; ballVY *= 0.3;
      }
    }

    // table bounce
    if (ballY + ballR() > tableY() && ballVY > 0) {
      ballY = tableY() - ballR(); ballVY *= -0.65; ballVX *= 0.96; spin *= 0.76;
      if (onTableBounce()) return;   // returns true if a point was awarded
    }
    // ceiling
    if (ballY - ballR() < 0 && ballVY < 0) { ballY = ballR(); ballVY *= -0.75; }

    // paddle returns
    if (checkPaddle(true,  leftPaddleX,  leftPaddleY))  return;
    if (checkPaddle(false, rightPaddleX, rightPaddleY)) return;

    // escaped past a paddle → out
    if (ballX < TableTennisSimScene.LHOMEX - 80)      { awardPoint(escapeWinnerLeft(-1)); return; }
    else if (ballX > TableTennisSimScene.RHOMEX + 80) { awardPoint(escapeWinnerLeft(1));  return; }
  }

  boolean escapeWinnerLeft(int escapedSide) {
    boolean landedOnEscapeSide = (lastBounceSide == escapedSide);
    if (landedOnEscapeSide) return escapedSide == 1;
    return escapedSide == -1;
  }

  // returns true if a point was awarded (caller bails)
  boolean onTableBounce() {
    int side = ballX < netX() ? -1 : 1;
    if (!serveBounced) {
      int serverSide = leftServes ? -1 : 1;
      if (side != serverSide) { faultThisPoint = true; awardPoint(!leftServes); return true; }
      float vy = -sqrt(2 * G() * (netH() + 70));
      float tApex = -vy / G();
      float distToNet = abs(netX() - ballX);
      float vx = constrain(distToNet / tApex, 6, 18);
      float dir = (netX() > ballX) ? 1 : -1;
      ballVY = vy; ballVX = dir * vx; serveBounced = true;
      return false;
    }
    if (!rallyStarted) {
      int opp = leftServes ? 1 : -1;
      if (side == opp) { rallyStarted = true; lastBounceSide = side; consecutiveBounces = 1; }
      else { faultThisPoint = true; awardPoint(!leftServes); return true; }
      return false;
    }
    if (lastBounceSide == 0) {
      if (side == lastHitSide) { awardPoint(lastHitSide > 0); return true; }
      lastBounceSide = side; consecutiveBounces = 1;
    } else if (side == lastBounceSide) {
      consecutiveBounces++;
      if (consecutiveBounces >= 2) { awardPoint(side > 0); return true; }
    } else { lastBounceSide = side; consecutiveBounces = 1; }
    return false;
  }

  boolean checkPaddle(boolean isLeft, float px, float py) {
    if (isLeft  && ballVX >= 0) return false;
    if (!isLeft && ballVX <= 0) return false;
    if (abs(ballX - px) > pw() / 2 + ballR() + 6) return false;
    if (abs(ballY - py) > ph() / 2 + ballR() + 4) return false;

    if (rallyStarted) {
      int pside = isLeft ? -1 : 1;
      if (lastBounceSide != pside) { awardPoint(!isLeft); return true; }
    }
    float hitPos = constrain((ballY - py) / (ph() / 2), -1, 1);
    float power    = random(6, 13);
    float speedMod = random(0.88, 1.14);
    float cap      = 22 * TableTennisSimScene.SPEEDMULT;
    float newSpeed = constrain((abs(ballVX) * speedMod + power * 0.3) * TableTennisSimScene.SPEEDMULT,
                               6 * TableTennisSimScene.SPEEDMULT, cap);
    ballVX = isLeft ? newSpeed : -newSpeed;
    ballVY = constrain(hitPos * 2 + random(-14, -1), -genome.launchVyMax, -2);
    float paddleVY = isLeft ? (leftPaddleY - prevLeftPaddleY) : (rightPaddleY - prevRightPaddleY);
    spin = constrain((hitPos * 0.10 - paddleVY * genome.brushCoeff) + random(-0.04, 0.04), -0.4, 0.4);
    ballVZ += (ballZ - (isLeft ? leftPaddleZ : rightPaddleZ)) * 0.05 + random(-1.5, 1.5);  // depth spread
    rallyCount++; lastHitSide = isLeft ? -1 : 1; lastBounceSide = 0; consecutiveBounces = 0;
    return false;
  }

  void moveAI() {
    prevLeftPaddleY = leftPaddleY; prevRightPaddleY = rightPaddleY;
    leftPaddleZ  += (ballZ - leftPaddleZ)  * 0.12;   // paddles track the ball in depth
    rightPaddleZ += (ballZ - rightPaddleZ) * 0.12;
    float restY = tableY() - 120;
    float yMin = ph() / 2, yMax = tableY() - ph() / 2 - 4;

    // refresh miss offsets when the ball reverses direction
    int dir = ballVX < 0 ? -1 : 1;
    if (dir != lastDirSign) {
      float MISS = 0.10;   // 10% of approaches get a big miss → keeps points ending
      leftMiss  = random(1) < MISS ? random(-1, 1) * ph() * 1.4 : random(-ph()*0.12, ph()*0.12);
      rightMiss = random(1) < MISS ? random(-1, 1) * ph() * 1.4 : random(-ph()*0.12, ph()*0.12);
      lastDirSign = dir;
    }
    float lt = (ballVX < 0) ? ballY + leftMiss  : restY;
    float rt = (ballVX > 0) ? ballY + rightMiss : restY;
    leftPaddleY  += (constrain(lt, yMin, yMax) - leftPaddleY)  * genome.aiSpeed;
    rightPaddleY += (constrain(rt, yMin, yMax) - rightPaddleY) * genome.aiSpeed;
    // step paddles toward home X (servers stand back; otherwise rest at home)
    leftPaddleX  += (TableTennisSimScene.LHOMEX - leftPaddleX)  * 0.15;
    rightPaddleX += (TableTennisSimScene.RHOMEX - rightPaddleX) * 0.15;
  }

  void awardPoint(boolean leftScored) {
    if (leftScored) leftPoints++; else rightPoints++;
    boolean serverScored = (leftServes == leftScored);
    pointsPlayed++;
    if (serverScored) serverWins++; else receiverWins++;
    if (moonThisPoint) moonPoints++;
    if (faultThisPoint) faults++;
    rallyLenSum += rallyCount;
    if (leftPoints >= 11 || rightPoints >= 11) { leftPoints = rightPoints = 0; } // new game
    leftServes = !leftServes;          // alternate serve
    pointPauseFrames = 40;             // brief coast before next serve
  }

  // ── fitness (stability + realism), 0..1 ─────────────────────────────────────
  float fitness() {
    if (pointsPlayed == 0) return 0;
    float moonRate  = (float) moonPoints / pointsPlayed;        // want 0
    float faultRate = (float) faults / pointsPlayed;            // want low
    float avgRally  = (float) rallyLenSum / pointsPlayed;
    float balance   = abs(serverWins - receiverWins) / (float) pointsPlayed;  // 0 = even
    float stability = 1 - moonRate;
    float serveOK   = 1 - constrain(faultRate, 0, 1);
    float balanceS  = 1 - balance;
    float rallyS    = constrain(avgRally / 6.0, 0, 1);          // ~6 hits = human-ish
    return 0.40 * stability + 0.20 * serveOK + 0.20 * balanceS + 0.20 * rallyS;
  }

  // running fitness for the live cell tint (cheap proxy before a full gen)
  float liveFitness() { return pointsPlayed == 0 ? 0.5 : fitness(); }
}
