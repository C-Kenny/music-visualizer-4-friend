/**
 * HourglassScene
 *
 * Sand timer: volume fills the bottom as music builds, then on a massive beat drop
 * (when bottom >94% full) the hourglass flips. Sand rendered as granular particles.
 */
class HourglassScene implements IScene {
  float sandFraction = 0.0;
  float rotation = 0;
  float targetRotation = 0;
  int flipCount = 0;

  float bulbHeight = 200;
  float bulbWidth  = 130;
  float neckWidth  = 12;

  float smoothBass = 0, smoothMid = 0, smoothHigh = 0;
  float dropImminence = 0;
  float beatWobble = 0;
  int lastFlipFrame = -9999; // cooldown: prevent rapid re-flips

  // Camera orbit + zoom
  float camRotX = 0.25;
  float camRotY = 0.0;
  float zoomLevel = 1.0;

  Skybox skybox = new Skybox();

  // Neck trickle — grains through the narrow neck
  int TRICKLE_COUNT = 30;
  float[] trickleY, trickleX, trickleZ;

  // Falling grains — from neck down through air gap to sand surface
  int FALL_COUNT = 60;
  float[] fallY, fallX, fallZ, fallSpeed;

  HourglassScene() {
    trickleY = new float[TRICKLE_COUNT];
    trickleX = new float[TRICKLE_COUNT];
    trickleZ = new float[TRICKLE_COUNT];
    fallY    = new float[FALL_COUNT];
    fallX    = new float[FALL_COUNT];
    fallZ    = new float[FALL_COUNT];
    fallSpeed = new float[FALL_COUNT];
  }

  void onEnter() {
    sandFraction = 0;
    rotation = 0;
    targetRotation = 0;
    flipCount = 0;
    beatWobble = 0;
    camRotX = 0.25;
    camRotY = 0.0;
    zoomLevel = 1.0;
    for (int i = 0; i < TRICKLE_COUNT; i++) resetTrickle(i, true);
    for (int i = 0; i < FALL_COUNT;   i++) resetFallGrain(i, true, 1);
    if (!skybox.loaded) {
      skybox.load(sketchPath("../../media/skyboxes/sky_23_2k/sky_23_cubemap_2k"));
    }
  }

  void onExit() {}

  void resetTrickle(int i, boolean randomSpread) {
    trickleX[i] = random(-neckWidth * 0.4, neckWidth * 0.4);
    trickleZ[i] = random(-neckWidth * 0.4, neckWidth * 0.4);
    trickleY[i] = randomSpread ? random(-20, 20) : -18 + random(-2, 2);
  }

  void resetFallGrain(int i, boolean randomSpread, int dir) {
    // Spawn tightly at neck center — looks like sand squeezing through the hole
    fallX[i] = random(-neckWidth * 0.15, neckWidth * 0.15);
    fallZ[i] = random(-neckWidth * 0.15, neckWidth * 0.15);
    fallSpeed[i] = random(2.0, 4.5);
    fallY[i] = randomSpread ? random(22 * dir, (bulbHeight + 2) * dir) : 22 * dir;
  }

  // ── Main draw ──────────────────────────────────────────────────────────────

  void drawScene(PGraphics canvas) {
    if (!skybox.loaded) skybox.load(sketchPath("../../media/skyboxes/sky_23_2k/sky_23_cubemap_2k"));
    smoothBass  = lerp(smoothBass,  analyzer.bass,  0.1);
    smoothMid   = lerp(smoothMid,   analyzer.mid,   0.1);
    smoothHigh  = lerp(smoothHigh,  analyzer.high,  0.1);
    if (analyzer.isBeat) beatWobble = 5 + smoothBass * 12;
    beatWobble *= 0.88;

    float audioBoost = 1.0 + smoothBass * 3.5;
    sandFraction += 0.00035 * audioBoost;
    sandFraction  = constrain(sandFraction, 0, 1);

    // Flip on a major pre-scanned drop (always top-20 strongest peaks per song).
    // 3s window, threshold 0.75 → triggers within ~750ms of a pre-scanned peak.
    // No real-time beat detector gate — trust the pre-scan timing.
    // Require bass > 0.4 as sanity check + 8s cooldown to prevent double-fires.
    dropImminence = dropPredictor.majorImminentDropFactor(audio.player.position(), 3.0);
    boolean cooldownOk  = (frameCount - lastFlipFrame) > 480; // 8 s at 60 fps
    boolean massiveDrop = dropPredictor.isReady
                       && dropImminence > 0.75
                       && smoothBass > 0.4
                       && sandFraction >= 0.95  // bottom must be nearly full before flipping
                       && cooldownOk;
    if (massiveDrop) {
      targetRotation += PI;
      flipCount++;
      sandFraction = 1.0 - sandFraction;
      lastFlipFrame = frameCount;
    }
    rotation = lerp(rotation, targetRotation, 0.06);

    canvas.background(8, 8, 12);
    canvas.pushMatrix();
    canvas.translate(canvas.width / 2, canvas.height / 2);
    canvas.rotateX(camRotX);
    canvas.rotateY(camRotY);
    skybox.draw(canvas);       // sky after orbit, before flip — doesn't flip with glass
    canvas.rotateZ(rotation);
    canvas.scale(zoomLevel);   // zoom applied after rotations, before all geometry

    canvas.lights();
    canvas.ambientLight(60, 90, 110);
    canvas.pointLight(200, 255, 255, 300, -300, 400);

    boolean posYIsBottom = (flipCount % 2 == 0);

    // Receiving bulb surface Y (where falling grains land)
    float receivingFloorY = posYIsBottom ? (bulbHeight + 2) : -(bulbHeight + 2);
    float receivingNeckY  = posYIsBottom ? 5 : -5;
    float receivingSurfY  = lerp(receivingFloorY, receivingNeckY, sandFraction);

    // Top (draining) bulb sand surface — grains spawn from here, not from air
    float topFraction  = 1.0 - sandFraction;
    float topFloorY    = posYIsBottom ? -(bulbHeight + 2) :  (bulbHeight + 2);
    float topNeckY     = posYIsBottom ? -5 : 5;
    float topSurfY     = lerp(topFloorY, topNeckY, topFraction);

    // Sand drawn first, full glass on top — correct from any camera angle
    if (posYIsBottom) {
      drawSandFill(canvas, sandFraction,       true);
      drawSandFill(canvas, 1 - sandFraction,   false);
    } else {
      drawSandFill(canvas, sandFraction,       false);
      drawSandFill(canvas, 1 - sandFraction,   true);
    }

    draw3DGlass(canvas); // full glass shell over sand

    // Grains rendered AFTER glass with depth test OFF — inside the glass silhouette
    // so they project correctly to screen regardless of depth buffer state.
    canvas.hint(DISABLE_DEPTH_TEST);
    drawTrickle(canvas, audioBoost, posYIsBottom, topSurfY, topFraction);
    drawFallingGrains(canvas, audioBoost, posYIsBottom, receivingSurfY, topFraction);
    canvas.hint(ENABLE_DEPTH_TEST);

    canvas.popMatrix();
    drawHUD(canvas);
    drawBeatTimeline(canvas);
  }

  // ── Sand fill — granular rings with noisy surface ─────────────────────────

  void drawSandFill(PGraphics canvas, float fraction, boolean isPositiveY) {
    if (fraction < 0.01) return;

    int   dir    = isPositiveY ? 1 : -1;
    float floorY = dir * (bulbHeight + 2);
    float neckY  = dir * 5;
    float surfY  = lerp(floorY, neckY, fraction);

    int slices     = 32;
    int ringDetail = 24;
    canvas.noStroke();

    // Floor cap disc — seals the bottom of the sand solid
    float floorR = max(2, getRadiusAtY(floorY) - 6);
    canvas.fill(65, 45, 12);
    canvas.beginShape(TRIANGLE_FAN);
    canvas.vertex(0, floorY, 0);
    for (int j = 0; j <= ringDetail; j++) {
      float a = TWO_PI * j / ringDetail;
      canvas.vertex(cos(a) * floorR, floorY, sin(a) * floorR);
    }
    canvas.endShape();

    // Body rings: outer lateral wall + solid inner fill disc at each level.
    // The fill disc seals the hollow tube center so sand looks solid from any angle.
    for (int i = 0; i < slices; i++) {
      float t1 = (float)i / slices;
      float t2 = (float)(i + 1) / slices;
      float y1 = lerp(floorY, surfY, t1);
      float y2 = lerp(floorY, surfY, t2);
      float r1 = max(2, getRadiusAtY(y1) - 6);
      float r2 = max(2, getRadiusAtY(y2) - 6);

      float bright1 = lerp(0.35, 0.78, t1);
      float bright2 = lerp(0.35, 0.78, t2);
      float gm1 = noise(i * 0.4,       frameCount * 0.005) * 0.3;
      float gm2 = noise((i+1) * 0.4,   frameCount * 0.005) * 0.3;

      // Outer lateral wall strip
      canvas.fill(
        (int)((185 + gm1 * 30) * bright1),
        (int)((130 + gm1 * 20) * bright1),
        (int)((45  + gm1 * 10) * bright1)
      );
      canvas.beginShape(TRIANGLE_STRIP);
      for (int j = 0; j <= ringDetail; j++) {
        float a   = TWO_PI * j / ringDetail;
        float yn1 = noise(cos(a) * 1.5 + i       * 0.7, sin(a) * 1.5 + 10) * 3.0 * dir;
        float yn2 = noise(cos(a) * 1.5 + (i + 1) * 0.7, sin(a) * 1.5 + 10) * 3.0 * dir;
        canvas.vertex(cos(a) * r1, y1 + yn1, sin(a) * r1);
        canvas.vertex(cos(a) * r2, y2 + yn2, sin(a) * r2);
      }
      canvas.endShape();

      // Inner fill disc at y2 — fills hollow interior, makes solid from any viewpoint
      canvas.fill(
        (int)((185 + gm2 * 30) * bright2),
        (int)((130 + gm2 * 20) * bright2),
        (int)((45  + gm2 * 10) * bright2)
      );
      canvas.beginShape(TRIANGLE_FAN);
      canvas.vertex(0, y2, 0);
      for (int j = 0; j <= ringDetail; j++) {
        float a   = TWO_PI * j / ringDetail;
        float yn2 = noise(cos(a) * 1.5 + (i + 1) * 0.7, sin(a) * 1.5 + 10) * 3.0 * dir;
        canvas.vertex(cos(a) * r2, y2 + yn2, sin(a) * r2);
      }
      canvas.endShape();
    }

    // Sandy surface: noisy disc, no specular ring
    float surfR = max(2, getRadiusAtY(surfY) - 6);
    drawSandySurface(canvas, surfY, surfR, dir);
  }

  // Granular surface — noise-displaced fan + scattered grain dots
  void drawSandySurface(PGraphics canvas, float surfY, float surfR, int dir) {
    int ringDetail = 28;
    canvas.noStroke();

    // Mounded noisy disc
    canvas.beginShape(TRIANGLE_FAN);
    canvas.fill(230, 185, 80);
    // Center slightly mounded
    canvas.vertex(0, surfY - dir * 4, 0);
    for (int j = 0; j <= ringDetail; j++) {
      float a = TWO_PI * j / ringDetail;
      // Rough noise: varies per angle and time (slow drift + beat wobble)
      float roughness = noise(cos(a) * 3 + frameCount * 0.02, sin(a) * 3 + 200) * (5 + beatWobble * 0.6) * dir;
      float bright = 0.7 + noise(cos(a) * 4, sin(a) * 4 + 300) * 0.3;
      canvas.fill(
        (int)(220 * bright),
        (int)(170 * bright),
        (int)(65  * bright)
      );
      canvas.vertex(cos(a) * surfR, surfY - roughness, sin(a) * surfR);
    }
    canvas.endShape();

    // Scattered grain dots on surface — sandy stipple effect
    int grainCount = 60;
    for (int g = 0; g < grainCount; g++) {
      // Deterministic scatter via noise index (stable positions, not random each frame)
      float ga = TWO_PI * g / grainCount + noise(g * 0.3) * 0.5;
      float gr = noise(g * 0.7 + 100) * surfR * 0.95;
      float gx = cos(ga) * gr;
      float gz = sin(ga) * gr;
      float gy = surfY - dir * (2 + noise(g * 0.5, frameCount * 0.01) * (3 + beatWobble * 0.4));
      float bright = 0.6 + noise(g * 0.2) * 0.4;
      canvas.stroke(
        (int)(255 * bright),
        (int)(200 * bright),
        (int)(80  * bright),
        200
      );
      canvas.strokeWeight(2.0 + noise(g * 0.9) * 2.5);
      canvas.point(gx, gy, gz);
    }
    canvas.noStroke();
  }

  // ── Neck trickle — grains from top sand surface through neck ─────────────

  void drawTrickle(PGraphics canvas, float audioBoost, boolean posYIsBottom, float topSurfY, float topFraction) {
    if (topFraction < 0.01) return; // top empty — no sand left to pour
    float neckDir  = posYIsBottom ? 1.0 : -1.0;
    float speed    = 1.5 + audioBoost * 0.6;
    float spawnY   = topSurfY; // spawn from where the top sand actually is
    float exitY    = 22.0 * neckDir; // exit point into bottom bulb

    for (int i = 0; i < TRICKLE_COUNT; i++) {
      trickleY[i] += speed * neckDir;

      // Reset when grain exits neck bottom into the receiving bulb
      if ((neckDir > 0 && trickleY[i] > exitY) || (neckDir < 0 && trickleY[i] < exitY)) {
        // Taper X/Z to neck width as we approach neck, widen near top sand
        float t = constrain(map(abs(trickleY[i] - spawnY), 0, abs(exitY - spawnY), 0, 1), 0, 1);
        float spawnSpread = lerp(getRadiusAtY(spawnY) * 0.3, neckWidth * 0.2, t);
        trickleX[i] = random(-spawnSpread, spawnSpread);
        trickleZ[i] = random(-spawnSpread, spawnSpread);
        trickleY[i] = spawnY + neckDir * random(0, 3);
      }

      // Taper spread toward neck center as grain falls
      float taper = constrain(map(abs(trickleY[i]), abs(spawnY), 22, 1.0, 0.2), 0.2, 1.0);
      float clampedX = trickleX[i] * taper;
      float clampedZ = trickleZ[i] * taper;

      float bright = 0.8 + noise(i * 0.3, frameCount * 0.05) * 0.2;
      canvas.stroke(
        (int)((220 + smoothBass * 35) * bright),
        (int)((170 + smoothMid  * 25) * bright),
        (int)(70 * bright),
        230
      );
      canvas.strokeWeight(2.5 + smoothBass * 1.5 + noise(i * 0.7) * 1.5);
      canvas.point(clampedX, trickleY[i], clampedZ);
    }
    canvas.noStroke();
  }

  // ── Falling grains — through air gap in receiving bulb ────────────────────

  void drawFallingGrains(PGraphics canvas, float audioBoost, boolean posYIsBottom, float receivingSurfY, float topFraction) {
    // Stop emitting when top bulb is nearly empty
    if (topFraction < 0.01) return;

    int dir = posYIsBottom ? 1 : -1;
    float neckExit = 22.0 * dir;
    float gravity  = 0.18 + smoothBass * 0.12;

    for (int i = 0; i < FALL_COUNT; i++) {
      // Accelerate grain downward
      fallSpeed[i] += gravity;
      fallY[i] += fallSpeed[i] * dir;

      // Tiny random horizontal drift — looks like a stream, not a blob
      fallX[i] += random(-0.25, 0.25);
      fallZ[i] += random(-0.25, 0.25);

      // Grain hit sand surface or out of bulb
      boolean hitSurface = (dir > 0 && fallY[i] >= receivingSurfY) ||
                           (dir < 0 && fallY[i] <= receivingSurfY);
      boolean outOfBounds = abs(fallY[i]) > bulbHeight + 5;

      if (hitSurface || outOfBounds) {
        resetFallGrain(i, false, dir);
        fallSpeed[i] = random(2.5, 6.0);
        continue;
      }

      // Draw grain — drawn after glass with depth test OFF, always visible inside bulb
      float bright = 0.8 + noise(i * 0.4, frameCount * 0.02) * 0.2;
      canvas.stroke(
        (int)((235 + smoothBass * 20) * bright),
        (int)((180 + smoothMid  * 15) * bright),
        (int)(65 * bright),
        255
      );
      canvas.strokeWeight(2.5 + noise(i * 0.6) * 2.0);
      canvas.point(fallX[i], fallY[i], fallZ[i]);
    }
    canvas.noStroke();
  }

  // ── Glass geometry ─────────────────────────────────────────────────────────

  void draw3DGlass(PGraphics canvas) {
    canvas.noStroke();
    canvas.fill(160, 220, 255, 40);
    canvas.specular(255);
    canvas.shininess(30);

    drawRevolvedBulb(canvas, -1);
    drawRevolvedBulb(canvas,  1);

    canvas.pushMatrix();
    canvas.fill(200, 230, 255, 90);
    drawCylinder(canvas, neckWidth, 10);
    canvas.popMatrix();
  }

  void drawRevolvedBulb(PGraphics canvas, int direction) {
    int detail = 32;
    int vSteps = 15;

    for (int vi = 0; vi < vSteps; vi++) {
      float y1 = direction * (2 + vi       * (bulbHeight / vSteps));
      float y2 = direction * (2 + (vi + 1) * (bulbHeight / vSteps));
      float r1 = getRadiusAtY(y1);
      float r2 = getRadiusAtY(y2);

      canvas.beginShape(TRIANGLE_STRIP);
      for (int hi = 0; hi <= detail; hi++) {
        float a = TWO_PI * hi / detail;
        canvas.vertex(cos(a) * r1, y1, sin(a) * r1);
        canvas.vertex(cos(a) * r2, y2, sin(a) * r2);
      }
      canvas.endShape();
    }
  }

  float getRadiusAtY(float yPos) {
    float ay = abs(yPos);
    if (ay < 2) return neckWidth;
    float t = (ay - 2) / (bulbHeight - 2);
    return lerp(neckWidth, bulbWidth, sin(t * PI / 2));
  }

  void drawCylinder(PGraphics canvas, float radius, float height) {
    int detail = 32;

    canvas.beginShape(TRIANGLE_STRIP);
    for (int ci = 0; ci <= detail; ci++) {
      float a = TWO_PI * ci / detail;
      canvas.vertex(cos(a) * radius, -height / 2, sin(a) * radius);
      canvas.vertex(cos(a) * radius,  height / 2, sin(a) * radius);
    }
    canvas.endShape();
  }

  // ── HUD ───────────────────────────────────────────────────────────────────

  void drawHUD(PGraphics canvas) {
    canvas.pushStyle();
    canvas.hint(PConstants.DISABLE_DEPTH_TEST);
    float ts = 11 * uiScale();
    canvas.fill(200, 255, 230);
    canvas.textSize(ts);
    canvas.textAlign(LEFT, TOP);
    canvas.text("Hourglass", 20, 20);
    canvas.fill(color(200, 200, 200));
    canvas.text("Fill: " + nf(sandFraction * 100, 0, 1) + "%", 20, 20 + ts * 1.5f);
    if (dropImminence > 0.01) {
      canvas.fill(255, 100, 100);
      canvas.text("DROP: " + nf(dropImminence * 100, 0, 0) + "%", 20, 20 + ts * 3.0f);
    }
    canvas.hint(PConstants.ENABLE_DEPTH_TEST);
    canvas.popStyle();
  }

  // ── Beat timeline strip ────────────────────────────────────────────────────
  // Horizontal bar at screen bottom. Shows ±30 s window. Drop ticks = orange marks.

  void drawBeatTimeline(PGraphics canvas) {
    canvas.pushStyle();
    canvas.hint(PConstants.DISABLE_DEPTH_TEST);

    float barH   = 18;
    float barY   = canvas.height - barH - 8;
    float barX   = 40;
    float barW   = canvas.width - 80;
    float nowMs  = audio.player.position();
    float windowMs = 30000; // ±30 seconds visible

    // Background track
    canvas.noStroke();
    canvas.fill(20, 20, 28, 200);
    canvas.rect(barX, barY, barW, barH, 4);

    // Playhead (center line)
    float cx = barX + barW * 0.5;
    canvas.stroke(255, 255, 255, 180);
    canvas.strokeWeight(2);
    canvas.line(cx, barY, cx, barY + barH);

    // Drop ticks — two tiers
    if (dropPredictor.isReady) {
      // Tier 1: strong beats (orange, short ticks, lower half)
      for (float dropMs : dropPredictor.dropTimes) {
        float dt = dropMs - nowMs;
        if (dt < -windowMs * 0.5 || dt > windowMs) continue;
        float tx = cx + (dt / windowMs) * barW;
        if (tx < barX || tx > barX + barW) continue;
        boolean isPast = dt < 0;
        canvas.stroke(isPast ? color(100, 65, 20, 70) : color(220, 130, 40, 180));
        canvas.strokeWeight(1.5);
        canvas.line(tx, barY + barH * 0.55, tx, barY + barH - 2);
      }

      // Tier 2: MASSIVE drops (bright red/white, full height, glow)
      for (float dropMs : dropPredictor.majorDropTimes) {
        float dt = dropMs - nowMs;
        if (dt < -windowMs * 0.5 || dt > windowMs) continue;
        float tx = cx + (dt / windowMs) * barW;
        if (tx < barX || tx > barX + barW) continue;
        boolean isPast    = dt < 0;
        boolean isNear    = dt > 0 && dt < 2000;
        boolean isImminent = dt > 0 && dt < 500;
        // Glow halo for imminent
        if (isImminent) {
          canvas.stroke(255, 60, 20, 100);
          canvas.strokeWeight(10);
          canvas.line(tx, barY, tx, barY + barH);
        }
        canvas.stroke(isPast ? color(160, 40, 20, 90) : (isNear ? color(255, 80, 30, 255) : color(255, 50, 50, 220)));
        canvas.strokeWeight(isNear ? 3.5 : 2.5);
        canvas.line(tx, barY + 1, tx, barY + barH - 1);
      }
    } else {
      // Scanning indicator
      canvas.fill(150, 150, 150, 160);
      canvas.textSize(10 * uiScale());
      canvas.textAlign(CENTER, CENTER);
      canvas.text("scanning...", barX + barW * 0.5, barY + barH * 0.5);
    }

    // Time labels
    canvas.fill(140, 140, 140, 200);
    canvas.textSize(9 * uiScale());
    canvas.textAlign(CENTER, TOP);
    canvas.text("now", cx, barY + barH + 2);

    canvas.hint(PConstants.ENABLE_DEPTH_TEST);
    canvas.popStyle();
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // Flip — preserve sand amounts (bottom 10% becomes top 10% after flip)
    if (c.aJustPressed) { targetRotation += PI; flipCount++; sandFraction = 1.0 - sandFraction; }

    // Camera orbit via right stick — center is width/2, height/2
    float nx = (c.rx / (float)width)  - 0.5;
    float ny = (c.ry / (float)height) - 0.5;
    float deadzone = 0.12;
    if (abs(nx) > deadzone) camRotY += nx * 0.04;
    if (abs(ny) > deadzone) camRotX += ny * 0.04;
    camRotX = constrain(camRotX, -PI/2, PI/2);
  }

  void handleKey(char keyChar) {
    if (keyChar == ' ') { targetRotation += PI; flipCount++; sandFraction = 1.0 - sandFraction; }
    if (keyChar == 'a' || keyChar == 'A') camRotY -= 0.05;
    if (keyChar == 'd' || keyChar == 'D') camRotY += 0.05;
    if (keyChar == 'w' || keyChar == 'W') camRotX -= 0.05;
    if (keyChar == 's' || keyChar == 'S') camRotX += 0.05;
    camRotX = constrain(camRotX, -PI/2, PI/2);
  }

  void handleMouseWheel(int delta) {
    // delta: -1 = scroll up (zoom in), +1 = scroll down (zoom out)
    zoomLevel *= (delta < 0) ? 1.08 : 0.93;
    zoomLevel = constrain(zoomLevel, 0.15, 5.0);
  }

  String[] getCodeLines() {
    return new String[]{ "Sand Volume Fill", "Beat-Reactive Surface", "Drop Imminence Flip" };
  }

  ControllerLayout[] getControllerLayout() { return new ControllerLayout[]{}; }
}
