/**
 * SimCubeScene (scene 54) — "Sim Cube"
 *
 * The Sim Lab (scene 53) laid out in 3D: many headless table-tennis matches
 * (TTSimGame), one at each cell of a cube-shaped lattice, floating as little
 * mini-court cards. Same genetic tuner as the 2D lab — each card is tinted by
 * fitness (red = unstable/moon, green = clean) and the population evolves on
 * each beat.
 *
 * Purely a visual sibling of scene 53 — it does NOT write tt_genome.cfg (the 2D
 * lab stays the canonical trainer so the two can't fight over the file).
 *
 * Two views (B / 'v' to toggle):
 *   CUBE   — the lattice of mini-courts in a rotating cube
 *   LADDER — king-of-the-hill: genomes sorted by fitness, fittest on top,
 *            gliding to new slots each generation so you watch selection happen
 *
 * Audio:   bass → sim speed (x1..x8)   beat → advance a generation
 * Control: RStick / mouse-drag → orbit   LStick Y → zoom   Y → toggle auto-spin
 *          A force gen   X reseed   B switch view   RT/LT grow/shrink lattice
 *
 * Lattice size is live: the "Lattice / side" knob (triggers, keyboard +/-, or
 * the web slider) sets the cells-per-side, so the population scales from 1 sim
 * (side 1) up to 512 (side 8). Push a fast machine high; tame an old laptop low.
 */
class SimCubeScene implements IScene {

  // ── Population & evolution ────────────────────────────────────────────────
  static final int MAX_LATTICE_SIDE     = 8;     // 8×8×8 = 512 sims (the ceiling)
  static final int DEFAULT_LATTICE_SIDE = 3;     // sane default: 27 sims
  static final int ELITE_COUNT          = 7;     // top genomes that survive a generation
  static final int MIN_STEPS_PER_GEN    = 240;   // don't evolve before this many sim steps
  static final int MAX_STEPS_PER_GEN    = 1400;  // force a generation after this many
  static final int MAX_SPEED_MULTIPLIER = 8;     // loudest bass runs the sims this much faster

  // ── Camera ────────────────────────────────────────────────────────────────
  static final float CAMERA_DISTANCE_FACTOR = 1.25;     // × screen height × zoom
  static final float FIELD_OF_VIEW          = PI / 3.0;
  static final float NEAR_CLIP              = 10;
  static final float FAR_CLIP               = 30000;
  static final float MIN_ZOOM               = 0.4;      // closest dolly-in
  static final float MAX_ZOOM               = 3.0;      // farthest dolly-out
  static final float ZOOM_SPEED             = 0.03;
  static final float ORBIT_TURN_SPEED       = 0.05;     // left/right look
  static final float ORBIT_TILT_SPEED       = 0.04;     // up/down look
  static final float MAX_TILT               = 1.4;      // radians, up or down
  static final float AUTO_SPIN_SPEED        = 0.004;    // idle turntable speed
  static final float AUTO_SPIN_BEAT_KICK    = 0.01;     // extra spin on a beat
  static final float STICK_DEADZONE         = 0.15;     // ignore tiny stick wobble
  static final float TRIGGER_PRESS_LEVEL    = 0.5;      // counts as a trigger "click"
  static final int   SPHERE_SMOOTHNESS      = 8;        // sphereDetail for the balls

  // ── Cube view layout (fractions of screen height) ─────────────────────────
  static final float CUBE_SPREAD          = 0.68;   // far corner-to-corner spread
  static final float CARD_TO_CELL_RATIO   = 0.647;  // court width vs cell spacing
  static final float LONE_CARD_WIDTH      = 0.22;   // court width when there's a single sim
  static final float LONE_CELL_PITCH      = 0.34;   // cell pitch when there's a single sim

  // ── Ladder view layout ────────────────────────────────────────────────────
  static final float LADDER_WIDTH          = 1.7;   // horizontal spread (× height)
  static final float LADDER_HEIGHT         = 1.30;  // vertical fitness axis (× height)
  static final float LADDER_CARD_MAX_WIDTH = 0.16;  // cap a card's width (× height)
  static final float LADDER_CARD_TO_COLUMN = 0.85;  // card width vs column spacing
  static final float CARD_GLIDE_SPEED      = 0.12;  // how fast cards slide to new slots

  // Camera starting pose for each view.
  static final float CUBE_START_TURN     = 0.6,  CUBE_START_TILT   = 0.45;
  static final float LADDER_START_TURN   = 0.0,  LADDER_START_TILT = 0.22;

  // ── Legal-play box proportions (fractions of the cell pitch) ──────────────
  // Real table tennis: the table is only ~76 cm tall but the ceiling is 4–5 m,
  // so the table sits LOW in the play volume — far more head-room than
  // floor-room (about 4.5 to 1). The table is drawn at the box's local y=0, and
  // up is the −y direction, so the ceiling reaches much further than the floor.
  static final float BOX_HALF_WIDTH    = 0.45;   // half the box width on X and Z
  static final float CEILING_HEIGHT    = 0.45;   // table → ceiling (up)
  static final float FLOOR_DEPTH       = 0.10;   // table → floor  (down), ~1/4.5 of ceiling

  // The play boxes are just a faint hint, not the focus. Their line opacity
  // fades as the lattice fills up, so a packed cube doesn't become a wall of
  // wireframe. (Opacity is 0..255; lower = more see-through.)
  static final float BOX_LINE_WEIGHT     = 1.0;
  static final float BOX_OPACITY_FEW     = 70;   // opacity for a small population
  static final float BOX_OPACITY_PACKED  = 16;   // opacity once the cube is packed
  static final int   BOX_FADE_START_SIMS = 27;   // at/under this many sims: boldest
  static final int   BOX_FADE_END_SIMS   = 343;  // at/over this many sims: faintest

  // ── Visual effect tuning ──────────────────────────────────────────────────
  static final float BEAT_FLASH_FADE      = 0.08;  // how fast the beat flash decays
  static final int   EVOLVE_PULSE_FRAMES  = 8;     // green pulse length after a generation
  static final float EVOLVE_PULSE_GLOW     = 60;   // extra brightness during that pulse
  static final float BALL_SIZE_BOOST       = 1.4;  // draw balls a bit bigger so they read
  static final float MIN_DRAWN_SIZE        = 2;    // never draw a shape smaller than this

  // ── HUD ───────────────────────────────────────────────────────────────────
  static final float HUD_TEXT_FACTOR = 0.022;  // text height vs screen height
  static final float HUD_TEXT_MIN    = 12, HUD_TEXT_MAX = 26;
  static final float HUD_MARGIN_X    = 18, HUD_MARGIN_Y = 14;

  // ── State ─────────────────────────────────────────────────────────────────
  SceneParam latticeSizeKnob =
      new SceneParam("grid", "Lattice / side", 1, MAX_LATTICE_SIDE, DEFAULT_LATTICE_SIDE);
  SceneParam[] params = { latticeSizeKnob };
  int latticeSide     = DEFAULT_LATTICE_SIDE;          // cells along one edge of the cube
  int populationSize  = latticeSide * latticeSide * latticeSide;

  TTSimGame[] games = new TTSimGame[populationSize];
  TTGenome bestGenome; float bestFitness = -1;
  int generation = 0, stepsThisGen = 0;

  float orbitTurn = CUBE_START_TURN;   // left/right camera angle
  float orbitTilt = CUBE_START_TILT;   // up/down camera angle
  float zoom = 1.0;                    // 1 = default camera distance
  boolean autoSpin = true;
  float beatFlash = 0;
  int lastEvolveFrame = 0;

  // view mode
  static final int VIEW_CUBE = 0, VIEW_LADDER = 1;
  int view = VIEW_CUBE;
  float[] ladderX, ladderY;            // smoothed ladder slot per game index
  boolean ladderSnapped = false;       // snap cards on first ladder frame, glide after
  boolean leftTriggerWasDown = false, rightTriggerWasDown = false;

  void onEnter() { reseed(); }
  void onExit() {}

  // Resize the lattice to the given cells-per-side (allocates the game array and
  // ladder buffers); does not seed the population.
  void resizeLattice(int cellsPerSide) {
    latticeSide = constrain(cellsPerSide, 1, MAX_LATTICE_SIDE);
    populationSize = latticeSide * latticeSide * latticeSide;
    if (games == null || games.length != populationSize) {
      games   = new TTSimGame[populationSize];
      ladderX = new float[populationSize];
      ladderY = new float[populationSize];
      ladderSnapped = false;
    }
  }

  // Build a genome from its six tuning numbers. (The 2D lab owns its own copy of
  // this; inner classes can't share static helpers, so this tiny duplicate keeps
  // the scene self-contained.)
  TTGenome makeGenome(float magnusStrength, float magnusTermMax, float spinFlightDecay,
                      float brushCoeff, float launchVyMax, float aiSpeed) {
    TTGenome genome = new TTGenome();
    genome.magnusStrength  = magnusStrength;
    genome.magnusTermMax   = magnusTermMax;
    genome.spinFlightDecay = spinFlightDecay;
    genome.brushCoeff      = brushCoeff;
    genome.launchVyMax     = launchVyMax;
    genome.aiSpeed         = aiSpeed;
    return genome;
  }

  TTGenome randomGenome() {
    return makeGenome(random(0.02, 0.07), random(0.04, 0.30), random(0.95, 1.0),
                      random(0.005, 0.05), random(10, 22), random(0.20, 0.45));
  }

  // Arbitrary-but-fixed seeds so each match starts with deterministic variety.
  int startingSeed(int index) { return index * 6151 + 17; }
  int childSeed(int index)    { return index * 99991 + generation * 13 + 3; }

  // Fill the population with a fresh set of genomes. The first two slots are the
  // canonical tuned / "always moons" pair when the lattice is big enough.
  void seedPopulation() {
    for (int i = 0; i < populationSize; i++) {
      TTGenome genome;
      if (i == 0)                          genome = makeGenome(0.045, 0.10, 0.98, 0.015, 12, 0.34); // tuned
      else if (i == 1 && populationSize > 1) genome = makeGenome(0.045, 9.99, 1.00, 0.030, 16, 0.34); // moony
      else                                 genome = randomGenome();
      games[i] = new TTSimGame(genome, startingSeed(i));
    }
  }

  void reseed() {
    resizeLattice(round(latticeSizeKnob.value));
    seedPopulation();
    generation = 0; stepsThisGen = 0; bestGenome = null; bestFitness = -1;
  }

  void drawScene(PGraphics pg) {
    pg.colorMode(RGB, 255);

    // ── live lattice resize (knob / triggers / web slider) ──────────────────
    int requestedSide = round(latticeSizeKnob.value);
    if (requestedSide != latticeSide) {
      resizeLattice(requestedSide);
      seedPopulation();
      generation = 0; stepsThisGen = 0;   // bestGenome persists across a resize
    }

    // ── advance the sims (louder bass = faster) ─────────────────────────────
    int simStepsThisFrame = 1 + round(constrain(analyzer.bass, 0, 1) * (MAX_SPEED_MULTIPLIER - 1));
    for (int step = 0; step < simStepsThisFrame; step++) {
      for (int i = 0; i < populationSize; i++) games[i].step();
      stepsThisGen++;
    }

    boolean onBeat = audio.beat.isOnset();
    if (onBeat) beatFlash = 1.0;
    beatFlash = lerp(beatFlash, 0, BEAT_FLASH_FADE);
    if ((onBeat && stepsThisGen >= MIN_STEPS_PER_GEN) || stepsThisGen >= MAX_STEPS_PER_GEN) evolve();

    if (autoSpin && view == VIEW_CUBE) orbitTurn += AUTO_SPIN_SPEED + beatFlash * AUTO_SPIN_BEAT_KICK;

    // ── 3D camera orbiting the centre (shared by both views) ────────────────
    pg.background(6, 8, 12);
    float centerX = pg.width / 2.0, centerY = pg.height / 2.0, centerZ = 0;
    float cameraDistance = pg.height * CAMERA_DISTANCE_FACTOR * zoom;
    float cameraX = centerX + cameraDistance * cos(orbitTilt) * sin(orbitTurn);
    float cameraY = centerY - cameraDistance * sin(orbitTilt);
    float cameraZ = centerZ + cameraDistance * cos(orbitTilt) * cos(orbitTurn);
    pg.camera(cameraX, cameraY, cameraZ, centerX, centerY, centerZ, 0, 1, 0);
    pg.perspective(FIELD_OF_VIEW, (float) pg.width / pg.height, NEAR_CLIP, FAR_CLIP);
    pg.hint(ENABLE_DEPTH_TEST);
    pg.lights();
    pg.sphereDetail(SPHERE_SMOOTHNESS);

    if (view == VIEW_CUBE) drawCubeView(pg, centerX, centerY, centerZ);
    else                   drawLadderView(pg, centerX, centerY, centerZ);

    drawHud(pg, simStepsThisFrame);
  }

  // ── CUBE view: the lattice of mini-courts ──────────────────────────────────
  void drawCubeView(PGraphics pg, float centerX, float centerY, float centerZ) {
    // The lattice keeps the same screen footprint at any size: `spread` is the
    // far corner-to-corner distance and the cards shrink to fit between cells.
    float spread      = pg.height * CUBE_SPREAD;
    float cellSpacing = (latticeSide > 1) ? spread / (latticeSide - 1) : 0;
    float cardWidth   = (latticeSide > 1) ? cellSpacing * CARD_TO_CELL_RATIO
                                          : pg.height * LONE_CARD_WIDTH;
    float worldScale  = cardWidth / TableTennisSimScene.VW;   // virtual court units → world
    float centerCell  = (latticeSide - 1) / 2.0;              // index of the middle cell

    // Legal-play box, bounded by the cell spacing so it never bleeds into a
    // neighbour. With a single sim there's no spacing, so fall back to a size
    // relative to the court.
    float cellPitch = (latticeSide > 1) ? cellSpacing : pg.height * LONE_CELL_PITCH;
    float boxWidth   = cellPitch * BOX_HALF_WIDTH * 2;
    float boxHeight  = cellPitch * (CEILING_HEIGHT + FLOOR_DEPTH);
    float boxCenterY = cellPitch * (FLOOR_DEPTH - CEILING_HEIGHT) / 2;  // negative = shifted up

    pg.pushMatrix();
    pg.translate(centerX, centerY, centerZ);

    // Faint outer hull — built from the SAME box geometry as the cells, so a
    // green box can never poke outside it: the spread across cells plus one box
    // on each face, sharing the box's upward offset.
    pg.noFill(); pg.stroke(40, 60, 80, 90); pg.strokeWeight(1);
    pg.pushMatrix();
    pg.translate(0, boxCenterY, 0);
    pg.box(spread + boxWidth, spread + boxHeight, spread + boxWidth);
    pg.popMatrix();

    for (int i = 0; i < populationSize; i++) {
      int column = i % latticeSide;                  // x
      int row    = (i / latticeSide) % latticeSide;  // y
      int layer  = i / (latticeSide * latticeSide);  // z
      pg.pushMatrix();
      pg.translate((column - centerCell) * cellSpacing,
                   (row    - centerCell) * cellSpacing,
                   (layer  - centerCell) * cellSpacing);
      drawMiniCourt(pg, games[i], worldScale, boxWidth, boxHeight, boxCenterY);
      pg.popMatrix();
    }
    pg.popMatrix();
  }

  // ── LADDER view: king-of-the-hill. Sort by fitness, put each genome on a
  // vertical axis (fittest at top), spread along the bottom by rank. Each frame
  // the cards glide toward their new slot, so when evolve() reshuffles the
  // ranking you SEE winners climb and losers sink + dissolve into children. ──
  void drawLadderView(PGraphics pg, float centerX, float centerY, float centerZ) {
    Integer[] ranking = indexesSortedByFitness();
    float ladderWidth   = pg.height * LADDER_WIDTH;
    float ladderHeight  = pg.height * LADDER_HEIGHT;
    float columnSpacing = ladderWidth / max(1, populationSize);
    float cardWidth     = min(pg.height * LADDER_CARD_MAX_WIDTH, columnSpacing * LADDER_CARD_TO_COLUMN);
    float worldScale    = cardWidth / TableTennisSimScene.VW;

    float cellPitch  = columnSpacing;          // box bounded by its column
    float boxWidth   = cellPitch * BOX_HALF_WIDTH * 2;
    float boxHeight  = cellPitch * (CEILING_HEIGHT + FLOOR_DEPTH);
    float boxCenterY = cellPitch * (FLOOR_DEPTH - CEILING_HEIGHT) / 2;

    float halfWidth  = ladderWidth / 2;
    float halfHeight = ladderHeight / 2;

    pg.pushMatrix();
    pg.translate(centerX, centerY, centerZ);

    // Faint rails marking the best (top) and worst (bottom) fitness levels.
    pg.stroke(40, 70, 90, 110); pg.strokeWeight(1);
    pg.line(-halfWidth, -halfHeight, 0,  halfWidth, -halfHeight, 0);  // fitness 1 (top)
    pg.line(-halfWidth,  halfHeight, 0,  halfWidth,  halfHeight, 0);  // fitness 0 (bottom)

    for (int rank = 0; rank < populationSize; rank++) {
      int gameIndex = ranking[rank];
      float fitness = constrain(games[gameIndex].liveFitness(), 0, 1);
      float rankFraction = (populationSize > 1) ? rank / (float) (populationSize - 1) : 0;
      float targetX = lerp(-halfWidth, halfWidth, rankFraction);
      float targetY = lerp(halfHeight, -halfHeight, fitness);   // higher fitness = higher up

      if (!ladderSnapped) {
        ladderX[gameIndex] = targetX; ladderY[gameIndex] = targetY;
      } else {
        ladderX[gameIndex] = lerp(ladderX[gameIndex], targetX, CARD_GLIDE_SPEED);
        ladderY[gameIndex] = lerp(ladderY[gameIndex], targetY, CARD_GLIDE_SPEED);
      }
      pg.pushMatrix();
      pg.translate(ladderX[gameIndex], ladderY[gameIndex], 0);
      drawMiniCourt(pg, games[gameIndex], worldScale, boxWidth, boxHeight, boxCenterY);
      pg.popMatrix();
    }
    ladderSnapped = true;
    pg.popMatrix();
  }

  // Game indexes sorted best fitness first (selection sort — population ≤ 512).
  Integer[] indexesSortedByFitness() {
    Integer[] ranking = new Integer[populationSize];
    float[] fitness = new float[populationSize];
    for (int i = 0; i < populationSize; i++) { ranking[i] = i; fitness[i] = games[i].liveFitness(); }
    for (int i = 0; i < populationSize; i++)
      for (int j = i + 1; j < populationSize; j++)
        if (fitness[ranking[j]] > fitness[ranking[i]]) {
          Integer swap = ranking[i]; ranking[i] = ranking[j]; ranking[j] = swap;
        }
    return ranking;
  }

  // One mini 3D court in the current local frame. Layout: the table surface sits
  // at local y=0, the net at local x=0, and the table's depth runs along z. All
  // sizes are baked in with `worldScale` (we never call pg.scale(), which would
  // balloon the stroke weight in P3D). boxWidth/boxHeight are the full size of
  // the legal-play box and boxCenterY shifts it up so the table sits low in it.
  void drawMiniCourt(PGraphics pg, TTSimGame game, float worldScale,
                     float boxWidth, float boxHeight, float boxCenterY) {
    float fitness = constrain(game.liveFitness(), 0, 1);
    float pulse = (frameCount - lastEvolveFrame < EVOLVE_PULSE_FRAMES) ? EVOLVE_PULSE_GLOW : 0;

    float netX      = TableTennisSimScene.NETX;
    float tableY    = TableTennisSimScene.TABLEY;
    float halfDepth = TableTennisSimScene.TABLE_DEPTH / 2;
    float leftHomeX = TableTennisSimScene.LHOMEX, rightHomeX = TableTennisSimScene.RHOMEX;
    float netHeight = TableTennisSimScene.NET_H, ballRadius = TableTennisSimScene.BALL_R;
    float paddleHeight = TableTennisSimScene.PADDLE_H;
    float paddleWidth  = TableTennisSimScene.PADDLE_W;
    float paddleDepth  = TableTennisSimScene.PADDLE_Z;

    // Fitness-tinted legal-play box (red = unstable/moon, green = clean). The
    // table (y=0) sits low in it — short floor gap, tall head-room. Kept mostly
    // see-through (and fainter the more cells there are) so it doesn't distract.
    float boxOpacity = constrain(
        map(populationSize, BOX_FADE_START_SIMS, BOX_FADE_END_SIMS, BOX_OPACITY_FEW, BOX_OPACITY_PACKED),
        BOX_OPACITY_PACKED, BOX_OPACITY_FEW);
    pg.noFill(); pg.strokeWeight(BOX_LINE_WEIGHT);
    pg.stroke(255 * (1 - fitness), 200 * fitness + 40 + pulse, 60 * fitness + pulse * 0.5, boxOpacity);
    pg.pushMatrix();
    pg.translate(0, boxCenterY, 0);
    pg.box(boxWidth, boxHeight, boxWidth);
    pg.popMatrix();

    // Table surface (a flat quad at local y=0).
    pg.fill(18, 70, 36); pg.stroke(120, 200, 140, 120); pg.strokeWeight(1);
    pg.beginShape(QUAD);
    pg.vertex((leftHomeX  - netX) * worldScale, 0, -halfDepth * worldScale);
    pg.vertex((rightHomeX - netX) * worldScale, 0, -halfDepth * worldScale);
    pg.vertex((rightHomeX - netX) * worldScale, 0,  halfDepth * worldScale);
    pg.vertex((leftHomeX  - netX) * worldScale, 0,  halfDepth * worldScale);
    pg.endShape(CLOSE);

    // Net (a vertical quad across the depth at x=0).
    pg.noStroke(); pg.fill(220, 230, 245, 90);
    pg.beginShape(QUAD);
    pg.vertex(0, 0,                     -halfDepth * worldScale);
    pg.vertex(0, -netHeight * worldScale, -halfDepth * worldScale);
    pg.vertex(0, -netHeight * worldScale,  halfDepth * worldScale);
    pg.vertex(0, 0,                      halfDepth * worldScale);
    pg.endShape(CLOSE);

    // Paddles.
    pg.noStroke(); pg.fill(90, 170, 255);
    drawBoxAt(pg, (game.leftPaddleX  - netX) * worldScale, (game.leftPaddleY  - tableY) * worldScale,
              game.leftPaddleZ  * worldScale,
              paddleWidth * worldScale, paddleHeight * worldScale, paddleDepth * worldScale);
    pg.fill(255, 130, 90);
    drawBoxAt(pg, (game.rightPaddleX - netX) * worldScale, (game.rightPaddleY - tableY) * worldScale,
              game.rightPaddleZ * worldScale,
              paddleWidth * worldScale, paddleHeight * worldScale, paddleDepth * worldScale);

    // Ball — turns red and pins to the table top when it "moons" (flies off).
    float drawnBallY = constrain(game.ballY, -ballRadius, TableTennisSimScene.VH);
    boolean mooned = game.ballY < -ballRadius;
    pg.fill(mooned ? color(255, 60, 60) : color(255, 250, 200));
    drawSphereAt(pg, (game.ballX - netX) * worldScale, (drawnBallY - tableY) * worldScale,
                 game.ballZ * worldScale, ballRadius * worldScale * BALL_SIZE_BOOST);
  }

  void drawBoxAt(PGraphics pg, float x, float y, float z, float w, float h, float d) {
    pg.pushMatrix();
    pg.translate(x, y, z);
    pg.box(max(MIN_DRAWN_SIZE, w), max(MIN_DRAWN_SIZE, h), max(MIN_DRAWN_SIZE, d));
    pg.popMatrix();
  }
  void drawSphereAt(PGraphics pg, float x, float y, float z, float radius) {
    pg.pushMatrix();
    pg.translate(x, y, z);
    pg.sphere(max(MIN_DRAWN_SIZE, radius));
    pg.popMatrix();
  }

  void drawHud(PGraphics pg, int simStepsThisFrame) {
    pg.hint(DISABLE_DEPTH_TEST);
    pg.camera(); pg.perspective(); pg.noLights();
    pg.textAlign(LEFT, TOP); pg.fill(60, 230, 120);
    pg.textSize(constrain(pg.height * HUD_TEXT_FACTOR, HUD_TEXT_MIN, HUD_TEXT_MAX));
    String heading = (view == VIEW_CUBE)
      ? "SIM CUBE — " + latticeSide + "×" + latticeSide + "×" + latticeSide + " = " + populationSize + " sims"
      : "SIM LADDER — " + populationSize + " genomes, fittest on top";
    pg.text(heading + "   gen " + generation
          + "   best " + nf(bestFitness < 0 ? 0 : bestFitness, 1, 3)
          + "   speed x" + simStepsThisFrame, HUD_MARGIN_X, HUD_MARGIN_Y);
    pg.hint(ENABLE_DEPTH_TEST);
  }

  void evolve() {
    Integer[] ranking = indexesSortedByFitness();
    for (int i = 0; i < populationSize; i++) games[i].genome.fitness = games[i].fitness();

    int bestIndex = ranking[0];
    float topFitness = games[bestIndex].fitness();
    if (topFitness > bestFitness) { bestFitness = topFitness; bestGenome = games[bestIndex].genome.copy(); }

    // Small lattices (a single sim) keep everyone; otherwise the top genomes
    // survive untouched and the rest become mutated children of a random elite.
    int survivingElites = min(ELITE_COUNT, populationSize);
    TTGenome[] elites = new TTGenome[survivingElites];
    for (int i = 0; i < survivingElites; i++) elites[i] = games[ranking[i]].genome.copy();

    for (int rank = 0; rank < populationSize; rank++) {
      int gameIndex = ranking[rank];
      if (rank < survivingElites) {
        games[gameIndex].resetStats();
      } else {
        TTGenome parent = elites[(int) random(survivingElites)];
        games[gameIndex] = new TTSimGame(parent.mutate(), childSeed(gameIndex));
      }
    }
    generation++; stepsThisGen = 0; lastEvolveFrame = frameCount;
  }

  // Switch view, giving each a sensible default camera (the ladder reads best
  // front-on and slightly tilted; the cube wants the 3/4 turntable view).
  void switchToView(int newView) {
    view = newView;
    autoSpin  = (newView == VIEW_CUBE);
    orbitTurn = (newView == VIEW_CUBE) ? CUBE_START_TURN : LADDER_START_TURN;
    orbitTilt = (newView == VIEW_CUBE) ? CUBE_START_TILT : LADDER_START_TILT;
    zoom = 1.0;
    ladderSnapped = false;   // snap cards to their slots on entry, then glide
  }

  void toggleView() { switchToView(view == VIEW_CUBE ? VIEW_LADDER : VIEW_CUBE); }

  void applyController(Controller c) {
    if (c.aJustPressed) evolve();
    if (c.xJustPressed) reseed();
    if (c.yJustPressed) autoSpin = !autoSpin;
    if (c.bJustPressed) toggleView();

    // Triggers grow / shrink the lattice one shell at a time, only on the press
    // (a held trigger shouldn't keep rebuilding). The D-pad is off-limits here —
    // it toggles backgrounds globally. drawScene() applies the resize.
    boolean leftTriggerDown  = c.lt > TRIGGER_PRESS_LEVEL;
    boolean rightTriggerDown = c.rt > TRIGGER_PRESS_LEVEL;
    if (rightTriggerDown && !rightTriggerWasDown) latticeSizeKnob.set(round(latticeSizeKnob.value) + 1);
    if (leftTriggerDown  && !leftTriggerWasDown)  latticeSizeKnob.set(round(latticeSizeKnob.value) - 1);
    leftTriggerWasDown  = leftTriggerDown;
    rightTriggerWasDown = rightTriggerDown;

    // Right stick orbits the camera.
    float rightStickX = map(c.rx, 0, width, -1, 1);
    float rightStickY = map(c.ry, 0, height, -1, 1);
    if (abs(rightStickX) > STICK_DEADZONE || abs(rightStickY) > STICK_DEADZONE) {
      autoSpin = false;
      orbitTurn += rightStickX * ORBIT_TURN_SPEED;
      orbitTilt = constrain(orbitTilt + rightStickY * ORBIT_TILT_SPEED, -MAX_TILT, MAX_TILT);
    }

    // Left stick (up/down) dollies the camera: push up = zoom in, pull down = out.
    float leftStickY = map(c.ly, 0, height, -1, 1);
    if (abs(leftStickY) > STICK_DEADZONE) zoom = constrain(zoom + leftStickY * ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM);
  }

  void handleKey(char k) {
    if (k == 'a' || k == 'A') evolve();
    else if (k == 'x' || k == 'X') reseed();
    else if (k == 'y' || k == 'Y') autoSpin = !autoSpin;
    else if (k == 'v' || k == 'V') toggleView();
    else handleParamKey(k);   // - / + nudge the lattice-size knob (drawScene applies)
  }

  SceneParam[] getParams() { return params; }

  String[] getCodeLines() {
    return new String[] {
      "SIM CUBE — " + populationSize + " matches in a "
          + latticeSide + "×" + latticeSide + "×" + latticeSide + " lattice",
      "",
      "same headless physics + genetic tuner",
      "as the 2D Sim Lab (scene 53):",
      "  vy += clamp(spin*|vx|*magnus, ±cap)",
      "  spin *= spinDecay  (bleed in flight)",
      "",
      "cards tinted by fitness (red→green)",
      "beat → evolve   bass → speed x1..x8",
      "B: CUBE ⇄ LADDER (watch them climb)",
      "lattice 1..8/side → 1..512 sims (live)",
      "RStick orbit  LStick zoom  Y spin  A gen",
      "X reseed   RT/LT lattice size"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("RStick", "Orbit / look"),
      new ControllerLayout("LStick", "Zoom in / out"),
      new ControllerLayout("B", "Cube / Ladder view"),
      new ControllerLayout("Y", "Auto-spin on/off"),
      new ControllerLayout("A", "Force a generation"),
      new ControllerLayout("X", "Reseed population"),
      new ControllerLayout("RT / LT", "Grow / shrink lattice")
    };
  }
}
