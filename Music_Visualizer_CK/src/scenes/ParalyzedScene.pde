/**
 * ParalyzedScene — inspired by NF's "Paralyzed" (severe depression, emotional
 * numbness, feeling frozen). No figure. The screen itself is a pane of glass
 * under pressure: hairline fractures spread from random points, live for a
 * while, and fade away as new ones take their place — a restless, healing-
 * never-quite-happening network rather than a frozen picture. A soft glow
 * sits behind the glass, out of reach, dimming as the pressure rises and
 * drifting on a slow arc across the sky (song position, or a ~90s loop for
 * device input) — the world keeps moving while nothing in here does.
 *
 * Hidden in the middle is a body-shaped no-go zone cracks simply won't grow
 * through — never drawn directly, but as the rest of the pane fills in it
 * reads like a chalk outline left behind by everything growing around it.
 *
 * No hard-coded timestamps: the arc rides a slow-following energy envelope
 * normalised against its own running min/max, so it adapts to whatever song
 * is loaded, not just this one.
 *
 *   pressure — 0..1, "the weight". Rises fast (spawns new fractures), holds
 *              once reached — a dip alone doesn't undo accumulated damage.
 *   collapse — detected as a real sustained fade after having been deep.
 *              Existing cracks stay; their light fades instead.
 *
 * Knobs (controller sticks / web sliders / autopilot):
 *   pressure — manual pull on the pressure envelope
 *   hue      — cold (numb blue) .. warm (panic amber) bias on the crack glow
 *   glow     — overall brightness
 *   grain    — static/noise density (the "can't feel anything" texture)
 *   crack    — beat-flash intensity on individual fractures
 *
 * Buttons: A resets knobs, X triggers a manual gasp (+ spark burst), Y forces
 * the collapse (drains the light early, for cueing the ending live), B wipes
 * the pane.
 *
 * Foreground: a single spark — the one piece of this scene you actually
 * pilot. Left stick flies it anywhere on the pane (inertial, drags to a
 * stop rather than snapping); right stick aims a Tesla-coil discharge out
 * from it when nothing's nearby to ground on. Fly close enough to an
 * existing crack and the discharge grabs it instead — grounding onto the
 * network, sending a glint down it, riding along as you move past. Hard
 * bass hits jolt the spark off course mid-flight, same restlessness as the
 * rest of the pane. L3 freezes it in place, R3 snaps it back to center
 * with a burst. 10s with no stick/button input and it flies itself —
 * Perlin-drift wander, aimed the way it's headed — same fade-out-on-touch
 * handover as ParamAutoPilot, but scene-local since the spark isn't a
 * SceneParam.
 */

// A body-shaped no-go zone, never drawn — cracks simply refuse to grow
// through it. As the rest of the pane fills in, the untouched silhouette
// reads like a chalk outline left behind by everything growing around it.
// Fallen pose: head + torso diagonal, both arms flung up past the head,
// legs splayed (one bent, one straight) — see documentation reference art.
float silDistToSeg(float px, float py, float x1, float y1, float x2, float y2) {
  float dx = x2 - x1, dy = y2 - y1;
  float lenSq = dx * dx + dy * dy;
  float t = (lenSq > 0) ? constrain(((px - x1) * dx + (py - y1) * dy) / lenSq, 0, 1) : 0;
  return dist(px, py, x1 + t * dx, y1 + t * dy);
}

// Closest point on segment (x1,y1)-(x2,y2) to (px,py), plus the distance —
// used by the foreground spark to find a nearby crack to ground onto.
float[] closestPointOnSegment(float px, float py, float x1, float y1, float x2, float y2) {
  float dx = x2 - x1, dy = y2 - y1;
  float lenSq = dx * dx + dy * dy;
  float t = (lenSq > 0) ? constrain(((px - x1) * dx + (py - y1) * dy) / lenSq, 0, 1) : 0;
  float cx = x1 + t * dx, cy = y1 + t * dy;
  return new float[]{cx, cy, dist(px, py, cx, cy)};
}

boolean inCrimeSceneSilhouette(float x, float y, float pgW, float pgH) {
  float cx = pgW * 0.5, cy = pgH * 0.56;
  float s = min(pgW, pgH) * 0.62;
  if (dist(x, y, cx + 0.12 * s, cy - 0.40 * s) < 0.085 * s) return true; // head
  if (silDistToSeg(x, y, cx + 0.04 * s, cy - 0.30 * s, cx - 0.16 * s, cy + 0.16 * s) < 0.085 * s) return true; // torso
  if (silDistToSeg(x, y, cx + 0.08 * s, cy - 0.28 * s, cx + 0.34 * s, cy - 0.52 * s) < 0.050 * s) return true; // R upper arm
  if (silDistToSeg(x, y, cx + 0.34 * s, cy - 0.52 * s, cx + 0.28 * s, cy - 0.74 * s) < 0.045 * s) return true; // R forearm
  if (silDistToSeg(x, y, cx + 0.02 * s, cy - 0.30 * s, cx - 0.24 * s, cy - 0.54 * s) < 0.050 * s) return true; // L upper arm
  if (silDistToSeg(x, y, cx - 0.24 * s, cy - 0.54 * s, cx - 0.16 * s, cy - 0.76 * s) < 0.045 * s) return true; // L forearm
  if (silDistToSeg(x, y, cx - 0.16 * s, cy + 0.16 * s, cx - 0.36 * s, cy + 0.44 * s) < 0.060 * s) return true; // L thigh (bent)
  if (silDistToSeg(x, y, cx - 0.36 * s, cy + 0.44 * s, cx - 0.56 * s, cy + 0.54 * s) < 0.055 * s) return true; // L shin
  if (silDistToSeg(x, y, cx - 0.06 * s, cy + 0.18 * s, cx + 0.34 * s, cy + 0.60 * s) < 0.060 * s) return true; // R leg (straight)
  return false;
}

class GlassCrack {
  ArrayList<float[]> segments = new ArrayList<float[]>(); // x1,y1,x2,y2,depth
  int birthFrame;
  int lifeFrames;       // this crack fades out and is retired after this long
  float flash = 0;      // decaying per-crack beat highlight
  float sparkPos = -1;  // -1 = idle, else marches along segments[] as a traveling glint
  float shimmerSeed;
  boolean liveThisFrame = false; // the foreground spark is currently grounded on this crack
  float pgW, pgH;        // canvas size at birth, for silhouette avoidance

  GlassCrack(float x, float y, int maxDepth, int now, float pgW, float pgH) {
    birthFrame = now;
    lifeFrames = (int) random(500, 1400); // ~8-23s at 60fps — cracks come and go
    shimmerSeed = random(1000);
    this.pgW = pgW; this.pgH = pgH;
    grow(x, y, random(TWO_PI), random(70, 150) * uiScale(), 0, maxDepth);
  }

  void grow(float x, float y, float angle, float len, int depth, int maxDepth) {
    float nx = x + cos(angle) * len, ny = y + sin(angle) * len;
    float mx = (x + nx) * 0.5, my = (y + ny) * 0.5;
    // The silhouette is a wall cracks refuse to cross — they simply stop.
    if (inCrimeSceneSilhouette(nx, ny, pgW, pgH) || inCrimeSceneSilhouette(mx, my, pgW, pgH)) return;
    segments.add(new float[]{x, y, nx, ny, depth});
    if (depth >= maxDepth) return;
    int subs = (depth == 0) ? 2 : (random(1) < 0.6 ? 1 : 2);
    for (int s = 0; s < subs; s++) {
      float newAngle = angle + random(-0.9, 0.9);
      float newLen = len * random(0.55, 0.75);
      if (newLen > 4 * uiScale()) grow(nx, ny, newAngle, newLen, depth + 1, maxDepth);
    }
  }
}

class ParalyzedScene implements IScene {

  // ── Tuning ──────────────────────────────────────────────────────────────
  final float ENERGY_FOLLOW   = 0.003;  // long-term energy smoothing (slow)
  final float TREND_FOLLOW    = 0.0006; // even slower — for real trend reversals
  final float RANGE_ADAPT     = 0.0006; // running min/max adaptation speed
  final float PRESSURE_RISE   = 0.02;
  final float FADE_ONLY_ON_COLLAPSE = 0.006; // how fast light drains, collapse only
  final float COLLAPSE_DROP   = 0.16; // trend-vs-long gap needed to call it a real collapse
  final int   MAX_CRACKS      = 22;
  final int   CRACK_DEPTH     = 6;
  final int   GRAIN_COUNT     = 260;

  // Live knobs
  SceneParam pPressure = new SceneParam("pressure", "Pressure Pull", -0.3, 0.3, 0);
  SceneParam pHue      = new SceneParam("hue",      "Color Tone",     0,   1,  0.5);
  SceneParam pGlow     = new SceneParam("glow",     "Glow",           0.3, 2.0, 1);
  SceneParam pGrain    = new SceneParam("grain",    "Static Grain",   0,   2,  1);
  SceneParam pCrack    = new SceneParam("crack",    "Crack Flash",    0,   2,  1);
  SceneParam[] params = { pPressure, pHue, pGlow, pGrain, pCrack };

  // ── State ───────────────────────────────────────────────────────────────
  float longEnergy   = 0;
  float trendEnergy  = 0;
  float runningMin    = 1;
  float runningMax    = 0;
  boolean rangeSeeded = false;

  float pressure     = 0;   // the weight — mostly one-way
  boolean everDeep   = false;
  boolean manualCollapse = false; // Y toggles a performer-forced collapse
  float lightFade    = 1;   // 1 = full light, drains only on real collapse
  float tension      = 0;   // vignette / anticipation

  ArrayList<GlassCrack> cracks = new ArrayList<GlassCrack>();
  float[] grainX, grainY, grainPhase;
  float breath = 0;
  float beatPulse = 0;   // fast-decaying whole-screen "heartbeat" hit
  float smoothBass = 0, smoothMid = 0, smoothHigh = 0;

  // ── Foreground: the free-flying spark — the one thing you actually pilot ─
  final int   SPARK_TRAIL_LEN = 36;
  final float BOLT_MAX_LEN_FRACTION = 0.26; // discharge reach as a fraction of min(w,h)
  final float SNAP_RADIUS_FRACTION  = 0.15; // how close to a crack before the spark grounds onto it
  final float IDLE_SECONDS_BEFORE_AUTOFLIGHT = 10; // no controller input this long -> autopilot flies it
  GlassCrack lastAttachedCrack = null;       // edge-detect for the "just grounded" jolt
  int lastSparkInputMillis = 0;              // real-input timestamp; drives the 10s idle autopilot
  float moveInputX = 0, moveInputY = 0;  // raw left-stick reading, set in applyController
  float aimAngle = 0, aimMag = 0;        // right-stick direction/magnitude for the discharge
  boolean sparkFrozen = false;           // L3 — freeze movement in place
  boolean recenterRequested = false;     // R3 — consumed in drawScene (needs pg dims)
  float sparkX = -1, sparkY = -1;        // -1 = not yet placed; lazy-inits to screen center
  float sparkVX = 0, sparkVY = 0;
  float sparkBurst = 0;                  // decaying release/gasp flash
  float[] sparkTrailX = new float[SPARK_TRAIL_LEN];
  float[] sparkTrailY = new float[SPARK_TRAIL_LEN];
  int   sparkTrailIdx = 0, sparkTrailFilled = 0;
  ArrayList<float[]> teslaBolt = new ArrayList<float[]>(); // rebuilt each frame: x1,y1,x2,y2

  void drawScene(PGraphics pg) {
    // ── Energy envelope ─────────────────────────────────────────────────
    longEnergy  = lerp(longEnergy,  analyzer.master, ENERGY_FOLLOW);
    trendEnergy = lerp(trendEnergy, analyzer.master, TREND_FOLLOW);

    if (!rangeSeeded && longEnergy > 0) { runningMin = runningMax = longEnergy; rangeSeeded = true; }
    if (longEnergy > runningMax) runningMax = longEnergy; else runningMax = lerp(runningMax, longEnergy, RANGE_ADAPT);
    if (longEnergy < runningMin) runningMin = longEnergy; else runningMin = lerp(runningMin, longEnergy, RANGE_ADAPT);

    float intensity = (runningMax > runningMin) ? constrain((longEnergy - runningMin) / (runningMax - runningMin), 0, 1) : 0;

    if (pressure > 0.55) everDeep = true;
    boolean collapsing = manualCollapse
      || (everDeep && (trendEnergy - longEnergy) > COLLAPSE_DROP * (runningMax - runningMin));

    float target = constrain(intensity + pPressure.value, 0, 1);
    if (target > pressure) pressure = lerp(pressure, target, PRESSURE_RISE);
    // else: holds — cracks don't un-happen just because it got quieter for a moment

    // Light only ever drains during a genuine collapse; otherwise it holds.
    if (collapsing) lightFade = lerp(lightFade, 0.15, FADE_ONLY_ON_COLLAPSE);

    // Cracks live, fade, and retire — the network keeps moving instead of
    // freezing solid. Pressure sets how busy it stays, not a fixed picture.
    for (int i = cracks.size() - 1; i >= 0; i--) {
      if (frameCount - cracks.get(i).birthFrame > cracks.get(i).lifeFrames) cracks.remove(i);
    }

    // Spawn new fractures as accumulated pressure demands more of them.
    // A small baseline exists from the start — the pane was never whole.
    int wantCracks = 3 + (int) (pressure * (MAX_CRACKS - 3));
    int spawnTries = 0;
    while (cracks.size() < wantCracks && spawnTries < 40) {
      float x = random(pg.width), y = random(pg.height);
      spawnTries++;
      if (inCrimeSceneSilhouette(x, y, pg.width, pg.height)) continue; // leave the outline untouched
      cracks.add(new GlassCrack(x, y, CRACK_DEPTH, frameCount, pg.width, pg.height));
    }

    // Anticipation: tighten before a predicted major drop, never release on it.
    float anticipation = 0;
    if (dropPredictor != null && dropPredictor.isReady && audio.player != null) {
      anticipation = dropPredictor.majorImminentDropFactor(audio.player.position(), 4.0);
    }
    tension = lerp(tension, constrain(pressure * 0.7 + anticipation * 0.3, 0, 1), 0.05);

    smoothBass = lerp(smoothBass, analyzer.bass, 0.18);
    smoothMid  = lerp(smoothMid,  analyzer.mid,  0.18);
    smoothHigh = lerp(smoothHigh, analyzer.high, 0.22);

    // Beat = a gasp: a handful of existing fractures flicker bright and a
    // glint races along them — trapped energy hunting for a way out, still
    // contained by the pane. Harder hits wake more of the network at once.
    if (analyzer.isBeat && !cracks.isEmpty() && pressure > 0.08) {
      int flashes = 1 + (int) constrain(smoothBass * 4, 0, cracks.size() - 1);
      for (int f = 0; f < flashes; f++) {
        GlassCrack gc = cracks.get((int) random(cracks.size()));
        gc.flash = 1;
        gc.sparkPos = 0;
      }
      beatPulse = 1;
    }
    beatPulse *= 0.88;
    for (GlassCrack c : cracks) {
      c.flash *= 0.85;
      if (c.sparkPos >= 0) {
        c.sparkPos += 1.6 + smoothBass * 1.5;
        if (c.sparkPos > c.segments.size()) c.sparkPos = -1;
      }
    }

    breath += 0.006;

    // ── Foreground spark: free-flying, inertial movement (left stick) ──────
    if (sparkX < 0) { sparkX = pg.width * 0.5; sparkY = pg.height * 0.5; } // lazy-init to center
    if (recenterRequested) {
      sparkX = pg.width * 0.5; sparkY = pg.height * 0.5;
      sparkVX = 0; sparkVY = 0; sparkBurst = 1;
      recenterRequested = false;
    }
    // No controller input for a while — the spark flies itself, wandering
    // the pane on slow Perlin drift instead of just sitting there.
    boolean autoFlight = (millis() - lastSparkInputMillis) > IDLE_SECONDS_BEFORE_AUTOFLIGHT * 1000;
    if (autoFlight && !sparkFrozen) {
      float t = millis() * 0.00035;
      moveInputX = (noise(t, 11.3) * 2 - 1) * 1.4;
      moveInputY = (noise(t, 47.9) * 2 - 1) * 1.4;
    }

    float moveAccel    = min(pg.width, pg.height) * 0.0022;
    float moveMaxSpeed = min(pg.width, pg.height) * 0.016;
    float margin       = min(pg.width, pg.height) * 0.04;
    if (!sparkFrozen) {
      sparkVX = constrain(sparkVX + moveInputX * moveAccel, -moveMaxSpeed, moveMaxSpeed);
      sparkVY = constrain(sparkVY + moveInputY * moveAccel, -moveMaxSpeed, moveMaxSpeed);
      sparkVX *= 0.92; sparkVY *= 0.92; // drag — release the stick and it glides to a stop
      sparkX += sparkVX; sparkY += sparkVY;
      if (sparkX < margin)            { sparkX = margin;            sparkVX =  abs(sparkVX) * 0.3; }
      if (sparkX > pg.width - margin) { sparkX = pg.width - margin;  sparkVX = -abs(sparkVX) * 0.3; }
      if (sparkY < margin)            { sparkY = margin;            sparkVY =  abs(sparkVY) * 0.3; }
      if (sparkY > pg.height - margin){ sparkY = pg.height - margin; sparkVY = -abs(sparkVY) * 0.3; }
    }
    // A hard bass hit jolts the spark off course mid-flight — restless, same
    // as the rest of the pane never quite settling.
    if (analyzer.isBeat && smoothBass > 0.32 && !sparkFrozen) {
      float joltA = random(TWO_PI);
      float joltMag = moveMaxSpeed * (0.6 + 0.8 * smoothBass);
      sparkVX += cos(joltA) * joltMag;
      sparkVY += sin(joltA) * joltMag;
      sparkBurst = max(sparkBurst, 0.7);
    }
    sparkBurst *= 0.88;

    // While flying itself, aim the discharge the way it's headed rather
    // than wherever the right stick was last left.
    if (autoFlight && (abs(sparkVX) + abs(sparkVY)) > 0.01) {
      aimAngle = atan2(sparkVY, sparkVX);
      aimMag = 0.55 + 0.25 * noise(millis() * 0.0006, 91.2);
    }

    sparkTrailX[sparkTrailIdx] = sparkX;
    sparkTrailY[sparkTrailIdx] = sparkY;
    sparkTrailIdx = (sparkTrailIdx + 1) % SPARK_TRAIL_LEN;
    sparkTrailFilled = min(sparkTrailFilled + 1, SPARK_TRAIL_LEN);

    // Fly close enough to an existing crack and the discharge grounds onto
    // it instead of free-aiming — snapping to the network as you move.
    for (GlassCrack cr : cracks) cr.liveThisFrame = false;
    GlassCrack nearestCrack = null;
    float nearestX = 0, nearestY = 0, nearestDist = Float.MAX_VALUE;
    for (GlassCrack cr : cracks) {
      for (float[] seg : cr.segments) {
        float[] cp = closestPointOnSegment(sparkX, sparkY, seg[0], seg[1], seg[2], seg[3]);
        if (cp[2] < nearestDist) { nearestDist = cp[2]; nearestX = cp[0]; nearestY = cp[1]; nearestCrack = cr; }
      }
    }
    float snapRadius = min(pg.width, pg.height) * SNAP_RADIUS_FRACTION;
    boolean attached = nearestCrack != null && nearestDist < snapRadius;

    float bx2, by2;
    if (attached) {
      bx2 = nearestX; by2 = nearestY;
      nearestCrack.liveThisFrame = true;
      if (nearestCrack != lastAttachedCrack) {
        // Just grounded on a new crack — a bright jolt down it.
        nearestCrack.flash = 1;
        nearestCrack.sparkPos = 0;
        sparkBurst = max(sparkBurst, 0.5);
      } else if (frameCount % 25 == 0) {
        // Stayed attached — keep recharging it rather than going dark.
        nearestCrack.flash = max(nearestCrack.flash, 0.6);
        if (nearestCrack.sparkPos < 0) nearestCrack.sparkPos = 0;
      }
    } else {
      // Nothing to ground on — free-aim discharge (right stick), bass swells its reach.
      float boltLen = min(pg.width, pg.height) * BOLT_MAX_LEN_FRACTION * aimMag * (0.65 + 0.35 * smoothBass);
      bx2 = sparkX + cos(aimAngle) * boltLen;
      by2 = sparkY + sin(aimAngle) * boltLen;
    }
    lastAttachedCrack = attached ? nearestCrack : null;

    // Tesla-coil discharge: a jittery, occasionally-branching arc instead of
    // a plain line — rebuilt fresh every frame so it crackles rather than sits.
    buildTeslaBolt(sparkX, sparkY, bx2, by2);

    render(pg, intensity, sparkX, sparkY, aimMag, attached);
  }

  // Jagged mid-point-displacement bolt from (x1,y1) to (x2,y2), with small
  // side-branches near the live end — a Tesla coil discharge, not a wire.
  void buildTeslaBolt(float x1, float y1, float x2, float y2) {
    teslaBolt.clear();
    int segs = 7;
    float jitter = min(width, height) * 0.018 * (0.4 + tension);
    float px = x1, py = y1;
    for (int i = 1; i <= segs; i++) {
      float t = (float) i / segs;
      float bx = lerp(x1, x2, t) + random(-jitter, jitter);
      float by = lerp(y1, y2, t) + random(-jitter, jitter);
      if (i == segs) { bx = x2; by = y2; } // always land exactly on the spark
      teslaBolt.add(new float[]{px, py, bx, by});
      // occasional short branch fork, more likely near the live (spark) end
      if (i > 2 && random(1) < 0.16 + 0.25 * ((float) i / segs)) {
        float fa = random(TWO_PI);
        float flen = jitter * random(1.5, 3.5);
        teslaBolt.add(new float[]{bx, by, bx + cos(fa) * flen, by + sin(fa) * flen, 1}); // flagged as a branch via extra element
      }
      px = bx; py = by;
    }
  }

  void render(PGraphics pg, float intensity, float sparkX, float sparkY, float aimMag, boolean attached) {
    float hueT = constrain(pHue.value * 0.4 + pressure * 0.5, 0, 1);
    // cold numb blue-gray (low hueT) → warm panicked amber-gray (high hueT)
    float rC = lerp(20, 70, hueT), gC = lerp(24, 40, hueT), bC = lerp(32, 24, hueT);
    pg.background(rC * 0.3, gC * 0.3, bC * 0.35);
    pg.pushStyle();

    // ── Heartbeat wash — the whole pane answers a hit, then settles ─────
    pg.blendMode(ADD);
    pg.noStroke();
    if (beatPulse > 0.02) {
      pg.fill(lerp(60, 120, hueT), lerp(70, 60, hueT), lerp(100, 50, hueT), 26 * beatPulse * pGlow.value);
      pg.rect(0, 0, pg.width, pg.height);
    }

    // ── Something behind the glass — a soft glow, out of reach ──────────
    // Smooth continuous falloff (many thin steps, Gaussian-ish) instead of a
    // handful of big jumps — that's what reads as "rings" instead of a glow.
    // It also drifts on a slow arc like the sun crossing the sky — the world
    // keeps moving on the other side of the glass while nothing in here does.
    float arcT;
    int songLen = (audio != null) ? audio.getLength() : 0;
    if (songLen > 0) arcT = constrain(audio.getPosition() / (float) songLen, 0, 1);
    else              arcT = (frameCount % 5400) / 5400.0; // ~90s loop when length is unknown (device input)
    float glowX = lerp(pg.width * 0.10, pg.width * 0.90, arcT);
    float glowY = lerp(pg.height * 0.60, pg.height * 0.14, sin(arcT * PI));
    float glowPulse = 0.8 + 0.12 * sin(breath) + 0.25 * smoothBass + 0.3 * beatPulse;
    float glowDim = lightFade * (1 - pressure * 0.4);
    float maxR = min(pg.width, pg.height) * 0.34 * glowPulse;
    float peakAlpha = 30 * glowDim * pGlow.value;
    int glowSteps = 28;
    for (int i = glowSteps; i >= 1; i--) {
      float t = (float) i / glowSteps;
      float rr = maxR * t;
      float a = peakAlpha * exp(-4.5 * t * t);
      pg.fill(lerp(110, 220, hueT), lerp(130, 160, hueT), lerp(190, 130, hueT), a);
      pg.ellipse(glowX, glowY, rr, rr);
    }
    pg.fill(255, 255, 250, 55 * glowDim * pGlow.value);
    pg.ellipse(glowX, glowY, maxR * 0.045, maxR * 0.045);
    pg.blendMode(BLEND);

    // ── Static grain — "can't feel anything" texture, alive not just noise ─
    if (grainX == null) {
      grainX = new float[GRAIN_COUNT]; grainY = new float[GRAIN_COUNT]; grainPhase = new float[GRAIN_COUNT];
      for (int i = 0; i < GRAIN_COUNT; i++) {
        grainX[i] = random(pg.width); grainY[i] = random(pg.height); grainPhase[i] = random(TWO_PI);
      }
    }
    pg.blendMode(ADD);
    float grainAlpha = (26 + 60 * smoothHigh + 30 * smoothMid) * pGrain.value;
    for (int i = 0; i < GRAIN_COUNT; i++) {
      float flick = 0.3 + 0.7 * noise(i * 0.7, frameCount * 0.025);
      pg.fill(190, 205, 220, grainAlpha * flick);
      float sz = max(1, (1.3 + beatPulse * 1.5) * uiScale());
      float speed = 0.4 + smoothMid * 1.6;
      pg.ellipse(grainX[i], grainY[i] - (frameCount * speed + grainPhase[i] * 40) % pg.height, sz, sz);
    }
    pg.blendMode(BLEND);

    // ── The glass pane, under pressure — livelier: shimmer + traveling sparks
    float glowAmt = pGlow.value * lightFade;
    for (GlassCrack c : cracks) {
      float fadeIn  = constrain((frameCount - c.birthFrame) / 30.0, 0, 1);           // grows in over 0.5s
      float remain  = c.lifeFrames - (frameCount - c.birthFrame);
      float fadeOut = constrain(remain / 90.0, 0, 1);                                // fades out over ~1.5s before retiring
      float age = fadeIn * fadeOut;
      float shimmer = 0.82 + 0.18 * sin(frameCount * 0.04 + c.shimmerSeed);
      for (float[] seg : c.segments) {
        int depth = (int) seg[4];
        float depthFalloff = 1.0 / (1 + depth * 0.6);
        float liveBoost = c.liveThisFrame ? 1.6 : 1.0; // grounded spark makes this crack a live wire
        float baseAlpha = (55 + 150 * pressure) * depthFalloff * age * glowAmt * shimmer * liveBoost;
        float flashBoost = c.flash * 220 * depthFalloff;
        pg.stroke(lerp(190, 255, hueT), lerp(205, 210, hueT), lerp(255, 185, hueT),
                  constrain(baseAlpha + flashBoost, 0, 255) * pCrack.value);
        pg.strokeWeight(max(1, (2.4 - depth * 0.3 + beatPulse * 1.6 + c.flash * 1.2) * uiScale()));
        pg.line(seg[0], seg[1], seg[2], seg[3]);
      }
    }
    // Traveling glints — trapped energy racing along a fracture, contained.
    pg.blendMode(ADD);
    pg.noStroke();
    for (GlassCrack c : cracks) {
      if (c.sparkPos < 0) continue;
      int idx = constrain((int) c.sparkPos, 0, c.segments.size() - 1);
      float[] seg = c.segments.get(idx);
      float fade = 1 - (c.sparkPos / max(1, c.segments.size()));
      pg.fill(255, 250, 235, 230 * fade * pCrack.value);
      float sz = max(2, 5 * uiScale() * fade);
      pg.ellipse(seg[2], seg[3], sz, sz);
    }
    pg.blendMode(BLEND);

    // ── Vignette — tightens with tension, never fully releases ─────────
    pg.noStroke();
    int vigSteps = 5;
    for (int i = 0; i < vigSteps; i++) {
      float t = (float) i / vigSteps;
      float a = tension * 90 * (1 - t) / pGlow.value;
      pg.fill(0, a);
      float inset = t * min(pg.width, pg.height) * 0.5;
      pg.rect(-inset * 0.2, -inset * 0.2, pg.width + inset * 0.4, pg.height + inset * 0.4);
    }

    // ── Foreground: the free-flying spark, ahead of the vignette, always readable
    pg.blendMode(ADD);
    pg.noStroke();
    // Idle (not aiming) still gets a faint residual crackle, not silence.
    // Grounded on a crack, the discharge runs at full charge regardless of aim.
    float chargeLevel = attached ? 1.0 : constrain(0.18 + 0.82 * aimMag, 0, 1);

    // Tesla-coil arc — bright core + soft outer glow, flickering with tension.
    for (float[] b : teslaBolt) {
      boolean isBranch = b.length > 4;
      float flicker = 0.6 + 0.4 * noise(b[0] * 0.01, frameCount * 0.3);
      float boltAlpha = (isBranch ? 90 : 180) * chargeLevel * (0.5 + 0.5 * tension) * flicker * pCrack.value;
      pg.stroke(200, 220, 255, boltAlpha * 0.4);
      pg.strokeWeight(max(1, 4 * uiScale()));
      pg.line(b[0], b[1], b[2], b[3]);
      pg.stroke(255, 255, 250, boltAlpha);
      pg.strokeWeight(max(1, 1.4 * uiScale()));
      pg.line(b[0], b[1], b[2], b[3]);
    }

    // Fading trail behind the spark.
    pg.noFill();
    int trailSegs = sparkTrailFilled;
    if (trailSegs > 2) {
      pg.strokeWeight(max(1, 2 * uiScale()));
      for (int s = 1; s < trailSegs; s++) {
        int a = (sparkTrailIdx - s + SPARK_TRAIL_LEN * 2) % SPARK_TRAIL_LEN;
        int b = (sparkTrailIdx - s - 1 + SPARK_TRAIL_LEN * 2) % SPARK_TRAIL_LEN;
        float fade = 1.0 - (float) s / trailSegs;
        pg.stroke(220, 230, 255, 140 * fade * fade * pCrack.value);
        pg.line(sparkTrailX[a], sparkTrailY[a], sparkTrailX[b], sparkTrailY[b]);
      }
    }

    // The spark itself — layered glow, brighter on release/gasp bursts.
    pg.noStroke();
    float sparkGlow = 1 + sparkBurst * 1.8;
    for (int layer = 4; layer >= 1; layer--) {
      float rr = (3 + layer * 3.5) * uiScale() * sparkGlow;
      pg.fill(220, 235, 255, (18 + 12 * sparkBurst) * pGlow.value);
      pg.ellipse(sparkX, sparkY, rr, rr);
    }
    pg.fill(255, 255, 255, 230);
    pg.ellipse(sparkX, sparkY, 4 * uiScale() * sparkGlow, 4 * uiScale() * sparkGlow);
    pg.blendMode(BLEND);

    pg.popStyle();
    pg.blendMode(BLEND); // never leak ADD into crossfade/HUD compositing
  }

  void onEnter() {
    // Deliberately do not clear cracks/pressure history — carried damage
    // persists like the feeling does. Only reset the purely visual decay.
    lastSparkInputMillis = millis(); // fresh idle window on entry
  }

  void onExit() {}

  void applyController(Controller c) {
    // Both sticks are dedicated to the foreground spark — that's the one
    // thing in this scene you actually drive in real time. The ambient
    // knobs (pressure/hue/glow/grain/crack) stay reachable via keyboard
    // < > - + or the web UI, same as any SceneParam.
    float dz = 0.12;
    float lx = (c.lx - width  * 0.5) / (width  * 0.5);
    float ly = (c.ly - height * 0.5) / (height * 0.5);
    moveInputX = (abs(lx) > dz) ? lx : 0;
    moveInputY = (abs(ly) > dz) ? ly : 0;

    float rx = (c.rx - width  * 0.5) / (width  * 0.5);
    float ry = (c.ry - height * 0.5) / (height * 0.5);
    float rmag = constrain(sqrt(rx * rx + ry * ry), 0, 1);
    if (rmag > dz) { aimAngle = atan2(ry, rx); aimMag = rmag; }
    else            aimMag = lerp(aimMag, 0, 0.08); // eases off rather than snapping

    boolean anyButton = c.aButton || c.bButton || c.xButton || c.yButton
      || c.leftStickClickButton || c.rightStickClickButton;
    if (abs(lx) > dz || abs(ly) > dz || rmag > dz || anyButton) lastSparkInputMillis = millis();

    if (c.aJustPressed) for (SceneParam q : params) q.reset();
    if (c.leftStickClickJustPressed)  sparkFrozen = !sparkFrozen;      // L3 — freeze in place
    if (c.rightStickClickJustPressed) recenterRequested = true;        // R3 — snap back to center + burst
    if (c.xJustPressed) triggerGasp();
    if (c.yJustPressed) manualCollapse = !manualCollapse;
    if (c.bJustPressed) resetPane();
  }

  // A performer-triggered gasp — same shape as a beat hit, on demand, plus a
  // burst on the foreground spark.
  void triggerGasp() {
    beatPulse = 1;
    sparkBurst = 1;
    int flashes = min(cracks.size(), 5);
    for (int f = 0; f < flashes; f++) {
      GlassCrack gc = cracks.get((int) random(cracks.size()));
      gc.flash = 1;
      gc.sparkPos = 0;
    }
  }

  // Wipe the pane clean and start the weight over from nothing.
  void resetPane() {
    cracks.clear();
    pressure = 0;
    everDeep = false;
    manualCollapse = false;
    lightFade = 1;
    tension = 0;
    sparkX = -1; sparkY = -1; sparkVX = 0; sparkVY = 0;
    moveInputX = 0; moveInputY = 0; aimAngle = 0; aimMag = 0;
    sparkFrozen = false; recenterRequested = false;
    sparkTrailFilled = 0; sparkTrailIdx = 0;
    lastAttachedCrack = null;
  }

  void handleKey(char k) {
    handleParamKey(k);
  }

  SceneParam[] getParams() { return params; }

  String[] getCodeLines() {
    return new String[] {
      "=== Paralyzed ===",
      "// the pane cracks under pressure, but never shatters",
      "intensity = normalize(longFollow(RMS), runningMin, runningMax)",
      "pressure  = rise fast toward intensity, holds — never un-cracks",
      "cracks    = live ~10-20s, fade, retire; pressure sets how many at once",
      "silhouette= body-shaped void, never drawn — cracks refuse to cross it",
      "collapse  = everDeep && (trend - long) > threshold * range",
      "lightFade = drains only on real collapse  // network stays, light leaves",
      "beat      = several cracks flicker + a glint races along  // a gasp",
      "spark     = LStick flies it, RStick aims a tesla-arc discharge",
      "          = hard bass hits jolt it off course mid-flight",
      "ground    = fly near a crack and the discharge snaps to it, sends a glint",
      "autopilot = 10s no input -> Perlin-drift flight, hands back the instant you touch a stick"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("LStick", "Fly the foreground spark anywhere on the pane"),
      new ControllerLayout("RStick", "Aim the discharge (only when no crack is close enough to ground on)"),
      new ControllerLayout("L3", "Freeze the spark in place"),
      new ControllerLayout("R3", "Snap back to center + burst"),
      new ControllerLayout("A", "Reset knobs to default"),
      new ControllerLayout("X", "Trigger a gasp (crack flash + spark burst)"),
      new ControllerLayout("Y", "Toggle forced collapse"),
      new ControllerLayout("B", "Wipe the pane — reset pressure, cracks & spark"),
    };
  }
}
