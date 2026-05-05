/**
 * TheyDontKnowScene — "they don't know" party meme.
 *
 * Pure black-outline-on-white, hand-drawn style matching the source meme:
 *   - Lonely wojak guy (party hat, sad face, holding drink) isolated on the
 *     left behind a wall; floor steps down to the crowd.
 *   - Right side: spiky-haired guy (back) embracing a long-hair girl
 *     (face visible, smiling).
 *   - Bottom-left: short-hair guy from behind hugging a long-hair girl with
 *     one arm RAISED.
 *   - Foreground center-right: large crouched dancer in motion.
 *
 * Crowd reacts to bass (jump/bounce) and mid (sway). Lonely guy stays still.
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

  String[] THOUGHTS = {
    "they don't know I'm running at [FPS] FPS",
    "they don't know I'm written in Processing",
    "they don't know the drop is coming",
    "they don't know I read every FFT bin",
    "they don't know I have 50 scenes"
  };
  int   thoughtIndex = 0;
  float thoughtTimer = 0;

  int laidOutFor_w = -1, laidOutFor_h = -1;

  void onEnter() {
    thoughtIndex = (int) random(THOUGHTS.length);
    thoughtTimer = 0;
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

    lonely    = new Figure(w * 0.27, h * 0.55, h * 0.40); lonely.intensity = 0.0;
    spikyGuy  = new Figure(w * 0.66, h * 0.80, h * 0.45); spikyGuy.intensity = 0.9; spikyGuy.phase = 0.0;
    kissGirl  = new Figure(w * 0.82, h * 0.82, h * 0.40); kissGirl.intensity = 0.8; kissGirl.phase = 0.4;
    hugGuy    = new Figure(w * 0.07, h * 0.96, h * 0.35); hugGuy.intensity = 0.9;   hugGuy.phase = 1.0;
    hugGirl   = new Figure(w * 0.20, h * 0.96, h * 0.35); hugGirl.intensity = 1.0;  hugGirl.phase = 1.6;
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

    // Subtle kick flash (meme stays paper-white but a party needs reactivity)
    if (kick > 0.65) {
      pg.noStroke();
      pg.fill(255, 200, 120, (kick - 0.65) * 220);
      pg.rect(0, 0, pg.width, pg.height);
    }

    pg.stroke(20);
    pg.strokeWeight(3.2 * uiScale());
    pg.noFill();

    // Wall + raised floor for lonely guy. Floor steps down to crowd level.
    float wallX     = pg.width * 0.16;
    float upperFloorY = pg.height * 0.55;
    float crowdFloorY = pg.height * 0.82;
    pg.line(wallX, 0, wallX, upperFloorY);                        // wall
    pg.line(wallX, upperFloorY, pg.width * 0.40, upperFloorY);    // upper floor (under lonely guy)
    pg.line(pg.width * 0.40, upperFloorY,
            pg.width * 0.40, crowdFloorY);                        // step down
    pg.line(pg.width * 0.40, crowdFloorY, pg.width, crowdFloorY); // crowd floor

    // ── Crowd ─────────────────────────────────────────
    spikyGuy.update(crowdEnergy, crowdSway);
    kissGirl.update(crowdEnergy, crowdSway);
    hugGuy.update(crowdEnergy, crowdSway);
    hugGirl.update(crowdEnergy, crowdSway);

    drawSpikyGuyBack(pg, spikyGuy);
    drawKissGirl   (pg, kissGirl, spikyGuy);
    drawHugGuyBack (pg, hugGuy);
    drawHugGirl    (pg, hugGirl, hugGuy);

    // ── Lonely guy (drawn last so wall is behind him) ──
    lonely.update(0, 0);
    drawLonelyGuy(pg, lonely);

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

    float headR = d.h * 0.11;
    float neckY = d.y - d.h * 0.78;
    float headY = neckY - headR * 0.95;

    // Round head (slightly egg-shaped)
    pg.ellipse(d.x, headY, headR * 1.95, headR * 2.1);

    // Sad wojak face: drooping eyes with bags, downturned mouth
    pg.strokeWeight(2.5 * uiScale());
    // eyes — small ovals
    pg.ellipse(d.x - headR * 0.40, headY + headR * 0.05, headR * 0.30, headR * 0.22);
    pg.ellipse(d.x + headR * 0.40, headY + headR * 0.05, headR * 0.30, headR * 0.22);
    // eye bags below
    pg.arc(d.x - headR * 0.40, headY + headR * 0.18, headR * 0.30, headR * 0.20, 0, PI);
    pg.arc(d.x + headR * 0.40, headY + headR * 0.18, headR * 0.30, headR * 0.20, 0, PI);
    // eyebrows — slanted concerned
    pg.line(d.x - headR * 0.65, headY - headR * 0.18, d.x - headR * 0.20, headY - headR * 0.10);
    pg.line(d.x + headR * 0.20, headY - headR * 0.10, d.x + headR * 0.65, headY - headR * 0.18);
    // mouth — small downturn
    pg.arc(d.x, headY + headR * 0.55, headR * 0.45, headR * 0.30, PI * 1.10, PI * 1.90, OPEN);

    // Party hat (triangle with horizontal stripes + pompom)
    pg.strokeWeight(3.2 * uiScale());
    float hatBaseY = headY - headR * 0.95;
    float hatTipY  = hatBaseY - headR * 1.95;
    float hatHalfW = headR * 0.95;
    pg.line(d.x - hatHalfW, hatBaseY, d.x + hatHalfW, hatBaseY);
    pg.line(d.x - hatHalfW, hatBaseY, d.x,            hatTipY);
    pg.line(d.x + hatHalfW, hatBaseY, d.x,            hatTipY);
    // stripes
    pg.strokeWeight(2 * uiScale());
    for (int i = 1; i <= 2; i++) {
      float ty = lerp(hatBaseY, hatTipY, i * 0.30);
      float halfW = hatHalfW * (1.0 - i * 0.30);
      pg.line(d.x - halfW, ty, d.x + halfW, ty);
    }
    // pompom (small ball above tip — outline only)
    pg.strokeWeight(3.0 * uiScale());
    pg.noFill();
    pg.ellipse(d.x, hatTipY - headR * 0.35, headR * 0.55, headR * 0.55);
    // tuft strokes
    pg.strokeWeight(2 * uiScale());
    for (int i = 0; i < 4; i++) {
      float a = i * (TWO_PI / 4) + PI * 0.25;
      float cx = d.x + cos(a) * headR * 0.20;
      float cy = hatTipY - headR * 0.35 + sin(a) * headR * 0.20;
      pg.line(cx, cy, cx + cos(a) * headR * 0.10, cy + sin(a) * headR * 0.10);
    }

    // T-shirt: shoulders + sleeves + bottom hem
    // Body landmarks (Y grows downward; smaller Y = higher on screen).
    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = d.y - d.h * 0.74;
    float chestY    = d.y - d.h * 0.60;
    float hemY      = d.y - d.h * 0.43;   // bottom of shirt
    float hipY      = d.y - d.h * 0.40;
    float kneeY     = d.y - d.h * 0.20;
    float halfShoulder = d.h * 0.14;
    float halfWaist    = d.h * 0.11;
    // neckline
    pg.line(d.x - headR * 0.55, neckY, d.x + headR * 0.55, neckY);
    // shoulders
    pg.line(d.x - headR * 0.55, neckY, d.x - halfShoulder, shoulderY);
    pg.line(d.x + headR * 0.55, neckY, d.x + halfShoulder, shoulderY);
    // sleeve undersides (short t-shirt sleeves)
    pg.line(d.x - halfShoulder, shoulderY, d.x - halfShoulder * 0.75, chestY);
    pg.line(d.x + halfShoulder, shoulderY, d.x + halfShoulder * 0.75, chestY);
    // shirt sides down to hem
    pg.line(d.x - halfShoulder * 0.75, chestY, d.x - halfWaist, hemY);
    pg.line(d.x + halfShoulder * 0.75, chestY, d.x + halfWaist, hemY);
    // shirt hem
    pg.line(d.x - halfWaist, hemY, d.x + halfWaist, hemY);

    // Pants: hem → hips → feet
    pg.line(d.x - halfWaist, hemY, d.x - d.h * 0.10, hipY);
    pg.line(d.x + halfWaist, hemY, d.x + d.h * 0.10, hipY);
    // outer leg lines
    pg.line(d.x - d.h * 0.10, hipY, d.x - d.h * 0.07, d.y);
    pg.line(d.x + d.h * 0.10, hipY, d.x + d.h * 0.07, d.y);
    // inner crotch + leg gap
    pg.line(d.x - d.h * 0.01, hipY + d.h * 0.01, d.x - d.h * 0.02, d.y);
    pg.line(d.x + d.h * 0.01, hipY + d.h * 0.01, d.x + d.h * 0.02, d.y);
    pg.line(d.x - d.h * 0.01, hipY + d.h * 0.01, d.x + d.h * 0.01, hipY + d.h * 0.01);

    // Right arm bent up holding cup at chest
    float cupX = d.x - d.h * 0.02;
    float cupY = chestY + d.h * 0.04;
    pg.line(d.x + halfShoulder - d.h * 0.02, shoulderY + d.h * 0.03, d.x + d.h * 0.13, chestY);
    pg.line(d.x + d.h * 0.13, chestY, cupX + d.h * 0.05, cupY);
    // cup rectangle
    pg.line(cupX, cupY, cupX + d.h * 0.06, cupY);
    pg.line(cupX, cupY, cupX + d.h * 0.005, cupY + d.h * 0.06);
    pg.line(cupX + d.h * 0.06, cupY, cupX + d.h * 0.055, cupY + d.h * 0.06);
    pg.line(cupX + d.h * 0.005, cupY + d.h * 0.06, cupX + d.h * 0.055, cupY + d.h * 0.06);

    // Left arm hanging straight down
    pg.line(d.x - halfShoulder + d.h * 0.01, shoulderY + d.h * 0.03,
            d.x - halfShoulder + d.h * 0.005, hemY + d.h * 0.02);

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

    // Head outline (3/4)
    pg.ellipse(d.x, headY, headR * 1.9, headR * 2.0);

    // Tall sharp anime spikes pointing up — single zig-zag stroke
    float hairBaseY = headY - headR * 0.65;
    float[] spikeXs = { -1.05f, -0.55f, -0.15f, 0.30f, 0.75f, 1.10f };
    float[] spikeHs = {  1.95f,  2.25f,  2.05f, 2.30f, 1.85f, 1.55f };
    pg.strokeWeight(3.2 * uiScale());
    pg.beginShape();
    pg.vertex(d.x + headR * spikeXs[0], hairBaseY + headR * 0.20);
    for (int i = 0; i < spikeXs.length; i++) {
      float tipX = d.x + headR * (spikeXs[i] + 0.05);
      float tipY = hairBaseY - headR * spikeHs[i];
      pg.vertex(tipX, tipY);
      // valley between spikes
      if (i < spikeXs.length - 1) {
        float vx = d.x + headR * (spikeXs[i] + spikeXs[i + 1]) * 0.5;
        pg.vertex(vx, hairBaseY + headR * 0.05);
      }
    }
    pg.vertex(d.x + headR * spikeXs[spikeXs.length - 1] + headR * 0.30, hairBaseY + headR * 0.20);
    pg.endShape();

    // Back of head — no face, just suggestion of an ear-shaped curve on left
    pg.strokeWeight(2.5 * uiScale());
    pg.arc(d.x - headR * 0.80, headY + headR * 0.10, headR * 0.30, headR * 0.45, PI * 0.55, PI * 1.45, OPEN);

    // T-shirt — back view, shows shoulders wide
    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = neckY + d.h * 0.05;
    float waistY    = d.y - d.h * 0.35 + bounce;
    float halfShoulder = d.h * 0.16;
    float halfWaist    = d.h * 0.13;
    // collar
    pg.line(d.x - headR * 0.65, neckY, d.x + headR * 0.65, neckY);
    pg.line(d.x - headR * 0.65, neckY, d.x - halfShoulder, shoulderY);
    pg.line(d.x + headR * 0.65, neckY, d.x + halfShoulder, shoulderY);
    // sides
    pg.line(d.x - halfShoulder, shoulderY, d.x - halfWaist, waistY);
    pg.line(d.x + halfShoulder, shoulderY, d.x + halfWaist, waistY);
    // bottom
    pg.line(d.x - halfWaist, waistY, d.x + halfWaist, waistY);

    // Right arm wraps forward toward the girl
    float armSway = sin(d.legPhase) * d.h * 0.02 * d.intensity;
    pg.line(d.x + halfShoulder, shoulderY + d.h * 0.02,
            d.x + halfShoulder + d.h * 0.18 + armSway, shoulderY + d.h * 0.10);
    pg.line(d.x + halfShoulder + d.h * 0.18 + armSway, shoulderY + d.h * 0.10,
            d.x + halfShoulder + d.h * 0.30 + armSway, shoulderY + d.h * 0.18);
    // Left arm — tucked behind
    pg.line(d.x - halfShoulder, shoulderY + d.h * 0.02,
            d.x - halfShoulder - d.h * 0.06, shoulderY + d.h * 0.20);

    // Jeans — visible legs below shirt hem
    pg.line(d.x - halfWaist, waistY, d.x - d.h * 0.10, d.y);
    pg.line(d.x + halfWaist, waistY, d.x + d.h * 0.10, d.y);
    pg.line(d.x, waistY - d.h * 0.02, d.x, d.y - d.h * 0.02);

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

    // Hair: single rounded silhouette around the head + a couple of flick strokes.
    pg.strokeWeight(2.8 * uiScale());
    pg.noFill();
    // Crown outline arc — wraps the back/top of the head down to jaw level.
    pg.bezier(d.x - headR * 1.15, headY + headR * 0.55,
              d.x - headR * 1.15, headY - headR * 1.10,
              d.x + headR * 1.15, headY - headR * 1.10,
              d.x + headR * 1.15, headY + headR * 0.55);
    // Two short tendril flicks falling past the jaw on the visible side.
    pg.bezier(d.x - headR * 0.95, headY + headR * 0.30,
              d.x - headR * 1.05, headY + headR * 0.70,
              d.x - headR * 0.85, headY + headR * 0.95,
              d.x - headR * 0.70, headY + headR * 1.10);
    pg.bezier(d.x - headR * 0.55, headY + headR * 0.50,
              d.x - headR * 0.65, headY + headR * 0.80,
              d.x - headR * 0.45, headY + headR * 0.95,
              d.x - headR * 0.30, headY + headR * 1.05);

    // Head
    pg.strokeWeight(3.2 * uiScale());
    pg.ellipse(d.x, headY, headR * 1.85, headR * 2.0);

    // Face: closed-eye smile (eye = upward arc), lashes, small smile mouth
    pg.strokeWeight(2.5 * uiScale());
    // closed left eye (the one we see, facing the kisser to her right)
    pg.arc(d.x - headR * 0.30, headY + headR * 0.05, headR * 0.40, headR * 0.25, PI * 1.0, PI * 2.0, OPEN);
    // a couple of lashes
    pg.line(d.x - headR * 0.50, headY - headR * 0.05, d.x - headR * 0.55, headY - headR * 0.20);
    pg.line(d.x - headR * 0.40, headY - headR * 0.10, d.x - headR * 0.42, headY - headR * 0.25);
    // small smile mouth
    pg.arc(d.x - headR * 0.10, headY + headR * 0.50, headR * 0.45, headR * 0.30, 0, PI, OPEN);
    // nose tick
    pg.line(d.x - headR * 0.10, headY + headR * 0.20, d.x - headR * 0.15, headY + headR * 0.35);

    // Body — torso + waist
    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = neckY + d.h * 0.05;
    float waistY    = d.y - d.h * 0.30 + bounce;
    float halfShoulder = d.h * 0.12;
    float halfWaist    = d.h * 0.10;
    pg.line(d.x - headR * 0.55, neckY, d.x - halfShoulder, shoulderY);
    pg.line(d.x + headR * 0.55, neckY, d.x + halfShoulder, shoulderY);
    pg.line(d.x - halfShoulder, shoulderY, d.x - halfWaist, waistY);
    pg.line(d.x + halfShoulder, shoulderY, d.x + halfWaist, waistY);
    // hip flare → pants
    pg.line(d.x - halfWaist, waistY, d.x - d.h * 0.13, d.y - d.h * 0.18 + bounce);
    pg.line(d.x + halfWaist, waistY, d.x + d.h * 0.13, d.y - d.h * 0.18 + bounce);
    // legs
    pg.line(d.x - d.h * 0.13, d.y - d.h * 0.18 + bounce, d.x - d.h * 0.08, d.y);
    pg.line(d.x + d.h * 0.13, d.y - d.h * 0.18 + bounce, d.x + d.h * 0.08, d.y);

    // Arm wrapping back around the kisser (toward leaning.x)
    float reachX = leaning.x + leaning.h * 0.10;
    float reachY = leaning.y - leaning.h * 0.55 + leaning.bounce();
    pg.line(d.x - halfShoulder, shoulderY + d.h * 0.02, reachX, reachY);
    // Other arm down
    pg.line(d.x + halfShoulder, shoulderY + d.h * 0.02,
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

    // Head
    pg.ellipse(d.x, headY, headR * 1.85, headR * 2.0);

    // Short messy hair — squiggly top
    pg.strokeWeight(2.5 * uiScale());
    pg.beginShape();
    pg.noFill();
    pg.vertex(d.x - headR * 0.85, headY - headR * 0.30);
    for (int i = 0; i <= 5; i++) {
      float t = i / 5.0;
      float hx = d.x + headR * lerp(-0.85, 0.85, t);
      float hy = headY - headR * (0.85 + 0.10 * sin(t * PI * 4));
      pg.vertex(hx, hy);
    }
    pg.vertex(d.x + headR * 0.85, headY - headR * 0.30);
    pg.endShape();

    // Body — back view torso
    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = neckY + d.h * 0.05;
    float waistY    = d.y - d.h * 0.25 + bounce;
    float halfShoulder = d.h * 0.18;
    float halfWaist    = d.h * 0.16;
    pg.line(d.x - headR * 0.70, neckY, d.x - halfShoulder, shoulderY);
    pg.line(d.x + headR * 0.70, neckY, d.x + halfShoulder, shoulderY);
    pg.line(d.x - halfShoulder, shoulderY, d.x - halfWaist, waistY);
    pg.line(d.x + halfShoulder, shoulderY, d.x + halfWaist, waistY);
    pg.line(d.x - halfWaist, waistY, d.x + halfWaist, waistY);

    // Right arm wraps around the girl's waist (target = girl center)
    float girlX = d.x + d.h * 0.40;     // approx hug girl x
    float girlWaistY = d.y - d.h * 0.40 + bounce;
    pg.line(d.x + halfShoulder, shoulderY + d.h * 0.02,
            d.x + halfShoulder + d.h * 0.10, shoulderY + d.h * 0.10);
    pg.line(d.x + halfShoulder + d.h * 0.10, shoulderY + d.h * 0.10,
            girlX - d.h * 0.05, girlWaistY);
    // Left arm tucked at side
    pg.line(d.x - halfShoulder, shoulderY + d.h * 0.02,
            d.x - halfShoulder - d.h * 0.02, waistY);

    // Pants — partial (cut off below)
    pg.line(d.x - halfWaist, waistY, d.x - d.h * 0.12, d.y);
    pg.line(d.x + halfWaist, waistY, d.x + d.h * 0.12, d.y);

    pg.popStyle();
  }

  // ── Long-hair girl with raised arm (bottom-left, being hugged) ─────────────
  void drawHugGirl(PGraphics pg, Figure d, Figure embracer) {
    pg.pushStyle();
    pg.stroke(20); pg.strokeWeight(3.2 * uiScale()); pg.noFill();

    float bounce = d.bounce();
    float headR  = d.h * 0.13;
    float neckY  = d.y - d.h * 0.70 + bounce;
    float headY  = neckY - headR * 0.85;

    // Hair: rounded crown silhouette + a few wavy flick strands to the shoulders.
    pg.strokeWeight(2.8 * uiScale());
    pg.noFill();
    pg.bezier(d.x - headR * 1.20, headY + headR * 0.50,
              d.x - headR * 1.20, headY - headR * 1.10,
              d.x + headR * 1.20, headY - headR * 1.10,
              d.x + headR * 1.20, headY + headR * 0.50);
    // Three flick strands on each side, ending just past the jaw.
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

    // Head
    pg.strokeWeight(3.2 * uiScale());
    pg.ellipse(d.x, headY, headR * 1.85, headR * 2.0);

    // Closed-eye happy face
    pg.strokeWeight(2.5 * uiScale());
    pg.arc(d.x - headR * 0.30, headY + headR * 0.10, headR * 0.40, headR * 0.22, PI, TWO_PI, OPEN);
    pg.arc(d.x + headR * 0.30, headY + headR * 0.10, headR * 0.40, headR * 0.22, PI, TWO_PI, OPEN);
    pg.arc(d.x, headY + headR * 0.55, headR * 0.55, headR * 0.40, 0, PI, OPEN);

    // Body
    pg.strokeWeight(3.2 * uiScale());
    float shoulderY = neckY + d.h * 0.05;
    float waistY    = d.y - d.h * 0.20 + bounce;
    float halfShoulder = d.h * 0.13;
    float halfWaist    = d.h * 0.11;
    pg.line(d.x - headR * 0.55, neckY, d.x - halfShoulder, shoulderY);
    pg.line(d.x + headR * 0.55, neckY, d.x + halfShoulder, shoulderY);
    pg.line(d.x - halfShoulder, shoulderY, d.x - halfWaist, waistY);
    pg.line(d.x + halfShoulder, shoulderY, d.x + halfWaist, waistY);

    // Right arm RAISED HIGH (the iconic pose) — fingers spread
    float armSway = sin(d.legPhase) * d.h * 0.05 * d.intensity;
    float handX = d.x + halfShoulder + d.h * 0.18 + armSway;
    float handY = shoulderY - d.h * 0.45;
    pg.line(d.x + halfShoulder, shoulderY + d.h * 0.02,
            d.x + halfShoulder + d.h * 0.10, shoulderY - d.h * 0.20);
    pg.line(d.x + halfShoulder + d.h * 0.10, shoulderY - d.h * 0.20, handX, handY);
    // 3 fingers
    for (int i = 0; i < 3; i++) {
      float a = -PI * 0.5 + (i - 1) * 0.35;
      pg.line(handX, handY, handX + cos(a) * d.h * 0.05, handY + sin(a) * d.h * 0.05);
    }

    // Left arm wraps around the embracer
    float wrapX = embracer.x + embracer.h * 0.10;
    float wrapY = embracer.y - embracer.h * 0.45 + embracer.bounce();
    pg.line(d.x - halfShoulder, shoulderY + d.h * 0.05, wrapX, wrapY);

    pg.popStyle();
  }

  // ── Thought bubble ─────────────────────────────────────────────────────────
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

    // Tail bubbles toward lonely guy's head
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
