// FFT Worm Scene — state 11
//
// One enormous worm whose body IS the frequency spectrum.
// Head = sub-bass, tail = air-highs. Each segment's radius and colour
// are driven live by its corresponding FFT band.
//
// Low segments  (head)  → fat, red/orange, punchy on bass hits
// Mid segments  (body)  → medium, green/yellow, groove-locked
// High segments (tail)  → thin, cyan/blue, shimmer rapidly
// Beat                  → ripple wave shoots from head to tail + flash ring
//
// Controller:
//   L Stick       → steer the worm's head
//   R Stick ↕     → body amplitude multiplier (how reactive the worm is)
//   A             → snap the worm into a circle formation
//   B             → release / resume wandering
//   X             → reverse travel direction
//   Y             → cycle colour palette (spectrum / heat / ice / mono)
//   RT            → turbo wander speed
//   LT            → slow crawl

class FFTWormScene implements IScene {
  // ... (keeping fields)
  final int   N          = 52;   
  final float SEP        = 16.0; 
  float[]     sx         = new float[N];
  float[]     sy         = new float[N];
  float       vxx        = 3, vyy = 1; // renamed to avoid potential name conflicts

  float[]     bandAmp    = new float[N];  
  float[]     ripple     = new float[N];
  float       noiseOff   = random(20000);
  float       speedScale = 1.0;
  float       ampMult    = 1.0;  
  boolean     circleMode = false;
  float       circleAng  = 0;    
  int         palette    = 0;    
  boolean     reversed   = false;
  boolean     steering   = false;
  float       steerX, steerY;

  FFTWormScene() {
    for (int i = 0; i < N; i++) {
      sx[i] = 1280 / 2.0 - i * SEP;
      sy[i] = 720 / 2.0;
    }
  }

  void drawScene(PGraphics pg) {
    boolean isBeat = analyzer.isBeat;
    int fftSize = max(1, audio.fft.avgSize());
    for (int i = 0; i < N; i++) {
      int band = (int) map(i, 0, N - 1, 0, fftSize - 1);
      float raw = audio.fft.getAvg(band);
      bandAmp[i] = lerp(bandAmp[i], constrain(raw * ampMult, 0, 40), 0.3);
    }

    if (isBeat) ripple[0] = 1.0;
    for (int i = N - 1; i > 0; i--) {
      ripple[i] = lerp(ripple[i], ripple[i-1], 0.5);
    }
    for (int i = 0; i < N; i++) ripple[i] *= 0.85;

    pg.background(5, 5, 14);
    float bass = bandAmp[0];
    if (bass > 2) {
      pg.colorMode(HSB, 360, 255, 255, 255);
      pg.noStroke(); pg.noFill();
      for (int r = 3; r > 0; r--) {
        pg.fill(240, 200, 100, bass * 1.2 * r);
        pg.ellipse(sx[0], sy[0], bass * 14 * r, bass * 14 * r);
      }
      pg.colorMode(RGB, 255);
    }

    if (!circleMode) {
      float mid = 0;
      for (int i = N/3; i < 2*N/3; i++) mid += bandAmp[i];
      mid /= (N / 3.0);

      if (steering) {
        float dx = steerX - sx[0], dy = steerY - sy[0];
        float d  = max(dist(sx[0], sy[0], steerX, steerY), 1);
        vxx += dx / d * 1.5;
        vyy += dy / d * 1.5;
      } else {
        float t      = pg.parent.frameCount * 0.003 + noiseOff;
        float wander = pg.parent.noise(sx[0] * 0.003 + noiseOff,
                             sy[0] * 0.003 + noiseOff * 1.6, t) * TWO_PI * 2.5;
        vxx += cos(wander) * 0.3 * (1 + mid * 0.04);
        vyy += sin(wander) * 0.3 * (1 + mid * 0.04);
      }

      float topSpeed = (5.5 + bass * 0.15) * speedScale;
      float spd = dist(0, 0, vxx, vyy);
      if (spd > topSpeed) { vxx = vxx / spd * topSpeed; vyy = vyy / spd * topSpeed; }

      float mg = 120;
      if (sx[0] < mg)          vxx += 0.7;
      if (sx[0] > pg.width  - mg) vxx -= 0.7;
      if (sy[0] < mg)          vyy += 0.7;
      if (sy[0] > pg.height - mg) vyy -= 0.7;

      sx[0] = constrain(sx[0] + vxx, 0, pg.width);
      sy[0] = constrain(sy[0] + vyy, 0, pg.height);

      for (int i = 1; i < N; i++) {
        float dx = sx[i-1] - sx[i];
        float dy = sy[i-1] - sy[i];
        float d  = dist(sx[i-1], sy[i-1], sx[i], sy[i]);
        if (d > SEP) {
          float pull = (d - SEP) / d;
          sx[i] += dx * pull;
          sy[i] += dy * pull;
        }
      }
    } else {
      circleAng += 0.01 * speedScale;
      float cx  = pg.width / 2.0, cy = pg.height / 2.0;
      float rad = min(pg.width, pg.height) * 0.28;
      for (int i = 0; i < N; i++) {
        float a   = circleAng + TWO_PI * i / N;
        float tx  = cx + cos(a) * rad;
        float ty  = cy + sin(a) * rad;
        sx[i] = lerp(sx[i], tx, 0.08);
        sy[i] = lerp(sy[i], ty, 0.08);
      }
    }

    pg.colorMode(HSB, 360, 255, 255, 255);
    pg.noStroke();
    for (int ii = N - 1; ii >= 0; ii--) {
      int i       = reversed ? (N - 1 - ii) : ii; 
      int drawIdx = ii;                             

      float amp = bandAmp[i];
      float rip = ripple[drawIdx];
      float t   = (float)drawIdx / (N - 1);  

      float perp_dx = (drawIdx < N-1) ? sx[drawIdx] - sx[drawIdx+1] : vxx;
      float perp_dy = (drawIdx < N-1) ? sy[drawIdx] - sy[drawIdx+1] : vyy;
      float perp_len = dist(0, 0, perp_dx, perp_dy);
      float px = 0, py = 0;
      if (perp_len > 0.01) { px = -perp_dy / perp_len; py = perp_dx / perp_len; }

      float freqSpeed = map(i, 0, N-1, 0.04, 0.35);
      float wiggleAmt = sin(pg.parent.frameCount * freqSpeed + drawIdx * 0.6) * amp * 0.45;
      float wx = sx[drawIdx] + px * wiggleAmt;
      float wy = sy[drawIdx] + py * wiggleAmt;

      float r = constrain(lerp(14, 3, t) + amp * 0.5 + rip * 5, 3, 24);

      float hueVal;
      switch (palette) {
        case 1:  hueVal = map(t, 0, 1, 0,   60);  break; 
        case 2:  hueVal = map(t, 0, 1, 180, 260); break; 
        case 3:  hueVal = 140; break;                      
        default: hueVal = map(t, 0, 1, 0, 270); break;    
      }
      float sat = map(rip, 0, 1, 210, 70);
      float bri = map(rip, 0, 1, 220, 255);

      float glowR = r * 2.0 + amp * 0.6;
      float glowA = constrain(lerp(40, 6, t) + amp * 1.5 + rip * 50, 0, 200);
      pg.fill(hueVal, sat, bri, glowA);
      pg.ellipse(wx, wy, glowR, glowR);

      pg.fill(hueVal, sat, bri * 0.50);
      pg.ellipse(wx, wy, r * 2, r * 2);

      pg.fill(hueVal, (int)(sat * 0.80), (int)(bri * 0.85));
      pg.ellipse(wx - r * 0.13, wy - r * 0.13, r * 1.65, r * 1.65);

      pg.fill(hueVal, (int)(sat * 0.55), bri);
      pg.ellipse(wx - r * 0.22, wy - r * 0.22, r * 1.05, r * 1.05);

      if (r > 4) {
        pg.fill(0, 0, 255, 220);   
        pg.ellipse(wx - r * 0.30, wy - r * 0.30, r * 0.42, r * 0.42);
      }
    }

    {
      float headR   = constrain(14 + bandAmp[0] * 0.5 + ripple[0] * 5, 8, 24);
      float faceAng = atan2(vyy, vxx);
      float perpX   = cos(faceAng + HALF_PI);
      float perpY   = sin(faceAng + HALF_PI);
      float eyeOff  = headR * 0.38;
      float eyeR    = headR * 0.34;
      float pupilR  = eyeR  * 0.52;
      float lookX   = cos(faceAng) * pupilR * 0.3;
      float lookY   = sin(faceAng) * pupilR * 0.3;

      pg.fill(0, 0, 255);
      pg.ellipse(sx[0] + perpX * eyeOff, sy[0] + perpY * eyeOff, eyeR * 2, eyeR * 2);
      pg.ellipse(sx[0] - perpX * eyeOff, sy[0] - perpY * eyeOff, eyeR * 2, eyeR * 2);
      pg.fill(0, 0, 0);
      pg.ellipse(sx[0] + perpX * eyeOff + lookX, sy[0] + perpY * eyeOff + lookY, pupilR, pupilR);
      pg.ellipse(sx[0] - perpX * eyeOff + lookX, sy[0] - perpY * eyeOff + lookY, pupilR, pupilR);
    }

    pg.colorMode(RGB, 255);

    String[] palNames = {"Spectrum", "Heat", "Ice", "Mono"};
    pg.pushStyle();
      float ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      pg.fill(0, 160); pg.noStroke(); pg.rectMode(CORNER);
      pg.rect(8, 8, 310 * uiScale(), mg + lh * 5);
      pg.fill(80, 200, 255); pg.textSize(ts); pg.textAlign(LEFT, TOP);
      pg.text("FFT Worm  (" + N + " bands)",                             12, 8 + mg);
      pg.fill(180, 220, 255);
      pg.text("Palette: " + palNames[palette] + "  (Y cycle)",           12, 8 + mg + lh);
      pg.text("Reactivity: " + nf(ampMult,1,2) + "  (R ↕)",             12, 8 + mg + lh * 2);
      pg.text("Speed: " + nf(speedScale,1,2) + "  (LT / RT)",           12, 8 + mg + lh * 3);
      pg.text("A=circle  B=wander  X=reverse  L=steer",                  12, 8 + mg + lh * 4);
    pg.popStyle();

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    steering = sqrt(lx*lx + ly*ly) > 0.18;
    if (steering) { steerX = c.lx; steerY = c.ly; }
    float ry = map(c.ry, 0, height, -1, 1);
    ampMult = map(ry, -1, 1, 3.0, 0.3);
    try {
      float z = c.stick.getSlider("z").getValue();
      speedScale = map(z, -1, 1, 0.2, 2.5);
    } catch (Exception e) {}
    if (c.aJustPressed) { circleMode = true; }
    if (c.bJustPressed) { circleMode = false; }
    if (c.xJustPressed) { reversed   = !reversed; }
    if (c.yJustPressed) { palette    = (palette + 1) % 4; }
  }

  void onEnter() { background(5, 5, 14); }
  void onExit() {}
  void handleKey(char k) {
    if (k == 'a') circleMode = true;
    if (k == 'b') circleMode = false;
    if (k == 'x') reversed   = !reversed;
  }
  
  String[] getCodeLines() {
    return new String[] {
      "=== FFT Worm ===",
      "// Logic: Spectrum-driven Segments",
      "Head = sub-bass, tail = highs",
      "seg_radius = lerp(14, 3, t) + amp * 0.5 + ripple * 5"
    };
  }
}
