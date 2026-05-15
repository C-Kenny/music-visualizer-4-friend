/**
 * TheyDontKnowScene — "they don't know" party meme.
 *
 * Pure black-outline-on-paper, hand-drawn meme aesthetic:
 *   - Lonely wojak guy (party hat, sad face, holding drink) isolated on the
 *     left behind a wall; floor steps down to the crowd.
 *   - Right side: spiky-haired guy (back) embracing a long-hair girl.
 *   - Bottom-left: short-hair guy from behind hugging a long-hair girl with
 *     one arm RAISED.
 *   - Foreground center: large crouched dancer in motion.
 *
 * All outline strokes are routed through HandyRenderer for jittered hand-drawn
 * texture (matches the original meme's sketchy lines). Crowd reacts to bass
 * (jump/bounce) and mid (sway). Lonely guy stays still beyond a tiny sad sway
 * and an occasional sip.
 */
class TheyDontKnowScene implements IScene {

  // ── Audio-tracked state ────────────────────────────────────────────────────
  float actualFps = 60.0;
  float fpsSum = 0;
  int   fpsCount = 0;
  float crowdEnergy = 0;
  float crowdSway   = 0;

  // Figures
  Figure lonely;
  Figure spikyGuy, kissGirl;
  Figure hugGuy, hugGirl;
  Figure dancer;

  // Lonely-guy idle: slow sway + occasional sip cycle (reaches cup to lips
  // and back). Sip phase 0..1 — 0=resting, 1=at lips.
  float lonelySway = 0;
  float sipPhase = 0;
  float sipCooldown = 4.0;

  // Foreground dancer cycles through moves so the front-and-center figure
  // stays visually fresh. Each move holds for ~1.5s.
  static final int MOVE_ARMS_OUT   = 0;
  static final int MOVE_RAISE_ROOF = 1;
  static final int MOVE_FIST_PUMP  = 2;
  static final int MOVE_SHIMMY     = 3;
  static final int MOVE_HEAD_BANG  = 4;
  static final int MOVE_COUNT      = 5;
  int   dancerMove = 0;
  // Use wall-clock millis for cycle timing — frameRate-based accumulation
  // was unreliable (the global frameRate doesn't always match actual render
  // rate, so timer drifted way slower than intended).
  int   dancerMoveLastMs = 0;
  int   dancerMoveDurationMs = 1500;

  // Sketchy renderer seed — keep it stable per scene-entry so jitter doesn't
  // crawl every frame (Handy's per-call randomness already adds life).
  int sketchSeed = 42;

  String[] THOUGHTS = {
    "they don't know I'm running at [FPS] FPS",
    "they don't know I'm written in Processing",
    "they don't know the drop is coming",
    "they don't know I read every FFT bin",
    "they don't know I have 50 scenes",
    "they don't know I came alone",
    "they don't know my pet is at home",
    "they don't know the DJ is my friend",
    "they don't know I made the visuals",
    "they don't know I'm just here for the snacks"
  };
  int   thoughtIndex = 0;
  float thoughtTimer = 0;

  int laidOutFor_w = -1, laidOutFor_h = -1;

  void onEnter() {
    thoughtIndex = (int) random(THOUGHTS.length);
    thoughtTimer = 0;
    sipPhase = 0;
    sipCooldown = 4.0 + random(2.0);
    sketchSeed = (int) random(1000);
    dancerMoveLastMs = 0;
    dancerMove = 0;
  }
  void onExit() {}
  void handleKey(char k) {}
  void applyController(Controller c) {}
  String[] getCodeLines() { return new String[]{ "they don't know" }; }
  ControllerLayout[] getControllerLayout() { return new ControllerLayout[0]; }

  // ── Layout ─────────────────────────────────────────────────────────────────
  void layout(int w, int h) {
    if (w == laidOutFor_w && h == laidOutFor_h) return;
    laidOutFor_w = w; laidOutFor_h = h;

    // Layout matches the source meme: lonely guy top-left, spiky-haired
    // guy + kiss girl middle-right, hugging pair bottom-left (large, faces
    // prominent), big crouched dancer dominating bottom-right. Dancer head
    // sits just above shoulders so it reads as "very close to camera".
    // Lonely guy upper-left on a raised platform, crowd on lower floor.
    // The wall + step divide the two zones (matches source meme).
    lonely    = new Figure(w * 0.25, h * 0.55, h * 0.32); lonely.intensity = 0.0;
    spikyGuy  = new Figure(w * 0.60, h * 0.86, h * 0.52); spikyGuy.intensity = 0.9; spikyGuy.phase = 0.0;
    kissGirl  = new Figure(w * 0.78, h * 0.86, h * 0.48); kissGirl.intensity = 0.8; kissGirl.phase = 0.4;
    hugGuy    = new Figure(w * 0.10, h * 1.05, h * 0.58); hugGuy.intensity = 0.9;   hugGuy.phase = 1.0;
    hugGirl   = new Figure(w * 0.28, h * 1.05, h * 0.58); hugGirl.intensity = 1.0;  hugGirl.phase = 1.6;
    dancer    = new Figure(w * 0.68, h * 1.18, h * 1.00); dancer.intensity = 1.2;   dancer.phase = 2.3;
  }

  // ── Sketchy renderer setup ──────────────────────────────────────────────────
  // h2 is the global plain HandyRenderer — re-bind to our buffer each frame
  // and re-apply roughness so other scenes can't leave it in a weird state.
  void setupSketchy(PGraphics pg) {
    h2.setGraphics(pg);
    h2.setSeed(sketchSeed);
    h2.setIsHandy(true);
    h2.setRoughness(1.4);
    // (Handy 2012 bundled jar lacks setBowing — would no-op anyway at default 1.0)
  }

  // ── Frame ──────────────────────────────────────────────────────────────────
  void drawScene(PGraphics pg) {
    pg.beginDraw();
    layout(pg.width, pg.height);

    fpsSum += frameRate; fpsCount++;
    if (fpsCount >= 30) { actualFps = fpsSum / fpsCount; fpsSum = 0; fpsCount = 0; }

    float kick = analyzer != null ? analyzer.bass : 0;
    float mid  = analyzer != null ? analyzer.mid  : 0;
    crowdEnergy = lerp(crowdEnergy, kick, 0.30);
    crowdSway   = lerp(crowdSway,   mid,  0.18);

    // Paper background — meme is pure white sketch.
    pg.background(245, 243, 238);

    // Subtle kick flash (paper-warm so we don't break the white-paper feel).
    if (kick > 0.65) {
      pg.noStroke();
      pg.fill(255, 200, 120, (kick - 0.65) * 220);
      pg.rect(0, 0, pg.width, pg.height);
    }

    setupSketchy(pg);

    pg.stroke(20);
    pg.strokeWeight(3.2 * uiScale());
    pg.noFill();

    // Wall + raised platform for lonely guy; step down to crowd floor.
    // Crowd floor stops short of the foreground dancer's feet so the line
    // doesn't visibly cross his legs (figures are outline-only).
    float wallX        = pg.width  * 0.18;
    float upperFloorY  = pg.height * 0.55;
    float stepX        = pg.width  * 0.32;
    float crowdFloorY  = pg.height * 0.86;
    float dancerLeftEdge = dancer.x - dancer.h * 0.30;
    h2.line(wallX, 0, wallX, upperFloorY);                   // wall
    h2.line(wallX, upperFloorY, stepX, upperFloorY);         // upper platform
    h2.line(stepX, upperFloorY, stepX, crowdFloorY);         // step down
    h2.line(stepX, crowdFloorY, dancerLeftEdge, crowdFloorY);// crowd floor

    // ── Crowd updates ──────────────────────────────────────
    spikyGuy.update(crowdEnergy, crowdSway);
    kissGirl.update(crowdEnergy, crowdSway);
    hugGuy.update(crowdEnergy, crowdSway);
    hugGirl.update(crowdEnergy, crowdSway);
    dancer.update(crowdEnergy, crowdSway);

    drawSpikyGuyBack(pg, spikyGuy);
    drawKissGirl   (pg, kissGirl, spikyGuy);
    drawHugGuyBack (pg, hugGuy);
    drawHugGirl    (pg, hugGirl, hugGuy);

    // ── Lonely guy idle ────────────────────────────────────
    // Sway: slow sin wave, ±3% of figure height. Sip: timer-driven cycle
    // that lifts the cup hand to the mouth and back.
    lonelySway = sin(millis() * 0.0011) * 0.5 + 0.5;
    sipCooldown -= 1.0 / max(frameRate, 1);
    if (sipCooldown <= 0 && sipPhase <= 0) sipPhase = 0.001;
    if (sipPhase > 0) {
      sipPhase += 0.012;
      if (sipPhase >= 1.0) {
        sipPhase = 0;
        sipCooldown = 5.0 + random(3.0);
      }
    }
    lonely.update(0, 0);
    drawLonelyGuy(pg, lonely);

    // Foreground crouched dancer — drawn AFTER lonely guy because the dancer
    // is closer to the camera (would occlude any crowd member at this Y).
    if (dancerMoveLastMs == 0) dancerMoveLastMs = millis();
    if (millis() - dancerMoveLastMs > dancerMoveDurationMs) {
      dancerMoveLastMs = millis();
      dancerMove = (dancerMove + 1) % MOVE_COUNT;
    }
    drawCrouchedDancer(pg, dancer);

    // ── Thought bubble ──
    thoughtTimer += 1.0 / max(frameRate, 1);
    if (thoughtTimer > 5.5) { thoughtTimer = 0; thoughtIndex = (thoughtIndex + 1) % THOUGHTS.length; }
    String t = THOUGHTS[thoughtIndex];
    if (t.contains("[FPS]")) t = t.replace("[FPS]", nf(actualFps, 0, 0));
    drawThoughtBubble(pg, t,
                      pg.width * 0.50, pg.height * 0.16,
                      lonely.x + lonely.h * 0.10, lonely.y - lonely.h * 0.78);

    pg.endDraw();
  }

  // ── Lonely wojak guy ───────────────────────────────────────────────────────
  void drawLonelyGuy(PGraphics pg, Figure d) {
    pg.pushStyle();
    pg.stroke(20); pg.strokeWeight(3.2 * uiScale()); pg.noFill();

    // Sad sway: ±3% of h, weighted by sin already in 0..1 range.
    float sx = (lonelySway - 0.5) * d.h * 0.06;

    float headR = d.h * 0.11;
    float neckY = d.y - d.h * 0.78;
    float headY = neckY - headR * 0.95;

    // Round head (slightly egg-shaped)
    h2.ellipse(d.x + sx, headY, headR * 1.95, headR * 2.1);

    // Wojak face: open droopy eyes with bags + small pupils, concerned brows,
    // tiny downturned mouth. Eyes are larger and more rounded than before so
    // they read as a proper face at a glance.
    pg.strokeWeight(2.5 * uiScale());
    float eyeLx = d.x + sx - headR * 0.38, eyeRx = d.x + sx + headR * 0.38;
    float eyeY  = headY + headR * 0.05;
    h2.ellipse(eyeLx, eyeY, headR * 0.45, headR * 0.32);
    h2.ellipse(eyeRx, eyeY, headR * 0.45, headR * 0.32);
    // pupils — solid dots, low in the eye for "looking down/sad"
    pg.pushStyle();
    pg.fill(20); pg.noStroke();
    pg.ellipse(eyeLx + headR * 0.04, eyeY + headR * 0.03, headR * 0.10, headR * 0.10);
    pg.ellipse(eyeRx - headR * 0.04, eyeY + headR * 0.03, headR * 0.10, headR * 0.10);
    pg.popStyle();
    pg.stroke(20); pg.noFill(); pg.strokeWeight(2.5 * uiScale());
    // eye bags droop below
    h2.arc(eyeLx, eyeY + headR * 0.22, headR * 0.40, headR * 0.22, 0, PI);
    h2.arc(eyeRx, eyeY + headR * 0.22, headR * 0.40, headR * 0.22, 0, PI);
    // concerned slanted eyebrows
    h2.line(d.x + sx - headR * 0.62, headY - headR * 0.20, d.x + sx - headR * 0.18, headY - headR * 0.10);
    h2.line(d.x + sx + headR * 0.18, headY - headR * 0.10, d.x + sx + headR * 0.62, headY - headR * 0.20);
    // small downturn mouth
    h2.arc(d.x + sx, headY + headR * 0.58, headR * 0.40, headR * 0.22, PI * 1.10, PI * 1.90);

    // Party hat (triangle with horizontal stripes + pompom)
    pg.strokeWeight(3.2 * uiScale());
    float hatBaseY = headY - headR * 0.95;
    float hatTipY  = hatBaseY - headR * 1.95;
    float hatHalfW = headR * 0.95;
    h2.line(d.x + sx - hatHalfW, hatBaseY, d.x + sx + hatHalfW, hatBaseY);
    h2.line(d.x + sx - hatHalfW, hatBaseY, d.x + sx,            hatTipY);
    h2.line(d.x + sx + hatHalfW, hatBaseY, d.x + sx,            hatTipY);
    pg.strokeWeight(2 * uiScale());
    for (int i = 1; i <= 2; i++) {
      float ty = lerp(hatBaseY, hatTipY, i * 0.30);
      float halfW = hatHalfW * (1.0 - i * 0.30);
      h2.line(d.x + sx - halfW, ty, d.x + sx + halfW, ty);
    }
    // pompom (small ball above tip)
    pg.strokeWeight(3.0 * uiScale());
    h2.ellipse(d.x + sx, hatTipY - headR * 0.35, headR * 0.55, headR * 0.55);
    pg.strokeWeight(2 * uiScale());
    for (int i = 0; i < 4; i++) {
      float a = i * (TWO_PI / 4) + PI * 0.25;
      float cx = d.x + sx + cos(a) * headR * 0.20;
      float cy = hatTipY - headR * 0.35 + sin(a) * headR * 0.20;
      h2.line(cx, cy, cx + cos(a) * headR * 0.10, cy + sin(a) * headR * 0.10);
    }

    // T-shirt: shoulders + sleeves + bottom hem
    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = d.y - d.h * 0.74;
    float chestY    = d.y - d.h * 0.60;
    float hemY      = d.y - d.h * 0.43;
    float hipY      = d.y - d.h * 0.40;
    float halfShoulder = d.h * 0.14;
    float halfWaist    = d.h * 0.11;
    h2.line(d.x + sx - headR * 0.55, neckY, d.x + sx + headR * 0.55, neckY);
    h2.line(d.x + sx - headR * 0.55, neckY, d.x + sx - halfShoulder, shoulderY);
    h2.line(d.x + sx + headR * 0.55, neckY, d.x + sx + halfShoulder, shoulderY);
    h2.line(d.x + sx - halfShoulder, shoulderY, d.x + sx - halfShoulder * 0.75, chestY);
    h2.line(d.x + sx + halfShoulder, shoulderY, d.x + sx + halfShoulder * 0.75, chestY);
    h2.line(d.x + sx - halfShoulder * 0.75, chestY, d.x + sx - halfWaist, hemY);
    h2.line(d.x + sx + halfShoulder * 0.75, chestY, d.x + sx + halfWaist, hemY);
    h2.line(d.x + sx - halfWaist, hemY, d.x + sx + halfWaist, hemY);

    // Pants: simple — outer leg lines from hem to feet, single center seam.
    // Source meme has clean pants without the prior crotch-split detail.
    h2.line(d.x + sx - halfWaist, hemY, d.x + sx - d.h * 0.09, d.y);
    h2.line(d.x + sx + halfWaist, hemY, d.x + sx + d.h * 0.09, d.y);
    h2.line(d.x + sx, hemY, d.x + sx, d.y);

    // Right arm holding cup. Sip animation: lift end of arm + cup toward
    // mouth on a half-cycle (sin curve so motion eases in/out).
    // sipLift in 0..1; cup rises to mouth at sipLift=1.
    float sipLift = sipPhase > 0 ? sin(sipPhase * PI) : 0;
    float restCupX = d.x + sx - d.h * 0.02;
    float restCupY = chestY + d.h * 0.04;
    float lipsX    = d.x + sx + headR * 0.05;
    float lipsY    = headY + headR * 0.55;
    float cupX = lerp(restCupX, lipsX,  sipLift);
    float cupY = lerp(restCupY, lipsY,  sipLift);

    // Elbow point also shifts up when sipping
    float elbowX = lerp(d.x + sx + d.h * 0.13, d.x + sx + d.h * 0.04, sipLift);
    float elbowY = lerp(chestY,                chestY - d.h * 0.10,  sipLift);

    h2.line(d.x + sx + halfShoulder - d.h * 0.02, shoulderY + d.h * 0.03, elbowX, elbowY);
    h2.line(elbowX, elbowY, cupX + d.h * 0.05, cupY);
    // cup rectangle
    h2.line(cupX, cupY, cupX + d.h * 0.06, cupY);
    h2.line(cupX, cupY, cupX + d.h * 0.005, cupY + d.h * 0.06);
    h2.line(cupX + d.h * 0.06, cupY, cupX + d.h * 0.055, cupY + d.h * 0.06);
    h2.line(cupX + d.h * 0.005, cupY + d.h * 0.06, cupX + d.h * 0.055, cupY + d.h * 0.06);

    // Left arm hanging straight down
    h2.line(d.x + sx - halfShoulder + d.h * 0.01, shoulderY + d.h * 0.03,
            d.x + sx - halfShoulder + d.h * 0.005, hemY + d.h * 0.02);

    pg.popStyle();
  }

  // ── Spiky-haired guy (back/3-quarter view, kissing) ────────────────────────
  void drawSpikyGuyBack(PGraphics pg, Figure d) {
    pg.pushStyle();
    pg.stroke(20); pg.strokeWeight(3.2 * uiScale()); pg.noFill();

    float bounce = d.bounce();
    float headR  = d.h * 0.10;
    float neckY  = d.y - d.h * 0.78 + bounce;
    float headY  = neckY - headR * 0.9;

    h2.ellipse(d.x, headY, headR * 1.9, headR * 2.0);

    // Anime spikes — start/end on the head silhouette (upper temples) so
    // the hair attaches to the head instead of floating above it. Valleys
    // dip down onto the head crown; tips reach high.
    float hairBaseY = headY - headR * 0.95;             // head crown (top of ellipse)
    float[] spikeXs = { -1.05f, -0.55f, -0.15f, 0.30f, 0.75f, 1.10f };
    float[] spikeHs = {  1.95f,  2.25f,  2.05f, 2.30f, 1.85f, 1.55f };
    pg.strokeWeight(3.2 * uiScale());
    pg.beginShape();
    // Start on the head ellipse at upper-left temple
    pg.vertex(d.x - headR * 0.92, headY - headR * 0.05);
    for (int i = 0; i < spikeXs.length; i++) {
      float tipX = d.x + headR * (spikeXs[i] + 0.05);
      float tipY = hairBaseY - headR * spikeHs[i];
      pg.vertex(tipX, tipY);
      if (i < spikeXs.length - 1) {
        float vx = d.x + headR * (spikeXs[i] + spikeXs[i + 1]) * 0.5;
        // Valley sits on the head crown so hair clearly attaches
        pg.vertex(vx, hairBaseY + headR * 0.05);
      }
    }
    // End on the head ellipse at upper-right temple
    pg.vertex(d.x + headR * 0.92, headY - headR * 0.05);
    pg.endShape();

    // Ear-shaped curve on left
    pg.strokeWeight(2.5 * uiScale());
    h2.arc(d.x - headR * 0.80, headY + headR * 0.10, headR * 0.30, headR * 0.45, PI * 0.55, PI * 1.45);

    // T-shirt — back view
    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = neckY + d.h * 0.05;
    float waistY    = d.y - d.h * 0.35 + bounce;
    float halfShoulder = d.h * 0.16;
    float halfWaist    = d.h * 0.13;
    h2.line(d.x - headR * 0.65, neckY, d.x + headR * 0.65, neckY);
    h2.line(d.x - headR * 0.65, neckY, d.x - halfShoulder, shoulderY);
    h2.line(d.x + headR * 0.65, neckY, d.x + halfShoulder, shoulderY);
    h2.line(d.x - halfShoulder, shoulderY, d.x - halfWaist, waistY);
    h2.line(d.x + halfShoulder, shoulderY, d.x + halfWaist, waistY);
    h2.line(d.x - halfWaist, waistY, d.x + halfWaist, waistY);

    // Right arm wraps forward
    float armSway = sin(d.legPhase) * d.h * 0.02 * d.intensity;
    h2.line(d.x + halfShoulder, shoulderY + d.h * 0.02,
            d.x + halfShoulder + d.h * 0.18 + armSway, shoulderY + d.h * 0.10);
    h2.line(d.x + halfShoulder + d.h * 0.18 + armSway, shoulderY + d.h * 0.10,
            d.x + halfShoulder + d.h * 0.30 + armSway, shoulderY + d.h * 0.18);
    // Left arm — tucked behind
    h2.line(d.x - halfShoulder, shoulderY + d.h * 0.02,
            d.x - halfShoulder - d.h * 0.06, shoulderY + d.h * 0.20);

    // Jeans
    h2.line(d.x - halfWaist, waistY, d.x - d.h * 0.10, d.y);
    h2.line(d.x + halfWaist, waistY, d.x + d.h * 0.10, d.y);
    h2.line(d.x, waistY - d.h * 0.02, d.x, d.y - d.h * 0.02);

    pg.popStyle();
  }

  // ── Long-hair girl being kissed (face visible, smiling) ────────────────────
  void drawKissGirl(PGraphics pg, Figure d, Figure leaning) {
    pg.pushStyle();
    pg.stroke(20); pg.strokeWeight(3.2 * uiScale()); pg.noFill();

    float bounce = d.bounce();
    float headR  = d.h * 0.11;
    float neckY  = d.y - d.h * 0.78 + bounce;
    float headY  = neckY - headR * 0.85;

    // Hair: rounded crown silhouette anchored just outside the head ellipse.
    // Endpoints land near the jawline so hair clearly frames the face.
    pg.strokeWeight(2.8 * uiScale());
    pg.bezier(d.x - headR * 0.95, headY + headR * 0.65,
              d.x - headR * 1.20, headY - headR * 1.10,
              d.x + headR * 1.20, headY - headR * 1.10,
              d.x + headR * 0.95, headY + headR * 0.65);
    // Two tendril flicks down past the jaw on the visible (left) side
    pg.bezier(d.x - headR * 0.90, headY + headR * 0.55,
              d.x - headR * 1.00, headY + headR * 0.85,
              d.x - headR * 0.80, headY + headR * 1.00,
              d.x - headR * 0.65, headY + headR * 1.10);
    pg.bezier(d.x - headR * 0.50, headY + headR * 0.65,
              d.x - headR * 0.60, headY + headR * 0.90,
              d.x - headR * 0.40, headY + headR * 1.00,
              d.x - headR * 0.25, headY + headR * 1.05);

    // Head
    pg.strokeWeight(3.2 * uiScale());
    h2.ellipse(d.x, headY, headR * 1.85, headR * 2.0);

    // Closed-eye smile — both eyes drawn so face reads as a face. Right eye
    // is the "nearer" one (slightly larger), left eye is partially behind
    // the cheek (smaller). Lashes on the larger eye.
    pg.strokeWeight(2.5 * uiScale());
    h2.arc(d.x - headR * 0.32, headY + headR * 0.05, headR * 0.32, headR * 0.20, PI * 1.0, PI * 2.0);
    h2.arc(d.x + headR * 0.22, headY + headR * 0.05, headR * 0.40, headR * 0.25, PI * 1.0, PI * 2.0);
    // lashes on the right (visible) eye
    h2.line(d.x + headR * 0.05, headY - headR * 0.05, d.x + headR * 0.00, headY - headR * 0.22);
    h2.line(d.x + headR * 0.20, headY - headR * 0.10, d.x + headR * 0.18, headY - headR * 0.28);
    h2.line(d.x + headR * 0.40, headY - headR * 0.05, d.x + headR * 0.45, headY - headR * 0.20);
    // smile + nose centered on face
    h2.arc(d.x - headR * 0.05, headY + headR * 0.50, headR * 0.50, headR * 0.32, 0, PI);
    h2.line(d.x - headR * 0.02, headY + headR * 0.22, d.x - headR * 0.10, headY + headR * 0.38);
    h2.line(d.x - headR * 0.10, headY + headR * 0.38, d.x - headR * 0.02, headY + headR * 0.42);

    // Body
    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = neckY + d.h * 0.05;
    float waistY    = d.y - d.h * 0.30 + bounce;
    float halfShoulder = d.h * 0.12;
    float halfWaist    = d.h * 0.10;
    h2.line(d.x - headR * 0.55, neckY, d.x - halfShoulder, shoulderY);
    h2.line(d.x + headR * 0.55, neckY, d.x + halfShoulder, shoulderY);
    h2.line(d.x - halfShoulder, shoulderY, d.x - halfWaist, waistY);
    h2.line(d.x + halfShoulder, shoulderY, d.x + halfWaist, waistY);
    h2.line(d.x - halfWaist, waistY, d.x - d.h * 0.13, d.y - d.h * 0.18 + bounce);
    h2.line(d.x + halfWaist, waistY, d.x + d.h * 0.13, d.y - d.h * 0.18 + bounce);
    h2.line(d.x - d.h * 0.13, d.y - d.h * 0.18 + bounce, d.x - d.h * 0.08, d.y);
    h2.line(d.x + d.h * 0.13, d.y - d.h * 0.18 + bounce, d.x + d.h * 0.08, d.y);

    // Arm wrapping back around the kisser
    float reachX = leaning.x + leaning.h * 0.10;
    float reachY = leaning.y - leaning.h * 0.55 + leaning.bounce();
    h2.line(d.x - halfShoulder, shoulderY + d.h * 0.02, reachX, reachY);
    h2.line(d.x + halfShoulder, shoulderY + d.h * 0.02,
            d.x + halfShoulder + d.h * 0.04, waistY + d.h * 0.05);

    pg.popStyle();
  }

  // ── Bottom-left guy from behind (short hair, hugging) ──────────────────────
  void drawHugGuyBack(PGraphics pg, Figure d) {
    pg.pushStyle();
    pg.stroke(20); pg.strokeWeight(3.2 * uiScale()); pg.noFill();

    float bounce = d.bounce();
    float headR  = d.h * 0.13;
    float neckY  = d.y - d.h * 0.78 + bounce;
    float headY  = neckY - headR * 0.9;

    h2.ellipse(d.x, headY, headR * 1.85, headR * 2.0);

    // Short messy hair — squiggly top. Endpoints land on the head ellipse
    // at upper temples; peaks rise just above the head crown so hair
    // visibly attaches to the head.
    pg.strokeWeight(2.5 * uiScale());
    pg.beginShape();
    pg.noFill();
    pg.vertex(d.x - headR * 0.92, headY - headR * 0.10);
    for (int i = 0; i <= 5; i++) {
      float t = i / 5.0;
      float hx = d.x + headR * lerp(-0.85, 0.85, t);
      float hy = headY - headR * (1.05 + 0.10 * sin(t * PI * 4));
      pg.vertex(hx, hy);
    }
    pg.vertex(d.x + headR * 0.92, headY - headR * 0.10);
    pg.endShape();

    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = neckY + d.h * 0.05;
    float waistY    = d.y - d.h * 0.25 + bounce;
    float halfShoulder = d.h * 0.18;
    float halfWaist    = d.h * 0.16;
    h2.line(d.x - headR * 0.70, neckY, d.x - halfShoulder, shoulderY);
    h2.line(d.x + headR * 0.70, neckY, d.x + halfShoulder, shoulderY);
    h2.line(d.x - halfShoulder, shoulderY, d.x - halfWaist, waistY);
    h2.line(d.x + halfShoulder, shoulderY, d.x + halfWaist, waistY);
    h2.line(d.x - halfWaist, waistY, d.x + halfWaist, waistY);

    // Right arm wraps around the girl
    float girlX = d.x + d.h * 0.40;
    float girlWaistY = d.y - d.h * 0.40 + bounce;
    h2.line(d.x + halfShoulder, shoulderY + d.h * 0.02,
            d.x + halfShoulder + d.h * 0.10, shoulderY + d.h * 0.10);
    h2.line(d.x + halfShoulder + d.h * 0.10, shoulderY + d.h * 0.10,
            girlX - d.h * 0.05, girlWaistY);
    h2.line(d.x - halfShoulder, shoulderY + d.h * 0.02,
            d.x - halfShoulder - d.h * 0.02, waistY);

    h2.line(d.x - halfWaist, waistY, d.x - d.h * 0.12, d.y);
    h2.line(d.x + halfWaist, waistY, d.x + d.h * 0.12, d.y);

    pg.popStyle();
  }

  // ── Long-hair girl with raised arm ─────────────────────────────────────────
  void drawHugGirl(PGraphics pg, Figure d, Figure embracer) {
    pg.pushStyle();
    pg.stroke(20); pg.strokeWeight(3.2 * uiScale()); pg.noFill();

    float bounce = d.bounce();
    float headR  = d.h * 0.13;
    float neckY  = d.y - d.h * 0.70 + bounce;
    float headY  = neckY - headR * 0.85;

    pg.strokeWeight(2.8 * uiScale());
    // Crown anchored at jaw edges of the head ellipse so hair frames the face
    pg.bezier(d.x - headR * 0.95, headY + headR * 0.55,
              d.x - headR * 1.25, headY - headR * 1.10,
              d.x + headR * 1.25, headY - headR * 1.10,
              d.x + headR * 0.95, headY + headR * 0.55);
    for (int i = 0; i < 3; i++) {
      float side = (i % 2 == 0) ? -1 : 1;
      float startX = d.x + side * headR * lerp(0.55, 1.10, i / 2.0);
      float startY = headY + headR * (0.30 + i * 0.10);
      float midX   = startX + side * headR * 0.10;
      float midY   = startY + headR * 0.45;
      float endX   = startX + side * headR * 0.05;
      float endY   = startY + headR * 0.95;
      pg.bezier(startX, startY, midX, midY - headR * 0.10, midX, midY + headR * 0.10, endX, endY);
    }

    pg.strokeWeight(3.2 * uiScale());
    h2.ellipse(d.x, headY, headR * 1.85, headR * 2.0);

    pg.strokeWeight(2.5 * uiScale());
    h2.arc(d.x - headR * 0.30, headY + headR * 0.10, headR * 0.40, headR * 0.22, PI, TWO_PI);
    h2.arc(d.x + headR * 0.30, headY + headR * 0.10, headR * 0.40, headR * 0.22, PI, TWO_PI);
    h2.arc(d.x, headY + headR * 0.55, headR * 0.55, headR * 0.40, 0, PI);

    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = neckY + d.h * 0.05;
    float waistY    = d.y - d.h * 0.20 + bounce;
    float halfShoulder = d.h * 0.13;
    float halfWaist    = d.h * 0.11;
    h2.line(d.x - headR * 0.55, neckY, d.x - halfShoulder, shoulderY);
    h2.line(d.x + headR * 0.55, neckY, d.x + halfShoulder, shoulderY);
    h2.line(d.x - halfShoulder, shoulderY, d.x - halfWaist, waistY);
    h2.line(d.x + halfShoulder, shoulderY, d.x + halfWaist, waistY);

    // Right arm raised
    float armSway = sin(d.legPhase) * d.h * 0.05 * d.intensity;
    float handX = d.x + halfShoulder + d.h * 0.18 + armSway;
    float handY = shoulderY - d.h * 0.45;
    h2.line(d.x + halfShoulder, shoulderY + d.h * 0.02,
            d.x + halfShoulder + d.h * 0.10, shoulderY - d.h * 0.20);
    h2.line(d.x + halfShoulder + d.h * 0.10, shoulderY - d.h * 0.20, handX, handY);
    for (int i = 0; i < 3; i++) {
      float a = -PI * 0.5 + (i - 1) * 0.35;
      h2.line(handX, handY, handX + cos(a) * d.h * 0.05, handY + sin(a) * d.h * 0.05);
    }

    // Left arm wraps around embracer
    float wrapX = embracer.x + embracer.h * 0.10;
    float wrapY = embracer.y - embracer.h * 0.45 + embracer.bounce();
    h2.line(d.x - halfShoulder, shoulderY + d.h * 0.05, wrapX, wrapY);

    pg.popStyle();
  }

  // ── Foreground crouched dancer ─────────────────────────────────────────────
  // Closer-to-camera figure mid-dance: feet planted wide, knees bent, arms
  // out, body leaning slightly side-to-side on `legPhase`. Drawn from the
  // back so we don't have to commit to a face — keeps eyes on the pair.
  void drawCrouchedDancer(PGraphics pg, Figure d) {
    pg.pushStyle();
    pg.stroke(20); pg.strokeWeight(3.5 * uiScale()); pg.noFill();

    float bounce = d.bounce();
    // Per-move body lean. Different moves move the torso differently —
    // shimmy is bigger side-to-side; head-bang dips forward on beat;
    // raise-roof and fist-pump stay mostly upright.
    float bodyLean = 0;
    float headDip  = 0;
    switch (dancerMove) {
      case MOVE_ARMS_OUT:   bodyLean = sin(d.legPhase * 0.5) * d.h * 0.04 * d.intensity; break;
      case MOVE_RAISE_ROOF: bodyLean = 0; break;
      case MOVE_FIST_PUMP:  bodyLean = sin(d.legPhase * 0.5) * d.h * 0.02 * d.intensity; break;
      case MOVE_SHIMMY:     bodyLean = sin(d.legPhase) * d.h * 0.08 * d.intensity; break;
      case MOVE_HEAD_BANG:  headDip  = max(0, sin(d.legPhase)) * d.h * 0.08 * d.intensity; break;
    }
    float headR    = d.h * 0.11;
    float neckY    = d.y - d.h * 0.62 + bounce + headDip;
    float headY    = neckY - headR * 0.85;
    float cx       = d.x + bodyLean;

    // Head
    h2.ellipse(cx, headY, headR * 1.9, headR * 2.0);

    // Hair — short messy fringe (back view)
    pg.strokeWeight(2.5 * uiScale());
    pg.beginShape();
    pg.noFill();
    pg.vertex(cx - headR * 0.92, headY - headR * 0.10);
    for (int i = 0; i <= 6; i++) {
      float t = i / 6.0;
      float hx = cx + headR * lerp(-0.85, 0.85, t);
      float hy = headY - headR * (1.05 + 0.14 * sin(t * PI * 5 + d.legPhase * 0.3));
      pg.vertex(hx, hy);
    }
    pg.vertex(cx + headR * 0.92, headY - headR * 0.10);
    pg.endShape();

    // Torso — wide back, crouched (shorter neck-to-waist than upright figs)
    pg.strokeWeight(3.5 * uiScale());
    float shoulderY = neckY + d.h * 0.04;
    float waistY    = d.y - d.h * 0.30 + bounce;
    float halfShoulder = d.h * 0.20;
    float halfWaist    = d.h * 0.15;
    h2.line(cx - headR * 0.70, neckY, cx - halfShoulder, shoulderY);
    h2.line(cx + headR * 0.70, neckY, cx + halfShoulder, shoulderY);
    h2.line(cx - halfShoulder, shoulderY, cx - halfWaist, waistY);
    h2.line(cx + halfShoulder, shoulderY, cx + halfWaist, waistY);
    h2.line(cx - halfWaist, waistY, cx + halfWaist, waistY);

    // Arm rendering varies by move. armBeat drives the per-move pulse.
    float armBeat   = sin(d.legPhase) * d.intensity;
    float beatPulse = max(0, armBeat);   // 0..1 on the upbeat half-cycle
    float lShX = cx - halfShoulder, rShX = cx + halfShoulder;
    float shAY = shoulderY + d.h * 0.02;

    switch (dancerMove) {
      case MOVE_ARMS_OUT: {
        // One arm up, one arm down, alternating on the beat.
        float lEx = lShX - d.h * 0.32, lEy = shAY - armBeat * d.h * 0.18;
        float rEx = rShX + d.h * 0.32, rEy = shAY + armBeat * d.h * 0.18;
        h2.line(lShX, shAY, lShX - d.h * 0.16, shAY + d.h * 0.02);
        h2.line(lShX - d.h * 0.16, shAY + d.h * 0.02, lEx, lEy);
        h2.line(rShX, shAY, rShX + d.h * 0.16, shAY + d.h * 0.02);
        h2.line(rShX + d.h * 0.16, shAY + d.h * 0.02, rEx, rEy);
        break;
      }
      case MOVE_RAISE_ROOF: {
        // Both palms up overhead, push up on each beat.
        float push = beatPulse * d.h * 0.10;
        float lHandY = headY - d.h * 0.30 - push;
        float rHandY = headY - d.h * 0.30 - push;
        float lElbX = lShX - d.h * 0.10, lElbY = shAY - d.h * 0.18;
        float rElbX = rShX + d.h * 0.10, rElbY = shAY - d.h * 0.18;
        h2.line(lShX, shAY, lElbX, lElbY);
        h2.line(lElbX, lElbY, lShX - d.h * 0.04, lHandY);
        h2.line(rShX, shAY, rElbX, rElbY);
        h2.line(rElbX, rElbY, rShX + d.h * 0.04, rHandY);
        // little open-palm ticks at the top of each hand
        for (int i = -1; i <= 1; i++) {
          h2.line(lShX - d.h * 0.04 + i * d.h * 0.025, lHandY,
                  lShX - d.h * 0.04 + i * d.h * 0.025, lHandY - d.h * 0.05);
          h2.line(rShX + d.h * 0.04 + i * d.h * 0.025, rHandY,
                  rShX + d.h * 0.04 + i * d.h * 0.025, rHandY - d.h * 0.05);
        }
        break;
      }
      case MOVE_FIST_PUMP: {
        // Right arm punches up high on each beat; left arm relaxed at side.
        float pump = beatPulse;
        float fistY = lerp(shAY - d.h * 0.05, headY - d.h * 0.40, pump);
        float fistX = rShX + d.h * 0.10;
        float rElbX = rShX + d.h * 0.14, rElbY = lerp(shAY + d.h * 0.05, shAY - d.h * 0.18, pump);
        h2.line(rShX, shAY, rElbX, rElbY);
        h2.line(rElbX, rElbY, fistX, fistY);
        // small fist circle
        h2.ellipse(fistX, fistY - d.h * 0.02, d.h * 0.05, d.h * 0.05);
        // Left arm hangs straight down
        h2.line(lShX, shAY, lShX - d.h * 0.04, shAY + d.h * 0.18);
        h2.line(lShX - d.h * 0.04, shAY + d.h * 0.18, lShX - d.h * 0.02, shAY + d.h * 0.32);
        break;
      }
      case MOVE_SHIMMY: {
        // Both hands on hips — elbows out, forearms angled to waist.
        float waistEdgeL = cx - halfWaist;
        float waistEdgeR = cx + halfWaist;
        float lElbX = lShX - d.h * 0.10, lElbY = shAY + d.h * 0.10;
        float rElbX = rShX + d.h * 0.10, rElbY = shAY + d.h * 0.10;
        h2.line(lShX, shAY, lElbX, lElbY);
        h2.line(lElbX, lElbY, waistEdgeL, waistY - d.h * 0.02);
        h2.line(rShX, shAY, rElbX, rElbY);
        h2.line(rElbX, rElbY, waistEdgeR, waistY - d.h * 0.02);
        break;
      }
      case MOVE_HEAD_BANG: {
        // Arms swing back loosely — exaggerated when head dips forward.
        float swing = sin(d.legPhase + PI) * d.intensity;
        float lEx = lShX - d.h * 0.18 - swing * d.h * 0.06;
        float lEy = shAY + d.h * 0.32 + swing * d.h * 0.04;
        float rEx = rShX + d.h * 0.18 + swing * d.h * 0.06;
        float rEy = shAY + d.h * 0.32 - swing * d.h * 0.04;
        h2.line(lShX, shAY, lEx, lEy);
        h2.line(rShX, shAY, rEx, rEy);
        break;
      }
    }

    // Bent legs — knees flared out, feet planted wide. Crouch depth pulses
    // with the kick so the figure visibly grooves.
    float crouch = 1.0 + d.bounceLerp * 0.15;
    float kneeY  = d.y - d.h * 0.16 / crouch + bounce;
    float footY  = d.y;
    float kneeOff = d.h * 0.18;
    float footOff = d.h * 0.22;
    h2.line(cx - halfWaist * 0.6, waistY, cx - kneeOff, kneeY);
    h2.line(cx + halfWaist * 0.6, waistY, cx + kneeOff, kneeY);
    h2.line(cx - kneeOff, kneeY, cx - footOff, footY);
    h2.line(cx + kneeOff, kneeY, cx + footOff, footY);
    // small foot ticks
    h2.line(cx - footOff, footY, cx - footOff - d.h * 0.06, footY);
    h2.line(cx + footOff, footY, cx + footOff + d.h * 0.06, footY);

    pg.popStyle();
  }

  // ── Thought bubble ─────────────────────────────────────────────────────────
  // Drawn with plain pg primitives (not Handy) — keeps the bubble readable
  // and visually distinct from the sketchy figures.
  void drawThoughtBubble(PGraphics pg, String text, float bx, float by, float tx, float ty) {
    pg.pushStyle();
    if (monoFont != null) pg.textFont(monoFont);
    pg.textAlign(CENTER, CENTER);
    pg.textSize(20 * uiScale());

    float pad = 22 * uiScale();
    float tw  = pg.textWidth(text) + pad * 2;
    float th  = pg.textAscent() + pg.textDescent() + pad * 2;

    pg.stroke(20); pg.strokeWeight(2.8 * uiScale());
    pg.fill(255);
    pg.ellipse(bx, by, tw, th);

    pg.fill(255);
    int n = 4;
    for (int i = 1; i <= n; i++) {
      float t = i / (float)(n + 1);
      float px = lerp(bx, tx, t);
      float py = lerp(by + th * 0.4, ty, t);
      float r  = lerp(20, 7, t) * uiScale();
      pg.ellipse(px, py, r, r);
    }

    pg.fill(20); pg.noStroke();
    pg.text(text, bx, by);
    pg.popStyle();
  }
}

// ── Figure state ─────────────────────────────────────────────────────────────
class Figure {
  float x, y, h;
  float intensity = 1.0;
  float phase = 0;
  float legPhase = 0;
  float bounceLerp = 0;

  Figure(float x, float y, float h) {
    this.x = x; this.y = y; this.h = h;
    this.legPhase = phase;
  }

  void update(float kick, float mid) {
    legPhase += (0.04 + kick * 0.5 + mid * 0.2) * intensity;
    bounceLerp = lerp(bounceLerp, kick * intensity, 0.30);
  }

  /** Vertical jump offset. Negative = up. */
  float bounce() {
    return -bounceLerp * h * 0.05;
  }
}
