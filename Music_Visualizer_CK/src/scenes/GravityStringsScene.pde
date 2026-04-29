// Gravity Strings — anchor strings sag under simulated gravity.
// Extended: sacred-geometry attractors, multi-body wells, cradle presets,
// skybox, gravity ripples, magnetic dipole mode, tethered solids.

class GravityStringsScene implements IScene {
  int   numAnchors    = 8;
  int   subdivisions  = 32;
  float phase         = 0;
  float pulse         = 0;
  float rotation      = 0;
  float rotationSpeed = 0.002;
  float gravity       = 1.0;

  // Per-skip sag physics
  static final int MAX_SKIP = 10;
  float[] sag    = new float[MAX_SKIP];
  float[] sagVel = new float[MAX_SKIP];
  static final float SPRING_K  = 0.03;
  static final float DAMPING   = 0.93;
  static final float SAG_SCALE = 0.14;

  // Feature toggles
  int     shapeIdx       = 0;        // 0=ring,1=tetra,2=cube,3=octa,4=dodeca,5=icosa
  String[] shapeNames    = {"Ring","Tetra","Cube","Octa","Dodeca","Icosa","Hexagram","JacobsLadder"};
  int     presetIdx      = 0;        // connection topology (overrides skip pattern)
  String[] presetNames   = {"AllSkips","Adjacent","Star","Hexagram","JacobsLadder","AllPairs"};
  int     wellCount      = 0;        // 0..4 orbiting gravity wells
  boolean magneticMode   = false;    // sag → curl around midpoint
  boolean tetheredSolids = false;    // small platonic at midpoints
  boolean skyboxOn       = false;
  int     skyboxIdx      = 0;
  String[] SKYBOXES = {
    "cloudy_01","cloudy_05","cloudy_10","cloudy_15","cloudy_20","cloudy_25"
  };
  Skybox skybox;
  float camRotY = 0, camRotX = 0.1;

  // Wells
  float wellPhase = 0, wellSpin = 0.012;
  float wellPolarity = 1.0;          // flips on beat for snap reformation

  // Ripples
  static final int MAX_RIPPLES = 8;
  float[] rippleR = new float[MAX_RIPPLES];
  float[] rippleAge = new float[MAX_RIPPLES];
  int rippleHead = 0;

  GravityStringsScene() {}

  void applyController(Controller c) {
    float ly = map(c.ly, 0, height, -1, 1);
    gravity = map(ly, -1, 1, 3.0, 0.1);

    float rx = map(c.rx, 0, width, -1, 1);
    int targetAnchors = round(map(rx, -1, 1, 4, 14));
    if (shapeIdx == 0) numAnchors = constrain(targetAnchors, 4, 14);

    // LT/RT: well count + spin
    if (c.rt > 0.5) wellSpin = lerp(wellSpin, 0.04, 0.05);
    else            wellSpin = lerp(wellSpin, 0.012, 0.05);

    if (c.aJustPressed) pluck(2.5);
    if (c.bJustPressed) wellCount = (wellCount + 1) % 5;
    if (c.yJustPressed) magneticMode = !magneticMode;
    if (c.xJustPressed) tetheredSolids = !tetheredSolids;
    if (c.leftStickClickJustPressed)  cycleShape(-1);
    if (c.rightStickClickJustPressed) cycleShape(+1);
    // Project convention: dpad left/right cycles background/skybox
    if (c.dpadRightJustPressed) { skyboxIdx = (skyboxIdx + 1) % SKYBOXES.length; skybox = null; skyboxOn = true; }
    if (c.dpadLeftJustPressed)  { skyboxIdx = (skyboxIdx - 1 + SKYBOXES.length) % SKYBOXES.length; skybox = null; skyboxOn = true; }
  }

  void cycleShape(int d) {
    shapeIdx = (shapeIdx + d + shapeNames.length) % shapeNames.length;
    presetIdx = shapeIdx == 0 ? presetIdx : 0;
    numAnchors = anchorCountForShape(shapeIdx, numAnchors);
  }

  int anchorCountForShape(int idx, int fallback) {
    switch(idx) {
      case 1: return 4;   // tetra
      case 2: return 8;   // cube vertices
      case 3: return 6;   // octa
      case 4: return 12;  // dodeca-ish (subset)
      case 5: return 12;  // icosa
      case 6: return 6;   // hexagram
      case 7: return 8;   // ladder
      default: return constrain(fallback, 4, 14);
    }
  }

  void pluck(float strength) {
    for (int i = 0; i < MAX_SKIP; i++) sagVel[i] -= strength + i * 0.2;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Gravity Strings (extended) ===",
      "",
      "shape: " + shapeNames[shapeIdx] + "   wells: " + wellCount,
      "magnetic: " + magneticMode + "   tethered: " + tetheredSolids,
      "skybox: " + (skyboxOn ? SKYBOXES[skyboxIdx] : "off"),
      "",
      "sag_vel += gravity*0.02 - sag*0.03;  sag_vel *= 0.93",
      "ripple boosts sag where midpoint distance ≈ ripple radius",
      "wells: orbit center; their net pull warps sag direction"
    };
  }

  void drawScene(PGraphics pg) {
    // Skybox first (P3D buffer expected)
    if (skyboxOn) drawSkyboxBg(pg);
    else pg.background(0);

    // Audio + beat
    if (analyzer.isBeat) {
      pulse = 1.0;
      rotation += 0.08;
      pluck(2.2);
      spawnRipple(min(pg.width, pg.height) * 0.05);
      wellPolarity = -wellPolarity;
    }

    // Sag physics
    int maxSkip = numAnchors / 2;
    for (int si = 0; si < maxSkip; si++) {
      sagVel[si] += gravity * 0.02;
      sagVel[si] -= sag[si] * SPRING_K;
      sagVel[si] *= DAMPING;
      sag[si] += sagVel[si];
      sag[si] = constrain(sag[si], -4.0, 4.0);
    }

    pulse    *= 0.88;
    phase    += 0.04;
    rotation += rotationSpeed;
    wellPhase += wellSpin;

    // Update ripples
    for (int i = 0; i < MAX_RIPPLES; i++) {
      if (rippleAge[i] > 0) {
        rippleR[i] += 8.0 + analyzer.bass * 4.0;
        rippleAge[i] -= 1.0;
      }
    }

    // Anchor positions
    float baseRadius = min(pg.width, pg.height) * 0.38;
    float r = baseRadius * (1.0 + pulse * 0.08);
    float[] ax = new float[numAnchors];
    float[] ay = new float[numAnchors];
    layoutAnchors(pg, ax, ay, r);

    // Wells
    float[] wx = new float[wellCount], wy = new float[wellCount];
    for (int w = 0; w < wellCount; w++) {
      float a = wellPhase + TWO_PI * w / max(1, wellCount);
      float wr = baseRadius * 0.45;
      wx[w] = pg.width  / 2.0 + cos(a) * wr;
      wy[w] = pg.height / 2.0 + sin(a) * wr;
    }

    // Strings — preset selects which (i,j) pairs
    int[][] pairs = pairsForPreset(presetIdx, numAnchors);
    for (int p = 0; p < pairs.length; p++) {
      int i = pairs[p][0], j = pairs[p][1];
      int skip = ((j - i) + numAnchors) % numAnchors;
      if (skip > maxSkip) skip = maxSkip;
      int band = (p * 7) % analyzer.spectrum.length;
      float bandAmp = analyzer.spectrum[band] * 3.0;

      pg.colorMode(HSB, 360, 255, 255, 255);
      float hue    = map(skip, 1, maxSkip, 270, 180);
      float alpha  = map(skip, 1, maxSkip, 240, 160);
      float weight = map(skip, 1, maxSkip, 4.0, 1.8);
      pg.colorMode(RGB, 255);
      pg.noFill();

      // Dark halo pass for skybox contrast
      pg.stroke(0, 0, 0, 180);
      pg.strokeWeight(weight + 2.5);
      drawString(pg, ax[i], ay[i], ax[j], ay[j], bandAmp, max(1, skip), i,
                 sag[max(0, min(MAX_SKIP - 1, skip - 1))], wx, wy);

      // Colored stroke on top
      pg.colorMode(HSB, 360, 255, 255, 255);
      pg.stroke((int)hue, 210, 255, (int)alpha);
      pg.strokeWeight(weight);
      pg.colorMode(RGB, 255);
      drawString(pg, ax[i], ay[i], ax[j], ay[j], bandAmp, max(1, skip), i,
                 sag[max(0, min(MAX_SKIP - 1, skip - 1))], wx, wy);
    }

    // Anchors
    pg.noStroke();
    for (int i = 0; i < numAnchors; i++) {
      float glow = 6 + pulse * 22;
      pg.fill(255, 220, 80, 70);
      pg.ellipse(ax[i], ay[i], glow * 2, glow * 2);
      pg.fill(255, 240, 160);
      pg.ellipse(ax[i], ay[i], glow * 0.4, glow * 0.4);
    }

    // Wells visual
    pg.noStroke();
    for (int w = 0; w < wellCount; w++) {
      float pol = (w % 2 == 0) ? wellPolarity : -wellPolarity;
      if (pol > 0) pg.fill(120, 180, 255, 180); else pg.fill(255, 110, 140, 180);
      pg.ellipse(wx[w], wy[w], 14, 14);
      pg.noFill();
      pg.stroke(pg.red(pg.get((int)wx[w], (int)wy[w])), 200);
      pg.strokeWeight(1.0);
      pg.ellipse(wx[w], wy[w], 26 + pulse * 12, 26 + pulse * 12);
    }

    // Ripple rings (visual)
    pg.noFill();
    for (int i = 0; i < MAX_RIPPLES; i++) {
      if (rippleAge[i] > 0) {
        pg.stroke(255, 255, 255, rippleAge[i] * 4);
        pg.strokeWeight(1.0);
        pg.ellipse(pg.width / 2.0, pg.height / 2.0, rippleR[i] * 2, rippleR[i] * 2);
      }
    }

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
    sceneHUD(pg, "Gravity Strings", new String[]{
      shapeNames[shapeIdx] + " | wells " + wellCount + " | mag " + (magneticMode?"on":"off") + " | tether " + (tetheredSolids?"on":"off"),
      "g " + nf(gravity,1,2) + " | anchors " + numAnchors + " | sky " + (skyboxOn ? SKYBOXES[skyboxIdx] : "off")
    });
  }

  void layoutAnchors(PGraphics pg, float[] ax, float[] ay, float r) {
    float cx = pg.width / 2.0, cy = pg.height / 2.0;
    if (shapeIdx == 6) {
      // hexagram = two interlocking triangles, 6 anchors
      for (int i = 0; i < numAnchors; i++) {
        float a = TWO_PI * i / numAnchors + rotation + (i % 2) * PI / numAnchors;
        ax[i] = cx + cos(a) * r;
        ay[i] = cy + sin(a) * r;
      }
    } else if (shapeIdx == 7) {
      // jacobs ladder: zigzag along vertical axis
      for (int i = 0; i < numAnchors; i++) {
        float t = (float)i / max(1, numAnchors - 1);
        ax[i] = cx + ((i % 2 == 0) ? -r * 0.6 : r * 0.6);
        ay[i] = cy - r + t * r * 2;
      }
    } else {
      // Default ring layout for shape 0..5 (platonic projections approximated as tilted rings)
      float tilt = shapeIdx * 0.18;
      for (int i = 0; i < numAnchors; i++) {
        float a = TWO_PI * i / numAnchors + rotation;
        float bx = cos(a) * r;
        float by = sin(a) * r * cos(tilt);
        ax[i] = cx + bx;
        ay[i] = cy + by + sin(a) * sin(tilt) * r * 0.3;
      }
    }
  }

  int[][] pairsForPreset(int idx, int n) {
    java.util.ArrayList<int[]> out = new java.util.ArrayList<int[]>();
    int maxSkip = n / 2;
    switch (idx) {
      case 1: // adjacent only
        for (int i = 0; i < n; i++) out.add(new int[]{i, (i + 1) % n});
        break;
      case 2: // star — every-other
        for (int i = 0; i < n; i++) out.add(new int[]{i, (i + 2) % n});
        break;
      case 3: // hexagram-ish — skip n/3
        for (int i = 0; i < n; i++) out.add(new int[]{i, (i + max(1, n / 3)) % n});
        break;
      case 4: // jacobs ladder — adjacent + cross rungs
        for (int i = 0; i < n - 1; i++) out.add(new int[]{i, i + 1});
        for (int i = 0; i < n - 2; i += 2) out.add(new int[]{i, i + 2});
        break;
      case 5: // all pairs
        for (int i = 0; i < n; i++)
          for (int j = i + 1; j < n; j++) out.add(new int[]{i, j});
        break;
      default: // all skip levels (original behaviour)
        for (int skip = 1; skip <= maxSkip; skip++)
          for (int i = 0; i < n; i++) out.add(new int[]{i, (i + skip) % n});
    }
    int[][] arr = new int[out.size()][];
    for (int i = 0; i < arr.length; i++) arr[i] = out.get(i);
    return arr;
  }

  void spawnRipple(float startR) {
    rippleR[rippleHead] = startR;
    rippleAge[rippleHead] = 60;
    rippleHead = (rippleHead + 1) % MAX_RIPPLES;
  }

  void drawSkyboxBg(PGraphics pg) {
    if (skybox == null) {
      skybox = new Skybox();
      skybox.load(resourcePath("media/skyboxes/" + SKYBOXES[skyboxIdx]));
    }
    pg.background(0);
    camRotY += 0.0008 + analyzer.bass * 0.002;
    pg.pushMatrix();
    pg.translate(pg.width / 2, pg.height / 2);
    pg.rotateX(camRotX);
    pg.rotateY(camRotY);
    skybox.draw(pg);
    pg.popMatrix();
    pg.blendMode(BLEND);
  }

  // Draw one string with sag, ripple boost, well-warped sag direction,
  // optional magnetic curl, and optional tethered solid at midpoint.
  void drawString(PGraphics pg, float x1, float y1, float x2, float y2,
                  float amplitude, int skip, int index, float sagOffset,
                  float[] wx, float[] wy) {
    float dx = x2 - x1, dy = y2 - y1;
    float len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;

    float nx = -dy / len, ny = dx / len;        // perpendicular unit
    float mx = (x1 + x2) * 0.5, my = (y1 + y2) * 0.5;

    // Well influence: net pull direction at midpoint
    float pullX = 0, pullY = 1;                 // default = down
    if (wx.length > 0) {
      float sxw = 0, syw = 0;
      for (int w = 0; w < wx.length; w++) {
        float pol = (w % 2 == 0) ? wellPolarity : -wellPolarity;
        float vx = wx[w] - mx, vy = wy[w] - my;
        float d = max(20, sqrt(vx * vx + vy * vy));
        sxw += pol * vx / d;
        syw += pol * vy / d;
      }
      float pl = max(0.001, sqrt(sxw * sxw + syw * syw));
      pullX = sxw / pl;
      pullY = syw / pl;
    }

    // Ripple boost: amplifies sag if midpoint near ripple radius
    float rippleBoost = 0;
    float cx = pg.width / 2.0, cy = pg.height / 2.0;
    float distFromCenter = sqrt((mx - cx) * (mx - cx) + (my - cy) * (my - cy));
    for (int i = 0; i < MAX_RIPPLES; i++) {
      if (rippleAge[i] > 0) {
        float d = abs(distFromCenter - rippleR[i]);
        if (d < 80) rippleBoost += (1.0 - d / 80.0) * (rippleAge[i] / 60.0) * 1.5;
      }
    }

    float phaseOff = phase * (1 + skip * 0.3) + index * 0.5;

    pg.beginShape();
    for (int s = 0; s <= subdivisions; s++) {
      float t  = (float)s / subdivisions;
      float bx = lerp(x1, x2, t);
      float by = lerp(y1, y2, t);

      // Lateral standing-wave vibration
      float vib = 0;
      for (int h = 1; h <= skip; h++) {
        vib += sin(t * PI * h) * sin(phaseOff * h) * amplitude / h;
      }

      // Sag envelope (max at midpoint), boosted by ripples
      float env = sin(t * PI);
      float sagMag = env * sagOffset * len * SAG_SCALE * (1.0 + rippleBoost);

      float ox, oy;
      if (magneticMode) {
        // Curl: sag rotates around midpoint as standing wave
        float curl = sin(t * TWO_PI + phase * 2.0) * sagOffset * len * SAG_SCALE * 0.6;
        ox = nx * (vib + curl);
        oy = ny * (vib + curl);
      } else {
        ox = nx * vib + pullX * sagMag;
        oy = ny * vib + pullY * sagMag;
      }
      pg.vertex(bx + ox, by + oy);
    }
    pg.endShape();

    // Tethered solid at midpoint, swung by sag
    if (tetheredSolids) {
      float sagMid = sagOffset * len * SAG_SCALE * (1.0 + rippleBoost);
      float tx = mx + pullX * sagMid;
      float ty = my + pullY * sagMid;
      drawTetheredSolid(pg, tx, ty, 8 + skip * 2, skip);
    }
  }

  void drawTetheredSolid(PGraphics pg, float x, float y, float r, int sides) {
    pg.noFill();
    pg.stroke(255, 255, 255, 160);
    pg.strokeWeight(1.0);
    pg.beginShape();
    int n = constrain(sides + 2, 3, 8);
    for (int i = 0; i < n; i++) {
      float a = TWO_PI * i / n + phase * 0.5;
      pg.vertex(x + cos(a) * r, y + sin(a) * r);
    }
    pg.endShape(CLOSE);
  }

  void onEnter() { background(0); }
  void onExit() {}

  void handleKey(char k) {
    if      (k == '[') cycleShape(-1);
    else if (k == ']') cycleShape(+1);
    else if (k == 'm' || k == 'M') magneticMode = !magneticMode;
    else if (k == 't' || k == 'T') tetheredSolids = !tetheredSolids;
    else if (k == 'w' || k == 'W') wellCount = (wellCount + 1) % 5;
    else if (k == 'k' || k == 'K') { skyboxOn = !skyboxOn; }
    else if (k == 'n' || k == 'N') { skyboxIdx = (skyboxIdx + 1) % SKYBOXES.length; skybox = null; }
    else if (k == 'o' || k == 'O') presetIdx = (presetIdx + 1) % presetNames.length;
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("LStick ↕", "Gravity strength"),
      new ControllerLayout("RStick ↔", "Anchor count (ring shape only)"),
      new ControllerLayout("A", "Pluck"),
      new ControllerLayout("B", "Cycle gravity wells (0-4)"),
      new ControllerLayout("Y", "Toggle magnetic mode"),
      new ControllerLayout("X", "Toggle tethered solids"),
      new ControllerLayout("L3/R3", "Cycle anchor shape"),
      new ControllerLayout("D-pad ←→", "Cycle skybox")
    };
  }
}
